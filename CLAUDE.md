# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Embassy is a lightweight, pure-Swift, async event-loop-based HTTP server (~1.5K LOC). Zero third-party dependencies. Targets macOS / iOS / tvOS (Apple platforms only; Linux support was removed in 2026). It's commonly embedded in iOS apps for UI testing against a local server. Envoy's `Ambassador` web framework is built on top of this.

## Build & test

```bash
swift build
swift test
swift test --filter <TestCaseName>/<testMethodName>   # single test
```

SwiftPM is the only build system; the old `Embassy.xcodeproj`/`.xcworkspace` and CocoaPods/Carthage manifests were removed. Open `Package.swift` directly in Xcode. Deployment floor is iOS 15 / macOS 12 / tvOS 15.

Test sources live at `Tests/EmbassyTests/`. Timing-sensitive tests sequence events with the shared `tick` constant in `TestingHelpers.swift` (100 ms) instead of whole seconds; keep new tests on that scale.

Lint config exists (`.swiftlint.yaml`) but no `swiftlint` invocation is wired into a script in this repo — run `swiftlint` directly if installed.

## Architecture

Everything lives flat under `Sources/` (single `Embassy` target, no submodules). The layers, bottom to top:

1. **Selector** (`Selector.swift`, `KqueueSelector.swift`) — thin protocol + a `kqueue()` wrapper for readiness notification on file descriptors. Raw syscalls are called as `Darwin.xxx` directly; the `Darwin.` prefix matters inside `TCPSocket`, whose methods shadow the libc names.
2. **EventLoop** (`EventLoop.swift` protocol, `SelectorEventLoop.swift` implementation) — the single-threaded run loop. Wraps a `Selector` and adds a timed-callback heap (`HeapSort.swift`) and thread-safe call scheduling (`Atomic.swift`) so callbacks can be enqueued from other threads via `call(withDelay:)` / `call(atTime:)`. **All SWSGI callbacks (`startResponse`, `sendBody`, `swsgi.input`) must only be invoked from the thread running the `EventLoop`** — never dispatch to it via GCD.
3. **TCPSocket / Transport** (`TCPSocket.swift`, `Transport.swift`, `IOUtils.swift`) — non-blocking socket wrapper and the read/write buffering layer built on top of an `EventLoop` + `Selector` pair. IPv6-first with IPv4 dual-stack support.
4. **HTTPConnection / HTTPRequest / HTTPHeaderParser** (`HTTPConnection.swift`, `HTTPRequest.swift`, `HTTPHeaderParser.swift`, `MultiDictionary.swift`) — per-connection HTTP/1.1 parsing and response writing state machine, sitting on a `Transport`.
5. **HTTPServer / DefaultHTTPServer** (`HTTPServer.swift` protocol, `DefaultHTTPServer.swift`) — accepts connections and dispatches each request into a **SWSGI** application closure.
6. **SWSGI** (`SWSGI.swift`, `SWSGIUtils.swift`) — the app-facing gateway interface (Embassy's answer to Python's WSGI): `([String: Any], startResponse, sendBody) -> Void`. This is the extension point consumers implement; everything below it is server plumbing. See README.md for the full `environ` key reference (`embassy.event_loop`, `embassy.connection`, `swsgi.input`, etc.).

**Logging** (`Logger.swift`, `DefaultLogger.swift`, `LogHandler.swift`, `*LogHandler.swift`, `LogFormatter.swift`) is a separate, independent subsystem (handler chain + formatter) used internally and exposed for consumers.

Test suite (`Tests/`) mirrors the source layout 1:1 (one `*Tests.swift` per major component) plus `TestingHelpers.swift` for shared fixtures.
