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

        var isIPv6Enabled: Bool {
            didSet {
                if isConnected {
                    print("Setting isIPv6Enabled will not have any effect until the TCP client is disconnected and reconnected again.")
                }
            }
        }
        
        var isIPv6AddressTranslationToIPv4Enabled: Bool = false
        
        init(
            remoteHost: String,
            remotePort: UInt16,
            interface: String?,
            isIPv6Enabled: Bool,
            framingMode: OSCTCPFramingMode,
            queue: DispatchQueue?,
            receiveHandler: OSCPacketHandler?
        ) {
            self.remoteHost = remoteHost
            self.remotePort = remotePort
            self.interface = interface
            self.isIPv6Enabled = isIPv6Enabled
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
        // sanitize inputs
        // negative values mean indefinite (no timeout) which is a bit dangerous
        let timeout = max(1.0, timeout)
        
        let remoteHost: String
        if isIPv6Enabled {
            // CocoaAsyncSocket operates in an egalitarian mode by default that supports both IPv4 and IPv6
            remoteHost = self.remoteHost
        } else {
            if isIPv6AddressTranslationToIPv4Enabled {
                // translate an IPv6 host/IP to an IPv4 if possible.
                let proposedRemoteHost = try IPUtils.ipAddressUsingReverseLookup(forHostnameOrIPAddress: self.remoteHost, family: .ipv4)
                guard let proposedRemoteHost else {
                    throw OSCIOError.noRemoteHost // TODO: could use a new invalidRemoteHost case
                }
                remoteHost = proposedRemoteHost
            } else {
                // use host as-is. if it's an IPv6 address (or CocoaAsyncSocket resolves it to one),
                // then it will throw an error during `connect()` since we will be disabling IPv6 on the socket.
                remoteHost = self.remoteHost
            }
        }
        
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
            try tcpSocket.connect(
                toHost: remoteHost,
                onPort: remotePort,
                viaInterface: interface,
                withTimeout: timeout
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
    }

    func close() {
        tcpSocket.disconnectAfterWriting()
    }
}

// MARK: - Communication

extension OSCTCPClient.Core: _OSCTCPPacketDispatcherProtocol {
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
