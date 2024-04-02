/*
 * Copyright 2024 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import AVFoundation
import LiveKit
import SwiftUI

// Make custom renderer view usable in SwiftUI
struct MySwiftUICustomRendererView: NativeViewRepresentable {
    let track: VideoTrack

    func makeView(context: Context) -> MyCustomRendererView {
        let view = MyCustomRendererView()
        updateView(view, context: context)
        return view
    }

    func updateView(_ view: MyCustomRendererView, context _: Context) {
        track.add(videoRenderer: view)
    }

    static func dismantleView(_: MyCustomRendererView, coordinator _: ()) {}
}

struct MyRemoteVideoTrackView: View {
    // let track = LocalVideoTrack.createCameraTrack()
    @EnvironmentObject var room: Room
    var body: some View {
        let firstRemoteVideoTrack = room.remoteParticipants.values
            .flatMap(\.trackPublications.values)
            .compactMap { $0.track as? RemoteVideoTrack }
            .first
        if let firstRemoteVideoTrack {
            MySwiftUICustomRendererView(track: firstRemoteVideoTrack)
        }
    }
}

class RoomContext: ObservableObject {
    let room = Room()
    init() {
        print("RoomContext.init()")
    }

    deinit {
        print("RoomContext.deinit")
    }
}

struct RoomView: View {
    // @StateObject var roomContext = RoomContext()
    let room = Room()

    var body: some View {
        MyRemoteVideoTrackView()
            // Attach Room object
            .environmentObject(room)
            // For example purpose, simply connect / disconnect when view appears / disappears
            .onAppear(perform: {
                Task {
                    // Connect to room...
                    try await room.connect(url: "", token: "")
                    // Publish camera...
                    try await room.localParticipant.setCamera(enabled: true)
                }
            })
            .onDisappear(perform: {
                Task {
                    await room.disconnect()
                }
            })
    }
}
