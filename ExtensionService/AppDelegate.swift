import AppKit
import Environment
import FileChangeChecker
import LaunchAgentManager
import Logger
import Preferences
import Service
import ServiceManagement
import ServiceUpdateMigration
import SwiftUI
import UpdateChecker
import UserDefaultsObserver
import UserNotifications

let bundleIdentifierBase = Bundle.main
    .object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String
let serviceIdentifier = bundleIdentifierBase + ".ExtensionService"

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let scheduledCleaner = ScheduledCleaner()
    private var statusBarItem: NSStatusItem!
    private var xpcListener: (NSXPCListener, ServiceDelegate)?
    private let updateChecker =
        UpdateChecker(
            hostBundle: locateHostBundleURL(url: Bundle.main.bundleURL)
                .flatMap(Bundle.init(url:))
        )

    func applicationDidFinishLaunching(_: Notification) {
        if ProcessInfo.processInfo.environment["IS_UNIT_TEST"] == "YES" { return }
        _ = GraphicalUserInterfaceController.shared
        _ = RealtimeSuggestionController.shared
        setupQuitOnUpdate()
        setupQuitOnUserTerminated()
        xpcListener = setupXPCListener()
        Logger.service.info("XPC Service started.")
        NSApp.setActivationPolicy(.accessory)
        buildStatusBarMenu()
        Task {
            do {
                try await ServiceUpdateMigrator().migrate()
            } catch {
                Logger.service.error(error.localizedDescription)
            }
        }
    }

    @objc private func buildStatusBarMenu() {
        let statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(
            withLength: NSStatusItem.squareLength
        )
        statusBarItem.button?.image = NSImage(named: "MenuBarIcon")

        let statusBarMenu = NSMenu(title: "Status Bar Menu")
        statusBarItem.menu = statusBarMenu

        let hostAppName = Bundle.main.object(forInfoDictionaryKey: "HOST_APP_NAME") as? String
            ?? "Codeium for Xcode"

        let copilotName = NSMenuItem(
            title: hostAppName,
            action: nil,
            keyEquivalent: ""
        )

        let checkForUpdate = NSMenuItem(
            title: "Check for Updates",
            action: #selector(checkForUpdate),
            keyEquivalent: ""
        )

        let openCopilotForXcode = NSMenuItem(
            title: "Open \(hostAppName)",
            action: #selector(openCopilotForXcode),
            keyEquivalent: ""
        )

        let openGlobalChat = NSMenuItem(
            title: "Open Chat",
            action: #selector(openGlobalChat),
            keyEquivalent: ""
        )

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: ""
        )
        quitItem.target = self

        statusBarMenu.addItem(copilotName)
        statusBarMenu.addItem(openCopilotForXcode)
        statusBarMenu.addItem(checkForUpdate)
//        statusBarMenu.addItem(.separator())
//        statusBarMenu.addItem(openGlobalChat)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(quitItem)
    }

    @objc func quit() {
        exit(0)
    }

    @objc func openCopilotForXcode() {
        let task = Process()
        if let appPath = locateHostBundleURL(url: Bundle.main.bundleURL)?.absoluteString {
            task.launchPath = "/usr/bin/open"
            task.arguments = [appPath]
            task.launch()
            task.waitUntilExit()
        }
    }

    @objc func openGlobalChat() {
        Task { @MainActor in
            let serviceGUI = GraphicalUserInterfaceController.shared
            serviceGUI.openGlobalChat()
        }
    }

    func setupQuitOnUpdate() {
        Task {
            guard let url = Bundle.main.executableURL else { return }
            let checker = await FileChangeChecker(fileURL: url)

            // If Xcode or Copilot for Xcode is made active, check if the executable of this program
            // is changed. If changed, quit this program.

            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didActivateApplicationNotification)
            for await notification in sequence {
                try Task.checkCancellation()
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                    app.isUserOfService
                else { continue }
                guard await checker.checkIfChanged() else {
                    Logger.service.info("Extension Service is not updated, no need to quit.")
                    continue
                }
                Logger.service.info("Extension Service will quit.")
                #if DEBUG
                #else
                exit(0)
                #endif
            }
        }
    }

    func setupQuitOnUserTerminated() {
        Task {
            // Whenever Xcode or the host application quits, check if any of the two is running.
            // If none, quit the XPC service.

            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didTerminateApplicationNotification)
            for await notification in sequence {
                try Task.checkCancellation()
                guard UserDefaults.shared.value(for: \.quitXPCServiceOnXcodeAndAppQuit)
                else { continue }
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                    app.isUserOfService
                else { continue }
                if NSWorkspace.shared.runningApplications.contains(where: \.isUserOfService) {
                    continue
                }
                exit(0)
            }
        }
    }

    func setupXPCListener() -> (NSXPCListener, ServiceDelegate) {
        let listener = NSXPCListener(machServiceName: serviceIdentifier)
        let delegate = ServiceDelegate()
        listener.delegate = delegate
        listener.resume()
        return (listener, delegate)
    }

    func requestAccessoryAPIPermission() {
        AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true,
        ] as NSDictionary)
    }

    @objc func checkForUpdate() {
        updateChecker.checkForUpdates()
    }
}

extension NSRunningApplication {
    var isUserOfService: Bool {
        [
            "com.apple.dt.Xcode",
            bundleIdentifierBase,
        ].contains(bundleIdentifier)
    }
}

func locateHostBundleURL(url: URL) -> URL? {
    var nextURL = url
    while nextURL.path != "/" {
        nextURL = nextURL.deletingLastPathComponent()
        if nextURL.lastPathComponent.hasSuffix(".app") {
            return nextURL
        }
    }
    let devAppURL = url
        .deletingLastPathComponent()
        .appendingPathComponent("Codeium for Xcode Dev.app")
    return devAppURL
}

