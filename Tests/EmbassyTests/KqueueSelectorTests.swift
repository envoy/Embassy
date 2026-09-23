//
//  KqueueSelectorTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation
import Testing

@testable import Embassy

@Suite struct KqueueSelectorTests {
    @Test func register() throws {
        let selector = try KqueueSelector()
        let socket = try TCPSocket()

        #expect(selector[socket.fileDescriptor] == nil)

        let data = "my data"
        try selector.register(socket.fileDescriptor, events: [.read], data: data)

        let key = try #require(selector[socket.fileDescriptor])
        #expect(key.fileDescriptor == socket.fileDescriptor)
        #expect(key.events == [.read])
        #expect(key.data as? String == data)
    }

    @Test func unregister() throws {
        let selector = try KqueueSelector()
        let socket = try TCPSocket()

        try selector.register(socket.fileDescriptor, events: [.read], data: nil)

        let key = try selector.unregister(socket.fileDescriptor)
        #expect(selector[socket.fileDescriptor] == nil)
        #expect(key.data as? String == nil)
        #expect(key.fileDescriptor == socket.fileDescriptor)
        #expect(key.events == [.read])
    }

    @Test func registerKeyError() throws {
        let selector = try KqueueSelector()
        let socket = try TCPSocket()
        try selector.register(socket.fileDescriptor, events: [.read], data: nil)

        #expect(throws: KqueueSelector.Error.self) {
            try selector.register(socket.fileDescriptor, events: [.read], data: nil)
        }
    }

    @Test func unregisterKeyError() throws {
        let selector = try KqueueSelector()
        let socket = try TCPSocket()

        #expect(throws: KqueueSelector.Error.self) {
            try selector.unregister(socket.fileDescriptor)
        }
    }

    @Test func selectOneSocket() async throws {
        let selector = try KqueueSelector()
        let (listenSocket, port) = try makeListenSocket()
        try selector.register(listenSocket.fileDescriptor, events: [.read], data: nil)

        // nothing is connecting, so select must wait out the whole timeout
        let idle = try await timed { toEventSet(try selector.select(timeout: 2 * tick)) }
        #expect(idle.result.isEmpty)
        expectDuration(2 * tick, idle.elapsed)

        let clientSocket = try TCPSocket()
        after(1) { try! clientSocket.connect(host: "::1", port: port) }

        let ready = try await timed { summarize(try selector.select(timeout: 10)) }
        expectDuration(1 * tick, ready.elapsed)
        #expect(ready.result.count == 1)
        #expect(ready.result.first?.fileDescriptor == listenSocket.fileDescriptor)
        #expect(ready.result.first?.events == [.read])
        #expect(ready.result.first?.hasData == false)
    }

    @Test func selectEventFilter() async throws {
        let selector = try KqueueSelector()
        let (listenSocket, port) = try makeListenSocket()
        // watching only for write on a listening socket: a pending connection is not a write event
        try selector.register(listenSocket.fileDescriptor, events: [.write], data: nil)

        #expect(try await onThread { toEventSet(try selector.select(timeout: 1 * tick)) }.isEmpty)

        let clientSocket = try TCPSocket()
        after(1) { try! clientSocket.connect(host: "::1", port: port) }

        #expect(try await onThread { toEventSet(try selector.select(timeout: 2 * tick)) }.isEmpty)
    }

    @Test func selectAfterUnregister() async throws {
        let selector = try KqueueSelector()
        let (listenSocket, port) = try makeListenSocket()
        try selector.register(listenSocket.fileDescriptor, events: [.read], data: nil)

        let clientSocket = try TCPSocket()
        after(1) { try! clientSocket.connect(host: "::1", port: port) }

        let ready = try await timed { toEventSet(try selector.select(timeout: 2 * tick)) }
        expectDuration(1 * tick, ready.elapsed)
        #expect(ready.result == [
            FileDescriptorEvent(fileDescriptor: listenSocket.fileDescriptor, ioEvent: .read)
        ])

        try selector.unregister(listenSocket.fileDescriptor)

        let clientSocket2 = try TCPSocket()
        after(1) { try! clientSocket2.connect(host: "::1", port: port) }

        let afterUnregister = try await timed { toEventSet(try selector.select(timeout: 2 * tick)) }
        expectDuration(2 * tick, afterUnregister.elapsed)
        #expect(afterUnregister.result.isEmpty)
    }

    @Test func selectMultipleSocket() async throws {
        let selector = try KqueueSelector()
        let (listenSocket, port) = try makeListenSocket()
        let clientSocket = try TCPSocket()

        try selector.register(listenSocket.fileDescriptor, events: [.read, .write], data: nil)
        try selector.register(clientSocket.fileDescriptor, events: [.read, .write], data: nil)

        try clientSocket.connect(host: "::1", port: port)
        try await Task.sleep(nanoseconds: UInt64(tick * TimeInterval(NSEC_PER_SEC)))

        let events0 = try await timed { toEventSet(try selector.select(timeout: 10)) }
        expectDuration(0, events0.elapsed)
        #expect(events0.result == [
            FileDescriptorEvent(fileDescriptor: clientSocket.fileDescriptor, ioEvent: .write),
            FileDescriptorEvent(fileDescriptor: listenSocket.fileDescriptor, ioEvent: .read)
        ])

        let acceptedSocket = try listenSocket.accept()
        try selector.register(acceptedSocket.fileDescriptor, events: [.read, .write], data: nil)

        let writeOnly: Set<FileDescriptorEvent> = [
            FileDescriptorEvent(fileDescriptor: clientSocket.fileDescriptor, ioEvent: .write),
            FileDescriptorEvent(fileDescriptor: acceptedSocket.fileDescriptor, ioEvent: .write)
        ]
        let events1 = try await timed { toEventSet(try selector.select(timeout: 10)) }
        expectDuration(0, events1.elapsed)
        #expect(events1.result == writeOnly)

        // both sockets stay write-ready, so select returns immediately with only
        // the write events; nothing is readable
        let events1b = try await timed { toEventSet(try selector.select(timeout: 1 * tick)) }
        expectDuration(0, events1b.elapsed)
        #expect(events1b.result == writeOnly)

        try clientSocket.send(data: Data("hello".utf8))
        try await Task.sleep(nanoseconds: UInt64(tick * TimeInterval(NSEC_PER_SEC)))

        let events2 = try await timed { toEventSet(try selector.select(timeout: 10)) }
        expectDuration(0, events2.elapsed)
        #expect(events2.result == [
            FileDescriptorEvent(fileDescriptor: clientSocket.fileDescriptor, ioEvent: .write),
            FileDescriptorEvent(fileDescriptor: acceptedSocket.fileDescriptor, ioEvent: .read),
            FileDescriptorEvent(fileDescriptor: acceptedSocket.fileDescriptor, ioEvent: .write)
        ])

        #expect(utf8String(try acceptedSocket.recv(size: 1024)) == "hello")

        let events3 = try await timed { toEventSet(try selector.select(timeout: 10)) }
        expectDuration(0, events3.elapsed)
        #expect(events3.result == writeOnly)

        let events3b = try await timed { toEventSet(try selector.select(timeout: 1 * tick)) }
        expectDuration(0, events3b.elapsed)
        #expect(events3b.result == writeOnly)
    }
}
