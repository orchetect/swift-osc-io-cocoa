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
        weak var parent: Parent?
        
        let udpSocket: GCDAsyncUdpSocket
        let udpDelegate = OSCUDPServer.Delegate()
        let queue: DispatchQueue
        var receiveHandler: OSCHandlerBlock?
        
        var timeTagMode: OSCTimeTagMode
        
        var remoteHost: String?
        
        var localPort: UInt16 {
            udpSocket.localPort()
        }
        private var _localPort: UInt16?
        
        var remotePort: UInt16 {
            get { _remotePort ?? localPort }
            set { _remotePort = (newValue == 0) ? nil : newValue }
        }
        private var _remotePort: UInt16?
        
        private(set) var interface: String?
        
        let isIPv4BroadcastEnabled: Bool
        
        private(set) var isStarted: Bool = false
        
        init(
            localPort: UInt16?,
            remoteHost: String?,
            remotePort: UInt16?,
            interface: String?,
            timeTagMode: OSCTimeTagMode,
            isIPv4BroadcastEnabled: Bool,
            queue: DispatchQueue?,
            receiveHandler: OSCHandlerBlock?
        ) {
            self.remoteHost = remoteHost
            _localPort = (localPort == nil || localPort == 0) ? nil : localPort
            _remotePort = (remotePort == nil || remotePort == 0) ? nil : remotePort
            self.interface = interface
            self.timeTagMode = timeTagMode
            self.isIPv4BroadcastEnabled = isIPv4BroadcastEnabled
            let queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCUDPSocket.queue")
            self.queue = queue
            self.receiveHandler = receiveHandler
            
            udpSocket = GCDAsyncUdpSocket(delegate: udpDelegate, delegateQueue: queue, socketQueue: nil)
            udpDelegate.oscServer = self
        }
        
        deinit {
            stop()
        }
    }
}

extension OSCUDPSocket.Core: @unchecked Sendable { }

// MARK: - Lifecycle

extension OSCUDPSocket.Core {
    func start() throws {
        guard !isStarted else { return }
        
        try udpSocket.enableBroadcast(isIPv4BroadcastEnabled)
        try udpSocket.bind(
            toPort: _localPort ?? 0, // 0 causes system to assign random open port
            interface: interface
        )
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
    func send(
        _ packet: OSCPacket,
        to host: String?,
        port: UInt16?
    ) throws {
        guard isStarted else {
            throw OSCUDPClientError.notStarted
        }
        
        guard let toHost = host ?? remoteHost else {
            throw OSCUDPClientError.noRemoteHost
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
    
    func send(
        _ bundle: OSCBundle,
        to host: String?,
        port: UInt16?
    ) throws {
        try send(.bundle(bundle), to: host, port: port)
    }
    
    func send(
        _ message: OSCMessage,
        to host: String?,
        port: UInt16?
    ) throws {
        try send(.message(message), to: host, port: port)
    }
}

extension OSCUDPSocket.Core: _OSCHandlerProtocol { }

// MARK: - Properties

extension OSCUDPSocket.Core {
    func setReceiveHandler(_ handler: OSCHandlerBlock?) {
        queue.async {
            self.receiveHandler = handler
        }
    }
}

#endif
