//
//  LogView.swift
//  xClient
//
//  Created by Douglas Adams on 10/10/20.
//

import SwiftUI
#if os(iOS)
import MessageUI
#endif

/// A View to display the contents of the app's log
///
public struct LogView: View {
    @EnvironmentObject var logManager : LogManager
    @EnvironmentObject var radioManager : RadioManager
    @Environment(\.presentationMode) var presentationMode

    public init() {}

    public var body: some View {
        
        VStack {
            LogHeaderView()
            Divider()
            LogBodyView()
            Divider()
            LogFooterView()
        }
        .frame(minWidth: 700)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .onAppear() {
            logManager.loadDefaultLog()
        }
        .sheet(isPresented: $logManager.showLogPicker) {
            LogPickerView().environmentObject(logManager)
        }
    }
}

struct LogHeaderView: View {
    @EnvironmentObject var logManager: LogManager

    var body: some View {
        #if os(macOS)
        HStack {
            Picker("Show Level", selection: $logManager.level) {
                ForEach(LogManager.LogLevel.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }.frame(width: 175)

            Spacer()
            Picker("Filter by", selection: $logManager.filterBy) {
                ForEach(LogManager.LogFilter.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }.frame(width: 175)

            TextField("Filter text", text: $logManager.filterByText)
                .frame(maxWidth: 300, alignment: .leading)
                .modifier(ClearButton(boundText: $logManager.filterByText))

            Spacer()
            Toggle(isOn: $logManager.showTimestamps) { Text("Show Timestamps") }
        }
        #elseif os(iOS)
        HStack {
            Text("Show Level")
            Picker(logManager.level.rawValue, selection: $logManager.level) {
                ForEach(LogManager.LogLevel.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }.frame(width: 175)

            Spacer()
            Text("Filter by")
            Picker(logManager.filterBy.rawValue, selection: $logManager.filterBy) {
                ForEach(LogManager.LogFilter.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }.frame(width: 175)

            TextField("Filter text", text: $logManager.filterByText)
                .frame(maxWidth: 300, alignment: .leading)
                .modifier(ClearButton(boundText: $logManager.filterByText))

            Spacer()
            Toggle(isOn: $logManager.showTimestamps) { Text("Show Timestamps") }
        }
        .pickerStyle(MenuPickerStyle())
        #endif
    }
}

struct LogBodyView: View {
    @EnvironmentObject var logManager: LogManager

    func lineColor(_ text: String) -> Color {
        if text.contains("[Debug]") {
            return .gray
        } else if  text.contains("[Info]") {
            return .primary
        } else if  text.contains("[Warning]") {
            return .orange
        } else if  text.contains("[Error]") {
            return .red
        } else {
            return .primary
        }
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading) {
                ForEach(logManager.logLines) { line in
                    Text(line.text)
                        .font(.system(size: CGFloat(logManager.fontSize), weight: .regular, design: .monospaced))
                        .foregroundColor(lineColor(line.text))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LogFooterView: View {
    @EnvironmentObject var logManager: LogManager

    #if os(macOS)
    var body: some View {
        HStack {
            Stepper("Font Size", value: $logManager.fontSize, in: 8...24)

            Spacer()
            Button("Email") { logManager.emailLog() }

            Spacer()
            HStack (spacing: 20) {
                Button("Refresh") { logManager.refreshLog() }
                Button("Load") { logManager.loadLog() }
                Button("Save") { logManager.saveLog() }
            }

            Spacer()
            Button("Clear") { logManager.clearLog() }
        }
    }

    #elseif os(iOS)
    @State private var result: Result<MFMailComposeResult, Error>? = nil
    @State private var isShowingMailView = false

    @State private var mailFailed = false

    var body: some View {
        HStack (spacing: 40) {
            Stepper("Font Size", value: $logManager.fontSize, in: 8...24).frame(width: 175)

            Spacer()
            Button("Email", action: {
                if MFMailComposeViewController.canSendMail() {
                    self.isShowingMailView.toggle()
                } else {
                    mailFailed = true
                }
            })
//            .disabled(logger.openFileUrl == nil)
            .alert(isPresented: $mailFailed) {
                Alert(title: Text("Unable to send Mail"),
                      message:  Text(result == nil ? "" : String(describing: result)),
                      dismissButton: .cancel(Text("Cancel")))
            }
            .sheet(isPresented: $isShowingMailView) {
                MailView(result: $result) { composer in
                    composer.setSubject("\(logManager.appName) Log")
                    composer.setToRecipients([logManager.supportEmail])
                    composer.addAttachmentData(logManager.getLogData()!, mimeType: "txt/plain", fileName: "\(logManager.appName)Log.txt")
                }
            }
            HStack (spacing: 40) {
                Button("Refresh", action: {logManager.refreshLog() })
                Button("Load", action: {logManager.loadLog() })
                    .alert(isPresented: $logManager.loadFailed) {
                        Alert(title: Text("Unable to load Log file"),
                              message:  Text(""),
                              dismissButton: .cancel(Text("Cancel")))
                    }
            }
            Button("Clear", action: {logManager.clearLog() })
        }
    }
    #endif
}

#if os(iOS)
// https://stackoverflow.com/questions/56784722/swiftui-send-email
public struct MailView: UIViewControllerRepresentable {

    @Environment(\.presentationMode) var presentation
    @Binding var result: Result<MFMailComposeResult, Error>?
    public var configure: ((MFMailComposeViewController) -> Void)?

    public class Coordinator: NSObject, MFMailComposeViewControllerDelegate {

        @Binding var presentation: PresentationMode
        @Binding var result: Result<MFMailComposeResult, Error>?

        init(presentation: Binding<PresentationMode>,
             result: Binding<Result<MFMailComposeResult, Error>?>) {
            _presentation = presentation
            _result = result
        }

        public func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            defer {
                $presentation.wrappedValue.dismiss()
            }
            guard error == nil else {
                self.result = .failure(error!)
                return
            }
            self.result = .success(result)
        }
    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(presentation: presentation,
                           result: $result)
    }

    public func makeUIViewController(context: UIViewControllerRepresentableContext<MailView>) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        configure?(vc)
        return vc
    }

    public func updateUIViewController(
        _ uiViewController: MFMailComposeViewController,
        context: UIViewControllerRepresentableContext<MailView>) {

    }
}
#endif

public struct LoggerView_Previews: PreviewProvider {
    public static var previews: some View {
        LogView()
            .environmentObject(RadioManager(delegate: MockRadioManagerDelegate()))
            .environmentObject(LogManager.sharedInstance)
    }
}
