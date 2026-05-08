//
//  OSCTCPServer.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

import Foundation
import SwiftOSCCore

public final class OSCTCPServer: OSCTCPServerProtocol {
    /// Internal operations core.
    let core: Core

    public init(
        port: UInt16?,
        interface: String?,
        timeTagMode: OSCTimeTagMode,
        framingMode: OSCTCPFramingMode,
        queue: DispatchQueue?,
        receiveHandler: OSCHandlerBlock?
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
    public func start() throws {
        try core.start()
    }

    public func stop() {
        core.stop()
    }
}

// MARK: - Communication

extension OSCTCPServer {
    public func send(_ oscPacket: OSCPacket) throws {
        let clientIDs = Array(core.tcpDelegate.clients.keys)
        try send(oscPacket, toClientIDs: clientIDs)
    }

    public func send(_ oscPacket: OSCPacket, toClientIDs clientIDs: [OSCTCPClientSessionID]) throws {
        for clientID in clientIDs {
            try core._send(oscPacket, toClientID: clientID)
        }
    }
}

// MARK: - Properties

extension OSCTCPServer {
    public var timeTagMode: OSCTimeTagMode {
        get { core.timeTagMode }
        set { core.timeTagMode = newValue }
    }
    
    public var localPort: UInt16 {
        core.localPort
    }
    
    public var interface: String? {
        core.interface
    }
    
    public var isStarted: Bool {
        core.isStarted
    }
    
    public var framingMode: OSCTCPFramingMode {
        core.framingMode
    }
    
    public func setReceiveHandler(_ handler: OSCHandlerBlock?) {
        core.setReceiveHandler(handler)
    }

    public func setNotificationHandler(_ handler: NotificationHandlerBlock?) {
        core.setNotificationHandler(handler)
    }

    public var clients: [OSCTCPClientSessionID: (host: String, port: UInt16)] {
        core.clients
    }

    public func disconnectClient(clientID: OSCTCPClientSessionID) {
        core.disconnectClient(clientID: clientID)
    }
}

#endif
