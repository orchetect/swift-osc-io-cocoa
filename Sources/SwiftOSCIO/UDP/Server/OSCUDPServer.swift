//
//  OSCUDPServer.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin)
import Foundation
import SwiftOSCCore
import SwiftOSCIOCore

#if os(watchOS)
// CocoaAsyncSocket does not support watchOS and will not successfully build, so use no-op stand-in
public typealias OSCUDPServer = NoOpOSCUDPServer
#else

public final class OSCUDPServer: OSCUDPServerProtocol {
    /// Internal operations core.
    let core: Core

    public init(
        port: UInt16?,
        interface: String?,
        isPortReuseEnabled: Bool,
        isIPv6Enabled: Bool,
        queue: DispatchQueue?,
        receiveHandler: OSCPacketHandler?
    ) {
        core = Core(
            port: port,
            interface: interface,
            isPortReuseEnabled: isPortReuseEnabled,
            isIPv6Enabled: isIPv6Enabled,
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

    // MARK: - Properties

    public var localPort: UInt16 {
        core.localPort
    }

    public var interface: String? {
        core.interface
    }

    public var isPortReuseEnabled: Bool {
        get { core.isPortReuseEnabled }
        set { core.isPortReuseEnabled = newValue }
    }

    public var isIPv6Enabled: Bool {
        get { core.isIPv6Enabled }
        set { core.isIPv6Enabled = newValue }
    }

    public var isStarted: Bool {
        core.isStarted
    }

    public func setReceiveHandler(_ handler: OSCPacketHandler?) {
        core.setReceiveHandler(handler)
    }

    public func setReceiveErrorHandler(_ handler: OSCDecodeErrorHandlerBlock?) {
        core.setReceiveErrorHandler(handler)
    }
}

extension OSCUDPServer: Sendable { }

#endif

#endif
