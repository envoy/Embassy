# Embassy

[![Build Status](https://travis-ci.org/envoy/Embassy.svg?branch=master)](https://travis-ci.org/envoy/Embassy)
[![GitHub license](https://img.shields.io/github/license/envoy/Embassy.svg)](https://github.com/envoy/Embassy/blob/master/LICENSE)

Lightweight async HTTP server in pure Swift for iOS UI Automatic testing data mocking

## Features
 
 - Super lightweight, only 1.5 K of lines
 - Zero third-party dependency
 - Async event loop HTTP server, long-polling, delay, all possible
 - HTTP Application based on SWSGI, super flexible

## Example

Here's a simple example shows how Embassy works.

```Swift
let loop = try! EventLoop(selector: try! KqueueSelector())
let app = { (environ: [String: AnyObject], startResponse: ((String, [(String, String)]) -> Void), sendBody: ([UInt8] -> Void)) in
    // Start HTTP response
    startResponse("200 OK", [])
    let pathInfo = environ["PATH_INFO"]!
    sendBody(Array("the path you're visiting is \(pathInfo.debugDescription)".utf8))
    // send EOF
    sendBody([])
}
let server = HTTPServer(eventLoop: loop, app: app, port: 8081)

// Start HTTP server to listen on the port
try! server.start()

// Run event loop
loop.runForever()
```

## What's SWSGI (Swift Web Server Gateway Interface)?

SWSGI is a hat tip to Python's [WSGI (Web Server Gateway Interface)](https://www.python.org/dev/peps/pep-3333/). It's a gateway interface enables web applications to talk to HTTP clients without knowing HTTP server implementation details.

It's defined as

```Swift
public typealias SWSGI = (
    environ: [String: AnyObject],
    startResponse: ((String, [(String, String)]) -> Void),
    sendBody: ([UInt8] -> Void)
) -> Void
```

For the arguments

### `environ`

It's a dictionary contains all necessary information about the request. It basically follows WSGI standard, except `wsgi.*` keys will be `swsgi.*` instead. For example:

```Swift
[
  "SERVER_NAME": "[::1]",
  "SERVER_PROTOCOL" : "HTTP/1.1",
  "SERVER_PORT" : "53479",
  "REQUEST_METHOD": "GET",
  "SCRIPT_NAME" : "",
  "PATH_INFO" : "/",
  "HTTP_HOST": "[::1]:8889",
  "HTTP_USER_AGENT" : "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.2661.102 Safari/537.36",
  "HTTP_ACCEPT_LANGUAGE" : "en-US,en;q=0.8,zh-TW;q=0.6,zh;q=0.4,zh-CN;q=0.2",
  "HTTP_CONNECTION" : "keep-alive",
  "HTTP_ACCEPT" : "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
  "HTTP_ACCEPT_ENCODING" : "gzip, deflate, sdch",
  "swsgi.version" : "0.1",
  "swsgi.input" : "",
  "swsgi.error" : "",
  "swsgi.multiprocess" : false,
  "swsgi.multithread" : false,
  "swsgi.url_scheme" : "http",
  "swsgi.run_once" : false
]
```

**Notice**: For now `swsgi.input` and `swsgi.error` are not defined yet.

### `startResponse`

Function for starting to send HTTP response header to client, the first argument is status code with message, e.g. "200 OK". The second argument is headers, as a list of key value tuple.

To response HTTP header, you can do

```Swift
startResponse("200 OK", [("Set-Cookie", "foo=bar")])
```

`startResponse` can only be called once per request, extra call will be simply ignored.

### `sendBody`

Function for sending body data to client. You need to call `startResponse` first in order to call `sendBody`. If you don't call `startResponse` first, all calls to `sendBody` will be ignored. To send data, here you can do

```Swift
sendBody(Array("hello".utf8))
```

To end the response data stream simply call `sendBody` with an empty bytes array.

```Swift
sendBody([])
```

## TODOs

 - [ ] Figure out how should we pass request body data stream into SWSGI environ dictionary
 - [ ] Configurable logging handler
