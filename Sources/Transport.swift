//
//  Transport.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// Thread confinement: every method and stored property of this type belongs to the thread
/// running its `EventLoop`. The `Sendable` conformance is unchecked because references to it are
/// captured by `@Sendable` loop callbacks, not because it is safe to touch from other threads.
public final class Transport: @unchecked Sendable {
    enum CloseReason {
        /// Connection closed by peer
        case byPeer
        /// Connection closed by ourselve
        case byLocal

        var isByPeer: Bool {
            if case .byPeer = self {
                return true
            }
            return false
        }

        var isByLocal: Bool {
            if case .byLocal = self {
                return true
            }
            return false
        }
    }

    /// Size for recv
    static let recvChunkSize = 1024

    /// Is this transport closed or not
    private(set) var closed: Bool = false
    /// Is this transport closing
    private(set) var closing: Bool = false
    var closedCallback: ((CloseReason) -> Void)?
    var readDataCallback: ((Data) -> Void)?

    private let socket: TCPSocket
    private let eventLoop: EventLoop
    // buffer for sending data out. Bytes before `outgoingOffset` have already been sent;
    // advancing the offset instead of removing from the front avoids a memmove of the
    // remaining body on every partial write under backpressure
    private var outgoingBuffer = Data()
    private var outgoingOffset = 0
    // once the consumed prefix passes this many bytes, drop it on the next append
    private static let compactionThreshold = 64 * 1024
    // whether our write callback is currently registered with the event loop
    private var writerRegistered = false
    // is reading enabled or not
    private var reading: Bool = true

    init(
        socket: TCPSocket,
        eventLoop: EventLoop,
        closedCallback: ((CloseReason) -> Void)? = nil,
        readDataCallback: ((Data) -> Void)? = nil
    ) {
        socket.ignoreSigPipe = true
        self.socket = socket
        self.eventLoop = eventLoop
        self.closedCallback = closedCallback
        self.readDataCallback = readDataCallback
        eventLoop.setReader(socket.fileDescriptor) { self.handleRead() }
    }

    deinit {
        eventLoop.removeReader(socket.fileDescriptor)
        eventLoop.removeWriter(socket.fileDescriptor)
    }

    /// Send data to peer (append in buffer and will be sent out later)
    ///  - Parameter data: data to send
    func write(data: Data) {
        // ensure we are not closed nor closing
        guard !closed && !closing else {
            // TODO: or raise error?
            return
        }
        if outgoingOffset >= Transport.compactionThreshold {
            outgoingBuffer.removeSubrange(..<outgoingOffset)
            outgoingOffset = 0
        }
        outgoingBuffer.append(data)
        handleWrite()
    }

    /// Send string with UTF8 encoding to peer
    ///  - Parameter string: string to send as UTF8
    func write(string: String) {
        write(data: Data(string.utf8))
    }

    /// Flush outgoing data and close the transport
    func close() {
        // ensure we are not closed nor closing
        guard !closed && !closing else {
            // TODO: or raise error?
            return
        }
        closing = true
        handleWrite()
    }

    func resume(reading: Bool) {
        // switch from not-reading to reading
        if reading && !self.reading {
            // call handle read later to check is there data available for reading
            eventLoop.call {
                self.handleRead()
            }
        }
        self.reading = reading
    }

    private func closedByPeer() {
        tearDown(reason: .byPeer)
    }

    private func closeByLocal() {
        tearDown(reason: .byLocal)
    }

    private func tearDown(reason: CloseReason) {
        closed = true
        eventLoop.removeReader(socket.fileDescriptor)
        eventLoop.removeWriter(socket.fileDescriptor)
        writerRegistered = false
        outgoingBuffer.removeAll()
        outgoingOffset = 0
        if let callback = closedCallback {
            callback(reason)
        }
        socket.close()
    }

    private func handleRead() {
        // ensure we are not closed
        guard !closed else {
            return
        }
        guard reading else {
            return
        }
        var data: Data!
        do {
            data = try socket.recv(size: Transport.recvChunkSize)
        } catch OSError.ioError(let number, _) {
            guard number != EAGAIN else {
                // if it's EAGAIN, it means no data to be read for now, just return
                // (usually means that this function was called by resumeReading)
                return
            }
            fatalError("Failed to read, errno=\(errno), message=\(lastErrorDescription())")
        } catch {
            fatalError("Failed to read")
        }
        guard data.count > 0 else {
            closedByPeer()
            return
        }
        // ensure we are not closing
        guard !closing else {
            return
        }
        if let callback = readDataCallback {
            callback(data)
        }
    }

    private func handleWrite() {
        // ensure we are not closed
        guard !closed else {
            return
        }
        // ensure we have something to write
        guard outgoingOffset < outgoingBuffer.count else {
            if closing {
                closeByLocal()
            }
            return
        }
        do {
            let sentBytes = try socket.send(data: outgoingBuffer[outgoingOffset...])
            outgoingOffset += sentBytes
            if outgoingOffset < outgoingBuffer.count {
                // Not all was written; wait for the socket to become writable again.
                // The registration is kept across partial writes rather than redone
                // on each one (each set/remove is two kevent syscalls).
                if !writerRegistered {
                    writerRegistered = true
                    eventLoop.setWriter(socket.fileDescriptor) { self.handleWrite() }
                }
            } else {
                // fully drained: release the consumed bytes but keep the capacity
                outgoingBuffer.removeAll(keepingCapacity: true)
                outgoingOffset = 0
                if writerRegistered {
                    writerRegistered = false
                    eventLoop.removeWriter(socket.fileDescriptor)
                }
                if closing {
                    closeByLocal()
                }
            }
        } catch let OSError.ioError(number, message) {
            switch number {
            case EAGAIN:
                break
            // Apparently on macOS EPROTOTYPE can be returned when the socket is not
            // fully shutdown (as an EPIPE would indicate). Here we treat them
            // essentially the same since we just tear the transport down anyway.
            // http://erickt.github.io/blog/2014/11/19/adventures-in-debugging-a-potential-osx-kernel-bug/
            case EPROTOTYPE:
                fallthrough
            case EPIPE:
                closedByPeer()

            default:
                fatalError("Failed to send, errno=\(number), message=\(message)")
            }
        } catch {
            fatalError("Failed to send")
        }
    }
}
