//
//  OSCTCPServer Core.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency internal import CocoaAsyncSocket
internal import SwiftOSCIOInternals
import Foundation
import SwiftOSCCore

extension OSCTCPServer {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Parent = OSCTCPServer

        let tcpSocket: GCDAsyncSocket
        let tcpDelegate: Parent.Delegate
        let queue: DispatchQueue
        var receiveHandler: OSCPacketHandler?
        var receiveErrorHandler: OSCDecodeErrorHandlerBlock?
        var notificationHandler: NotificationHandlerBlock?
        var localPort: UInt16 {
            tcpSocket.localPort
        }

        var _localPort: UInt16?
        let interface: String?
        private(set) var isStarted: Bool = false
        let framingMode: OSCTCPFramingMode

        init(
            port: UInt16?,
            interface: String? = nil,
            framingMode: OSCTCPFramingMode,
            queue: DispatchQueue?,
            receiveHandler: OSCPacketHandler?
        ) {
            _localPort = (port == nil || port == 0) ? nil : port
            self.interface = interface
            self.framingMode = framingMode
            let queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCTCPServer.queue", target: .global())
            self.queue = queue
            self.receiveHandler = receiveHandler

            tcpDelegate = Parent.Delegate(framingMode: framingMode)
            tcpSocket = GCDAsyncSocket(delegate: tcpDelegate, delegateQueue: queue, socketQueue: nil)
            tcpDelegate.oscServer = self
        }

        deinit {
            stop()
        }
    }
}

extension OSCTCPServer.Core: @unchecked Sendable { } // TODO: unchecked

// MARK: - Lifecycle

extension OSCTCPServer.Core {
    func start() throws {
        guard !isStarted else { return }

        do {
            try tcpSocket.accept(
                onInterface: interface,
                port: _localPort ?? 0 // 0 causes system to assign random open port
            )
        } catch let error as GCDAsyncSocketError where error.code == .badParamError {
            // catch invalid interface error because we have a specific SwiftOSC error case for it.
            // CocoaAsyncSocket does not provide granular enough error types to know if it's an interface error
            // so we must resort to error string introspection.
            throw OSCIOError.invalidInterface
        } catch {
            throw error
        }

        isStarted = true
    }

    func stop() {
        // disconnect all clients
        tcpDelegate.closeClients()

        // close server
        tcpSocket.disconnectAfterWriting()

        isStarted = false
    }
}

// MARK: - Communication

extension OSCTCPServer.Core {
    func send(
        _ packet: OSCPacket,
        toClientIDs clientIDs: [OSCTCPClientSessionID]?,
        errorHandler: ((_ clientID: OSCTCPClientSessionID, _ error: any Error) -> Void)?
    ) {
        let clientIDs = clientIDs ?? Array(tcpDelegate.clients.keys)
        for clientID in clientIDs {
            do {
                try send(packet, toClientID: clientID)
            } catch {
                errorHandler?(clientID, error)
            }
        }
    }

    func send(_ packet: OSCPacket, toClientID clientID: OSCTCPClientSessionID) throws {
        guard let connection = tcpDelegate.clients[clientID] else {
            throw OSCIOError.clientNotFound(clientID: clientID)
        }

        try connection._send(packet)
    }
}

extension OSCTCPServer.Core: _OSCTCPPacketHandlerProtocol {
    // provides implementation for dispatching incoming OSC data
}

extension OSCTCPServer.Core: OSCTCPGeneratesServerNotificationsProtocol {
    func generateConnectedNotification(remoteHost: String, remotePort: UInt16, clientID: OSCTCPClientSessionID) {
        let notif: Parent.Notification = .connected(remoteHost: remoteHost, remotePort: remotePort, clientID: clientID)
        notificationHandler?(notif)
    }

    func generateDisconnectedNotification(
        remoteHost: String,
        remotePort: UInt16,
        clientID: OSCTCPClientSessionID,
        error: (any Error)?
    ) {
        let notif: Parent.Notification = .disconnected(remoteHost: remoteHost, remotePort: remotePort, clientID: clientID, error: error)
        notificationHandler?(notif)
    }
}

// MARK: - Properties

extension OSCTCPServer.Core {
    var clients: [OSCTCPClientSessionID: (host: String, port: UInt16)] {
        tcpDelegate
            .clients
            .reduce(into: [:] as [OSCTCPClientSessionID: (host: String, port: UInt16)]) { base, element in
                base[element.key] = (
                    host: element.value.remoteHost,
                    port: element.value.remotePort
                )
            }
    }

    func disconnectClient(clientID: OSCTCPClientSessionID) {
        tcpDelegate.closeClient(clientID: clientID)
    }

    func setReceiveHandler(_ handler: OSCPacketHandler?) {
        queue.sync {
            self.receiveHandler = handler
        }
    }

    func setReceiveErrorHandler(_ handler: OSCDecodeErrorHandlerBlock?) {
        queue.sync {
            self.receiveErrorHandler = handler
        }
    }

    func setNotificationHandler(_ handler: Parent.NotificationHandlerBlock?) {
        queue.sync {
            self.notificationHandler = handler
        }
    }
}

#endif
