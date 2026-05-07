//
//  OSCTCPClient.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency import CocoaAsyncSocket
import Foundation
import SwiftOSCCore

/// Connects to a remote host via TCP connection in order to send and receive OSC packets over the network.
///
/// Use this class when a bidirectional TCP connection is desired to be made to a remote host.
///
/// A TCP connection is also generally more reliable than using the UDP protocol.
///
/// Since TCP is inherently a bidirectional network connection, both ``OSCTCPClient`` and ``OSCTCPServer`` can send and
/// receive once a connection is made. Messages sent by the server are only received by the client, and vice-versa.
///
/// What differentiates this client class from the server class is that the client class is designed to connect to a
/// remote TCP server. (Whereas, the server is designed to listen for inbound connections.)
public final class OSCTCPClient {
    /// Internal client core.
    let core: Core

    /// Notification type.
    public typealias Notification = OSCTCPClientNotification

    /// Notification handler closure.
    public typealias NotificationHandlerBlock = @Sendable (_ notification: Notification) -> Void

    /// Time tag mode. Determines how OSC bundle time tags are handled.
    public var timeTagMode: OSCTimeTagMode {
        get { core.timeTagMode }
        set { core.timeTagMode = newValue }
    }

    /// Remote network hostname.
    public var remoteHost: String {
        core.remoteHost
    }

    /// Remote network port.
    public var remotePort: UInt16 {
        core.remotePort
    }

    /// Network interface to restrict connections to.
    public var interface: String? {
        core.interface
    }

    /// Returns a boolean indicating whether the OSC socket is connected to the remote host.
    public var isConnected: Bool {
        core.tcpSocket.isConnected
    }

    /// TCP packet framing mode.
    public var framingMode: OSCTCPFramingMode {
        core.framingMode
    }

    /// Initialize with a remote hostname and UDP port.
    ///
    /// > Note:
    /// >
    /// > Call ``connect(timeout:)`` to connect to the remote host in order to begin sending messages.
    /// > The connection may be closed at any time by calling ``close()`` and then reconnected again as needed.
    ///
    /// - Parameters:
    ///   - remoteHost: Remote hostname or IP address.
    ///   - remotePort: Remote port number.
    ///   - interface: Optionally specify a network interface for which to constrain connections.
    ///   - timeTagMode: OSC TimeTag mode. (Default is recommended.)
    ///   - framingMode: TCP framing mode. Both server and client must use the same framing mode. (Default is recommended.)
    ///   - queue: Optionally supply a custom dispatch queue for receiving OSC packets and dispatching the
    ///     handler callback closure. If `nil`, a dedicated internal background queue will be used.
    ///   - receiveHandler: Handler to call when OSC bundles or messages are received.
    public init(
        remoteHost: String,
        remotePort: UInt16,
        interface: String? = nil,
        timeTagMode: OSCTimeTagMode = .ignore,
        framingMode: OSCTCPFramingMode = .osc1_1,
        queue: DispatchQueue? = nil,
        receiveHandler: OSCHandlerBlock? = nil
    ) {
        core = Core(
            remoteHost: remoteHost,
            remotePort: remotePort,
            interface: interface,
            timeTagMode: timeTagMode,
            framingMode: framingMode,
            queue: queue,
            receiveHandler: receiveHandler
        )
        core.parent = self
    }
}

extension OSCTCPClient: Sendable { }

// MARK: - Lifecycle

extension OSCTCPClient {
    /// Connects to the remote host.
    ///
    /// - Parameters:
    ///   - timeout: Supply a timeout period in seconds.
    public func connect(timeout: TimeInterval = 5.0) throws {
        try core.connect(timeout: timeout)
    }

    /// Close the connection, if any.
    public func close() {
        core.close()
    }
}

// MARK: - Communication

extension OSCTCPClient {
    /// Send an OSC bundle or message to the host.
    public func send(_ oscPacket: OSCPacket) throws {
        try core._send(oscPacket)
    }

    /// Send an OSC bundle to the host.
    public func send(_ oscBundle: OSCBundle) throws {
        try core._send(oscBundle)
    }

    /// Send an OSC message to the host.
    public func send(_ oscMessage: OSCMessage) throws {
        try core._send(oscMessage)
    }
}

// MARK: - Properties

extension OSCTCPClient {
    /// Set the receive handler closure.
    /// This closure will be called when OSC bundles or messages are received.
    public func setReceiveHandler(_ handler: OSCHandlerBlock?) {
        core.setReceiveHandler(handler)
    }

    /// Set the notification handler closure.
    /// This closure will be called when a notification is generated, such as connection and disconnection events.
    public func setNotificationHandler(_ handler: NotificationHandlerBlock?) {
        core.setNotificationHandler(handler)
    }
}

#endif
