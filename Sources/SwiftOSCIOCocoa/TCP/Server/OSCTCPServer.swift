//
//  OSCTCPServer.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

import Foundation
import SwiftOSCCore

/// Listens on a local port for TCP connections in order to send and receive OSC packets over the network.
///
/// Use this class when you are taking the role of the host and one or more remote clients will want to connect via
/// bidirectional TCP connection.
///
/// A TCP connection is also generally more reliable than using the UDP protocol.
///
/// Since TCP is inherently a bidirectional network connection, both ``OSCTCPClient`` and ``OSCTCPServer`` can send and
/// receive once a connection is made. Messages sent by the server are only received by the client, and vice-versa.
///
/// What differentiates this server class from the client class is that the server is designed to listen for inbound
/// connections. (Whereas, the client class is designed to connect to a remote TCP server.)
public final class OSCTCPServer {
    /// Internal operations core.
    let core: Core

    /// Notification type.
    public typealias Notification = OSCTCPServerNotification

    /// Notification handler closure.
    public typealias NotificationHandlerBlock = @Sendable (_ notification: Notification) -> Void

    /// Initialize with a remote hostname and UDP port.
    ///
    /// > Note:
    /// >
    /// > Call ``start()`` to begin listening for connections.
    /// > The connections may be closed at any time by calling ``stop()`` and then restarted again as needed.
    ///
    /// - Parameters:
    ///   - port: Local network port to listen for inbound connections.
    ///     If `nil` or `0`, a random available port in the system will be chosen.
    ///   - interface: Optionally specify a network interface for which to constrain connections.
    ///   - timeTagMode: OSC TimeTag mode. Default is recommended.
    ///   - framingMode: TCP framing mode. Both server and client must use the same framing mode. (Default is recommended.)
    ///   - queue: Optionally supply a custom dispatch queue for receiving OSC packets and dispatching the
    ///     handler callback closure. If `nil`, a dedicated internal background queue will be used.
    ///   - receiveHandler: Handler to call when OSC bundles or messages are received.
    public init(
        port: UInt16?,
        interface: String? = nil,
        timeTagMode: OSCTimeTagMode = .ignore,
        framingMode: OSCTCPFramingMode = .osc1_1,
        queue: DispatchQueue? = nil,
        receiveHandler: OSCHandlerBlock? = nil
    ) {
        core = Core(
            port: port,
            interface: interface,
            timeTagMode: timeTagMode,
            framingMode: framingMode,
            queue: queue,
            receiveHandler: receiveHandler
        )
        core.parent = self
    }
}

extension OSCTCPServer: Sendable { }

// MARK: - Lifecycle

extension OSCTCPServer {
    /// Starts listening for inbound connections.
    public func start() throws {
        try core.start()
    }

    /// Closes any open client connections and stops listening for inbound connection requests.
    public func stop() {
        core.stop()
    }
}

// MARK: - Communication

extension OSCTCPServer {
    /// Send an OSC bundle or message to all connected clients.
    public func send(_ oscPacket: OSCPacket) throws {
        let clientIDs = Array(core.tcpDelegate.clients.keys)
        try send(oscPacket, toClientIDs: clientIDs)
    }

    /// Send an OSC bundle to all connected clients.
    public func send(_ oscBundle: OSCBundle) throws {
        try send(.bundle(oscBundle))
    }

    /// Send an OSC message to all connected clients.
    public func send(_ oscMessage: OSCMessage) throws {
        try send(.message(oscMessage))
    }

    /// Send an OSC bundle or message to one or more connected clients.
    public func send(_ oscPacket: OSCPacket, toClientIDs clientIDs: [OSCTCPClientSessionID]) throws {
        for clientID in clientIDs {
            try core._send(oscPacket, toClientID: clientID)
        }
    }

    /// Send an OSC bundle to one or more connected clients.
    public func send(_ oscBundle: OSCBundle, toClientIDs clientIDs: [OSCTCPClientSessionID]) throws {
        try send(.bundle(oscBundle), toClientIDs: clientIDs)
    }

    /// Send an OSC message to one or more connected clients.
    public func send(_ oscMessage: OSCMessage, toClientIDs clientIDs: [OSCTCPClientSessionID]) throws {
        try send(.message(oscMessage), toClientIDs: clientIDs)
    }
}

// MARK: - Properties

extension OSCTCPServer {
    /// Time tag mode. Determines how OSC bundle time tags are handled.
    public var timeTagMode: OSCTimeTagMode {
        get { core.timeTagMode }
        set { core.timeTagMode = newValue }
    }
    
    /// Local network port.
    public var localPort: UInt16 {
        core.localPort
    }
    
    /// Network interface to restrict connections to.
    public var interface: String? {
        core.interface
    }
    
    /// Returns a boolean indicating whether the OSC server has been started.
    public var isStarted: Bool {
        core.isStarted
    }
    
    /// TCP packet framing mode.
    public var framingMode: OSCTCPFramingMode {
        core.framingMode
    }
    
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

    /// Returns a dictionary of currently connected clients keyed by client session ID.
    ///
    /// > Note:
    /// >
    /// > A client ID is transient and only valid for the lifecycle of the connection. Client IDs are randomly-assigned
    /// > upon each newly-made connection. For this reason, these IDs should not be stored persistently, but instead
    /// > queried from the OSC TCP server when a client connects or analyzing currently-connected clients.
    public var clients: [OSCTCPClientSessionID: (host: String, port: UInt16)] {
        core.clients
    }

    /// Disconnect a connected client from the server.
    public func disconnectClient(clientID: OSCTCPClientSessionID) {
        core.disconnectClient(clientID: clientID)
    }
}

#endif
