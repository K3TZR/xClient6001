//
//  LogPickerView.swift
//  xClient
//
//  Created by Douglas Adams on 3/4/21.
//

import SwiftUI

// ----------------------------------------------------------------------------
// MARK: - Primary view

public struct LogPickerView: View {
    @EnvironmentObject var logManager : LogManager
    @Environment(\.presentationMode) var presentationMode

    public init() {}

    public var body: some View {

        VStack {
            LogPickerHeaderView()
            Divider()
            LogPickerBodyView()
            Divider()
            LogPickerFooterView()
        }
        .frame(minHeight: 300)
        .padding()
    }
}

// ----------------------------------------------------------------------------
// MARK: - Subviews

struct LogPickerHeaderView: View {

    var body: some View {
        Text("Select a log file").font(.title)
    }
}

struct LogPickerBodyView: View {
    @EnvironmentObject var logManager : LogManager

    var body: some View {
        #if os(macOS)
        List(logManager.fileUrls, id: \.id, selection: $logManager.selection) { log in
            Text(log.url.lastPathComponent)
        }
        #elseif os(iOS)
        List(logManager.fileUrls, id: \.id, selection: $logManager.selection) { log in
            Text(log.url.lastPathComponent)
        }
        .environment(\.editMode, .constant(EditMode.active))
        #endif
    }
}

struct LogPickerFooterView: View {
    @EnvironmentObject var logger : LogManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        HStack(spacing: 80) {
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }.keyboardShortcut(.cancelAction)

            Button("Select") {
                presentationMode.wrappedValue.dismiss()
                logger.loadFile(at: logger.selection)
            }
            .disabled(logger.selection == nil)
            .keyboardShortcut(.defaultAction)
        }
        .frame(alignment: .leading)
    }
}

// ----------------------------------------------------------------------------
// MARK: - Preview

struct LogPickerView_Previews: PreviewProvider {
    static var previews: some View {
        LogPickerView().environmentObject(LogManager.sharedInstance)
    }
}
