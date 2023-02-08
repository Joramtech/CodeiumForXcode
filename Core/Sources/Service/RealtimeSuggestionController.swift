import AppKit
import CGEventObserver
import Foundation
import os.log
import QuartzCore
import SwiftUI
import XPCShared

public actor RealtimeSuggestionController {
    public static let shared = RealtimeSuggestionController()

    private var listeners = Set<AnyHashable>()
    var eventObserver: CGEventObserverType = CGEventObserver(eventsOfInterest: [
        .keyUp,
        .keyDown,
        .rightMouseDown,
        .leftMouseDown,
    ])
    private var task: Task<Void, Error>?
    private var inflightPrefetchTask: Task<Void, Error>?
    let realtimeSuggestionIndicatorController = RealtimeSuggestionIndicatorController()

    private init() {
        // Start the auto trigger if Xcode is running.
        Task {
            for xcode in await Environment.runningXcodes() {
                await start(by: xcode.processIdentifier)
            }
            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didLaunchApplicationNotification)
            for await notification in sequence {
                try Task.checkCancellation()
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { continue }
                guard app.bundleIdentifier == "com.apple.dt.Xcode" else { continue }
                await start(by: app.processIdentifier)
            }
        }

        // Remove listener if Xcode is terminated.
        Task {
            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didTerminateApplicationNotification)
            for await notification in sequence {
                try Task.checkCancellation()
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { continue }
                guard app.bundleIdentifier == "com.apple.dt.Xcode" else { continue }
                await stop(by: app.processIdentifier)
            }
        }
    }

    private func start(by listener: AnyHashable) {
        os_log(.info, "Add auto trigger listener: %@.", listener as CVarArg)
        listeners.insert(listener)

        if task == nil {
            task = Task { [stream = eventObserver.stream] in
                for await event in stream {
                    await self.handleKeyboardEvent(event: event)
                }
            }
        }
        if eventObserver.activateIfPossible() {
            realtimeSuggestionIndicatorController?.isObserving = true
        }
    }

    private func stop(by listener: AnyHashable) {
        os_log(.info, "Remove auto trigger listener: %@.", listener as CVarArg)
        listeners.remove(listener)
        guard listeners.isEmpty else { return }
        os_log(.info, "Auto trigger is stopped.")
        task?.cancel()
        task = nil
        eventObserver.deactivate()
        realtimeSuggestionIndicatorController?.isObserving = false
    }

    func handleKeyboardEvent(event: CGEvent) async {
        inflightPrefetchTask?.cancel()

        if Task.isCancelled { return }
        guard await Environment.isXcodeActive() else { return }

        // cancel in-flight tasks
        await withTaskGroup(of: Void.self) { group in
            for (_, workspace) in await workspaces {
                group.addTask {
                    await workspace.cancelInFlightRealtimeSuggestionRequests()
                }
            }
            group.addTask {
                await { @ServiceActor in
                    inflightRealtimeSuggestionsTasks.forEach { $0.cancel() }
                    inflightRealtimeSuggestionsTasks.removeAll()
                }()
            }
        }

        let escape = 0x35
        let isEditing = await Environment.frontmostXcodeWindowIsEditor()

        // if Xcode suggestion panel is presenting, and we are not trying to close it
        // ignore this event.
        if !isEditing, event.getIntegerValueField(.keyboardEventKeycode) != escape {
            return
        }

        let shouldTrigger = {
            // closing auto-complete panel
            if isEditing, event.getIntegerValueField(.keyboardEventKeycode) == escape {
                return true
            }

            // normally typing
            if event.type == .keyUp,
               event.getIntegerValueField(.keyboardEventKeycode) != escape
            {
                return true
            }

            return false
        }()

        guard shouldTrigger else { return }

        inflightPrefetchTask = Task { @ServiceActor in
            try? await Task.sleep(nanoseconds: UInt64(
                UserDefaults.shared
                    .value(forKey: SettingsKey.realtimeSuggestionDebounce) as? Int
                    ?? 800_000_000
            ))
            guard UserDefaults.shared.bool(forKey: SettingsKey.realtimeSuggestionToggle)
            else { return }
            if Task.isCancelled { return }
            os_log(.info, "Prefetch suggestions.")
            do {
                try await Environment.triggerAction("Prefetch Suggestions")
            } catch {
                os_log(.info, "%@", error.localizedDescription)
            }
        }
    }
}

/// Present a tiny dot next to mouse cursor if real-time suggestion is enabled.
final class RealtimeSuggestionIndicatorController {
    struct IndicatorContentView: View {
        @State var opacity: CGFloat = 1
        @State var scale: CGFloat = 1
        var body: some View {
            Circle()
                .fill(Color.accentColor.opacity(opacity))
                .scaleEffect(.init(width: scale, height: scale))
                .frame(width: 8, height: 8)
                .onAppear {
                    Task {
                        await Task.yield() // to avoid unwanted translations.
                        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                            opacity = 0.5
                            scale = 0.5
                        }
                    }
                }
        }
    }

    class UserDefaultsObserver: NSObject {
        var onChange: (() -> Void)?

        override func observeValue(
            forKeyPath keyPath: String?,
            of object: Any?,
            change: [NSKeyValueChangeKey: Any]?,
            context: UnsafeMutableRawPointer?
        ) {
            onChange?()
        }
    }

    private var displayLink: CVDisplayLink!
    private var isDisplayLinkStarted: Bool = false
    private var userDefaultsObserver = UserDefaultsObserver()
    var isObserving = false {
        didSet {
            Task {
                await updateIndicatorVisibility()
            }
        }
    }

    @MainActor
    let window = {
        let it = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .white.withAlphaComponent(0)
        it.level = .statusBar
        it.contentView = NSHostingView(
            rootView: IndicatorContentView().frame(minWidth: 10, minHeight: 10)
        )
        return it
    }()

    init?() {
        _ = CVDisplayLinkCreateWithCGDisplay(CGMainDisplayID(), &displayLink)
        guard displayLink != nil else { return nil }
        CVDisplayLinkSetOutputHandler(displayLink) { [weak self] _, _, _, _, _ in
            guard let self else { return kCVReturnSuccess }
            self.updateIndicatorLocation()
            return kCVReturnSuccess
        }

        Task {
            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didActivateApplicationNotification)
            for await notification in sequence {
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { continue }
                guard app.bundleIdentifier == "com.apple.dt.Xcode" else { continue }
                await updateIndicatorVisibility()
            }
        }

        Task {
            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didDeactivateApplicationNotification)
            for await notification in sequence {
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { continue }
                guard app.bundleIdentifier == "com.apple.dt.Xcode" else { continue }
                await updateIndicatorVisibility()
            }
        }

        Task {
            userDefaultsObserver.onChange = { [weak self] in
                Task { [weak self] in
                    await self?.updateIndicatorVisibility()
                }
            }
            UserDefaults.shared.addObserver(
                userDefaultsObserver,
                forKeyPath: SettingsKey.realtimeSuggestionToggle,
                options: .new,
                context: nil
            )
        }
    }

    private func updateIndicatorVisibility() async {
        let isVisible = await {
            let isOn = UserDefaults.shared.bool(forKey: SettingsKey.realtimeSuggestionToggle)
            let isXcodeActive = await Environment.isXcodeActive()
            return isOn && isXcodeActive && isObserving
        }()

        await { @MainActor in
            guard window.isVisible != isVisible else { return }
            if isVisible {
                CVDisplayLinkStart(self.displayLink)
            } else {
                CVDisplayLinkStop(self.displayLink)
            }
            window.setIsVisible(isVisible)
        }()
    }

    private func updateIndicatorLocation() {
        Task { @MainActor in
            if !window.isVisible {
                return
            }

            var frame = window.frame
            let location = NSEvent.mouseLocation
            frame.origin = .init(x: location.x + 15, y: location.y + 15)
            frame.size = .init(width: 10, height: 10)
            window.setFrame(frame, display: false)
            window.makeKey()
        }
    }
}