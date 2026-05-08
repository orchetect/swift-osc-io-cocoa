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
        
        public var localPort: UInt16 {
            udpSocket.localPort()
        }
        
        private var _localPort: UInt16?
        
        private(set) var interface: String?
        
        var isPortReuseEnabled: Bool
        
        var isIPv4BroadcastEnabled: Bool {
            get { _isIPv4BroadcastEnabled }
            set {
                _isIPv4BroadcastEnabled = newValue
                try? udpSocket.enableBroadcast(newValue)
            }
        }
        private var _isIPv4BroadcastEnabled: Bool
        
        private(set) var isStarted: Bool = false
        
        init(
            localPort: UInt16?,
            interface: String?,
            isPortReuseEnabled: Bool,
            isIPv4BroadcastEnabled: Bool
        ) {
            udpSocket.setDelegate(udpDelegate, delegateQueue: .global())
            
            _localPort = (localPort == nil || localPort == 0) ? nil : localPort
            self.interface = interface
            self.isPortReuseEnabled = isPortReuseEnabled
            _isIPv4BroadcastEnabled = isIPv4BroadcastEnabled
        }
        
        deinit {
            stop()
        }
    }
}

extension OSCUDPClient.Core: @unchecked Sendable { } // TODO: unchecked

// MARK: - Lifecycle

extension OSCUDPClient.Core {
    func start() throws {
        guard !isStarted else { return }
        
        stop()
        
        try udpSocket.enableReusePort(isPortReuseEnabled)
        try udpSocket.enableBroadcast(isIPv4BroadcastEnabled)
        try udpSocket.bind(
            toPort: _localPort ?? 0, // 0 causes system to assign random open port
            interface: interface
        )

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
