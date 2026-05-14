//
//  OSCTCPClient Core.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency internal import CocoaAsyncSocket
internal import SwiftOSCIOInternals
import Foundation
import SwiftOSCCore

extension OSCTCPClient {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Parent = OSCTCPClient

        let tcpSocket: GCDAsyncSocket
        let tcpDelegate: Delegate
        let clientID: OSCTCPClientSessionID = 0
        let queue: DispatchQueue
        var receiveHandler: OSCPacketHandler?
        var receiveErrorHandler: OSCDecodeErrorHandlerBlock?
        var notificationHandler: Parent.NotificationHandlerBlock?
        let remoteHost: String
        let remotePort: UInt16
        let interface: String?
        let framingMode: OSCTCPFramingMode

        init(
            remoteHost: String,
            remotePort: UInt16,
            interface: String?,
            framingMode: OSCTCPFramingMode,
            queue: DispatchQueue?,
            receiveHandler: OSCPacketHandler?
        ) {
            self.remoteHost = remoteHost
            self.remotePort = remotePort
            self.interface = interface
            self.framingMode = framingMode
            let queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCTCPClient.queue", target: .global())
            self.queue = queue
            self.receiveHandler = receiveHandler

            tcpDelegate = Delegate()
            tcpSocket = GCDAsyncSocket(delegate: tcpDelegate, delegateQueue: queue, socketQueue: nil)
            tcpDelegate.oscServer = self
        }

        deinit {
            close()
        }
    }
}

extension OSCTCPClient.Core: @unchecked Sendable { } // TODO: unchecked

// MARK: - Lifecycle

extension OSCTCPClient.Core {
    func connect(timeout: TimeInterval = 5.0) throws {
        do {
            try tcpSocket.connect(
                toHost: remoteHost,
                onPort: remotePort,
                viaInterface: interface,
                withTimeout: max(1.0, timeout) // negative values mean indefinite (no timeout) which is a bit dangerous
            )
        } catch let error as GCDAsyncSocketError where error.code == .badParamError {
            // catch invalid interface error because we have a specific SwiftOSC error case for it.
            // CocoaAsyncSocket does not provide granular enough error types to know if it's an interface error
            // so we must resort to error string introspection.
            throw OSCIOError.invalidInterface
        } catch {
            throw error
        }
    }

    func close() {
        tcpSocket.disconnectAfterWriting()
    }
}

// MARK: - Communication

extension OSCTCPClient.Core: _OSCTCPPacketHandlerProtocol {
    // provides implementation for dispatching incoming OSC data
}

extension OSCTCPClient.Core: _OSCTCPSendProtocol {
    // provides implementation for sending OSC data

    func send(_ packet: OSCPacket) throws {
        try _send(packet)
    }
}

extension OSCTCPClient.Core: OSCTCPGeneratesClientNotificationsProtocol {
    func generateConnectedNotification() {
        let notif: Parent.Notification = .connected
        notificationHandler?(notif)
    }

    func generateDisconnectedNotification(error: (any Error)?) {
        let notif: Parent.Notification = .disconnected(error: error)
        notificationHandler?(notif)
    }
}

// MARK: - Properties

extension OSCTCPClient.Core {
    var isConnected: Bool {
        tcpSocket.isConnected
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
