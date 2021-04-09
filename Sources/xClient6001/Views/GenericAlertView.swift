//
//  GenericAlertView.swift
//  xClient
//
//  Created by Douglas Adams on 12/5/20.
//

#if os(macOS)
import SwiftUI

// ----------------------------------------------------------------------------
// MARK: - Primary view

public struct GenericAlertView: View {
    @EnvironmentObject var radioManager : RadioManager
    
    public init() {}

    public var body: some View {
        
        VStack(spacing: 20) {
            GenericAlertHeaderView(params: radioManager.currentAlert)
            Divider()
            GenericAlertBodyView(params: radioManager.currentAlert)
        }.padding()
    }
}

// ----------------------------------------------------------------------------
// MARK: - Subviews

struct GenericAlertHeaderView: View {
    let params: AlertParams

    var body: some View {
        Text(params.title).font(.title)

        if params.message == "" {
            EmptyView()
        } else {
            HStack {
                if params.symbolName == "" {
                    EmptyView()
                } else {
                Image(systemName: params.symbolName)
                    .font(.system(size: 30))
                }

                Text(params.message)
                    .multilineTextAlignment(.center)
                    .font(.body)
            }
        }
    }
}

struct GenericAlertBodyView: View {
    let params: AlertParams
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 10) {
            ForEach(params.buttons.indices) { i in
                let button = params.buttons[i]
                if button.text == "Cancel" {
                    Button(action: {
                        button.action()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(button.text)
                            .frame(width: 175)
                            .foregroundColor(button.color == nil ? Color(.controlTextColor) : button.color)
                    }.keyboardShortcut(.cancelAction)

                } else {
                    Button(action: {
                        button.action()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(button.text)
                            .frame(width: 175)
                            .foregroundColor(button.color == nil ? Color(.controlTextColor) : button.color)
                    }
                }
            }.frame(width: 250)
        }
    }
}

// ----------------------------------------------------------------------------
// MARK: - Preview

public struct GenericAlertView_Previews: PreviewProvider {
    public static var previews: some View {
        GenericAlertView()
            .environmentObject(RadioManager(delegate: MockRadioManagerDelegate()))
    }
}
#endif
