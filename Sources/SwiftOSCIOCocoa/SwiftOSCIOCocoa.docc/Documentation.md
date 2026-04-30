# ``SwiftOSCIOCocoa``

Adds network I/O layer for Apple platforms on top of SwiftOSCCore.

## Overview

![SwiftOSC I/O: Cocoa](swift-osc-io-cocoa-banner.png)

- OSC address pattern matching and dispatch
- Convenient OSC message value type masking, validation and strong-typing
- Support for custom OSC types
- Supports Swift 6 Concurrency
- Fully unit tested
- Full DocC documentation

## Topics

### Welcome
- <doc:Getting-Started>
- <doc:Sending-OSC>
- <doc:Receiving-OSC>

### OSC I/O

- ``OSCTimeTagMode``
- ``OSCHandlerBlock``

### OSC I/O (UDP)

- ``OSCUDPClient``
- ``OSCUDPServer``
- ``OSCUDPSocket``

### OSC I/O (TCP)

- ``OSCTCPClient``
- ``OSCTCPServer``
- ``OSCTCPFramingMode``
- ``OSCTCPClientSessionID``
- ``OSCTCPPacketLengthHeaderDecodingError``
- ``OSCTCPSLIPDecodingError``
