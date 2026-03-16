//
//  WebServerManager.swift
//  PicMate
//
//  Created by Claude on 2026/03/16.
//

import Foundation
import Network

@MainActor @Observable
class WebServerManager {

    // MARK: - Observable State

    var isRunning: Bool = false
    var localIPAddress: String?
    var port: UInt16 = 8080
    var connectionCount: Int = 0

    // MARK: - Private

    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var activeConnections: [ObjectIdentifier: NWConnection] = [:]

    // MARK: - Lifecycle

    func start() {
        guard listener == nil else { return }
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
            let newListener = try NWListener(using: parameters, on: nwPort)

            newListener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.handleNewConnection(connection)
                }
            }

            newListener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        self.isRunning = true
                        self.refreshIPAddress()
                    case .failed:
                        self.stop()
                    case .cancelled:
                        self.isRunning = false
                    default:
                        break
                    }
                }
            }

            listener = newListener
            newListener.start(queue: .global(qos: .userInitiated))
        } catch {
            debugPrint("Failed to create listener: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for (_, connection) in activeConnections {
            connection.cancel()
        }
        activeConnections.removeAll()
        isRunning = false
        connectionCount = 0
        localIPAddress = nil
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        let connectionID = ObjectIdentifier(connection)
        activeConnections[connectionID] = connection
        connectionCount = activeConnections.count

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .cancelled, .failed:
                    self.activeConnections.removeValue(forKey: connectionID)
                    self.connectionCount = self.activeConnections.count
                default:
                    break
                }
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
        receiveHTTPData(on: connection, accumulated: Data())
    }

    nonisolated func receiveHTTPData(
        on connection: NWConnection,
        accumulated: Data
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else {
                connection.cancel()
                return
            }

            var buffer = accumulated
            buffer.append(data)

            // Check if we have complete headers
            let headerTerminator = Data("\r\n\r\n".utf8)
            guard let headerEndRange = buffer.range(of: headerTerminator) else {
                if buffer.count > 1_048_576 {
                    // Headers too large, reject
                    let response = HTTPResponse.badRequest("Headers too large")
                    self.sendResponse(response, on: connection)
                    return
                }
                // Headers not complete yet, keep receiving
                self.receiveHTTPData(on: connection, accumulated: buffer)
                return
            }

            let headerData = buffer[buffer.startIndex..<headerEndRange.lowerBound]
            guard let headerString = String(data: headerData, encoding: .utf8) else {
                connection.cancel()
                return
            }

            let bodyStartIndex = headerEndRange.upperBound
            let currentBody = buffer[bodyStartIndex...]

            // Parse Content-Length
            let contentLength = parseContentLength(from: headerString)

            if currentBody.count < contentLength {
                // Need more body data
                self.receiveHTTPBody(
                    on: connection,
                    headerString: headerString,
                    bodyBuffer: Data(currentBody),
                    expectedLength: contentLength
                )
            } else {
                // Complete request
                let body = Data(currentBody.prefix(contentLength))
                let request = Self.buildHTTPRequest(headerString: headerString, body: body)
                self.dispatchRequest(request, on: connection)
            }
        }
    }

    nonisolated func receiveHTTPBody(
        on connection: NWConnection,
        headerString: String,
        bodyBuffer: Data,
        expectedLength: Int
    ) {
        // Enforce max upload size of 50 MB
        let maxSize = 50 * 1024 * 1024
        guard expectedLength <= maxSize else {
            let response = HTTPResponse.badRequest("Upload too large (max 50 MB)")
            sendResponse(response, on: connection)
            return
        }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else {
                connection.cancel()
                return
            }

            var buffer = bodyBuffer
            buffer.append(data)

            if buffer.count < expectedLength {
                self.receiveHTTPBody(
                    on: connection,
                    headerString: headerString,
                    bodyBuffer: buffer,
                    expectedLength: expectedLength
                )
            } else {
                let body = Data(buffer.prefix(expectedLength))
                let request = Self.buildHTTPRequest(headerString: headerString, body: body)
                self.dispatchRequest(request, on: connection)
            }
        }
    }

    nonisolated private func dispatchRequest(_ request: HTTPRequest, on connection: NWConnection) {
        Task {
            let response = await self.handleRequest(request)
            self.sendResponse(response, on: connection)
        }
    }

    nonisolated private func sendResponse(_ response: HTTPResponse, on connection: NWConnection) {
        let data = response.serialized()
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - IP Address Discovery

    func refreshIPAddress() {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil, 0,
                        NI_NUMERICHOST
                    )
                    address = String(decoding: hostname.map { UInt8(bitPattern: $0) }.prefix(while: { $0 != 0 }), as: UTF8.self)
                }
            }
        }
        localIPAddress = address
    }

    // MARK: - HTTP Parsing Helpers (nonisolated)

    nonisolated private func parseContentLength(from headerString: String) -> Int {
        let lines = headerString.components(separatedBy: "\r\n")
        for line in lines {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:") {
                let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                return Int(value) ?? 0
            }
        }
        return 0
    }

    nonisolated static func buildHTTPRequest(headerString: String, body: Data) -> HTTPRequest {
        HTTPRequestParser.parse(headerString: headerString, body: body)
    }
}
