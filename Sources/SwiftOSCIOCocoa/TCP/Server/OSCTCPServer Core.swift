//
//  OSCTCPServer Core.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency internal import CocoaAsyncSocket
import Foundation
import SwiftOSCCore
internal import SwiftOSCIOInternals

extension OSCTCPServer {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Parent = OSCTCPServer
        weak var parent: Parent?
        
        let tcpSocket: GCDAsyncSocket
        let tcpDelegate: Parent.Delegate
        let queue: DispatchQueue
        var receiveHandler: OSCHandlerBlock?
        var notificationHandler: NotificationHandlerBlock?
        var timeTagMode: OSCTimeTagMode
        var localPort: UInt16 {
            tcpSocket.localPort
        }
        var _localPort: UInt16?
        let interface: String?
        private(set) var isStarted: Bool = false
        let framingMode: OSCTCPFramingMode
        
        init(
            port: UInt16?,
            interface: String? = nil,
            timeTagMode: OSCTimeTagMode,
            framingMode: OSCTCPFramingMode,
            queue: DispatchQueue?,
            receiveHandler: OSCHandlerBlock?
        ) {
            _localPort = (port == nil || port == 0) ? nil : port
            self.interface = interface
            self.timeTagMode = timeTagMode
            self.framingMode = framingMode
            let queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCTCPServer.queue")
            self.queue = queue
            self.receiveHandler = receiveHandler
            
            tcpDelegate = Parent.Delegate(framingMode: framingMode)
            tcpSocket = GCDAsyncSocket(delegate: tcpDelegate, delegateQueue: queue, socketQueue: nil)
            tcpDelegate.oscServer = self
        }
        
        deinit {
            stop()
        }
    }
}

extension OSCTCPServer.Core: @unchecked Sendable { } // TODO: unchecked

// MARK: - Lifecycle

extension OSCTCPServer.Core {
    func start() throws {
        guard !isStarted else { return }
        
        try tcpSocket.accept(
            onInterface: interface,
            port: _localPort ?? 0 // 0 causes system to assign random open port
        )
        
        isStarted = true
    }
    
    func stop() {
        // disconnect all clients
        tcpDelegate.closeClients()
        
        // close server
        tcpSocket.disconnectAfterWriting()
        
        isStarted = false
    }
}

// MARK: - Communication

extension OSCTCPServer.Core {
    func _send(_ oscPacket: OSCPacket, toClientID clientID: OSCTCPClientSessionID) throws {
        guard let connection = tcpDelegate.clients[clientID] else {
            throw OSCTCPServerError.clientNotFound(clientID: clientID)
        }
        
        try connection._send(oscPacket)
    }
    
    func _send(_ oscBundle: OSCBundle, toClientID clientID: OSCTCPClientSessionID) throws {
        try _send(.bundle(oscBundle), toClientID: clientID)
    }
    
    func _send(_ oscMessage: OSCMessage, toClientID clientID: OSCTCPClientSessionID) throws {
        try _send(.message(oscMessage), toClientID: clientID)
    }
}

extension OSCTCPServer.Core: _OSCTCPHandlerProtocol {
    // provides implementation for dispatching incoming OSC data
}

extension OSCTCPServer.Core: OSCTCPGeneratesServerNotificationsProtocol {
    func generateConnectedNotification(remoteHost: String, remotePort: UInt16, clientID: OSCTCPClientSessionID) {
        let notif: Parent.Notification = .connected(remoteHost: remoteHost, remotePort: remotePort, clientID: clientID)
        notificationHandler?(notif)
    }
    
    func generateDisconnectedNotification(
        remoteHost: String,
        remotePort: UInt16,
        clientID: OSCTCPClientSessionID,
        error: (any Error)?
    ) {
        let notif: Parent.Notification = .disconnected(remoteHost: remoteHost, remotePort: remotePort, clientID: clientID, error: error)
        notificationHandler?(notif)
    }
}

// MARK: - Properties

extension OSCTCPServer.Core {
    func setReceiveHandler(_ handler: OSCHandlerBlock?) {
        queue.async {
            self.receiveHandler = handler
        }
    }
    
    func setNotificationHandler(_ handler: Parent.NotificationHandlerBlock?) {
        queue.async {
            self.notificationHandler = handler
        }
    }
    
    var clients: [OSCTCPClientSessionID: (host: String, port: UInt16)] {
        tcpDelegate
            .clients
            .reduce(into: [:] as [OSCTCPClientSessionID: (host: String, port: UInt16)]) { base, element in
                base[element.key] = (
                    host: element.value.remoteHost,
                    port: element.value.remotePort
                )
            }
    }
    
    func disconnectClient(clientID: OSCTCPClientSessionID) {
        tcpDelegate.closeClient(clientID: clientID)
    }
}

#endif
