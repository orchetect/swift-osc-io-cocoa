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

        /// Internal queue used for synchronizing access to mutable properties.
        let syncQueue = DispatchQueue(label: "com.orchetect.SwiftOSC.OSCTCPServer.Core.syncQueue", target: .global())

        let tcpSocket: GCDAsyncSocket
        let tcpDelegate: Parent.Core.Delegate
        let queue: DispatchQueue

        var receiveHandler: OSCPacketHandler? {
            get { syncQueue.sync { _receiveHandler } }
            set { syncQueue.sync { _receiveHandler = newValue } }
        }

        nonisolated(unsafe) private var _receiveHandler: OSCPacketHandler?

        var receiveErrorHandler: OSCDecodeErrorHandlerBlock? {
            get { syncQueue.sync { _receiveErrorHandler } }
            set { syncQueue.sync { _receiveErrorHandler = newValue } }
        }

        nonisolated(unsafe) private var _receiveErrorHandler: OSCDecodeErrorHandlerBlock?

        var notificationHandler: Parent.NotificationHandlerBlock? {
            get { syncQueue.sync { _notificationHandler } }
            set { syncQueue.sync { _notificationHandler = newValue } }
        }

        nonisolated(unsafe) private var _notificationHandler: Parent.NotificationHandlerBlock?

        var localPort: UInt16 {
            tcpSocket.localPort
        }

        private var preferredLocalPort: UInt16? {
            get { syncQueue.sync { _preferredLocalPort } }
            set { syncQueue.sync { _preferredLocalPort = newValue } }
        }

        nonisolated(unsafe) private var _preferredLocalPort: UInt16?

        let interface: String?

        var isIPv6Enabled: Bool {
            get {
                syncQueue.sync { _isIPv6Enabled }
            }
            set {
                syncQueue.sync { _isIPv6Enabled = newValue }
                if isStarted {
                    print("Setting isIPv6Enabled will not have any effect until the TCP server is stopped and restarted again.")
                }
            }
        }

        nonisolated(unsafe) private var _isIPv6Enabled: Bool

        private(set) var isStarted: Bool {
            get { syncQueue.sync { _isStarted } }
            set { syncQueue.sync { _isStarted = newValue } }
        }

        nonisolated(unsafe) private var _isStarted: Bool = false

        let framingMode: OSCTCPFramingMode

        init(
            port: UInt16?,
            interface: String?,
            isIPv6Enabled: Bool,
            framingMode: OSCTCPFramingMode,
            queue: DispatchQueue?,
            receiveHandler: OSCPacketHandler?
        ) {
            _preferredLocalPort = (port == nil || port == 0) ? nil : port
            self.interface = interface
            _isIPv6Enabled = isIPv6Enabled
            self.framingMode = framingMode
            let queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCTCPServer.queue", target: .global())
            self.queue = queue
            _receiveHandler = receiveHandler

            tcpDelegate = Parent.Core.Delegate(framingMode: framingMode)
            tcpSocket = GCDAsyncSocket(delegate: tcpDelegate, delegateQueue: queue, socketQueue: nil) // do NOT use syncQueue
            tcpDelegate.oscServer = self
        }

        deinit {
            stop()
        }
    }
}

extension OSCTCPServer.Core: Sendable { }

// MARK: - Lifecycle

extension OSCTCPServer.Core {
    func start() throws {
        guard !isStarted else { return }

        // by default, if interface is passed as `nil`, CocoaAsyncSocket will bind to the "any" wildcard.
        // but we can't pass the actual string to the `interface` parameter of bind() so we need to translate it to `nil`.
        let interface = (interface == "0.0.0.0" || interface == "::") ? nil : interface

        if isIPv6Enabled {
            // by default, both IPv4 and IPv6 are enabled
            tcpSocket.isIPv4PreferredOverIPv6 = true // still prefer v4 when possible
            tcpSocket.isIPv6Enabled = true
        } else {
            // by default, both IPv4 and IPv6 are enabled
            tcpSocket.isIPv4PreferredOverIPv6 = true
            tcpSocket.isIPv6Enabled = false
        }

        do {
            // CocoaAsyncSocket operates in an egalitarian mode by default that supports both IPv4 and IPv6
            try tcpSocket.accept(
                onInterface: interface,
                port: preferredLocalPort ?? 0 // 0 causes system to assign random open port
            )
        } catch let error as GCDAsyncSocketError
            where error.code == .badParamError
            && error.localizedDescription.localizedCaseInsensitiveContains("Unknown interface")
        {
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

extension OSCTCPServer.Core: _OSCTCPPacketDispatcherProtocol {
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
    var localHost: String? {
        isStarted ? tcpSocket.localHost : nil
    }

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
        receiveHandler = handler
    }

    func setReceiveErrorHandler(_ handler: OSCDecodeErrorHandlerBlock?) {
        receiveErrorHandler = handler
    }

    func setNotificationHandler(_ handler: Parent.NotificationHandlerBlock?) {
        notificationHandler = handler
    }
}

#endif
