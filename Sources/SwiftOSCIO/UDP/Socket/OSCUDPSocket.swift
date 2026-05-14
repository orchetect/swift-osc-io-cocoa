//
//  OSCUDPSocket.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin)
import Foundation
import SwiftOSCCore
import SwiftOSCIOCore

#if os(watchOS)
// CocoaAsyncSocket does not support watchOS and will not successfully build, so use no-op stand-in
public typealias OSCUDPSocket = NoOpOSCUDPSocket
#else

public final class OSCUDPSocket: OSCUDPSocketProtocol {
    /// Internal operations core.
    let core: Core

    public init(
        localPort: UInt16?,
        remoteHost: String?,
        remotePort: UInt16?,
        interface: String?,
        isIPv4BroadcastEnabled: Bool,
        queue: DispatchQueue?,
        receiveHandler: OSCPacketHandler?
    ) {
        core = Core(
            localPort: localPort,
            remoteHost: remoteHost,
            remotePort: remotePort,
            interface: interface,
            isIPv4BroadcastEnabled: isIPv4BroadcastEnabled,
            queue: queue,
            receiveHandler: receiveHandler
        )
    }

    // MARK: - Lifecycle

    public func start() throws {
        try core.start()
    }

    public func stop() {
        core.stop()
    }

    // MARK: - Communication

    public func send(_ packet: OSCPacket, to host: String?, port: UInt16?) throws {
        try core.send(packet, to: host, port: port)
    }

    // MARK: - Properties

    public var remoteHost: String? {
        get { core.remoteHost }
        set { core.remoteHost = newValue }
    }

    public var localPort: UInt16 {
        core.localPort
    }

    public var remotePort: UInt16 {
        get { core.remotePort }
        set { core.remotePort = newValue }
    }

    public var interface: String? {
        core.interface
    }

    public var isIPv4BroadcastEnabled: Bool {
        core.isIPv4BroadcastEnabled
    }

    public var isStarted: Bool {
        core.isStarted
    }

    public func setReceiveHandler(_ handler: OSCPacketHandler?) {
        core.setReceiveHandler(handler)
    }
}

extension OSCUDPSocket: Sendable { }

#endif

#endif
