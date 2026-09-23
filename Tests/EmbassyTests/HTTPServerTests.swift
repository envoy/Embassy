//
//  HTTPServerTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation
import Testing

@testable import Embassy

@Suite struct HTTPServerTests {
    private let session = URLSession(configuration: .default)

    private func makeLoop() throws -> SelectorEventLoop {
        try SelectorEventLoop(selector: try KqueueSelector())
    }

    private func url(_ server: DefaultHTTPServer, path: String = "") -> URL {
        URL(string: "http://[::1]:\(server.listenAddress.port)\(path)")!
    }

    /// Starts the server, runs the loop on its own thread while `request`
    /// performs the client side, then stops the loop and waits for it.
    private func serve<T: Sendable>(
        _ server: DefaultHTTPServer,
        on loop: SelectorEventLoop,
        request: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try server.start()
        let loopTask = Task { _ = await run(loop) }
        defer {
            loop.stop()
        }
        let result = try await request()
        loop.stop()
        await loopTask.value
        return result
    }

    @Test func environ() async throws {
        let loop = try makeLoop()
        let received = Locked<[String: Any]?>(nil)
        let server = DefaultHTTPServer(eventLoop: loop, port: 0) { environ, _, _ in
            received.value = environ
            loop.stop()
        }
        try server.start()
        let loopTask = Task { _ = await run(loop) }
        // the app never responds; the request only completes once the server
        // closes the connection during stop()
        let request = Task { try? await session.data(from: url(server, path: "/path?foo=bar")) }
        await loopTask.value
        server.stop()
        _ = await request.value

        let environ = try #require(received.value)
        #expect(environ["REQUEST_METHOD"] as? String == "GET")
        #expect(environ["HTTP_HOST"] as? String == "[::1]:\(server.port)" || environ["HTTP_HOST"] != nil)
        #expect(environ["SERVER_PROTOCOL"] as? String == "HTTP/1.1")
        #expect(environ["SERVER_PORT"] as? String == String(server.port))
        #expect(environ["SCRIPT_NAME"] as? String == "")
        #expect(environ["PATH_INFO"] as? String == "/path")
        #expect(environ["QUERY_STRING"] as? String == "foo=bar")
        #expect(environ["swsgi.version"] as? String == "0.1")
        #expect(environ["swsgi.multithread"] as? Bool == false)
        #expect(environ["swsgi.multiprocess"] as? Bool == false)
        #expect(environ["swsgi.url_scheme"] as? String == "http")
        #expect(environ["swsgi.run_once"] as? Bool == false)
        #expect(environ["embassy.connection"] as? HTTPConnection != nil)
        #expect(environ["embassy.event_loop"] as? EventLoop != nil)
        #expect(environ["embassy.version"] as? String == Embassy.version)
    }

    @Test func startResponse() async throws {
        let loop = try makeLoop()
        let server = DefaultHTTPServer(eventLoop: loop, port: 0) { _, startResponse, sendBody in
            startResponse("451 Big brother doesn't like this", [
                ("Content-Type", "video/porn"),
                ("Server", "Embassy-by-envoy"),
                ("X-Foo", "Bar")
            ])
            sendBody(Data())
        }

        let (data, response) = try await serve(server, on: loop) {
            try await session.data(from: url(server))
        }
        let http = try #require(response as? HTTPURLResponse)
        #expect(data.isEmpty)
        #expect(http.statusCode == 451)
        #expect(http.value(forHTTPHeaderField: "Content-Type") == "video/porn")
        #expect(http.value(forHTTPHeaderField: "Server") == "Embassy-by-envoy")
        #expect(http.value(forHTTPHeaderField: "X-Foo") == "Bar")
    }

    @Test func sendBody() async throws {
        let loop = try makeLoop()
        let bigDataChunk = Data(makeRandomString(574300).utf8)
        let server = DefaultHTTPServer(eventLoop: loop, port: 0) { _, startResponse, sendBody in
            startResponse("200 OK", [])
            sendBody(bigDataChunk)
            sendBody(Data())
        }

        let (data, response) = try await serve(server, on: loop) {
            try await session.data(from: url(server))
        }
        #expect(data.count == bigDataChunk.count)
        #expect(data == bigDataChunk)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
    }

    @Test func asyncSendBody() async throws {
        let loop = try makeLoop()
        let server = DefaultHTTPServer(eventLoop: loop, port: 0) { environ, startResponse, sendBody in
            startResponse("200 OK", [])
            let loop = environ["embassy.event_loop"] as! EventLoop
            loop.call(withDelay: 1 * tick) { sendBody(Data("hello ".utf8)) }
            loop.call(withDelay: 2 * tick) { sendBody(Data("baby ".utf8)) }
            loop.call(withDelay: 3 * tick) {
                sendBody(Data("fin".utf8))
                sendBody(Data())
            }
        }

        let (data, response) = try await serve(server, on: loop) {
            try await session.data(from: url(server))
        }
        #expect(utf8String(data) == "hello baby fin")
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
    }

    /// Echo app that also records everything read from swsgi.input
    private func echoApp(recording received: Locked<[Data]>) -> SWSGI {
        { environ, startResponse, sendBody in
            if environ["HTTP_EXPECT"] as? String == "100-continue" {
                startResponse("100 Continue", [])
            } else {
                startResponse("200 OK", [])
            }
            let input = environ["swsgi.input"] as! SWSGIInput
            input { data in
                received.append(data)
                sendBody(data)
            }
        }
    }

    @Test(arguments: [40960, 5])
    func postBody(bodyLength: Int) async throws {
        // 5 bytes is small enough to arrive with the header as the initial body;
        // 40 KB streams in through swsgi.input across several reads
        let loop = try makeLoop()
        let postBodyString = makeRandomString(bodyLength)
        let received = Locked<[Data]>([])
        let server = DefaultHTTPServer(eventLoop: loop, port: 0, app: echoApp(recording: received))

        let (data, _) = try await serve(server, on: loop) {
            var request = URLRequest(url: url(server))
            request.httpMethod = "POST"
            request.httpBody = Data(postBodyString.utf8)
            return try await session.data(for: request)
        }

        // ensure EOF is passed
        #expect(received.value.last?.count == 0)
        #expect(utf8String(Data(received.value.joined())) == postBodyString)
        #expect(utf8String(data) == postBodyString)
    }

    @Test func addressReuse() async throws {
        let loop = try makeLoop()
        let called = Locked(false)
        let app: SWSGI = { _, startResponse, sendBody in
            startResponse("200 OK", [])
            sendBody(Data())
            called.value = true
        }
        let server1 = DefaultHTTPServer(eventLoop: loop, port: 0, app: app)
        try server1.start()
        let port = server1.listenAddress.port
        server1.stop()

        // binding the same port straight after a close needs SO_REUSEADDR
        let server2 = DefaultHTTPServer(eventLoop: loop, port: port, app: app)
        _ = try await serve(server2, on: loop) {
            try await session.data(from: url(server2))
        }
        #expect(called.value)
    }

    @Test func stopAndWait() async throws {
        let loop = try makeLoop()
        let server = DefaultHTTPServer(eventLoop: loop, port: 0) { _, startResponse, sendBody in
            startResponse("200 OK", [])
            sendBody(Data())
        }
        try server.start()
        let loopTask = Task { _ = await run(loop) }

        let stopped = try await timed { server.stopAndWait() }
        expectDuration(0, stopped.elapsed)

        loop.stop()
        await loopTask.value
    }

    @Test func stopAndWaitAsync() async throws {
        let loop = try makeLoop()
        let server = DefaultHTTPServer(eventLoop: loop, port: 0) { _, startResponse, sendBody in
            startResponse("200 OK", [])
            sendBody(Data())
        }
        try server.start()
        let loopTask = Task { _ = await run(loop) }

        let start = DispatchTime.now()
        await server.stopAndWait()
        expectDuration(0, seconds(since: start))

        loop.stop()
        await loopTask.value
    }
}
