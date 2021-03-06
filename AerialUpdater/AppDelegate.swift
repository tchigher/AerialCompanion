//
//  AppDelegate.swift
//  AerialUpdater
//
//  Created by Guillaume Louel on 24/07/2020.
//

import Cocoa

enum IconMode {
    case normal, updating, notification
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    lazy var firstTimeSetupWindowController = FirstTimeSetupWindowController()

    lazy var menuViewController = MenuViewController()
    
    // MARK: - Lifecycle
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        debugLog("Version \(Helpers.version) launched on  \(ProcessInfo.processInfo.operatingSystemVersionString)")
        //Preferences.firstTimeSetup = false
        
        let arguments = ProcessInfo.processInfo.arguments

        // Ensure not in bundle
        ensureNotInBundle()
        
        // This is imperative, breaks everything
        ensureNotInstalledForAllUsers()
        
        if arguments.contains("--silent") {
            debugLog("Background mode")

            // Returns true if we need to stay around
            if !silentModeCheck() {
                return
            }
            // We're staying then !
            debugLog("Falling back to menu for a notification")
        } else if !Preferences.firstTimeSetup {
            debugLog("Do First Time Setup")
            doFirstTimeSetup()
        }
        
        // Menu mode, we may fall down here from silent mode too in notify mode,
        // or if we must update
        
        // Set the icon
        setIcon(mode: .normal)
        
        createMenu()
    }
    
    func ensureNotInBundle() {
        do {
            let info = try Bundle.main.bundleURL.resourceValues(forKeys: [.volumeNameKey])
            if let volume = info.volumeName {
                if volume.starts(with: "Aerial") {
                    Helpers.showErrorAlert(question: "Oops", text: "Aerial can only be run from the Applications folder. Drag Aerial to Applications, then open Applications and run it again.", button: "Ok")
                    
                    NSApplication.shared.terminate(self)
                }
            }
        } catch {
            errorLog("Ensure bundle error")
        }
    }
    
    func doFirstTimeSetup() {
        var topLevelObjects: NSArray? = NSArray()
        if !Bundle.main.loadNibNamed(NSNib.Name("FirstTimeSetupWindowController"),
                            owner: firstTimeSetupWindowController,
                            topLevelObjects: &topLevelObjects) {
            errorLog("Could not load nib for FirstTimeSetup, please report")
        }
        firstTimeSetupWindowController.windowDidLoad()
        firstTimeSetupWindowController.showWindow(self)
        firstTimeSetupWindowController.window!.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // This returns true if we should stay around, and false if we can safely return
    func silentModeCheck() -> Bool {
        Update.instance.commandLine = true

        // Force a cache update
        CachedManifest.instance.updateNow()

        // Make sure we don't need to update, or redirect you there
        if UpdaterVersion.needsUpdating() {
            return true         // Then stay around !
        }
        
        let (stringVersion, shouldInstall) = Update.instance.check()

        if shouldInstall {
            debugLog(stringVersion)
            if Preferences.updateMode == .automatic {
                Update.instance.unattendedPerform()
                return false    // We are done
            } else {
                return true     // Stay around !
            }
        } else {
            // We need to stay around for a bit, because if not
            // launchd will think we are crashing...
            debugLog("No new version, quitting in 20sec.")
            RunLoop.main.run(until: Date() + 0x14)
            NSApplication.shared.terminate(self)

            return false
        }
    }
    
    // Ensure we don't have something in /Library/Screen Savers/
    func ensureNotInstalledForAllUsers() {
        if LocalVersion.isInstalledForAllUsers() {
            NSApp.activate(ignoringOtherApps: true)
            // Open finder with the file selected
            NSWorkspace.shared.selectFile(LocalVersion.aerialAllUsersPath, inFileViewerRootedAtPath: "/Library/Screen Savers/")

            while LocalVersion.isInstalledForAllUsers() {
                let result = Helpers.showAlert(question: "Aerial is currently installed for All Users", text: "In order for the updater to work, you need to uninstall the current version of Aerial. \n\nYou can do this by deleting the Aerial.saver file in the Finder window that just opened. Press Try Again when done.", button1: "Try Again", button2: "Quit")

                if !result {
                    // Quit !
                    NSApplication.shared.terminate(self)
                }
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    // Change the icon based on status
    func setIcon(mode: IconMode) {
        DispatchQueue.main.async {
            print("setIcon \(mode)")
            switch mode {
            case .normal:
                self.statusItem.image = NSImage(named: "Status48")
            case .updating:
                self.statusItem.image = NSImage(named: "StatusTransp48")
            case .notification:
                self.statusItem.image = NSImage(named: "Status48Attention")
            }

            self.statusItem.image?.size.width = 22
            self.statusItem.image?.size.height = 22
        }
    }
    
    // MARK: - Menu Content Setup and Update
    // Load the menu from MenuView.xib and attach it to our StatusItem
    func createMenu() {
        var topLevelObjects: NSArray? = NSArray()

        menuViewController.setDelegate(self)
        // Grab the menu from the nib
        Bundle.main.loadNibNamed("MenuView", owner: menuViewController, topLevelObjects: &topLevelObjects)
        
        // This bugs me a lot, I shouldn't have to call this manually ?
        menuViewController.viewDidLoad()

        // Grab the menu from the nib and set it
        let objs = topLevelObjects! as [AnyObject]
        for obj in objs {
            if obj is NSMenu {
                // Menu found, set it on our statusItem !
                statusItem.menu = obj as? NSMenu
            }
        }
    }
    
    func updateMenu() {
        print("upd")
        menuViewController.updateMenuSettings()
    }
    func updateMenuContent() {
        menuViewController.updateMenuContent()
    }
}

