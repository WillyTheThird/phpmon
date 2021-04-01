//
//  Services.swift
//  PHP Monitor
//
//  Copyright © 2021 Nico Verbruggen. All rights reserved.
//

import Foundation
import AppKit

class Actions {
    
    // MARK: - Detect PHP Versions
    
    public static func detectPhpVersions() -> [String]
    {
        let files = Shell.pipe("ls \(Paths.optPath) | grep php@")
        var versions = files.components(separatedBy: "\n")
        
        // Remove all empty strings
        versions.removeAll { (string) -> Bool in
            return (string == "")
        }
        
        // Get a list of versions only
        var versionsOnly : [String] = []
        versions.forEach { (string) in
            let version = string.components(separatedBy: "php@")[1]
            // Only append the version if it doesn't already exist (avoid dupes)
            if !versionsOnly.contains(version)
                // and make sure that the version is supported
                && Constants.SupportedPhpVersions.contains(version)
            {
                versionsOnly.append(version)
            }
        }
        
        // Make sure the aliased version is detected
        // The user may have `php` installed, but not e.g. `php@8.0`
        // We should also detect that as a version that is installed
        let phpAlias = App.shared.brewPhpVersion
        
        // Avoid inserting a duplicate
        if (!versionsOnly.contains(phpAlias)) {
            versionsOnly.append(phpAlias);
        }
        
        return versionsOnly
    }
    
    // MARK: - Services
    
    public static func restartPhpFpm()
    {
        brew("services restart \(App.phpInstall!.formula)", sudo: true)
    }
    
    public static func restartNginx()
    {
        brew("services restart nginx", sudo: true)
    }
    
    public static func restartDnsMasq()
    {
        brew("services restart dnsmasq", sudo: true)
    }
    
    public static func switchToPhpVersion(version: String, availableVersions: [String])
    {
        valet("use php@\(version)")
    }
    
    // MARK: - Finding Config Files
    
    public static func openGenericPhpConfigFolder()
    {
        let files = [NSURL(fileURLWithPath: "\(Paths.etcPath)/php")];
        NSWorkspace.shared.activateFileViewerSelecting(files as [URL])
    }
    
    public static func openPhpConfigFolder(version: String)
    {
        let files = [NSURL(fileURLWithPath: "\(Paths.etcPath)/php/\(version)/php.ini")];
        NSWorkspace.shared.activateFileViewerSelecting(files as [URL])
    }
    
    public static func openValetConfigFolder()
    {
        let files = [NSURL(fileURLWithPath: NSString(string: "~/.config/valet").expandingTildeInPath)];
        NSWorkspace.shared.activateFileViewerSelecting(files as [URL])
    }
    
    // MARK: - Quick Fix
    
    /**
     Detects all currently available PHP versions, and unlinks each and every one of them.
     After this, the brew services are also stopped, the latest PHP version is linked, and php + nginx are restarted.
     If this does not solve the issue, the user may need to install additional extensions and/or run `composer global update`.
     */
    public static func fixMyPhp()
    {
        brew("services restart dnsmasq", sudo: true)
        
        detectPhpVersions().forEach { (version) in
            let formula = (version == App.shared.brewPhpVersion) ? "php" : "php@\(version)"
            brew("unlink php@\(version)")
            brew("services stop \(formula)")
            brew("services stop \(formula)", sudo: true)
        }
        
        brew("services stop php")
        brew("services stop nginx")
        brew("link php")
        brew("services restart dnsmasq", sudo: true)
        brew("services stop php", sudo: true)
        brew("services stop nginx", sudo: true)
    }
    
    // MARK: Common Shell Commands
    
    /**
     Runs a `valet` command. Can run as superuser.
     */
    public static func valet(_ command: String)
    {
        // Sadly, this does not seem to work?
        Shell.run("\(Paths.valet) \(command)")
    }
    
    /**
     Runs a `brew` command. Can run as superuser.
     */
    public static func brew(_ command: String, sudo: Bool = false)
    {
        Shell.run("\(sudo ? "sudo " : "")" + "\(Paths.brew) \(command)")
    }
    
    /**
     Runs `sed` in order to replace all occurrences of a string in a specific file with another.
     */
    public static func sed(file: String, original: String, replacement: String)
    {
        Shell.run("sed -i '' 's/\(original)/\(replacement)/g' \(file)")
    }
    
    /**
     Uses `grep` to determine whether a particular query string can be found in a particular file.
     */
    public static func grepContains(file: String, query: String) -> Bool
    {
        return Shell.pipe("""
            grep -q '\(query)' \(file); [ $? -eq 0 ] && echo "YES" || echo "NO"
            """)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .contains("YES")
    }
}
