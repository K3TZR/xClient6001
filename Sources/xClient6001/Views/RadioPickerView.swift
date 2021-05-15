//
//  RadioPickerView.swift
//  xClient6001
//
//  Created by Douglas Adams on 8/15/20.
//  Copyright © 2020-2021 Douglas Adams. All rights reserved.
//

import SwiftUI

// ----------------------------------------------------------------------------
// MARK: - Primary view

public struct RadioPickerView: View {
    @EnvironmentObject var radioManager: RadioManager
    
    public init() {}
    
    public var body: some View {
        VStack {
            RadioPickerHeaderView()
            Divider()
            RadioPickerBodyView()            
            Divider()
            RadioPickerFooterView()
        }
        .padding()
        .frame(minWidth: 550)
        .onDisappear(perform: {radioManager.connectRadio(at: radioManager.pickerSelection)})
    }
}

// ----------------------------------------------------------------------------
// MARK: - Subviews

struct RadioPickerHeaderView: View {
    @EnvironmentObject var radioManager: RadioManager

    var body: some View {
        Text(radioManager.pickerHeading ?? "").font(.largeTitle)
        VStack (spacing: 20) {
            ForEach(radioManager.pickerMessages, id: \.self) { message in
                Text(message).foregroundColor(.red)
            }
        }.padding(.bottom, 20)
    }
}

struct RadioPickerBodyView : View {
    @EnvironmentObject var radioManager : RadioManager

    var body: some View {

        VStack (alignment: .leading) {
            ListHeader()
            Divider()
            if radioManager.pickerPackets.count == 0 {
                EmptyList()
            } else {
                PopulatedList()
            }
        }
        .frame(minHeight: 200)
    }
}

struct ListHeader: View {
    var body: some View {
        HStack {
            #if os(macOS)
            Text("").frame(width: 8)
            #elseif os(iOS)
            Text("").frame(width: 25)
            #endif
            Text("Type").frame(width: 130, alignment: .leading)
            Text("Name").frame(width: 130, alignment: .leading)
            Text("Status").frame(width: 130, alignment: .leading)
            Text("Station(s)").frame(width: 130, alignment: .leading)
        }
    }
}

struct EmptyList: View {
    @EnvironmentObject var radioManager : RadioManager

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("---------- No \(radioManager.delegate.guiIsEnabled ? "Radios" : "Stations") found ----------")
                    .foregroundColor(.red)
                Spacer()
            }
            Spacer()
        }
    }
}

struct PopulatedList: View {
    @EnvironmentObject var radioManager : RadioManager

    var body: some View {
        #if os(macOS)
        let stdColor = Color(.controlTextColor)

        List(radioManager.pickerPackets, id: \.id, selection: $radioManager.pickerSelection) { packet in
            HStack {
                Text(packet.type == .local ? "LOCAL" : "SMARTLINK").frame(width: 130, alignment: .leading)
                Text(packet.nickname).frame(width: 130, alignment: .leading)
                Text(packet.status.rawValue).frame(width: 130, alignment: .leading)
                Text(packet.stations).frame(width: 130, alignment: .leading)
            }
            .foregroundColor( packet.isDefault ? .red : stdColor )
        }
        .frame(alignment: .leading)

        #elseif os(iOS)
        let stdColor = Color(.label)

        List(radioManager.pickerPackets, id: \.id, selection: $radioManager.pickerSelection) { packet in
            HStack {
                Text(packet.type == .local ? "LOCAL" : "SMARTLINK").frame(width: 130, alignment: .leading)
                Text(packet.nickname).frame(width: 130, alignment: .leading)
                Text(packet.status.rawValue).frame(width: 130, alignment: .leading)
                Text(packet.stations).frame(width: 130, alignment: .leading)
            }
            .contextMenu {
                Button {
                    print("Set packet \(packet.id) as Default")
                } label: {
                    Label("Set as Default")
                }

                Button {
                    print("Clear default")
                } label: {
                    Label("Clear default")
                }
            }
            .foregroundColor( packet.isDefault ? .red : stdColor )
        }
        .frame(alignment: .leading)
        .environment(\.editMode, .constant(EditMode.active))
        #endif
    }
}

struct RadioPickerFooterView: View {
    @EnvironmentObject var radioManager : RadioManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        HStack(spacing: 40){
            TestButtonView()
            Button("Cancel") {
                radioManager.pickerSelection = nil
                presentationMode.wrappedValue.dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Connect") {
                presentationMode.wrappedValue.dismiss()
            }
            .disabled(radioManager.pickerSelection == nil)
            .keyboardShortcut(.defaultAction)
        }
    }
}

struct TestButtonView: View {
    @EnvironmentObject var radioManager :RadioManager

    var body: some View {

        HStack {
            // only enable Test if a SmartLink connection is selected
            let testDisabled = !radioManager.delegate.smartlinkIsEnabled || radioManager.pickerSelection == nil || radioManager.pickerPackets[radioManager.pickerSelection!].type != .wan

            Button("Test") {
                    radioManager.smartlinkTest()
            }
            .popover(isPresented: $radioManager.smartlinkShowTestResults) {
                Text(radioManager.smartlinkTestResults!)
                            .padding()
            }
            .disabled(testDisabled)

            Circle()
                .fill(radioManager.smartlinkTestStatus ? Color.green : Color.red)
                .frame(width: 20, height: 20)
        }
    }
}

// ----------------------------------------------------------------------------
// MARK: - Preview

public struct RadioPickerView_Previews: PreviewProvider {    
    public static var previews: some View {
        RadioPickerView()
            .environmentObject(RadioManager(delegate: MockRadioManagerDelegate() ))
    }
}
