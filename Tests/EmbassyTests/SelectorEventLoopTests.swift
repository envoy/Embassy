//
//  SelectorEventLoopTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation
import Testing

@testable import Embassy

@Suite struct SelectorEventLoopTests {
    private func makeLoop() throws -> SelectorEventLoop {
        try SelectorEventLoop(selector: try KqueueSelector())
    }

    @Test func stop() async throws {
        let loop = try makeLoop()
        let runningWhenStopped = Locked<Bool?>(nil)
        after(1) {
            runningWhenStopped.value = loop.running
            loop.stop()
        }

        #expect(!loop.running)
        let elapsed = await run(loop)
        expectDuration(1 * tick, elapsed)
        #expect(runningWhenStopped.value == true)
        #expect(!loop.running)
    }

    @Test func callSoon() async throws {
        let loop = try makeLoop()
        let called = Locked(false)
        loop.call {
            called.value = true
            loop.stop()
        }
        let elapsed = await run(loop)
        expectDuration(0, elapsed)
        #expect(called.value)
    }

    @Test func callLater() async throws {
        let loop = try makeLoop()
        let events = Locked<[Int]>([])
        loop.call(withDelay: 0) { events.append(0) }
        loop.call(withDelay: 1 * tick) { events.append(1) }
        loop.call(withDelay: 2 * tick) { loop.stop() }
        loop.call(withDelay: 3 * tick) { events.append(3) }

        let elapsed = await run(loop)
        expectDuration(2 * tick, elapsed)
        #expect(events.value == [0, 1])
    }

    @Test func callAtOrder() async throws {
        let loop = try makeLoop()
        let events = Locked<[Int]>([])
        let now = Date()
        loop.call(atTime: now.addingTimeInterval(0)) { events.append(0) }
        loop.call(atTime: now.addingTimeInterval(0.000002)) { events.append(2) }
        loop.call(atTime: now.addingTimeInterval(0.000001)) { events.append(1) }
        loop.call(atTime: now.addingTimeInterval(0.000004)) {
            events.append(4)
            loop.stop()
        }
        loop.call(atTime: now.addingTimeInterval(0.000003)) { events.append(3) }

        let elapsed = await run(loop)
        expectDuration(0, elapsed)
        #expect(events.value == [0, 1, 2, 3, 4])
    }

    @Test func setReader() async throws {
        let loop = try makeLoop()
        let (listenSocket, port) = try makeListenSocket()
        let readerCalled = Locked(false)

        loop.setReader(listenSocket.fileDescriptor) {
            readerCalled.value = true
            loop.stop()
        }

        let clientSocket = try TCPSocket()
        loop.call(withDelay: 1 * tick) {
            try! clientSocket.connect(host: "::1", port: port)
        }

        let elapsed = await run(loop)
        expectDuration(1 * tick, elapsed)
        #expect(readerCalled.value)
    }

    @Test func setWriter() async throws {
        let loop = try makeLoop()
        let (_, port) = try makeListenSocket()
        let writerCalled = Locked(false)
        let clientSocket = try TCPSocket()

        loop.call(withDelay: 1 * tick) {
            try! clientSocket.connect(host: "::1", port: port)
            // Notice: It seems we should only select on the socket after it's either connecting
            // or listening, and that's why we put setWriter here instead of before or after
            // ref: http://stackoverflow.com/q/41656400/25077
            loop.setWriter(clientSocket.fileDescriptor) {
                writerCalled.value = true
                loop.stop()
            }
        }

        let elapsed = await run(loop)
        expectDuration(1 * tick, elapsed)
        #expect(writerCalled.value)
    }

    @Test func removeReader() async throws {
        let loop = try makeLoop()
        let (listenSocket, port) = try makeListenSocket()
        let clientSocket = try TCPSocket()
        let acceptedSocket = Locked<TCPSocket?>(nil)
        let readData = Locked<[String]>([])

        loop.setReader(listenSocket.fileDescriptor) {
            let accepted = try! listenSocket.accept()
            acceptedSocket.value = accepted
            loop.setReader(accepted.fileDescriptor) {
                readData.append(utf8String(try! accepted.recv(size: 1024)))
                if readData.value.count >= 2 {
                    loop.removeReader(accepted.fileDescriptor)
                }
            }
        }

        try clientSocket.connect(host: "::1", port: port)

        loop.call(withDelay: 1 * tick) { try! clientSocket.send(data: Data("hello".utf8)) }
        loop.call(withDelay: 2 * tick) { try! clientSocket.send(data: Data("baby".utf8)) }
        loop.call(withDelay: 3 * tick) { try! clientSocket.send(data: Data("fin".utf8)) }
        loop.call(withDelay: 4 * tick) { loop.stop() }

        let elapsed = await run(loop)
        expectDuration(4 * tick, elapsed)
        #expect(readData.value == ["hello", "baby"])
    }

    @Test func eventLoopReferenceCycle() throws {
        // Notice: we had a reference cycle from the setReader callback to the
        // selector loop object before, we ensure that when loop is not hold
        // by anybody, it should be released here
        weak let loop = try makeLoop()
        #expect(loop == nil)
    }
}
