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

class MyCustomRendererView: NativeView {
    public let sampleBufferDisplayLayer: AVSampleBufferDisplayLayer

    override init(frame: CGRect) {
        sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
        super.init(frame: frame)
        sampleBufferDisplayLayer.videoGravity = .resizeAspectFill
        #if os(macOS)
        // this is required for macOS
        wantsLayer = true
        layer?.insertSublayer(sampleBufferDisplayLayer, at: 0)
        #elseif os(iOS)
        layer.insertSublayer(sampleBufferDisplayLayer, at: 0)
        #else
        fatalError("Unimplemented")
        #endif
    }

    override func performLayout() {
        super.performLayout()
        sampleBufferDisplayLayer.frame = bounds
        sampleBufferDisplayLayer.removeAllAnimations()
    }
}

// Conform to VideoRenderer
extension MyCustomRendererView: VideoRenderer {
    var isAdaptiveStreamEnabled: Bool { true }
    var adaptiveStreamSize: CGSize { bounds.size }
    func set(size _: CGSize) {}

    func render(frame: LiveKit.VideoFrame) {
        if let sampleBuffer = frame.toCMSampleBuffer() {
            sampleBufferDisplayLayer.sampleBufferRenderer.enqueue(sampleBuffer)
        }
    }
}
