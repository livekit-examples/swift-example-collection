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

import SwiftUI

import LiveKit
import LiveKitWebRTC
import WebRTC

// Example of importing both LiveKit(LiveKitWebRTC) and normal WebRTC

struct ContentView: View {
    var body: some View {
        VStack {
            Button(action: {
                print("LiveKitSDK.version: \(LiveKitSDK.version)")

                // Example reading symbol from LiveKitWebRTC
                print("kRTCVp9CodecName (LiveKitWebRTC): \(LiveKitWebRTC.kRTCVp9CodecName)")
                // Example reading symbol from WebRTC
                print("kRTCVp9CodecName (WebRTC): \(WebRTC.kRTCVp9CodecName)")

                let instance1 = LiveKitWebRTC.LKRTCDefaultVideoEncoderFactory()
                print("DefaultVideoEncoderFactory (LiveKitWebRTC): \(String(describing: instance1))")

                let instance2 = WebRTC.RTCDefaultVideoEncoderFactory()
                print("DefaultVideoEncoderFactory (WebRTC): \(String(describing: instance2))")

            }, label: {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
            })
        }
        .padding()
    }
}

class Example: LiveKit.VideoRenderer {
    var isAdaptiveStreamEnabled: Bool { false }
    var adaptiveStreamSize: CGSize {
        CGSize(width: 100, height: 100)
    }

    func set(size _: CGSize) {}

    func render(frame _: LiveKit.VideoFrame) {
        // frame.toWebRTCVideoFrame()
    }
}

extension LiveKit.VideoRotation {
    func toWebRTCRotation() -> WebRTC.RTCVideoRotation {
        switch self {
        case ._0: return ._0
        case ._90: return ._90
        case ._180: return ._180
        case ._270: return ._270
        }
    }
}

extension LiveKit.VideoFrame {
    // Example to convert frame
    func toWebRTCVideoFrame() -> WebRTC.RTCVideoFrame {
        let rtcBuffer: RTCVideoFrameBuffer
        if let buffer = buffer as? CVPixelVideoBuffer {
            rtcBuffer = WebRTC.RTCCVPixelBuffer(pixelBuffer: buffer.pixelBuffer)
        } else if let buffer = buffer as? I420VideoBuffer {
            rtcBuffer = WebRTC.RTCI420Buffer(width: buffer.chromaWidth,
                                             height: buffer.chromaHeight,
                                             dataY: buffer.dataY,
                                             dataU: buffer.dataU,
                                             dataV: buffer.dataV)
        } else {
            fatalError("Unsupported type")
        }

        return RTCVideoFrame(buffer: rtcBuffer,
                             rotation: rotation.toWebRTCRotation(),
                             timeStampNs: timeStampNs)
    }
}
