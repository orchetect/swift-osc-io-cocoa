//
//  OSCTCPServer Delegate ClientConnection.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency internal import CocoaAsyncSocket
import Foundation
import SwiftOSCCore

extension OSCTCPServer.Delegate {
    /// Internal class encapsulating a remote client connection session accepted by a local ``OSCTCPServer``.
    final class ClientConnection {
        weak var delegate: OSCTCPServer.Delegate?
        let tcpDelegate: CocoaOSCTCPClient.Core.Delegate
        
        let tcpSocket: GCDAsyncSocket
        let clientID: OSCTCPClientSessionID
        let remoteHost: String // cached, since GCDAsyncSocket resets it upon disconnection
        let remotePort: UInt16 // cached, since GCDAsyncSocket resets it upon disconnection
        let framingMode: OSCTCPFramingMode

        init(
            tcpSocket: GCDAsyncSocket,
            clientID: OSCTCPClientSessionID,
            framingMode: OSCTCPFramingMode,
            delegate: OSCTCPServer.Delegate?
        ) {
            self.delegate = delegate
            
            self.tcpSocket = tcpSocket
            self.clientID = clientID
            remoteHost = tcpSocket.connectedHost ?? ""
            remotePort = tcpSocket.connectedPort
            self.framingMode = framingMode
            
            tcpDelegate = CocoaOSCTCPClient.Core.Delegate()
            tcpDelegate.oscServer = self
        }

        deinit {
            close()
        }
    }
}

extension OSCTCPServer.Delegate.ClientConnection: @unchecked Sendable { } // TODO: unchecked

// MARK: - Lifecycle

extension OSCTCPServer.Delegate.ClientConnection {
    func close() {
        tcpSocket.disconnectAfterReadingAndWriting()
        tcpSocket.delegate = nil
    }
}

// MARK: - Communication

extension OSCTCPServer.Delegate.ClientConnection: _OSCTCPSendProtocol {
    // provides implementation for sending OSC data
}

extension OSCTCPServer.Delegate.ClientConnection: _OSCTCPHandlerProtocol {
    var queue: DispatchQueue {
        tcpSocket.delegateQueue ?? .global()
    }

    var timeTagMode: OSCTimeTagMode {
        delegate?.oscServer?.timeTagMode ?? .ignore
    }

    var receiveHandler: OSCHandlerBlock? {
        delegate?.oscServer?.receiveHandler
    }
    
    func setReceiveHandler(_ handler: OSCHandlerBlock?) {
        delegate?.oscServer?.setReceiveHandler(handler)
    }
}

extension OSCTCPServer.Delegate.ClientConnection: _OSCTCPGeneratesClientNotificationsProtocol {
    // note that this is never called because when a remote connection closes, its socket does not fire
    // `socketDidDisconnect(...)` in GCDAsyncSocketDelegate, but we have to implement this due to
    // other protocol requirements
    func _generateConnectedNotification() {
        delegate?.oscServer?._generateConnectedNotification(
            remoteHost: remoteHost,
            remotePort: remotePort,
            clientID: clientID
        )
    }

    // note that this is never called because when a remote connection closes, its socket does not fire
    // `socketDidDisconnect(...)` in GCDAsyncSocketDelegate, but we have to implement this due to
    // other protocol requirements
    func _generateDisconnectedNotification(error: (any Error)?) {
        delegate?.oscServer?._generateDisconnectedNotification(
            remoteHost: remoteHost,
            remotePort: remotePort,
            clientID: clientID,
            error: error
        )
    }
}

#endif
