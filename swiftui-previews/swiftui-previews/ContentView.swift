/*
 * Copyright 2026 LiveKit
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

import CoreText
import Foundation
import LiveKit
import SwiftUI

#if canImport(UIKit)
import UIKit

typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit

typealias PlatformColor = NSColor
#endif

struct ContentView: View {
    @State private var mock = MockVideoSource()

    var body: some View {
        VStack(spacing: 20) {
            Text("LiveKitSDK: v\(LiveKitSDK.version)")
            SwiftUIVideoView(mock.track, renderMode: .sampleBuffer)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(minWidth: 100, minHeight: 100)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

@Observable
final class MockVideoSource {
    let track: LocalVideoTrack
    private var timer: Timer?
    private var frameCount: Int = 0
    private var currentFps: Int = 0
    private var framesThisSecond: Int = 0
    private var lastFpsUpdate: Date = .init()

    init(fps: Double = 30) {
        track = LocalVideoTrack.createBufferTrack(name: "preview")
        start(fps: fps)
    }

    deinit {
        timer?.invalidate()
    }

    private func start(fps: Double) {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { [weak self] _ in
            guard
                let self,
                let capturer = track.capturer as? BufferCapturer
            else { return }

            // Update FPS counter every second
            framesThisSecond += 1
            let now = Date()
            let elapsed = now.timeIntervalSince(lastFpsUpdate)
            if elapsed >= 1.0 {
                currentFps = Int(Double(framesThisSecond) / elapsed)
                framesThisSecond = 0
                lastFpsUpdate = now
            }

            // Cycle hue over ~5 seconds (at 30fps = 150 frames per cycle)
            let hue = CGFloat(frameCount % 150) / 150.0
            let color = PlatformColor(hue: hue, saturation: 1.0, brightness: 0.8, alpha: 1.0)

            guard let buffer = Self.makePixelBuffer(color: color, frameCount: frameCount, fps: currentFps, size: CGSize(width: 640, height: 360))
            else { return }

            capturer.capture(buffer)
            frameCount += 1
        }
    }

    private static func makePixelBuffer(color: PlatformColor, frameCount: Int, fps: Int, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard let buffer = pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard
            let base = CVPixelBufferGetBaseAddress(buffer),
            let ctx = CGContext(
                data: base,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
            )
        else { return nil }

        // Fill background with color
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))

        // Draw frame counter and FPS
        let text = "Frame: \(frameCount) | FPS: \(fps)" as CFString
        let font = CTFontCreateUIFontForLanguage(.system, 18, nil)!
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(gray: 1.0, alpha: 1.0),
        ]
        let attributedString = CFAttributedStringCreate(nil, text, attributes as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attributedString)

        // Center the text
        let textBounds = CTLineGetBoundsWithOptions(line, [])
        let x = (size.width - textBounds.width) / 2
        let y = (size.height - textBounds.height) / 2
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, ctx)

        return buffer
    }
}
