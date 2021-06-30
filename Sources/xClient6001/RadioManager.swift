//
//  RadioManager.swift
//  xClient6001
//
//  Created by Douglas Adams on 8/23/20.
//  Copyright © 2020-2021 Douglas Adams. All rights reserved.
//

import Foundation
import SwiftUI
import xLib6001
import WebKit
import JWTDecode

public struct PickerPacket : Identifiable, Equatable, Comparable {
    public var id         = 0
    var packetIndex       = 0
    var type: ConnectionType = .local
    var nickname          = ""
    var status: ConnectionStatus = .available
    public var stations   = ""
    var serialNumber      = ""
    var isDefault         = false
//    var connectionString: String { "\(type == .wan ? "wan" : "local").\(serialNumber)" }
    var connectionString = ""

    public static func ==(lhs: PickerPacket, rhs: PickerPacket) -> Bool {
        guard lhs.serialNumber != "" else { return false }
        return lhs.connectionString == rhs.connectionString
    }
    public static func <(lhs: PickerPacket, rhs: PickerPacket) -> Bool {
        if lhs.type.rawValue < rhs.type.rawValue { return true }
        if lhs.type.rawValue == rhs.type.rawValue && lhs.nickname.lowercased() < rhs.nickname.lowercased() { return true }
        if lhs.type.rawValue == rhs.type.rawValue && lhs.nickname.lowercased() == rhs.nickname.lowercased() && lhs.stations.lowercased() < rhs.stations.lowercased() { return true }
        return false
    }
}

public enum ConnectionType: String {
    case wan
    case local
}

public enum ConnectionStatus: String {
    case available
    case inUse = "in_use"
}

public struct Station: Identifiable {
    public var id        = 0
    public var name      = ""
    public var clientId: String?
    
    public init(id: Int, name: String, clientId: String?) {
        self.id = id
        self.name = name
        self.clientId = clientId
    }
}

public struct AlertButton {
    var text = ""
    var color: Color?
    var action: ()->Void
    
    public init(_ text: String, _ action: @escaping ()->Void, color: Color? = nil) {
        self.text = text
        self.action = action
        self.color = color
    }
}

public enum AlertStyle {
    case informational
    case warning
    case error
}

public struct AlertParams {
    public var style: AlertStyle = .informational
    public var title    = ""
    public var message  = ""
    public var symbolName = ""
    public var buttons  = [AlertButton]()
}

public enum ViewType: Hashable, Identifiable {
    case genericAlert
    case radioPicker
    case smartlinkAuthentication
    case smartlinkStatus

    public var id: Int {
        return self.hashValue
    }
}

public protocol RadioManagerDelegate {
    var clientId: String?                   {get set}
    var defaultGuiConnection: String?       {get set}
    var defaultNonGuiConnection: String?    {get set}
    var guiIsEnabled: Bool                  {get set}
    var smartlinkCallsign: String?          {get set}
    var smartlinkEmail: String?             {get set}
    var smartlinkIsEnabled: Bool            {get set}
    var smartlinkName: String?              {get set}
    var stationName: String?                {get set}

    func didConnect()
    func didFailToConnect()
    func willConnect()
    func willDisconnect()
}

public final class RadioManager: ObservableObject {
    typealias connectionTuple = (type: String, serialNumber: String, station: String)
    
    // ----------------------------------------------------------------------------
    // MARK: - Static properties
    
    public static let kUserInitiated = "User initiated"
        
    // ----------------------------------------------------------------------------
    // MARK: - Published properties
    
    @Published public var activeView: ViewType?
    @Published public var isConnected = false
    @Published public var pickerHeading: String?
    @Published public var pickerMessages = [String]()
    @Published public var pickerPackets = [PickerPacket]()
    @Published public var pickerSelection: Int?
    @Published public var showAlert = false
    @Published public var smartlinkImage: Image?
    @Published public var smartlinkIsLoggedIn = false
    @Published public var smartlinkShowTestResults = false
    @Published public var smartlinkTestStatus = false

    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    public var activeRadio: Radio? { Api.sharedInstance.activeRadio}
    public var radios: [Radio] { Discovery.sharedInstance.radios }
    public var currentAlert = AlertParams()
    public var delegate: RadioManagerDelegate!
    public var sheetType: ViewType = .radioPicker
    public var smartlinkTestResults: String?

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var auth0UrlString = ""

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _api = Api.sharedInstance
    private var _authManager: AuthManager!
    private var _autoBind: Int? = nil
    private let _log = LogProxy.sharedInstance.logMessage
    private var _wanServer: WanServer?

    private let kAvailable = "available"
    private let kInUse = "in_use"

    #if os(macOS)
    private let kPlatform = "macOS"
    private let kStation = "Mac"
    #elseif os(iOS)
    private let kPlatform = "iOS"
    private let kStation = "iPad"
    #endif

    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    public init(delegate: RadioManagerDelegate) {
        self.delegate = delegate

        _wanServer = WanServer(delegate: self)
        _authManager = AuthManager(radioManager: self)

        // start Discovery
        let _ = Discovery.sharedInstance

        // start listening to notifications
        addNotifications()

        // if non-Gui, is there a saved Client Id?
        if delegate.guiIsEnabled == false && delegate.clientId == nil {
            // NO, assign one
            self.delegate.clientId = UUID().uuidString
        }
        // if SmartLink enabled, are we logged in?
        if delegate.smartlinkIsEnabled && smartlinkIsLoggedIn == false {
            // NO, attempt to log in
            smartlinkLogin(showPicker: false)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Initiate a connection to a Radio
    ///
    public func connect() {
        //    Order of connection attempts:
        //      1. connect to the default (if a default is non-blank)
        //      2. otherwise, show picker
        
        delegate.willConnect()

        // connect to default?
        if delegate.guiIsEnabled && delegate.defaultGuiConnection != nil {
            _log("RadioManager, connecting to Gui default: \(delegate.defaultGuiConnection!)", .info,  #function, #file, #line)
            connectRadio(using: delegate.defaultGuiConnection!)
        } else if delegate.guiIsEnabled == false && delegate.defaultNonGuiConnection != nil {
            _log("RadioManager, connecting to non-Gui default: \(delegate.defaultNonGuiConnection!)", .info,  #function, #file, #line)
            connectRadio(using: delegate.defaultNonGuiConnection!)
        } else {
            showView(.radioPicker)
        }
    }
    
    /// Initiate a connection to the Radio with the specified connection string
    /// - Parameter connection:   a connection string (in the form <type>.<serialNumber>)
    ///
    public func connectRadio(using connectionString: String) {
        // is it a valid connection string?
        if let connectionTuple = parseConnectionString(connectionString) {
            // VALID, is there a match?
            if let index = findMatchingConnection(connectionTuple) {
                // YES, attempt a connection to it
                connectRadio(at: index)
            } else {
                // NO, no match found
                showView(.radioPicker, messages: ["No match found for: \(connectionString)"])
            }
        } else {
            // NOT VALID
            showView(.radioPicker, messages: ["\(connectionString) is an invalid connection"])        }
    }

    /// Disconnect the current connection
    /// - Parameter msg:    explanation
    ///
    public func disconnect(reason: String = RadioManager.kUserInitiated) {
        _log("RadioManager, disconnect: \(reason)", .info,  #function, #file, #line)
        
        delegate.willDisconnect()

        // tell the library to disconnect
        _api.disconnect(reason: reason)
        
        DispatchQueue.main.async { self.isConnected = false }

        // if anything unusual, tell the user
        if reason != RadioManager.kUserInitiated {
            currentAlert = AlertParams(title: "Radio was disconnected",
                                      message: reason,
                                      symbolName: "multiply.octagon",
                                      buttons: [AlertButton( "Ok", {})])
            showView(.genericAlert)
        }
    }

    /// Send a command to the Radio
    ///
    public func send(command: String) {
        guard command != "" else { return }
        
        // send the command to the Radio via TCP
        _api.send( command )
    }

    public func showView(_ type: ViewType, messages: [String] = [String]()) {
        switch type {
        
        case .genericAlert:
            #if os(macOS)
            DispatchQueue.main.async { [self] in activeView = type }
            #elseif os(iOS)
            DispatchQueue.main.async { [self] in showAlert = true }
            #endif

        case .radioPicker:
            loadPickerPackets()
            smartlinkTestStatus = false
            pickerSelection = nil
            pickerMessages = messages
            pickerHeading = "Select a \(delegate.guiIsEnabled ? "Radio" : "Station")"
            DispatchQueue.main.async { [self] in activeView = type }

        case .smartlinkAuthentication:
            DispatchQueue.main.async { [self] in activeView = type }

        case .smartlinkStatus:
            DispatchQueue.main.async { [self] in activeView = type }
        }
    }

    /// Show the Default Picker sheet
    ///
    public func defaultChoose() {
        var buttons = [AlertButton]()
        buttons.append(AlertButton( "Clear the current Default", { self.defaultClear() }))
        buttons.append(AlertButton( "Cancel", {}))
        currentAlert = AlertParams(title: "Choose one",
                                   message: "",
                                   symbolName: "info.circle",
                                   buttons: buttons)
        showView(.genericAlert)
    }
    
    public func defaultClear() {
        DispatchQueue.main.async { [self] in
            if delegate.guiIsEnabled {
                delegate.defaultGuiConnection = nil
            } else {
                delegate.defaultNonGuiConnection = nil
            }
        }
    }
       
    public func defaultSet(_ pickerSelection: Int) {
        DispatchQueue.main.async { [self] in
            if delegate.guiIsEnabled {
                delegate.defaultGuiConnection = pickerPackets[pickerSelection].connectionString
            } else {
                delegate.defaultNonGuiConnection = pickerPackets[pickerSelection].connectionString
            }
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Public methods (Smartlink)

    public func smartlinkEnabledToggle() {
        if delegate.smartlinkIsEnabled && smartlinkIsLoggedIn { smartlinkLogout() }
        delegate.smartlinkIsEnabled.toggle()
    }

    public func smartlinkForceLogin() {
        delegate.smartlinkEmail = ""
        _authManager.forceNewLogin()
        smartlinkLogout()
    }
    
    public func smartlinkLogin(showPicker: Bool = true) {
        if _wanServer == nil { _wanServer = WanServer(delegate: self) }

        // attempt a SmartLink login using existing credentials
        if smartlinkConnect() {
            smartlinkIsLoggedIn = true
            if showPicker { showView(.radioPicker) }

        } else {
            // obtain new credentials
            showView(.smartlinkAuthentication)
        }
    }

    public func smartlinkAuthenticate(email: String, password: String) {
        if let idToken = _authManager.requestTokens(for: email, pwd: password) {
            // instantiate WanServer (as needed)
            if _wanServer == nil { _wanServer = WanServer(delegate: self) }
            // try to connect
            if _wanServer!.connectToSmartlink(appName: (Bundle.main.infoDictionary!["CFBundleName"] as! String),
                                   platform: kPlatform,
                                   idToken: idToken) {
                smartlinkIsLoggedIn = true
                delegate.smartlinkEmail = email
                showView(.radioPicker)
            }
        }
    }

    public func smartlinkLogout() {
        Discovery.sharedInstance.removeSmartLinkRadios()
        _wanServer?.disconnectFromSmartlink()
        _wanServer = nil
        DispatchQueue.main.async { [self] in
            delegate.smartlinkName = nil
            delegate.smartlinkCallsign = nil
            smartlinkImage = nil
            smartlinkIsLoggedIn = false
        }
    }

    /// Called when the Picker's Test button is clicked
    ///
    public func smartlinkTest() {
        guard pickerSelection != nil else { return }
        _wanServer?.test( pickerPackets[pickerSelection!].serialNumber )
    }

    // ----------------------------------------------------------------------------
    // MARK: - Internal methods

    /// Initiate a connection to the Radio with the specified index
    ///   This method is called by the Picker when a selection is made and the Connect button is pressed
    ///
    /// - Parameter index:    an index into the PickerPackets array
    ///
    func connectRadio(at index: Int?) {
        if let index = index {
            guard activeRadio == nil else { disconnect() ; return }
            
            let packetIndex = delegate.guiIsEnabled ? index : pickerPackets[index].packetIndex
            
            if radios.count - 1 >= packetIndex {
                let radio = radios[packetIndex]

                // if Non-Gui, schedule automatic binding
                _autoBind = delegate.guiIsEnabled ? nil : index

                if radio.isWan {
                    _wanServer?.connectTo(radio.serialNumber, holePunchPort: radio.negotiatedHolePunchPort)
                } else {
                    openRadio(at: packetIndex)
                }
            }
        }
    }

    /// Disconnect another client (not this one))
    /// - Parameters:
    ///   - packet: the radio's DiscoveryPacket
    ///   - handle: the handle to disconnect
    func clientDisconnect(_ packet: DiscoveryPacket, handle: Handle) {
        if packet.isWan {
            _wanServer?.disconnectFrom( packet.serialNumber )
        } else {
            _api.requestClientDisconnect( handle: handle )
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private

    /// Determine the state of the Radio being opened and allow the user to choose how to proceed
    /// - Parameter packet:     the packet describing the Radio to be opened
    ///
    private func openRadio(at index: Int) {
        guard delegate.guiIsEnabled else {
            connectToRadio(at: index, isGui: delegate.guiIsEnabled, station: delegate.stationName)
            return
        }
        
        switch (radios[index].status.lowercased(), radios[index].guiClients.count) {

        case (kAvailable, 0):           // not connected to another client
            connectToRadio(at: index, station: delegate.stationName)
            
        case (kAvailable, 1):           // connected to another client
            let firstButtonAction = { [self] in
                connectToRadio(at: index, isGui: delegate.guiIsEnabled, pendingDisconnect: .some(handle: radios[index].guiClients[0].handle), station: delegate.stationName)
            }
            let secondButtonAction = { [self] in
                connectToRadio(at: index, isGui: delegate.guiIsEnabled, station: delegate.stationName)
            }
            currentAlert = AlertParams(title: "Radio is connected to Station",
                                       message: radios[index].guiClients[0].station,
                                      symbolName: "exclamationmark.triangle",
                                      buttons: [
                                        AlertButton( "Close \(radios[index].guiClients[0].station)", firstButtonAction ),
                                        AlertButton( "Multiflex Connect", secondButtonAction),
                                        AlertButton( "Cancel", {})
                                      ])
            showView(.genericAlert)

        case (kInUse, 2):               // connected to 2 clients
            let firstButtonAction = { [self] in
                connectToRadio(at: index, isGui: delegate.guiIsEnabled, pendingDisconnect: .some(handle: radios[index].guiClients[0].handle), station: delegate.stationName)      }
            let secondButtonAction = { [self] in
                connectToRadio(at: index, isGui: delegate.guiIsEnabled, pendingDisconnect: .some(handle: radios[index].guiClients[1].handle), station: delegate.stationName)      }
            currentAlert = AlertParams(title: "Radio is connected to multiple Stations",
                                      message: "",
                                      symbolName: "exclamationmark.triangle",
                                      buttons: [
                                        AlertButton( "Close \(radios[index].guiClients[0].station)", firstButtonAction ),
                                        AlertButton( "Close \(radios[index].guiClients[1].station)", secondButtonAction),
                                        AlertButton( "Cancel", {})
                                      ])
            showView(.genericAlert)

        default:
            break
        }
    }

    /// Open a connection to the SmartLink server using existing credentials
    /// - Parameter auth0Email:     saved email (if any)
    private func smartlinkConnect() -> Bool {
        // is there an Id Token available?
        if let idToken = _authManager.getExistingIdToken() {

            // try to connect
            let appName = (Bundle.main.infoDictionary!["CFBundleName"] as! String)
            return _wanServer!.connectToSmartlink(appName: appName, platform: kPlatform, idToken: idToken)
        }
        // NO, user will need to reenter user / pwd to authenticate
        _log("RadioManager, SmartlinkLogin: Previous ID Token not found", .debug, #function, #file, #line)
        return false
    }

    /// Given aTuple find a match in PickerPackets
    /// - Parameter conn: a Connection Tuple
    /// - Returns: the index into Packets (if any) of a match
    private func findMatchingConnection(_ conn: connectionTuple) -> Int? {
        for (i, packet) in pickerPackets.enumerated() {
            if packet.serialNumber == conn.serialNumber && packet.type.rawValue == conn.type {
                if delegate.guiIsEnabled {
                    return i
                } else if packet.stations == conn.station {
                    return i
                }
            }
        }
        return nil
    }
    
    /// Cause a bind command to be sent
    /// - Parameter id:     a Client Id
    private func bindToClientId(_ id: String) {
        activeRadio?.boundClientId = id
    }
    
    /// Attempt to open a connection to the specified Radio
    /// - Parameters:
    ///   - packet:             the packet describing the Radio
    ///   - pendingDisconnect:  a struct describing a pending disconnect (if any)
    private func connectToRadio(at index: Int, isGui: Bool = true, pendingDisconnect: Api.PendingDisconnect = .none, station: String?) {
        // station will be "Mac" if not passed
        let stationName = (station == nil ? kStation : station!)
        
        // attempt a connection
        if _api.connect( Api.ConnectionParams(index: index,
                                              station: stationName,
                                              program: Bundle.main.infoDictionary!["CFBundleName"] as! String,
                                              clientId: isGui ? delegate.clientId : nil,
                                              isGui: isGui,
                                              wanHandle: radios[index].wanHandle,
                                              logState: .none,
                                              pendingDisconnect: pendingDisconnect)) {

            delegate.didConnect()
        } else {
            delegate.didFailToConnect()
        }
    }

    func loadPickerPackets() {
        DispatchQueue.main.async { [self] in pickerPackets = getPickerPackets() }
    }

    /// Create a subset of DiscoveryPackets
    /// - Returns:                an array of PickerPacket
    private func getPickerPackets() -> [PickerPacket] {
        var newPackets = [PickerPacket]()

        var p = 0
        if delegate.guiIsEnabled {
            // GUI connection
            radios.forEach{ radio in
                let connectionString = radio.isWan ? "wan." : "local." + radio.serialNumber
                newPackets.append( PickerPacket(id: p,
                                                packetIndex: p,
                                                type: radio.isWan ? .wan : .local,
                                                nickname: radio.nickname,
                                                status: ConnectionStatus(rawValue: radio.status.lowercased()) ?? .inUse,
                                                stations: String(radio.guiClients.reduce("", {$0 + $1.station + " " }).dropLast()),
                                                serialNumber: radio.serialNumber,
                                                isDefault: delegate.defaultGuiConnection == connectionString,
                                                connectionString: connectionString))
                p += 1
            }

        } else {
            // Non-Gui connection
            var i = 0
            radios.forEach{ radio in
                radio.guiClients.forEach { guiClient in
                    let connectionString = (radio.isWan ? "wan." : "local.") + radio.serialNumber + "." + guiClient.station
                    newPackets.append( PickerPacket(id: i,
                                                    packetIndex: p,
                                                    type: radio.isWan ? .wan : .local,
                                                    nickname: radio.nickname,
                                                    status: ConnectionStatus(rawValue: radio.status.lowercased()) ?? .inUse,
                                                    stations: guiClient.station,
                                                    serialNumber: radio.serialNumber,
                                                    isDefault: delegate.defaultNonGuiConnection == connectionString,
                                                    connectionString: connectionString))
                    i += 1
                }
                p += 1
            }
        }
        return newPackets.sorted(by: {$0 < $1} )
    }
    
    /// Parse the components of a connection string
    /// - Parameter connectionString:   a string of the form <type>.<serialNumber>
    /// - Returns:                      a tuple containing the parsed values (if any)
    private func parseConnectionString(_ connectionString: String) -> (type: String, serialNumber: String, station: String)? {
        // A Connection is stored as a String in the form:
        //      "<type>.<serial number>"  OR  "<type>.<serial number>.<station>"
        //      where:
        //          <type>            "local" OR "wan", (wan meaning SmartLink)
        //          <serial number>   a serial number, e.g. 1234-5678-9012-3456
        //          <station>         a Station name e.g "Windows" (only used for non-Gui connections)
        //
        // If the Type and period separator are omitted. "local" is assumed
        //
        
        // split by the "." (if any)
        let parts = connectionString.components(separatedBy: ".")
        
        switch parts.count {
        case 3:
            // <type>.<serial number>
            return (parts[0], parts[1], parts[2])
        case 2:
            // <type>.<serial number>
            return (parts[0], parts[1], "")
        case 1:
            // <serial number>, type defaults to local
            return (parts[0], "local", "")
        default:
            // unknown, not a valid connection string
            return nil
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification methods
    
    private func addNotifications() {
        NotificationCenter.makeObserver(self, with: #selector(reloadPickerPackets(_:)),   of: .discoveredRadios)
        NotificationCenter.makeObserver(self, with: #selector(clientDidConnect(_:)),   of: .clientDidConnect)
        NotificationCenter.makeObserver(self, with: #selector(clientDidDisconnect(_:)),   of: .clientDidDisconnect)
        NotificationCenter.makeObserver(self, with: #selector(reloadPickerPackets(_:)),   of: .guiClientHasBeenAdded)
        NotificationCenter.makeObserver(self, with: #selector(guiClientHasBeenUpdated(_:)), of: .guiClientHasBeenUpdated)
        NotificationCenter.makeObserver(self, with: #selector(reloadPickerPackets(_:)), of: .guiClientHasBeenRemoved)
    }
    
    @objc private func reloadPickerPackets(_ note: Notification) {
        loadPickerPackets()
    }
    
    @objc private func clientDidConnect(_ note: Notification) {
        DispatchQueue.main.async { [self] in
            isConnected = true
        }

    }
    
    @objc private func clientDidDisconnect(_ note: Notification) {
        DispatchQueue.main.async { [self] in
            isConnected = false
            if let reason = note.object as? String {
                disconnect(reason: reason)
            }
        }
    }
    
    @objc private func guiClientHasBeenUpdated(_ note: Notification) {
        loadPickerPackets()
        
        if let guiClient = note.object as? GuiClient {
            // ClientId has been populated
            DispatchQueue.main.async { [self] in
                
                if _autoBind != nil {
                    if guiClient.station == pickerPackets[_autoBind!].stations && guiClient.clientId != nil {
                        bindToClientId(guiClient.clientId!)
                    }
                }
            }
        }
    }
}

// ----------------------------------------------------------------------------

extension RadioManager: WanServerDelegate {

    public func wanSettings(name: String, call: String) {
        DispatchQueue.main.async{ [self] in
            delegate.smartlinkName = name
            delegate.smartlinkCallsign = call
        }
    }

    public func wanConnectReady(handle: String, serial: String) {
        for (i, radio) in Discovery.sharedInstance.radios.enumerated() where radio.serialNumber == serial && radio.isWan {
            Discovery.sharedInstance.radios[i].wanHandle = handle
            openRadio(at: i)
        }
    }

    public func wanTestResults(_ results: WanTestConnectionResults) {
        // assess the result
        let success = (results.forwardTcpPortWorking == true &&
                        results.forwardUdpPortWorking == true &&
                        results.upnpTcpPortWorking == false &&
                        results.upnpUdpPortWorking == false &&
                        results.natSupportsHolePunch  == false) ||

            (results.forwardTcpPortWorking == false &&
                results.forwardUdpPortWorking == false &&
                results.upnpTcpPortWorking == true &&
                results.upnpUdpPortWorking == true &&
                results.natSupportsHolePunch  == false)

        smartlinkTestResults =
        """
        Forward Tcp Port:\t\t\(results.forwardTcpPortWorking)
        Forward Udp Port:\t\t\(results.forwardUdpPortWorking)
        UPNP Tcp Port:\t\t\(results.upnpTcpPortWorking)
        UPNP Udp Port:\t\t\(results.upnpUdpPortWorking)
        Nat Hole Punch:\t\t\(results.natSupportsHolePunch)
        """
        // set the indicator
        DispatchQueue.main.async {
            self.smartlinkTestStatus = success
            self.smartlinkShowTestResults = true
        }
    }
}

