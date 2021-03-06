import Cocoa
import ApplicationServices

class Applications {
    static var list = [Application]()

    static func observeNewWindows() {
        for app in list {
            guard app.runningApplication.isFinishedLaunching else { continue }
            app.observeNewWindows()
        }
    }

    static func observeNewWindowsBlocking() {
        let group = DispatchGroup()
        for app in list {
            guard app.runningApplication.isFinishedLaunching else { continue }
            app.observeNewWindows(group)
        }
        _ = group.wait(wallTimeout: .now() + .seconds(1))
    }

    static func initialDiscovery() {
        addInitialRunningApplications()
        addInitialRunningApplicationsWindows()
        WorkspaceEvents.observeRunningApplications()
    }

    static func addInitialRunningApplications() {
        addRunningApplications(NSWorkspace.shared.runningApplications)
    }

    static func addInitialRunningApplicationsWindows() {
        let otherSpaces = Spaces.otherSpaces()
        if otherSpaces.count == 0 {
            Applications.observeNewWindows()
        } else {
            let windowsOnCurrentSpace = Spaces.windowsInSpaces([Spaces.currentSpaceId])
            let windowsOnOtherSpaces = Spaces.windowsInSpaces(otherSpaces)
            let windowsOnlyOnOtherSpaces = Array(Set(windowsOnOtherSpaces).subtracting(windowsOnCurrentSpace))
            if windowsOnlyOnOtherSpaces.count > 0 {
                // on initial launch, we use private APIs to bring windows from other spaces into the current space, observe them, then remove them from the current space
                CGSAddWindowsToSpaces(cgsMainConnectionId, windowsOnlyOnOtherSpaces as NSArray, [Spaces.currentSpaceId])
                Applications.observeNewWindowsBlocking()
                CGSRemoveWindowsFromSpaces(cgsMainConnectionId, windowsOnlyOnOtherSpaces as NSArray, [Spaces.currentSpaceId])
            }
        }
    }

    static func addRunningApplications(_ runningApps: [NSRunningApplication]) {
        runningApps.forEach {
            if isActualApplication($0) {
                Applications.list.append(Application($0))
            }
        }
    }

    static func removeRunningApplications(_ runningApps: [NSRunningApplication]) {
        var windowsOnTheLeftOfFocusedWindow = 0
        for runningApp in runningApps {
            Applications.list.removeAll(where: { $0.runningApplication.isEqual(runningApp) })
            Windows.list.enumerated().forEach { (index, window) in
                if window.application.runningApplication.isEqual(runningApp) && index < Windows.focusedWindowIndex {
                    windowsOnTheLeftOfFocusedWindow += 1
                }
            }
            Windows.list.removeAll(where: { $0.application.runningApplication.isEqual(runningApp) })
        }
        guard Windows.list.count > 0 else { App.app.hideUi(); return }
        if windowsOnTheLeftOfFocusedWindow > 0 {
            Windows.cycleFocusedWindowIndex(-windowsOnTheLeftOfFocusedWindow)
        }
        App.app.refreshOpenUi()
    }

    static func refreshBadges() {
        retryAxCallUntilTimeout {
            let axDock = AXUIElementCreateApplication(Applications.list.first { $0.runningApplication.bundleIdentifier == "com.apple.dock" }!.runningApplication.processIdentifier)
            let axList = try axDock.children()!.first { try $0.role() == "AXList" }!
            let axAppDockItem = try axList.children()!.filter { try $0.subrole() == "AXApplicationDockItem" && ($0.appIsRunning() ?? false) }
            try Applications.list.forEach { app in
                if app.runningApplication.activationPolicy == .regular,
                   let bundleId = app.runningApplication.bundleIdentifier,
                   let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    app.dockLabel = try axAppDockItem.first { try $0.attribute(kAXURLAttribute, URL.self) == url }?.attribute(kAXStatusLabelAttribute, String.self)
                }
            }
        }
    }

    private static func isActualApplication(_ app: NSRunningApplication) -> Bool {
        return (app.activationPolicy != .prohibited || isNotXpc(app)) && notAltTab(app)
    }

    private static func isNotXpc(_ app: NSRunningApplication) -> Bool {
        return app.bundleURL
            .flatMap { Bundle(url: $0) }
            .flatMap { $0.infoDictionary }
            .flatMap { $0["CFBundlePackageType"] as? String } != "XPC!"
    }

    // managing AltTab windows within AltTab create all sorts of side effects
    // e.g. hiding the thumbnails panel gives focus to the preferences panel if open, thus changing its order in the list
    private static func notAltTab(_ app: NSRunningApplication) -> Bool {
        return app.processIdentifier != ProcessInfo.processInfo.processIdentifier
    }
}
