//
//  OSCUDPServer.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

import Foundation
import SwiftOSCCore

/// Receives OSC packets from the network on a specific UDP listen port.
///
/// A single global OSC server instance is often created once at app startup to receive OSC messages
/// on a specific local port. The default OSC port is 8000 but it may be set to any open port if
/// desired.
public final class OSCUDPServer {
    /// Internal operations core.
    let core: Core

    /// Initialize an OSC server.
    ///
    /// The default port for OSC communication is 8000 but may change depending on device/software
    /// manufacturer.
    ///
    /// > Note:
    /// >
    /// > Ensure ``start()`` is called once after initialization in order to begin receiving messages.
    ///
    /// - Parameters:
    ///   - port: Local port to listen on for inbound OSC packets.
    ///     If `nil` or `0`, a random available port in the system will be chosen.
    ///   - interface: Optionally specify a network interface for which to constrain communication.
    ///   - isPortReuseEnabled: Enable local UDP port reuse by other processes to receive broadcast packets.
    ///   - timeTagMode: OSC TimeTag mode. (Default is recommended.)
    ///   - queue: Optionally supply a custom dispatch queue for receiving OSC packets and dispatching the
    ///     handler callback closure. If `nil`, a dedicated internal background queue will be used.
    ///   - receiveHandler: Handler to call when OSC bundles or messages are received.
    public init(
        port: UInt16? = 8000,
        interface: String? = nil,
        isPortReuseEnabled: Bool = false,
        timeTagMode: OSCTimeTagMode = .ignore,
        queue: DispatchQueue? = nil,
        receiveHandler: OSCHandlerBlock? = nil
    ) {
        core = Core(
            port: port,
            interface: interface,
            isPortReuseEnabled: isPortReuseEnabled,
            timeTagMode: timeTagMode,
            queue: queue,
            receiveHandler: receiveHandler
        )
        core.parent = self
    }
}

extension OSCUDPServer: Sendable { }

// MARK: - Lifecycle

extension OSCUDPServer {
    /// Bind the local UDP port and begin listening for OSC packets.
    public func start() throws {
        try core.start()
    }

    /// Stops listening for data and closes the OSC server port.
    public func stop() {
        core.stop()
    }
}

// MARK: - Properties

extension OSCUDPServer {
    /// Time tag mode. Determines how OSC bundle time tags are handled.
    public var timeTagMode: OSCTimeTagMode {
        get { core.timeTagMode }
        set { core.timeTagMode = newValue }
    }
    
    /// UDP port used by the OSC server to listen for inbound OSC packets.
    /// This may only be set at the time of initialization.
    public var localPort: UInt16 {
        core.udpSocket.localPort()
    }
    
    /// Network interface to restrict connections to.
    public var interface: String? {
        core.interface
    }
    
    /// Enable local UDP port reuse by other processes.
    /// This property must be set prior to calling ``start()`` in order to take effect.
    ///
    /// By default, only one socket can be bound to a given IP address & port combination at a time. To enable
    /// multiple processes to simultaneously bind to the same address & port, you need to enable
    /// this functionality in the socket. All processes that wish to use the address & port
    /// simultaneously must all enable reuse port on the socket bound to that port.
    ///
    /// Due to limitations of `SO_REUSEPORT` on Apple platforms, enabling this only permits receipt of broadcast
    /// or multicast messages for any additional sockets which bind to the same address and port. Unicast
    /// messages are only received by the first socket to bind.
    public var isPortReuseEnabled: Bool {
        get { core.isPortReuseEnabled }
        set { core.isPortReuseEnabled = newValue }
    }
    
    /// Returns a boolean indicating whether the OSC server has been started.
    public var isStarted: Bool {
        core.isStarted
    }
    
    /// Set the receive handler closure.
    /// This closure will be called when OSC bundles or messages are received.
    public func setReceiveHandler(_ handler: OSCHandlerBlock?) {
        core.setReceiveHandler(handler)
    }
}

#endif
