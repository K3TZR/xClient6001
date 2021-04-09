//
//  LogManager.swift
//  xClient
//
//  Created by Douglas Adams on 3/4/20.
//  Copyright © 2020 Douglas Adams. All rights reserved.
//

import Foundation
import XCGLogger
import xLib6001
import SwiftUI

// ----------------------------------------------------------------------------
// Logging implementation
//      Access to this logging functionality should be given to the App and any
//      underlying Library so that their messages will be included in application logs.
//
//      For example, see this usage in xApiMac init()
//
//          // initialize and configure the Logger
//          _log = Logger.sharedInstance.logMessage
//
//          // give the Api access to our logger
//          LogProxy.sharedInstance.delegate = Logger.sharedInstance
//
// ----------------------------------------------------------------------------

public class LogManager: LogHandler, ObservableObject {
    // ----------------------------------------------------------------------------
    // MARK: - Static properties
    
    static let kMaxLogFiles: UInt8  = 10
    static let kMaxTime: TimeInterval = 60 * 60 // 1 Hour
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public enum LogFilter: String, CaseIterable {
        case none
        case includes
        case excludes
    }

    public enum LogLevel: String, CaseIterable {
        case debug    = "Debug"
        case info     = "Info"
        case warning  = "Warning"
        case error    = "Error"
    }

    public struct LogLine: Identifiable {
        public var id    = 0
        public var text  = ""
    }

    public struct LogList: Identifiable {
        public var id    = 0
        public var url: URL
    }

    public var appName      = ""
    public var domain       = ""
    public var supportEmail = "support@"

    // ----------------------------------------------------------------------------
    // MARK: - Published properties
    
    @Published var filterBy: LogFilter  = .none         { didSet{filterLog() }}
    @Published var filterByText         = ""            { didSet{filterLog() }}
    @Published public var fontSize      = 12
    @Published var level: LogLevel      = .debug        { didSet{filterLog() }}
    @Published var loadFailed           = false
    @Published var logLines             = [LogLine]()
    @Published var selection: Int?
    @Published var showLogPicker        = false
    @Published var showTimestamps       = false         { didSet{filterLog() }}

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties

    var fileUrls = [LogList]()
    var log: XCGLogger {
        get { _objectQ.sync { _log } }
        set { _objectQ.sync(flags: .barrier) {_log = newValue }}}

    // ----------------------------------------------------------------------------
    // MARK: - Private properties

    private var _defaultLogUrl: URL!
    private var _defaultFolder: String!
    private var _linesArray = [String.SubSequence]()
    private var _log: XCGLogger!
    private var _logLevel: XCGLogger.Level = .debug
    private var _logString: String!
    private var _objectQ: DispatchQueue!
    private var _openFileUrl: URL?

    // ----------------------------------------------------------------------------
    // MARK: - Singleton
    
    /// Provide access to the Logger singleton
    ///
    public static var sharedInstance = LogManager()
    
    private init() {
        let bundleId = Bundle.main.bundleIdentifier
        let parts = bundleId?.split(separator: ".")
        if let p = parts, p.count == 3 {
            domain = String(p[0] + "." + p[1])
            appName = String(p[2])
            supportEmail += (p[1] + "." + p[0])
        }
        _objectQ = DispatchQueue(label: appName + ".Logger.objectQ", attributes: [.concurrent])
        _log = XCGLogger(identifier: appName, includeDefaultDestinations: false)

        let defaultLogName = appName + ".log"
        _defaultFolder = URL.appSupport.path + "/" + domain + "." + appName + "/Logs"

        #if DEBUG
        // for DEBUG only
        // Create a destination for the system console log (via NSLog)
        let systemDestination = AppleSystemLogDestination(identifier: appName + ".systemDestination")
        
        // Optionally set some configuration options
        systemDestination.outputLevel           = _logLevel
        systemDestination.showFileName          = false
        systemDestination.showFunctionName      = false
        systemDestination.showLevel             = true
        systemDestination.showLineNumber        = false
        systemDestination.showLogIdentifier     = false
        systemDestination.showThreadName        = false

        // Add the destination to the logger
        log.add(destination: systemDestination)
        #endif
        
        // Get / Create a file log destination
        if let logs = URL.logs {
            let fileDestination = AutoRotatingFileDestination(writeToFile: logs.appendingPathComponent(defaultLogName),
                                                              identifier: appName + ".autoRotatingFileDestination",
                                                              shouldAppend: true,
                                                              appendMarker: "- - - - - App was restarted - - - - -")

            // Optionally set some configuration options
            fileDestination.outputLevel             = _logLevel
            fileDestination.showDate                = true
            fileDestination.showFileName            = false
            fileDestination.showFunctionName        = false
            fileDestination.showLevel               = true
            fileDestination.showLineNumber          = false
            fileDestination.showLogIdentifier       = false
            fileDestination.showThreadName          = false
            fileDestination.targetMaxLogFiles       = LogManager.kMaxLogFiles
            fileDestination.targetMaxTimeInterval   = LogManager.kMaxTime

            // Process this destination in the background
            fileDestination.logQueue = XCGLogger.logQueue

            // Add the destination to the logger
            log.add(destination: fileDestination)

            // Add basic app info, version info etc, to the start of the logs
            log.logAppDetails()

            // format the date (only effects the file logging)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss:SSS"
            dateFormatter.locale = Locale.current
            log.dateFormatter = dateFormatter

            _defaultLogUrl = URL(fileURLWithPath: _defaultFolder + "/" + defaultLogName)
        } else {
            #if os(macOS)
            let alert = NSAlert()
            alert.messageText = "Logging failure"
            alert.informativeText = "unable to find / create Log folder"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Ok")

            alert.runModal()
            #endif
            fatalError("Logging failure:, unable to find / create Log folder")
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - LogHandlerDelegate methods
    
    /// Process log messages
    /// - Parameters:
    ///   - msg:        a message
    ///   - level:      the severity level of the message
    ///   - function:   the name of the function creating the msg
    ///   - file:       the name of the file containing the function
    ///   - line:       the line number creating the msg
    ///
    public func logMessage(_ msg: String, _ level: MessageLevel, _ function: StaticString, _ file: StaticString, _ line: Int) -> Void {
        // Log Handler to support XCGLogger
        switch level {

        case .verbose:  log.verbose(msg, functionName: function, fileName: file, lineNumber: line )
        case .debug:    log.debug(msg, functionName: function, fileName: file, lineNumber: line)
        case .info:     log.info(msg, functionName: function, fileName: file, lineNumber: line)
        case .warning:  log.warning(msg, functionName: function, fileName: file, lineNumber: line)
        case .error:    log.error(msg, functionName: function, fileName: file, lineNumber: line)
        case .severe:   log.severe(msg, functionName: function, fileName: file, lineNumber: line)
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - LoggerView actions

    public func backToMain() {
        NotificationCenter.default.post(name: Notification.Name("showMainView"), object: nil)
    }

    public func loadDefaultLog() {
        loadLog(at: _defaultLogUrl)
    }

    public func loadFile(at index: Int?) {
        guard index != nil else { return }

        loadLog(at: fileUrls[index!].url)
    }

    public func loadLog(at logUrl: URL? = nil) {
        if let url = logUrl {
            // read it & populate the textView
            do {
                logLines.removeAll()

                _logString = try String(contentsOf: url, encoding: .ascii)
                _linesArray = _logString.split(separator: "\n")
                _openFileUrl = url
                filterLog()

            } catch {
                DispatchQueue.main.async { self.loadFailed = true }
            }

        } else {
            let defaultFolderUrl = URL(fileURLWithPath: _defaultFolder)
            let urls = try! FileManager().contentsOfDirectory(at: defaultFolderUrl, includingPropertiesForKeys: nil)
            fileUrls.removeAll()
            for (i, url) in urls.enumerated() {
                fileUrls.append(LogList(id: i, url: url))
            }
            DispatchQueue.main.async { self.showLogPicker = true }
        }
    }

    #if os(iOS)
    public func getLogData() -> Data? {
        guard _openFileUrl != nil else { return nil }
        return try! Data(contentsOf: _openFileUrl!)
    }
    #endif

    public func refreshLog() {
        loadLog(at: _openFileUrl)
    }

    public func clearLog() {
        _logString = ""
        _linesArray = _logString.split(separator: "\n")
        filterLog()
    }

    #if os(macOS)
    public func saveLog() {
        // Allow the User to save a copy of the Log file
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["log"]
        savePanel.allowsOtherFileTypes = false
        savePanel.nameFieldStringValue = _openFileUrl?.lastPathComponent ?? ""
        savePanel.directoryURL = URL(fileURLWithPath: "~/Desktop".expandingTilde)

        // open a Save Dialog
        savePanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { [unowned self] (result: NSApplication.ModalResponse) in

            // if the user pressed Save
            if result == NSApplication.ModalResponse.OK {

                if let url = savePanel.url {
                    // write it to the File
                    do {
                        try self._logString.write(to: url, atomically: true, encoding: .ascii)

                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "Unable to save Log file"
                        alert.informativeText = url.lastPathComponent
                        alert.alertStyle = .critical
                        alert.addButton(withTitle: "Ok")

                        alert.runModal()
                    }
                }
            }
        }
    }

    /// Email the currently open Log file
    ///
    func emailLog() {
        let service = NSSharingService(named: NSSharingService.Name.composeEmail)!
        service.recipients = [supportEmail]
        service.subject = appName + " Log file"
        service.perform(withItems: [_openFileUrl!])
    }
    #endif

    /// Filter the displayed Log
    /// - Parameter level:    log level
    ///
    func filterLog() {
        var limitedLines    = [String.SubSequence]()
        var filteredLines   = [String.SubSequence]()
        
        // filter the log entries
        switch level {

        case .debug:     filteredLines = _linesArray
        case .info:      filteredLines = _linesArray.filter { $0.contains(" [" + LogLevel.error.rawValue + "] ") || $0.contains(" [" + LogLevel.warning.rawValue + "] ") || $0.contains(" [" + LogLevel.info.rawValue + "] ") }
        case .warning:   filteredLines = _linesArray.filter { $0.contains(" [" + LogLevel.error.rawValue + "] ") || $0.contains(" [" + LogLevel.warning.rawValue + "] ") }
        case .error:     filteredLines = _linesArray.filter { $0.contains(" [" + LogLevel.error.rawValue + "] ") }
        }

        switch filterBy {

        case .none:      limitedLines = filteredLines
        case .includes:  limitedLines = filteredLines.filter { $0.contains(filterByText) }
        case .excludes:  limitedLines = filteredLines.filter { !$0.contains(filterByText) }
        }
        logLines = [LogLine]()
        for (i, line) in limitedLines.enumerated() {
            let offset = line.firstIndex(of: "[") ?? line.startIndex
            logLines.append( LogLine(id: i, text: showTimestamps ? String(line) : String(line[offset...]) ))
        }
    }
}

// ----------------------------------------------------------------------------
// MARK: - Extensions

//extension URL {
//    /// setup the Support folders
//    ///
//    static var appSupport: URL { return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first! }
//
//    static func createLogFolder(domain: String, appName: String) -> URL? {
//        return createAsNeeded(domain + "." + appName + "/Logs")
//    }
//
//    static func createAsNeeded(_ folder: String) -> URL? {
//        let fileManager = FileManager.default
//        let folderUrl = appSupport.appendingPathComponent( folder )
//
//        // does the folder exist?
//        if fileManager.fileExists( atPath: folderUrl.path ) == false {
//            // NO, create it
//            do {
//                try fileManager.createDirectory( at: folderUrl, withIntermediateDirectories: true, attributes: nil)
//            } catch {
//                return nil
//            }
//        }
//        return folderUrl
//    }
//}

extension String {
    var expandingTilde: String { NSString(string: self).expandingTildeInPath }
}

extension URL {

  /// setup the Support folders
  ///
  static var appSupport : URL { return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first! }
  static var logs : URL? { return createAsNeeded("net.k3tzr.xApiMac/Logs") }
  static var macros : URL? { return createAsNeeded("net.k3tzr.xApiMac/Macros") }

  static func createAsNeeded(_ folder: String) -> URL? {
    let fileManager = FileManager.default
    let folderUrl = appSupport.appendingPathComponent( folder )

    // does the folder exist?
    if fileManager.fileExists( atPath: folderUrl.path ) == false {

      // NO, create it
      do {
        try fileManager.createDirectory( at: folderUrl, withIntermediateDirectories: true, attributes: nil)
      } catch {
        return nil
      }
    }
    return folderUrl
  }
}
