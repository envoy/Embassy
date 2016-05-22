//
//  SWSGI.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/19/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation


/**
    Swift Web Server Gateway Interface

    This is a HTTP server gateway interface inspired by Python's WSGI
 
     - Parameter environ: environ variables for the incoming HTTP request (TODO: keys need to be defined)
     - Parameter startResponse: function to call to inform server to start sending HTTP response header to client,
                                first argument is the status text, e.g. "200 OK". The second argument is a list of
                                header key and value pair
     - Parameter sendBody: function to call to send the HTTP body to client, to end the stream, simply send an UInt8
                           with zero length
 
*/
public typealias SWSGI = (environ: [String: AnyObject], startResponse: ((String, [(String, String)]) -> Void), sendBody: ([UInt8] -> Void)) -> Void
