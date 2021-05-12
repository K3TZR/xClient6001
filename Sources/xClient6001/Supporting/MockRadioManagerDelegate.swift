//
//  MockRadioManagerDelegate.swift
//  xClient6001
//
//  Created by Douglas Adams on 9/5/20.
//  Copyright © 2020-2021 Douglas Adams. All rights reserved.
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
    var smartlinkCallsign: String?
    var smartlinkEmail: String?
    var smartlinkIsEnabled = true
    var smartlinkIsLoggedIn = true
    var smartlinkName: String?
    var smartlinkWasLoggedIn = true
    var smartlinkUserImage: Image?
    var stationName: String? = "MockStation"

    var activePacket: DiscoveryPacket?
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    func willConnect() {}
    func didConnect() {}
    func didFailToConnect() {}
    func willDisconnect() {}
}
