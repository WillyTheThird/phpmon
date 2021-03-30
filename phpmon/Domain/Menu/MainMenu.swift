//
//  MainMenu.swift
//  PHP Monitor
//
//  Copyright © 2021 Nico Verbruggen. All rights reserved.
//

import Cocoa

class MainMenu: NSObject, NSWindowDelegate {

    static let shared = MainMenu()
    
    /**
     The status bar item with variable length.
     */
    let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength
    )
    
    // MARK: - UI related
    
    /**
     Kick off the startup of the rendering of the main menu.
     */
    func startup() {
        // Start with the icon
        setStatusBar(image: NSImage(named: NSImage.Name("StatusBarIcon"))!)
        
        // Perform environment boot checks
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            Startup().checkEnvironment(success: { onEnvironmentPass() },
                                       failure: { onEnvironmentFail() }
            )
        }
    }
    
    /**
     When the environment is all clear and the app can run, let's go.
     */
    private func onEnvironmentPass() {
        App.shared.availablePhpVersions = Actions.detectPhpVersions()
        updatePhpVersionInStatusBar()
        
        // Schedule a request to fetch the PHP version every 60 seconds
        DispatchQueue.main.async { [self] in
            App.shared.timer = Timer.scheduledTimer(
                timeInterval: 60,
                target: self,
                selector: #selector(updatePhpVersionInStatusBar),
                userInfo: nil,
                repeats: true
            )
        }
    }
    
    /**
     When the environment is not OK, present an alert to inform the user.
     */
    private func onEnvironmentFail() {
        DispatchQueue.main.async { [self] in
            let close = Alert.present(
                messageText: "alert.cannot_start.title".localized,
                informativeText: "alert.cannot_start.info".localized,
                buttonTitle: "alert.cannot_start.close".localized,
                secondButtonTitle: "alert.cannot_start.retry".localized
            )
            
            if (close) {
                exit(1)
            }
            
            startup()
        }
    }
    
    /**
     Update the menu's contents, based on what's going on.
     */
    func update() {
        // Update the menu item on the main thread
        DispatchQueue.main.async { [self] in
            // Create a new menu
            let menu = StatusMenu()
            
            // Add the PHP versions (or error messages)
            menu.addPhpVersionMenuItems()
            menu.addItem(NSMenuItem.separator())
            
            // Add the possible actions
            menu.addPhpActionMenuItems()
            menu.addItem(NSMenuItem.separator())
            
            // Add information about services & actions
            menu.addPhpConfigurationMenuItems()
            menu.addItem(NSMenuItem.separator())
            
            // Add about & quit menu items
            menu.addItem(NSMenuItem(title: "mi_preferences".localized, action: #selector(openPrefs), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "mi_about".localized, action: #selector(openAbout), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "mi_quit".localized, action: #selector(terminateApp), keyEquivalent: "q"))
            
            // Make sure every item can be interacted with
            menu.items.forEach({ (item) in
                item.target = self
            })
            
            statusItem.menu = menu
        }
    }
    
    /**
     Sets the status bar image based on a version string.
     */
    func setStatusBarImage(version: String) {
        setStatusBar(
            image: MenuBarImageGenerator.textToImage(text: version)
        )
    }
    
    /**
     Sets the status bar image, based on the provided NSImage.
     The image will be used as a template image.
     */
    func setStatusBar(image: NSImage) {
        if let button = statusItem.button {
            image.isTemplate = true
            button.image = image
        }
    }
    
    // MARK: - Nicer callbacks
    
    /**
     Executes a specific callback and fires the completion callback,
     while updating the UI as required. As long as the completion callback
     does not fire, the app is presumed to be busy and the UI reflects this.
     
     - Parameter execute: Callback of the work that needs to happen.
     - Parameter completion: Callback that is fired when the work is done.
     */
    private func waitAndExecute(_ execute: @escaping () -> Void, completion: @escaping () -> Void = {})
    {
        App.shared.busy = true
        setBusyImage()
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            update()
            execute()
            App.shared.busy = false
            
            DispatchQueue.main.async { [self] in
                updatePhpVersionInStatusBar()
                update()
                completion()
            }
        }
    }
    
    // MARK: - User Interface
    
    @objc func updatePhpVersionInStatusBar() {
        App.shared.currentInstall = PhpInstallation()
        refreshIcon()
        update()
    }
    
    func refreshIcon() {
        DispatchQueue.main.async { [self] in
            if (App.busy) {
                setStatusBar(image: NSImage(named: NSImage.Name("StatusBarIcon"))!)
            } else {
                if Preferences.preferences[.shouldDisplayDynamicIcon] == false {
                    // Static icon has been requested
                    setStatusBar(image: NSImage(named: NSImage.Name("StatusBarIconStatic"))!)
                } else {
                    // The dynamic icon has been requested
                    setStatusBarImage(version: App.phpInstall!.version.short)
                }
            }
        }
    }
    
    @objc func reloadPhpMonitorMenuInBackground() {
        waitAndExecute {
            // This automatically reloads the menu
            print("Reloading information about the PHP installation (in the background)...")
        }
    }
    
    @objc func reloadPhpMonitorMenu() {
        waitAndExecute({
            // This automatically reloads the menu
            print("Reloading information about the PHP installation...")
        }, completion: {
            // Add a slight delay to make sure it loads the new menu
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Open the menu again
                MainMenu.shared.statusItem.button?.performClick(nil)
            }
        })
    }
    
    @objc func setBusyImage() {
        DispatchQueue.main.async { [self] in
            setStatusBar(image: NSImage(named: NSImage.Name("StatusBarIcon"))!)
        }
    }
    
    // MARK: - Actions
    
    @objc func restartPhpFpm() {
        waitAndExecute({
            Actions.restartPhpFpm()
        })
    }
    
    @objc func restartAllServices() {
        waitAndExecute {
            Actions.restartDnsMasq()
            Actions.restartPhpFpm()
            Actions.restartNginx()
        }
    }
    
    @objc func restartNginx() {
        waitAndExecute {
            Actions.restartNginx()
        }
    }
    
    @objc func restartDnsMasq() {
        waitAndExecute {
            Actions.restartDnsMasq()
        }
    }
    
    @objc func toggleExtension(sender: ExtensionMenuItem) {
        waitAndExecute {
            sender.phpExtension?.toggle()
        }
    }
    
    @objc func openPhpInfo() {
        waitAndExecute {
            try! "<?php phpinfo();".write(toFile: "/tmp/phpmon_phpinfo.php", atomically: true, encoding: .utf8)
            Shell.run("\(Paths.binPath)/php-cgi -q /tmp/phpmon_phpinfo.php > /tmp/phpmon_phpinfo.html")
        } completion: {
            NSWorkspace.shared.open(URL(string: "file:///private/tmp/phpmon_phpinfo.html")!)
        }
    }
    
    @objc func forceRestartLatestPhp() {
        // Tell the user the switch is about to occur
        Alert.notify(message: "alert.force_reload.title".localized, info: "alert.force_reload.info".localized)
        
        // Start switching
        waitAndExecute {
            Actions.fixMyPhp()
        } completion: {
            Alert.notify(message: "alert.force_reload_done.title".localized, info: "alert.force_reload_done.info".localized)
        }
    }
    
    @objc func openActiveConfigFolder() {
        if (App.phpInstall!.version.error) {
            // php version was not identified
            Actions.openGenericPhpConfigFolder()
            return
        }
        
        // php version was identified
        Actions.openPhpConfigFolder(version: App.phpInstall!.version.short)
    }
    
    @objc func openValetConfigFolder() {
        Actions.openValetConfigFolder()
    }
    
    @objc func switchToPhpVersion(sender: PhpMenuItem) {
        // print("Switching to: PHP \(sender.version)")
        
        setBusyImage()
        App.shared.busy = true
        
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            // Update the PHP version in the status bar
           updatePhpVersionInStatusBar()
            
            // Update the menu
            update()
            
            // Switch the PHP version
            Actions.switchToPhpVersion(
                version: sender.version,
                availableVersions: App.shared.availablePhpVersions
            )
            
            // Mark as no longer busy
            App.shared.busy = false
            
            // Perform UI updates on main thread
            DispatchQueue.main.async { [self] in
                updatePhpVersionInStatusBar()
                update()
                
                // Send a notification that the switch has been completed
                LocalNotification.send(
                    title: String(format: "notification.version_changed_title".localized, sender.version),
                    subtitle: String(format: "notification.version_changed_desc".localized, sender.version)
                )
            }
        }
    }
    
    @objc func openAbout() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel()
    }
    
    @objc func openPrefs() {
        PrefsVC.show()
    }
    
    @objc func terminateApp() {
        NSApplication.shared.terminate(nil)
    }
}
