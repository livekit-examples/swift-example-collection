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
    let pip: Bool
    
    private let videoCallController = AVPictureInPictureVideoCallViewController()

    func makeUIViewController(context: Context) -> UIViewController {
        let rendering = PiPRenderingView { frame in
            videoCallController.view.transform = CGAffineTransform(rotationAngle: frame.rotation.rotationAngle)
            videoCallController.preferredContentSize = frame.rotatedSize
        }
        rendering.sampleBufferDisplayLayer.videoGravity = .resizeAspectFill
        rendering.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        rendering.frame = videoCallController.view.bounds
        videoCallController.view.addSubview(rendering)
        track.add(videoRenderer: rendering)
        
        return videoCallController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if pip {
            context.coordinator.start()
        } else {
            context.coordinator.stop()
        }
    }
    
    func makeCoordinator() -> PiPCoordinator {
        let contentSource = AVPictureInPictureController.ContentSource(activeVideoCallSourceView: videoCallController.view, contentViewController: videoCallController)
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        
        let coordinator = PiPCoordinator(controller: controller)
        return coordinator
    }
}

class PiPRenderingView: UIView {
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

extension PiPRenderingView: VideoRenderer {
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

class PiPCoordinator: NSObject, AVPictureInPictureControllerDelegate {
    private let controller: AVPictureInPictureController
    
    init(controller: AVPictureInPictureController) {
        self.controller = controller
        super.init()
        controller.delegate = self
    }
    
    func start() {
        controller.startPictureInPicture()
    }
    
    func stop() {
        controller.stopPictureInPicture()
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
