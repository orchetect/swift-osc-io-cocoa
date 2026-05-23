//
//  OSCUDPServer Core.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency internal import CocoaAsyncSocket
internal import SwiftOSCIOInternals
import Foundation
import SwiftOSCCore

extension OSCUDPServer {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Parent = OSCUDPServer

        /// Internal queue used for synchronizing access to mutable properties.
        let syncQueue = DispatchQueue(label: "com.orchetect.SwiftOSC.OSCUDPServer.Core.syncQueue", target: .global())

        let udpSocket: GCDAsyncUdpSocket
        let udpDelegate = Parent.Core.Delegate()
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

        var localHost: String? {
            isStarted ? udpSocket.localHost() : nil
        }

        var localPort: UInt16 {
            udpSocket.localPort()
        }

        private var preferredLocalPort: UInt16? {
            get { syncQueue.sync { _preferredLocalPort } }
            set { syncQueue.sync { _preferredLocalPort = newValue } }
        }

        nonisolated(unsafe) private var _preferredLocalPort: UInt16?

        let interface: String?

        var isPortReuseEnabled: Bool {
            get { syncQueue.sync { _isPortReuseEnabled } }
            set { syncQueue.sync { _isPortReuseEnabled = newValue } }
        }

        nonisolated(unsafe) private var _isPortReuseEnabled: Bool

        var isIPv6Enabled: Bool {
            get {
                syncQueue.sync { _isIPv6Enabled }
            }
            set {
                syncQueue.sync { _isIPv6Enabled = newValue }
                if isStarted {
                    print("Setting isIPv6Enabled will not have any effect until the UDP server is stopped and started again.")
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
            port: UInt16?,
            interface: String?,
            isPortReuseEnabled: Bool,
            isIPv6Enabled: Bool,
            queue: DispatchQueue?,
            receiveHandler: OSCPacketHandler?
        ) {
            _preferredLocalPort = (port == nil || port == 0) ? nil : port
            self.interface = interface
            _isPortReuseEnabled = isPortReuseEnabled
            _isIPv6Enabled = isIPv6Enabled
            self.queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCUDPServer.queue", target: .global())
            _receiveHandler = receiveHandler

            udpSocket = GCDAsyncUdpSocket(delegate: udpDelegate, delegateQueue: self.queue, socketQueue: nil) // do NOT use syncQueue
            udpDelegate.oscServer = self
        }

        deinit {
            stop()
        }
    }
}

extension OSCUDPServer.Core: Sendable { }

// MARK: - Lifecycle

extension OSCUDPServer.Core {
    func start() throws {
        guard !isStarted else { return }

        stop()

        // by default, if interface is passed as `nil`, CocoaAsyncSocket will bind to the "any" wildcard.
        // but we can't pass the actual string to the `interface` parameter of bind() so we need to translate it to `nil`.
        let interface = (interface == "0.0.0.0" || interface == "::") ? nil : interface

        let port = preferredLocalPort ?? 0 // 0 causes system to assign random open port
        
        try udpSocket.enableReusePort(isPortReuseEnabled)

        // CocoaAsyncSocket operates in an egalitarian mode by default that supports both IPv4 and IPv6 unless told otherwise
        if isIPv6Enabled {
            // by default, both IPv4 and IPv6 are enabled
            udpSocket.setPreferIPv4() // still prefer v4 when possible
            udpSocket.setIPv6Enabled(true)
        } else {
            // by default, both IPv4 and IPv6 are enabled
            udpSocket.setPreferIPv4()
            udpSocket.setIPv6Enabled(false)
        }

        do {
            try udpSocket.bind(
                toPort: port,
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

extension OSCUDPServer.Core: _OSCPacketDispatcherProtocol {
    // provides implementation for dispatching incoming OSC data
}

// MARK: - Properties

extension OSCUDPServer.Core {
    func setReceiveHandler(_ handler: OSCPacketHandler?) {
        receiveHandler = handler
    }

    func setReceiveErrorHandler(_ handler: OSCDecodeErrorHandlerBlock?) {
        receiveErrorHandler = handler
    }
}

#endif
