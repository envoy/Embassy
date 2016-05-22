//
//  Logger.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

struct Logger {
    enum Level: Int {
        case NOTSET = 0
        case DEBUG = 10
        case INFO = 20
        case WARNING = 30
        case ERROR = 40
        case CRITICAL = 50
        
        var name: String {
            switch self {
            case .NOTSET:
                return "NOTSET"
            case .DEBUG:
                return "DEBUG"
            case .INFO:
                return "INFO"
            case .WARNING:
                return "WARNING"
            case .ERROR:
                return "ERROR"
            case .CRITICAL:
                return "CRITICAL"
            }
        }
    }
    
    let name: String
    let level: Level
    
    init(name: String, level: Level = .INFO) {
        self.name = name
        self.level = level
    }
    
    init(fileName: String = #file, level: Level = .INFO) {
        self.name = Logger.moduleNameForFileName(fileName)
        self.level = level
    }
    
    func debug(@autoclosure message: Void -> String, caller: String = #function, file: String = #file, line: Int = #line) {
        log(.DEBUG, message: message, caller: caller, file: file, line: line)
    }
    
    func info(@autoclosure message: Void -> String, caller: String = #function, file: String = #file, line: Int = #line) {
        log(.INFO, message: message, caller: caller, file: file, line: line)
    }
    
    func warning(@autoclosure message: Void -> String, caller: String = #function, file: String = #file, line: Int = #line) {
        log(.WARNING, message: message, caller: caller, file: file, line: line)
    }
    
    func error(@autoclosure message: Void -> String, caller: String = #function, file: String = #file, line: Int = #line) {
        log(.ERROR, message: message, caller: caller, file: file, line: line)
    }
    
    func critical(@autoclosure message: Void -> String, caller: String = #function, file: String = #file, line: Int = #line) {
        log(.CRITICAL, message: message, caller: caller, file: file, line: line)
    }
    
    func log(level: Level, @autoclosure message: Void -> String, caller: String = #function, file: String = #file, line: Int = #line) {
        // TODO: let handler to handle this if neessary
        let messageString = message()
        let time = NSDate()
        print("\(time) [\(level)] - \(name): \(messageString)")
    }
    
    /// Strip file name and return only the name part, e.g. /path/to/MySwiftModule.swift will be MySwiftModule
    static func moduleNameForFileName(fileName: String) -> String {
        return ((fileName as NSString).lastPathComponent as NSString).stringByDeletingPathExtension
    }
}
