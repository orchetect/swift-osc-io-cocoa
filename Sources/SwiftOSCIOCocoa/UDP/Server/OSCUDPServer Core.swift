//
//  OSCUDPServer Core.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency internal import CocoaAsyncSocket
import Foundation
import SwiftOSCCore
internal import SwiftOSCIOInternals

extension OSCUDPServer {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Parent = OSCUDPServer
        weak var parent: Parent?
        
        let udpSocket: GCDAsyncUdpSocket
        let udpDelegate = Parent.Delegate()
        let queue: DispatchQueue
        var receiveHandler: OSCHandlerBlock?
        
        var timeTagMode: OSCTimeTagMode
        private var _localPort: UInt16?
        private(set) var interface: String?
        var isPortReuseEnabled: Bool = false
        private(set) var isStarted: Bool = false
        
        init(
            port: UInt16?,
            interface: String?,
            isPortReuseEnabled: Bool,
            timeTagMode: OSCTimeTagMode,
            queue: DispatchQueue?,
            receiveHandler: OSCHandlerBlock?
        ) {
            _localPort = (port == nil || port == 0) ? nil : port
            self.interface = interface
            self.isPortReuseEnabled = isPortReuseEnabled
            self.timeTagMode = timeTagMode
            self.queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCUDPServer.queue")
            self.receiveHandler = receiveHandler
            
            udpSocket = GCDAsyncUdpSocket(delegate: udpDelegate, delegateQueue: self.queue, socketQueue: nil)
            udpDelegate.oscServer = self
        }
        
        deinit {
            stop()
        }
    }
}

extension OSCUDPServer.Core: @unchecked Sendable { }

// MARK: - Lifecycle

extension OSCUDPServer.Core {
    func start() throws {
        guard !isStarted else { return }
        
        stop()
        
        try udpSocket.enableReusePort(isPortReuseEnabled)
        try udpSocket.bind(
            toPort: _localPort ?? 0, // 0 causes system to assign random open port
            interface: interface
        )
        try udpSocket.beginReceiving()
        
        // update local port if it has changed or been assigned by the system
        _localPort = udpSocket.localPort()
        
        isStarted = true
    }

    func stop() {
        udpSocket.close()
        
        isStarted = false
    }
}

// MARK: - Communication

extension OSCUDPServer.Core: _OSCHandlerProtocol {
    // provides implementation for dispatching incoming OSC data
}

// MARK: - Properties

extension OSCUDPServer.Core {
    func setReceiveHandler(_ handler: OSCHandlerBlock?) {
        queue.async {
            self.receiveHandler = handler
        }
    }
}

#endif
