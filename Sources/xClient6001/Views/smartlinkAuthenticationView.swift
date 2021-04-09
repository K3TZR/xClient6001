//
//  NewSmartlinkAuthorizationView.swift
//  xClient
//
//  Created by Douglas Adams on 3/16/21.
//

import SwiftUI

// ----------------------------------------------------------------------------
// MARK: - Primary view

public struct smartlinkAuthenticationView: View {
    @EnvironmentObject var radioManager : RadioManager
    @Environment(\.presentationMode) var presentationMode

    @State var email = ""
    @State var password = ""

    public init() {
    }

    public var body: some View {
        VStack(spacing: 30) {
            Text("Smartlink Login").font(.title)
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 40) {
                    Text("Email:")
                    Text("Password:")
                }

                VStack(alignment: .leading, spacing: 40) {
                    TextField("", text: $email)
                        .modifier(ClearButton(boundText: $email))
                    SecureField("", text: $password)
                        .modifier(ClearButton(boundText: $password))
                }
            }

            HStack(spacing: 60) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Log in") {
                    presentationMode.wrappedValue.dismiss()
                    radioManager.smartlinkAuthenticate(email: email, password: password)
                }
                .disabled(email == "" || password == "")
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(minWidth: 400)
        .padding()
    }
}

// ----------------------------------------------------------------------------
// MARK: - Preview

public struct smartlinkAuthenticationView_Previews: PreviewProvider {
    public static var previews: some View {
        smartlinkAuthenticationView()
            .environmentObject(RadioManager(delegate: MockRadioManagerDelegate()))
    }
}
