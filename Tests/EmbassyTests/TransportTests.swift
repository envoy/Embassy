//
//  TransportTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation
import Testing

@testable import Embassy

@Suite struct TransportTests {
    /// A client transport connected to a listening socket, plus the server-side
    /// transport once the loop accepts it. Callbacks are wired by the caller.
    private struct Pair {
        let loop: SelectorEventLoop
        let client: Transport
        let server = Locked<Transport?>(nil)
    }

    private func makePair(
        clientRead: @escaping @Sendable (Data) -> Void,
        serverRead: @escaping @Sendable (Data) -> Void,
        serverClosed: (@Sendable (Transport.CloseReason) -> Void)? = nil
    ) throws -> Pair {
        let loop = try SelectorEventLoop(selector: try KqueueSelector())
        let (listenSocket, port) = try makeListenSocket()
        let clientSocket = try TCPSocket()
        let client = Transport(socket: clientSocket, eventLoop: loop, readDataCallback: clientRead)
        let pair = Pair(loop: loop, client: client)

        loop.setReader(listenSocket.fileDescriptor) {
            let accepted = try! listenSocket.accept()
            pair.server.value = Transport(
                socket: accepted,
                eventLoop: loop,
                closedCallback: serverClosed,
                readDataCallback: serverRead
            )
        }
        try clientSocket.connect(host: "::1", port: port)
        return pair
    }

    @Test func bigChunkReadAndWrite() async throws {
        let clientReceived = Locked<[String]>([])
        let serverReceived = Locked<[String]>([])
        let totalReceivedSize = Locked(0)
        let chunks = [128, 5743, 2731, 538, 2048, 1].map(makeRandomString)
        let totalDataSize = chunks.reduce(0) { $0 + $1.count }

        let pair = try makePair(
            clientRead: { data in
                clientReceived.append(utf8String(data))
                totalReceivedSize.withLock { $0 += data.count }
            },
            serverRead: { data in
                serverReceived.append(utf8String(data))
                totalReceivedSize.withLock { $0 += data.count }
            }
        )
        let loop = pair.loop

        loop.call(withDelay: 1 * tick) { pair.client.write(string: chunks[0]) }
        loop.call(withDelay: 2 * tick) { pair.server.value!.write(string: chunks[1]) }
        loop.call(withDelay: 3 * tick) { pair.client.write(string: chunks[2]) }
        loop.call(withDelay: 4 * tick) { pair.server.value!.write(string: chunks[3]) }
        loop.call(withDelay: 5 * tick) { pair.client.write(string: chunks[4]) }
        loop.call(withDelay: 6 * tick) { pair.server.value!.write(string: chunks[5]) }
        // poll for completion from the loop so the test does not depend on which
        // side's read callback sees the final byte
        loop.call(withDelay: 7 * tick) { loop.stop() }

        await run(loop)

        #expect(totalReceivedSize.value == totalDataSize)
        #expect(serverReceived.value.joined() == chunks[0] + chunks[2] + chunks[4])
        #expect(clientReceived.value.joined() == chunks[1] + chunks[3] + chunks[5])
    }

    @Test func readAndWrite() async throws {
        let clientReceived = Locked<[String]>([])
        let serverReceived = Locked<[String]>([])
        let pair = try makePair(
            clientRead: { clientReceived.append(utf8String($0)) },
            serverRead: { serverReceived.append(utf8String($0)) }
        )
        let loop = pair.loop

        loop.call(withDelay: 1 * tick) { pair.client.write(string: "a") }
        loop.call(withDelay: 2 * tick) { pair.server.value!.write(string: "1") }
        loop.call(withDelay: 3 * tick) { pair.client.write(string: "b") }
        loop.call(withDelay: 4 * tick) { pair.server.value!.write(string: "2") }
        loop.call(withDelay: 5 * tick) { pair.client.write(string: "c") }
        loop.call(withDelay: 6 * tick) { pair.server.value!.write(string: "3") }
        loop.call(withDelay: 7 * tick) { loop.stop() }

        await run(loop)

        #expect(serverReceived.value == ["a", "b", "c"])
        #expect(clientReceived.value == ["1", "2", "3"])
    }

    @Test func closeByPeer() async throws {
        let serverReceived = Locked<[String]>([])
        let serverClosedReason = Locked<Transport.CloseReason?>(nil)
        let serverClosedFlag = Locked<Bool?>(nil)
        let clientStateBeforeClose = Locked<(closed: Bool, closing: Bool)?>(nil)
        let clientClosingAfterClose = Locked<Bool?>(nil)
        let server = Locked<Transport?>(nil)

        let pair = try makePair(
            clientRead: { _ in },
            serverRead: { serverReceived.append(utf8String($0)) },
            serverClosed: { reason in
                serverClosedFlag.value = server.value?.closed
                serverClosedReason.value = reason
            }
        )
        let loop = pair.loop
        let bigDataChunk = makeRandomString(574300)

        loop.call(withDelay: 1 * tick) {
            server.value = pair.server.value
            pair.client.write(string: "hello")
        }
        loop.call(withDelay: 2 * tick) {
            clientStateBeforeClose.value = (pair.client.closed, pair.client.closing)
            pair.client.write(string: bigDataChunk)
            pair.client.close()
            clientClosingAfterClose.value = pair.client.closing
        }
        // the server side sees EOF once the client has flushed and closed; give
        // the 574 KB body a few ticks to drain through the loopback
        loop.call(withDelay: 6 * tick) { loop.stop() }

        await run(loop)

        #expect(clientStateBeforeClose.value?.closed == false)
        #expect(clientStateBeforeClose.value?.closing == false)
        #expect(clientClosingAfterClose.value == true)
        #expect(serverClosedReason.value?.isByPeer == true)
        #expect(serverClosedFlag.value == true)
        #expect(pair.client.closed)
        #expect(pair.server.value?.closed == true)
        #expect(serverReceived.value.joined().count == "hello".count + bigDataChunk.count)
    }

    @Test func readingPause() async throws {
        let clientReceived = Locked<[String]>([])
        let serverReceived = Locked<[String]>([])
        // (client count, server count) sampled while reading is paused
        let countsWhilePaused = Locked<[(Int, Int)]>([])
        let pair = try makePair(
            clientRead: { clientReceived.append(utf8String($0)) },
            serverRead: { serverReceived.append(utf8String($0)) }
        )
        let loop = pair.loop
        @Sendable func sample() {
            countsWhilePaused.append((clientReceived.value.count, serverReceived.value.count))
        }

        loop.call(withDelay: 1 * tick) { pair.client.write(string: "a") }
        loop.call(withDelay: 2 * tick) { pair.server.value!.write(string: "1") }
        loop.call(withDelay: 3 * tick) {
            pair.client.resume(reading: false)
            pair.server.value!.resume(reading: false)
            pair.client.write(string: "b")
        }
        loop.call(withDelay: 4 * tick) {
            sample()
            pair.server.value!.write(string: "2")
        }
        loop.call(withDelay: 5 * tick) {
            sample()
            pair.client.write(string: "c")
        }
        loop.call(withDelay: 6 * tick) {
            sample()
            pair.server.value!.write(string: "3")
        }
        loop.call(withDelay: 7 * tick) {
            pair.client.resume(reading: true)
            pair.server.value!.resume(reading: true)
        }
        loop.call(withDelay: 8 * tick) { loop.stop() }

        await run(loop)

        #expect(countsWhilePaused.value.map(\.0) == [1, 1, 1])
        #expect(countsWhilePaused.value.map(\.1) == [1, 1, 1])
        #expect(serverReceived.value == ["a", "bc"])
        #expect(clientReceived.value == ["1", "23"])
    }
}
