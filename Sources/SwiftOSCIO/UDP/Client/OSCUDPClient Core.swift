//
//  OSCUDPClient Core.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency internal import CocoaAsyncSocket
import Foundation

extension OSCUDPClient {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Parent = OSCUDPClient

        private let udpSocket = GCDAsyncUdpSocket()
        private let udpDelegate = Delegate()

        /// Internal queue used for synchronizing access to mutable properties.
        let syncQueue = DispatchQueue(label: "com.orchetect.SwiftOSC.OSCUDPClient.Core.syncQueue", target: .global())
        
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
        
        var isIPv4BroadcastEnabled: Bool {
            get {
                syncQueue.sync { _isIPv4BroadcastEnabled }
            }
            set {
                syncQueue.sync { _isIPv4BroadcastEnabled = newValue }
                try? udpSocket.enableBroadcast(newValue)
            }
        }
        nonisolated(unsafe) private var _isIPv4BroadcastEnabled: Bool

        var isIPv6Enabled: Bool {
            get {
                syncQueue.sync { _isIPv6Enabled }
            }
            set {
                syncQueue.sync { _isIPv6Enabled = newValue }
                if isStarted {
                    print("Setting isIPv6Enabled will not have any effect until the UDP client is stopped and started again.")
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
            interface: String?,
            isPortReuseEnabled: Bool,
            isIPv4BroadcastEnabled: Bool,
            isIPv6Enabled: Bool
        ) {
            udpSocket.setDelegate(udpDelegate, delegateQueue: .global()) // do NOT use syncQueue

            _preferredLocalPort = (localPort == nil || localPort == 0) ? nil : localPort
            self.interface = interface
            _isPortReuseEnabled = isPortReuseEnabled
            _isIPv4BroadcastEnabled = isIPv4BroadcastEnabled
            _isIPv6Enabled = isIPv6Enabled
        }

        deinit {
            stop()
        }
    }
}

extension OSCUDPClient.Core: Sendable { }

// MARK: - Lifecycle

extension OSCUDPClient.Core {
    func start() throws {
        guard !isStarted else { return }

        stop()

        try udpSocket.enableReusePort(isPortReuseEnabled)
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

        isStarted = true
    }

    func stop() {
        udpSocket.close()

        isStarted = false
    }
}

// MARK: - Communication

extension OSCUDPClient.Core {
    func send(_ packet: OSCPacket, to host: String, port: UInt16) throws {
        let data = try packet.rawData()

        udpSocket.send(
            data,
            toHost: host,
            port: port,
            withTimeout: 1.0,
            tag: 0
        )
    }
}

#endif
