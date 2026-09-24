import SwiftUI

@main
struct SMSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("SMSync") {
            ContentView()
                .environmentObject(SyncViewModel.shared)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover = NSPopover()
    var viewModel: SyncViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ContactResolver.shared.resolveAllContacts()
        setupMenuBar()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "message.fill", accessibilityDescription: "SMSync")
            button.action = #selector(togglePopover)
            button.target = self
        }

        viewModel = SyncViewModel.shared
        viewModel?.startDiscovery()
        popover.contentViewController = NSHostingController(rootView: MenuBarView(viewModel: viewModel!))
        popover.behavior = .transient
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            if !(viewModel?.isConnected ?? false) {
                viewModel?.startDiscovery()
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
