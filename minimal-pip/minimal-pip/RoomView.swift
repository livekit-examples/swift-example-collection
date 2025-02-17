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
    @EnvironmentObject var room: Room
    @State var track: LocalVideoTrack?

    var body: some View {
        // For remote tracks:
        // let track = room.remoteParticipants.values
        //     .flatMap(\.trackPublications.values)
        //     .compactMap { $0.track as? RemoteVideoTrack }
        //     .first
        Group {
            if let track {
                MySwiftUICustomRendererView(track: track)
            } else {
                Text("No Video track")
            }
        }.onAppear {
            track = LocalVideoTrack.createCameraTrack()
            Task {
                if let cameraCapturer = track?.capturer as? CameraCapturer {
                    cameraCapturer.isMultitaskingAccessEnabled = true
                }
                try await track?.start()
            }
        }.onDisappear {
            Task {
                try await track?.stop()
            }
        }
    }
}

class RoomContext: ObservableObject {
    // Don't suspend local video tracks in background
    let room = Room(roomOptions: RoomOptions(suspendLocalVideoTracksInBackground: false))

    init() {
        #if os(iOS)
        // Audio session category switch is required for PIP to work
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            print("Setting category to AVAudioSessionCategoryPlayback failed.")
        }
        #endif
    }
}

struct RoomView: View {
    @StateObject var roomContext = RoomContext()
    let room = Room()

    var body: some View {
        MyRemoteVideoTrackView()
            // Attach Room object
            .environmentObject(room)
            // For example purpose, simply connect / disconnect when view appears / disappears
            .onAppear(perform: {
                Task {
                    // Set your token here
                    try await room.connect(url: "", token: "")
                }
            })
            .onDisappear(perform: {
                Task {
                    await room.disconnect()
                }
            })
    }
}
