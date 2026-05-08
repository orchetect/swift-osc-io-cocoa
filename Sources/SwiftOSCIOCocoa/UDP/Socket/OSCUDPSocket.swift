//
//  OSCUDPSocket.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency internal import CocoaAsyncSocket
import Foundation
import SwiftOSCCore

/// Sends and receives OSC packets over the network by binding a single local UDP port to both send
/// OSC packets from and listen for incoming packets.
///
/// The `OSCUDPSocket` object internally combines both an OSC server and client sharing the same local
/// UDP port number. What sets it apart from ``OSCUDPServer`` and ``OSCUDPClient`` is that it does not
/// require enabling port reuse to accomplish this. It also can conceptually make communicating
/// bidirectionally with a single remote host more intuitive.
///
/// This also fulfils a niche requirement for communicating with OSC devices such as the Behringer
/// X32 & M32 which respond back using the UDP port that they receive OSC messages from. For
/// example: if an OSC message was sent from port 8000 to the X32's port 10023, the X32 will respond
/// by sending OSC messages back to you on port 8000.
public final class OSCUDPSocket {
    /// Internal operations core.
    let core: Core

    /// Time tag mode. Determines how OSC bundle time tags are handled.
    public var timeTagMode: OSCTimeTagMode {
        get { core.timeTagMode }
        set { core.timeTagMode = newValue }
    }

    /// Remote network hostname.
    /// If non-nil, this host will be used in calls to ``send(_:to:port:)-(OSCPacket,_,_)``. The host may still be
    /// overridden using the `host` parameter in the call to ``send(_:to:port:)-(OSCPacket,_,_)``..
    public var remoteHost: String? {
        get { core.remoteHost }
        set { core.remoteHost = newValue }
    }

    /// Local UDP port used to both send OSC packets from and listen for incoming packets.
    /// This may only be set at the time of initialization.
    ///
    /// The default port for OSC communication is 8000 but may change depending on device/software
    /// manufacturer.
    ///
    /// > Note:
    /// >
    /// > If `localPort` was not specified at the time of initialization, reading this
    /// > property may return a value of `0` until the first successful call to ``send(_:to:port:)-(OSCPacket,_,_)``
    /// > is made.
    public var localPort: UInt16 {
        core.localPort
    }

    /// UDP port used by to send OSC packets. This may be set at any time.
    /// This port will be used in calls to ``send(_:to:port:)-(OSCPacket,_,_)``. The port may still be overridden
    /// using the `port` parameter in the call to ``send(_:to:port:)-(OSCPacket,_,_)``.
    ///
    /// The default port for OSC communication is 8000 but may change depending on device/software
    /// manufacturer.
    public var remotePort: UInt16 {
        get { core.remotePort }
        set { core.remotePort = newValue }
    }

    /// Network interface to restrict connections to.
    public var interface: String? {
        core.interface
    }

    /// Enable sending IPv4 broadcast messages from the socket.
    ///
    /// By default, the socket will not allow you to send broadcast messages as a network safeguard
    /// and it is an opt-in feature.
    ///
    /// A broadcast UDP message can be sent to a correctly formatted broadcast address. A broadcast
    /// address is the highest IP address for a subnet or a network.
    ///
    /// For example, a class C network with first octet `192`, one subnet, and subnet mask of
    /// `255.255.255.0` would have a broadcast address of `192.168.0.255` and would effectively send
    /// to `192.168.0.*` (where `*` is the range `1 ... 254`).
    ///
    /// 255.255.255.255 is a special broadcast address which targets all hosts on a local network.
    ///
    /// For more information on IPv4 broadcast addresses, see
    /// [Broadcast Address (Wikipedia)](https://en.wikipedia.org/wiki/Broadcast_address) and [Subnet
    /// Calculator](https://www.subnet-calculator.com).
    ///
    /// Internet Protocol version 6 (IPv6) does not implement this method of broadcast, and
    /// therefore does not define broadcast addresses. Instead, IPv6 uses multicast addressing.
    public var isIPv4BroadcastEnabled: Bool {
        core.isIPv4BroadcastEnabled
    }

    /// Returns a boolean indicating whether the OSC socket has been started.
    public var isStarted: Bool {
        core.isStarted
    }

    /// Initialize with a remote hostname and UDP port.
    ///
    /// > Note:
    /// >
    /// > Ensure ``start()`` is called once after initialization in order to begin sending and receiving messages.
    ///
    /// - Parameters:
    ///   - localPort: Local port to listen on for inbound OSC packets.
    ///     If `nil` or `0`, a random available port in the system will be chosen.
    ///   - remoteHost: Remote hostname or IP address.
    ///   - remotePort: Remote port on the remote host machine to send outbound OSC packets to.
    ///     If `nil` or `0`, the `localPort` value will be used.
    ///   - interface: Optionally specify a network interface for which to constrain communication.
    ///   - timeTagMode: OSC time-tag mode. The default is recommended.
    ///   - isIPv4BroadcastEnabled: Enable sending IPv4 broadcast messages from the socket.
    ///     See ``isIPv4BroadcastEnabled`` for more details.
    ///   - queue: Optionally supply a custom dispatch queue for receiving OSC packets and dispatching the
    ///     handler callback closure. If `nil`, a dedicated internal background queue will be used.
    ///   - receiveHandler: Handler to call when OSC bundles or messages are received.
    public init(
        localPort: UInt16? = nil,
        remoteHost: String? = nil,
        remotePort: UInt16? = nil,
        interface: String? = nil,
        timeTagMode: OSCTimeTagMode = .ignore,
        isIPv4BroadcastEnabled: Bool = false,
        queue: DispatchQueue? = nil,
        receiveHandler: OSCHandlerBlock? = nil
    ) {
        core = Core(
            localPort: localPort,
            remoteHost: remoteHost,
            remotePort: remotePort,
            interface: interface,
            timeTagMode: timeTagMode,
            isIPv4BroadcastEnabled: isIPv4BroadcastEnabled,
            queue: queue,
            receiveHandler: receiveHandler
        )
        core.parent = self
    }
}

extension OSCUDPSocket: Sendable { }

// MARK: - Lifecycle

extension OSCUDPSocket {
    /// Bind the local UDP port and begin listening for OSC packets.
    public func start() throws {
        try core.start()
    }

    /// Stops listening for data and closes the OSC port.
    public func stop() {
        core.stop()
    }
}

// MARK: - Communication

extension OSCUDPSocket {
    /// Send an OSC bundle or message to the remote host.
    /// The ``remoteHost`` and ``remotePort`` properties are used unless one or both are
    /// overridden in this call.
    ///
    /// The default port for OSC communication is 8000 but may change depending on device/software
    /// manufacturer.
    public func send(
        _ packet: OSCPacket,
        to host: String? = nil,
        port: UInt16? = nil
    ) throws {
        try core.send(packet, to: host, port: port)
    }

    /// Send an OSC bundle to the remote host.
    /// The ``remoteHost`` and ``remotePort`` properties are used unless one or both are
    /// overridden in this call.
    ///
    /// The default port for OSC communication is 8000 but may change depending on device/software
    /// manufacturer.
    public func send(
        _ bundle: OSCBundle,
        to host: String? = nil,
        port: UInt16? = nil
    ) throws {
        try send(.bundle(bundle), to: host, port: port)
    }

    /// Send an OSC message to the remote host.
    /// The ``remoteHost`` and ``remotePort`` properties are used unless one or both are
    /// overridden in this call.
    ///
    /// The default port for OSC communication is 8000 but may change depending on device/software
    /// manufacturer.
    public func send(
        _ message: OSCMessage,
        to host: String? = nil,
        port: UInt16? = nil
    ) throws {
        try send(.message(message), to: host, port: port)
    }
}

// MARK: - Properties

extension OSCUDPSocket {
    /// Set the receive handler closure.
    /// This closure will be called when OSC bundles or messages are received.
    public func setReceiveHandler(_ handler: OSCHandlerBlock?) {
        core.setReceiveHandler(handler)
    }
}

#endif
