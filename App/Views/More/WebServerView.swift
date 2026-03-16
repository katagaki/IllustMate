//
//  WebServerView.swift
//  PicMate
//
//  Created by Claude on 2026/03/16.
//

import SwiftUI

struct WebServerView: View {

    @Environment(WebServerManager.self) var webServer

    var body: some View {
        Section {
            Toggle(
                String(localized: "WebServer", table: "More"),
                isOn: Binding(
                    get: { webServer.isRunning },
                    set: { newValue in
                        if newValue {
                            webServer.start()
                        } else {
                            webServer.stop()
                        }
                    }
                )
            )
            if webServer.isRunning, let ip = webServer.localIPAddress {
                LabeledContent(String(localized: "WebServer.Address", table: "More")) {
                    Text("http://\(ip):\(webServer.port)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.accent)
                        .textSelection(.enabled)
                }
            }
        } header: {
            Text("WebServer.Header", tableName: "More")
        } footer: {
            Text("WebServer.Description", tableName: "More")
        }
    }
}
