//
//  MockRadioManagerDelegate.swift
//  xClient
//
//  Created by Douglas Adams on 9/5/20.
//

import xLib6001
import SwiftUI

class MockRadioManagerDelegate: RadioManagerDelegate {
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var clientId: String?
    var connectToFirstRadioIsEnabled = false
    var defaultNonGuiConnection: String?
    var defaultGuiConnection: String?
    var guiIsEnabled = true
    var smartlinkEmail: String?
    var smartlinkIsEnabled = true
    var smartlinkIsLoggedIn = true
    var smartlinkWasLoggedIn = true
    var smartlinkUserImage: Image?
    var stationName = "MockStation"

    var activePacket: DiscoveryPacket?
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    func willConnect() {}
    func didConnect() {}
    func didFailToConnect() {}
    func willDisconnect() {}
}
