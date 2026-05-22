//
//  OSCUDPSocket Core.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency internal import CocoaAsyncSocket
import Foundation
import SwiftOSCCore
import SwiftOSCIOCore

extension OSCUDPSocket {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Parent = OSCUDPSocket

        /// Internal queue used for synchronizing access to mutable properties.
        let syncQueue = DispatchQueue(label: "com.orchetect.SwiftOSC.OSCUDPSocket.Core.syncQueue", target: .global())
        
        let udpSocket: GCDAsyncUdpSocket
        let udpDelegate = Parent.Delegate()
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

        var remoteHost: String? {
            get { syncQueue.sync { _remoteHost } }
            set { syncQueue.sync { _remoteHost = newValue } }
        }
        nonisolated(unsafe) private var _remoteHost: String?

        var localPort: UInt16 {
            udpSocket.localPort()
        }
        
        var preferredLocalPort: UInt16? {
            get { syncQueue.sync { _preferredLocalPort } }
            set { syncQueue.sync { _preferredLocalPort = newValue } }
        }
        nonisolated(unsafe) private var _preferredLocalPort: UInt16?

        var remotePort: UInt16 {
            get { syncQueue.sync { _remotePort } ?? localPort }
            set { syncQueue.sync { _remotePort = (newValue == 0) ? nil : newValue } }
        }
        nonisolated(unsafe) private var _remotePort: UInt16?

        let interface: String?

        let isIPv4BroadcastEnabled: Bool

        var isIPv6Enabled: Bool {
            get {
                syncQueue.sync { _isIPv6Enabled }
            }
            set {
                syncQueue.sync { _isIPv6Enabled = newValue }
                if isStarted {
                    print("Setting isIPv6Enabled will not have any effect until the UDP socket is stopped and started again.")
                }
            }
        }
        nonisolated(unsafe) private var _isIPv6Enabled: Bool
        
        private(set) var isStarted: Bool {
            get { syncQueue.sync { _isStarted } }
            set { syncQueue.sync { _isStarted = newValue } }
        }
        nonisolated(unsafe) private var _isStarted: Bool = false

        init(
            localPort: UInt16?,
            remoteHost: String?,
            remotePort: UInt16?,
            interface: String?,
            isIPv4BroadcastEnabled: Bool,
            isIPv6Enabled: Bool,
            queue: DispatchQueue?,
            receiveHandler: OSCPacketHandler?
        ) {
            _remoteHost = remoteHost
            _preferredLocalPort = (localPort == nil || localPort == 0) ? nil : localPort
            _remotePort = (remotePort == nil || remotePort == 0) ? nil : remotePort
            self.interface = interface
            self.isIPv4BroadcastEnabled = isIPv4BroadcastEnabled
            _isIPv6Enabled = isIPv6Enabled
            let queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCUDPSocket.queue", target: .global())
            self.queue = queue
            _receiveHandler = receiveHandler

            udpSocket = GCDAsyncUdpSocket(delegate: udpDelegate, delegateQueue: queue, socketQueue: nil)
            udpDelegate.oscServer = self
        }

        deinit {
            stop()
        }
    }
}

extension OSCUDPSocket.Core: Sendable { }

// MARK: - Lifecycle

extension OSCUDPSocket.Core {
    func start() throws {
        guard !isStarted else { return }

        try udpSocket.enableBroadcast(isIPv4BroadcastEnabled)

        // by default, if interface is passed as `nil`, CocoaAsyncSocket will bind to the "any" wildcard.
        // but we can't pass the actual string to the `interface` parameter of bind() so we need to translate it to `nil`.
        let interface = (interface == "0.0.0.0" || interface == "::") ? nil : interface
        
        do {
            try udpSocket.bind(
                toPort: preferredLocalPort ?? 0, // 0 causes system to assign random open port
                interface: interface
            )
        } catch let error as GCDAsyncUdpSocketError
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

        try udpSocket.beginReceiving()

        isStarted = true
    }

    func stop() {
        udpSocket.close()

        isStarted = false
    }
}

// MARK: - Communication

extension OSCUDPSocket.Core {
    func send(_ packet: OSCPacket, to host: String?, port: UInt16?) throws {
        guard isStarted else {
            throw OSCIOError.notStarted
        }

        guard let toHost = host ?? remoteHost else {
            throw OSCIOError.noRemoteHost
        }

        let data = try packet.rawData()

        udpSocket.send(
            data,
            toHost: toHost,
            port: port ?? remotePort,
            withTimeout: 1.0,
            tag: 0
        )
    }
}

extension OSCUDPSocket.Core: _OSCPacketDispatcherProtocol {
    // provides implementation for dispatching incoming OSC data
}

// MARK: - Properties

extension OSCUDPSocket.Core {
    func setReceiveHandler(_ handler: OSCPacketHandler?) {
        receiveHandler = handler
    }

    func setReceiveErrorHandler(_ handler: OSCDecodeErrorHandlerBlock?) {
        receiveErrorHandler = handler
    }
}

#endif
