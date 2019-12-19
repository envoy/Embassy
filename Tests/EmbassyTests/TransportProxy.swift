//
//  TransportTests2.swift
//  Embassy-iOS
//
//  Created by robert.pub on 2019/10/21.
//  Copyright © 2019 Fang-Pen Lin. All rights reserved.
//

import Foundation

class TransportProxy:TransportDelegate {

    var closedCallback: ((Transport.CloseReason) -> Void)?
    var readDataCallback: ((Data) -> Void)?
    let transport:Transport

     init(
         socket: TCPSocket,
         eventLoop: EventLoop,
         closedCallback: ((Transport.CloseReason) -> Void)? = nil,
         readDataCallback: ((Data) -> Void)? = nil
     ) {
         self.closedCallback = closedCallback
         self.readDataCallback = readDataCallback
         transport = Transport.init(socket: socket, eventLoop: eventLoop)
         transport.delegate = self
     }
    
    func getTransport() -> Transport{
        return transport
    }
    
    func closedCallback(_ reason: Transport.CloseReason) {
        guard let closedCallback = self.closedCallback else { return}
        closedCallback(reason)
    }
    
    func readDataCallback(_ data: Data) {
        guard let readDataCallback = self.readDataCallback else { return }
        readDataCallback(data)
    }
}
