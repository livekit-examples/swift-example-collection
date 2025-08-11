//
//  PiP.swift
//  minimal-pip
//
//  Created by Blaze Pankowski on 11/08/2025.
//

import SwiftUI
import AVKit
import LiveKit

struct PiPView: UIViewControllerRepresentable {
    let track: VideoTrack
    
    @State private var previewController = PreviewViewController()
    @State private var videoCallController = VideoCallViewController()
    
    func makeUIViewController(context: Context) -> UIViewController {
        track.add(videoRenderer: previewController)
        track.add(videoRenderer: videoCallController)
        
        return previewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        let contentSource = AVPictureInPictureController.ContentSource(activeVideoCallSourceView: previewController.view, contentViewController: videoCallController)
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        
        let coordinator = Coordinator(controller: controller)
        controller.delegate = coordinator
        return coordinator
    }
    
    final class Coordinator: NSObject, AVPictureInPictureControllerDelegate {
        private let controller: AVPictureInPictureController
        
        init(controller: AVPictureInPictureController) {
            self.controller = controller
            super.init()
        }

        // Implement delegate methods if needed...
    }
}

final class PreviewViewController: UIViewController, VideoRenderer {
    private lazy var renderingView = SampleRenderingView()
    
    override func loadView() {
        view = renderingView
    }
    
    var isAdaptiveStreamEnabled: Bool { true }
    var adaptiveStreamSize: CGSize { view.bounds.size }

    func render(frame: LiveKit.VideoFrame) {
        if let sampleBuffer = frame.toCMSampleBuffer() {
            Task { @MainActor in
                renderingView.sampleBufferDisplayLayer.sampleBufferRenderer.enqueue(sampleBuffer)
                view.transform = CGAffineTransform(rotationAngle: frame.rotation.rotationAngle)
            }
        }
    }
}

final class VideoCallViewController: AVPictureInPictureVideoCallViewController, VideoRenderer {
    private lazy var renderingView = SampleRenderingView()
    
    override func loadView() {
        view = renderingView
        // or add more subviews...
    }
    
    var isAdaptiveStreamEnabled: Bool { true }
    var adaptiveStreamSize: CGSize { view.bounds.size }

    func render(frame: LiveKit.VideoFrame) {
        if let sampleBuffer = frame.toCMSampleBuffer() {
            Task { @MainActor in
                renderingView.sampleBufferDisplayLayer.sampleBufferRenderer.enqueue(sampleBuffer)
                view.transform = CGAffineTransform(rotationAngle: frame.rotation.rotationAngle)
                preferredContentSize = frame.rotatedSize
            }
        }
    }
}

final class SampleRenderingView: UIView {
    override class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }
    
    var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
        layer as! AVSampleBufferDisplayLayer
    }
}

extension LiveKit.VideoRotation {
    var rotationAngle: CGFloat {
        switch self {
        case ._0: return 0
        case ._90: return .pi / 2
        case ._180: return .pi
        case ._270: return 3 * .pi / 2
        @unknown default: return 0
        }
    }
}

extension LiveKit.VideoFrame {
    var rotatedSize: CGSize {
        switch rotation {
        case ._90, ._270: return CGSize(width: Int(dimensions.height), height: Int(dimensions.width))
        default: return CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
        }
    }
}
