//
//  TCPSocketTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation
import Testing

@testable import Embassy

@Suite struct TCPSocketTests {
    /// Accepts on a helper thread while the client connects from here
    private func connectPair(clientBlocking: Bool = true) async throws -> (client: TCPSocket, accepted: TCPSocket) {
        let (listenSocket, port) = try makeListenSocket(blocking: true)
        async let accepted = onThread { try listenSocket.accept() }
        let client = try TCPSocket(blocking: clientBlocking)
        try client.connect(host: "::1", port: port)
        return (client, try await accepted)
    }

    @Test func accept() async throws {
        let (_, accepted) = try await connectPair(clientBlocking: false)
        #expect(accepted.fileDescriptor >= 0)
    }

    @Test func readAndWrite() async throws {
        let (client, accepted) = try await connectPair()
        let stringToSend = "hello baby"
        let bytesToSend = Data(stringToSend.utf8)

        let sentBytes = try client.send(data: bytesToSend)
        #expect(sentBytes == bytesToSend.count)

        let received = try await onThread {
            // accept() hands back a non-blocking socket; block so the read waits
            // for the bytes instead of racing the send with EAGAIN
            accepted.blocking = true
            return try accepted.recv(size: 1024)
        }
        #expect(utf8String(received) == stringToSend)
    }

    @Test func getPeerName() async throws {
        let (client, accepted) = try await connectPair()
        #expect(try accepted.getPeerName().0 == "::1")
        #expect(try client.getPeerName().0 == "::1")
    }

    @Test func getSockName() async throws {
        let (client, accepted) = try await connectPair()
        #expect(try accepted.getSockName().0 == "::1")
        #expect(try client.getSockName().0 == "::1")
    }
}
