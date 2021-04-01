//
//  Paths.swift
//  PHP Monitor
//
//  Copyright © 2021 Nico Verbruggen. All rights reserved.
//

import Foundation

enum HomebrewDir: String {
    case opt = "/opt/homebrew"
    case usr = "/usr/local"
}

class Paths {
    
    static let shared = Paths()
    var baseDir : HomebrewDir
    
    init() {
        let optBrewFound = Shell.fileExists("\(HomebrewDir.opt.rawValue)/bin/brew")
        let usrBrewFound = Shell.fileExists("\(HomebrewDir.usr.rawValue)/bin/brew")
        
        if (optBrewFound) {
            // This is usually the case with Homebrew installed on Apple Silicon
            baseDir = .opt
        } else if (usrBrewFound) {
            // This is usually the case with Homebrew installed on Intel (or Rosetta 2)
            baseDir = .usr
        } else {
            // Falling back to default "legacy" Homebrew location (for Intel)
            print("Seems like we couldn't determine the Homebrew directory.")
            print("This usually means we're in trouble... (no Homebrew?)")
            baseDir = .usr
        }
        
        print("Homebrew directory: \(baseDir)")
        print("Adding to PATH of /bin/sh...")
    }
    
    // - MARK: Binaries
    
    public static var valet: String {
        return "/Users/\(whoami)/.composer/vendor/bin/valet"
    }
    
    public static var brew: String {
        return "\(binPath)/brew"
    }
    
    public static var php: String {
        return "\(binPath)/php"
    }
    
    public static var whoami: String {
        return String(Shell.pipe("whoami").split(separator: "\n")[0])
    }
    
    // - MARK: Paths
    
    public static var binPath: String {
        return "\(shared.baseDir.rawValue)/bin"
    }
    
    public static var optPath: String {
        return "\(shared.baseDir.rawValue)/opt"
    }
    
    public static var etcPath: String {
        return "\(shared.baseDir.rawValue)/etc"
    }
}
