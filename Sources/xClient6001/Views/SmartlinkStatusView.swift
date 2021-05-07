//
//  SmartLinkStatusView.swift
//  xClient
//
//  Created by Douglas Adams on 8/13/20.
//

import SwiftUI

// ----------------------------------------------------------------------------
// MARK: - Primary view

public struct SmartlinkStatusView: View {

    public init() {}
        
    public var body: some View {
        
        VStack(spacing: 20) {
            SmartlinkStatusHeader()
            Divider()
            SmartlinkStatusBody()
            Divider()
            SmartlinkStatusFooter()
        }
        .padding()
    }
}

// ----------------------------------------------------------------------------
// MARK: - Subviews

struct SmartlinkStatusHeader: View {
    @EnvironmentObject var radioManager : RadioManager

    @AppStorage("smartlinkIsEnabled") var smartlinkIsEnabled: Bool = false

    public var body: some View {

        Text("Smartlink Status").font(.title)
        if smartlinkIsEnabled {
            if !radioManager.smartlinkIsLoggedIn {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                    Text("----- Logged Out -----").foregroundColor(.red)
                }
            } else {
                EmptyView()
            }
        } else {
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                Text("----- Disabled -----").foregroundColor(.red)
            }
        }
    }
}

struct SmartlinkStatusBody: View {
    @EnvironmentObject var radioManager : RadioManager

    @AppStorage("smartlinkEmail") var smartlinkEmail = ""
    @AppStorage("smartlinkName") var smartlinkName = ""
    @AppStorage("smartlinkCallsign") var smartlinkCallsign = ""

    public var body: some View {

        HStack (spacing: 20) {
            if radioManager.smartlinkImage == nil {
                Image(systemName: "person.circle")
                    .font(.system(size: 60))
            } else {
                radioManager.smartlinkImage!
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
            }
            VStack (alignment: .leading, spacing: 10) {
                Text("Name").bold()
                Text("Callsign").bold()
                Text("Email").bold()
            }
            .frame(width: 70, alignment: .leading)

            VStack (alignment: .leading, spacing: 10) {
                Text(smartlinkName)
                Text(smartlinkCallsign)
                Text(smartlinkEmail)
            }
            .frame(width: 200, alignment: .leading)
        }
    }
}

struct SmartlinkStatusFooter: View {
    @EnvironmentObject var radioManager : RadioManager
    @Environment(\.presentationMode) var presentationMode

    @AppStorage("smartlinkIsEnabled") var smartlinkIsEnabled = false

    public var body: some View {

        HStack(spacing: 60) {
            Button(smartlinkIsEnabled ? "Disable" : "Enable") {
                radioManager.smartlinkEnabledToggle()
                presentationMode.wrappedValue.dismiss()
            }
            Button("Force Login") {
                radioManager.smartlinkForceLogin()
                presentationMode.wrappedValue.dismiss()
            }
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }.keyboardShortcut(.defaultAction)
        }
    }
}

// ----------------------------------------------------------------------------
// MARK: - Preview

struct SmartLinkView_Previews: PreviewProvider {
    static var previews: some View {
        SmartlinkStatusView()
            .environmentObject(RadioManager(delegate: MockRadioManagerDelegate()))
    }
}
