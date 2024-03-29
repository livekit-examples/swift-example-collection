//
//  ContentView.swift
//  Shared
//
//  Created by Hiroshi Horie on 2022/09/13.
//

import SwiftUI
import LiveKitClient

class Controller: ObservableObject {

    let room: Room

    init() {
        print("init")
        room = Room()
        room.add(delegate: self)

        room.connect("wss://_____.livekit.cloud",
                     "")
    }

    deinit {
        print("deinit")
    }
}

extension Controller: RoomDelegate {

    func room(_ room: Room, didUpdate connectionState: ConnectionState, oldValue: ConnectionState) {
        //
        print("connectionState -> \(connectionState)")
    }
}

struct ContentView: View {

    @ObservedObject var ctrl = Controller()

    var body: some View {
        Text("LiveKit Client SDK Ver. \(LiveKit.version)")
            .padding()
    }
}
