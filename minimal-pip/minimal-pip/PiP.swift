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
    
    private let previewController = UIViewController()
    private let videoCallController = AVPictureInPictureVideoCallViewController()
    
    func makeUIViewController(context: Context) -> UIViewController {
        let videoCallView = SampleRenderingView { frame in
            videoCallController.view.transform = CGAffineTransform(rotationAngle: frame.rotation.rotationAngle)
            videoCallController.preferredContentSize = frame.rotatedSize
        }
        videoCallView.sampleBufferDisplayLayer.videoGravity = .resizeAspectFill
        videoCallView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        videoCallView.frame = videoCallController.view.bounds
        videoCallController.view.addSubview(videoCallView)
        track.add(videoRenderer: videoCallView)
        
        let previewView = SampleRenderingView { frame in
            previewController.view.transform = CGAffineTransform(rotationAngle: frame.rotation.rotationAngle)
        }
        previewView.sampleBufferDisplayLayer.videoGravity = .resizeAspectFill
        previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        previewView.frame = previewController.view.bounds
        previewController.view.addSubview(previewView)
        track.add(videoRenderer: previewView)
        
        return previewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        let contentSource = AVPictureInPictureController.ContentSource(activeVideoCallSourceView: previewController.view, contentViewController: videoCallController)
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.setValue(1, forKey: "controlsStyle")
        
        let coordinator = Coordinator(controller: controller)
        controller.delegate = coordinator
        return coordinator
    }
    
    class Coordinator: NSObject, AVPictureInPictureControllerDelegate {
        private let controller: AVPictureInPictureController
        
        init(controller: AVPictureInPictureController) {
            self.controller = controller
            super.init()
        }

        // Implement delegate methods if needed...
    }
}

final class SampleRenderingView: UIView {
    override class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }
    
    var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
        layer as! AVSampleBufferDisplayLayer
    }
    
    let onRender: (LiveKit.VideoFrame) -> Void

    init(onRender: @MainActor @escaping (LiveKit.VideoFrame) -> Void) {
        self.onRender = onRender
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SampleRenderingView: VideoRenderer {
    var isAdaptiveStreamEnabled: Bool { true }
    var adaptiveStreamSize: CGSize { bounds.size }
    func set(size _: CGSize) {}

    func render(frame: LiveKit.VideoFrame) {
        if let sampleBuffer = frame.toCMSampleBuffer() {
            Task { @MainActor in
                sampleBufferDisplayLayer.sampleBufferRenderer.enqueue(sampleBuffer)
                onRender(frame)
            }
        }
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
