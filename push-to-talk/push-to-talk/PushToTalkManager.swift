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

import AVFoundation
import Combine
import LiveKit
import os
import PushToTalk
import SwiftUI

final class PushToTalkManager: NSObject, ObservableObject {
    static let shared = PushToTalkManager()

    nonisolated static let channelNameKey = "channelName"
    nonisolated static let defaultChannelName = "LiveKit"
    private nonisolated static let logger = Logger(subsystem: "io.livekit.swift-sdk.push-to-talk-example", category: "PushToTalk")

    @AppStorage("url") var url = ""
    @AppStorage("token") var token = ""
    @AppStorage(channelNameKey) var channelName = defaultChannelName

    @Published private(set) var channelUUID: UUID?
    @Published private(set) var isTransmitting = false
    @Published private(set) var activeSpeaker: RemoteParticipant?
    @Published private(set) var pushToken: String?

    let room = Room()

    private var channelManager: PTChannelManager?

    override private init() {
        super.init()
        room.add(delegate: self)
        configureAudio()

        Task {
            do {
                channelManager = try await PTChannelManager.channelManager(delegate: self, restorationDelegate: self)
            } catch {
                Self.logger.error("Failed to create channel manager: \(error)")
            }
        }
    }

    private func configureAudio() {
        // The system activates and deactivates the audio session around each transmission, so the SDK must not.
        AudioManager.shared.audioSession.isAutomaticConfigurationEnabled = false

        do {
            // Stays off until the system hands over an active session in channelManager(_:didActivate:).
            try AudioManager.shared.setEngineAvailability(.none)
            // The default mute mode keeps mic input running while muted, which would hold the mic
            // while the system activates the session only to play a remote speaker.
            try AudioManager.shared.set(microphoneMuteMode: .restart)
            // The system activates the session with the category already set, so it must be in place before the first activation.
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
        } catch {
            Self.logger.critical("Failed to configure audio: \(error)")
        }
    }
}

// MARK: - Channel control

extension PushToTalkManager {
    func joinChannel() async {
        guard let channelManager else { return }

        // Prompt here in the foreground, since enabling the mic later can happen from the lock screen.
        guard await LiveKitSDK.ensureDeviceAccess(for: [.audio]) else {
            Self.logger.error("Microphone access denied")
            return
        }

        let descriptor = PTChannelDescriptor(name: channelName, image: nil)
        channelManager.requestJoinChannel(channelUUID: UUID(), descriptor: descriptor)
    }

    func leaveChannel() {
        guard let channelManager, let channelUUID else { return }
        channelManager.leaveChannel(channelUUID: channelUUID)
    }

    func beginTransmitting() {
        guard let channelManager, let channelUUID else { return }
        channelManager.requestBeginTransmitting(channelUUID: channelUUID)
    }

    func stopTransmitting() {
        guard let channelManager, let channelUUID else { return }
        channelManager.stopTransmitting(channelUUID: channelUUID)
    }
}

// MARK: - Room control

extension PushToTalkManager {
    private func connectRoom() async {
        guard room.connectionState == .disconnected else { return }

        do {
            try await room.connect(url: url, token: token)
        } catch {
            Self.logger.error("Failed to connect to room: \(error)")
            leaveChannel()
        }
    }

    private func updateServiceStatus(for connectionState: ConnectionState) async {
        guard let channelManager, let channelUUID else { return }

        let status: PTServiceStatus = switch connectionState {
        case .connected: .ready
        case .connecting, .reconnecting: .connecting
        default: .unavailable
        }

        do {
            try await channelManager.setServiceStatus(status, channelUUID: channelUUID)
        } catch {
            Self.logger.error("Failed to set service status: \(error)")
        }
    }

    private func updateActiveSpeaker() async {
        guard let channelManager, let channelUUID else { return }

        // Talkers keep their mic unmuted only while transmitting.
        let speaker = room.remoteParticipants.values.first { $0.isMicrophoneEnabled() }
        guard speaker?.identity != activeSpeaker?.identity else { return }
        activeSpeaker = speaker

        // Setting a participant makes the system activate the audio session for playback, and nil ends it.
        let participant = speaker.map { PTParticipant(name: $0.displayName, image: nil) }
        do {
            try await channelManager.setActiveRemoteParticipant(participant, channelUUID: channelUUID)
        } catch {
            Self.logger.error("Failed to set active remote participant: \(error)")
        }
    }
}

extension Participant {
    var displayName: String {
        if let name, !name.isEmpty {
            return name
        }
        return identity?.stringValue ?? "Unknown"
    }
}

// MARK: - PTChannelManagerDelegate

extension PushToTalkManager: PTChannelManagerDelegate {
    nonisolated func channelManager(_ channelManager: PTChannelManager, didJoinChannel channelUUID: UUID, reason: PTChannelJoinReason) {
        Self.logger.info("Joined channel \(channelUUID), reason: \(reason.rawValue)")

        Task { @MainActor in
            // A restored channel can report its join before channelManager(delegate:restorationDelegate:) returns.
            self.channelManager = channelManager
            self.channelUUID = channelUUID
            await connectRoom()
        }
    }

    nonisolated func channelManager(_: PTChannelManager, didLeaveChannel channelUUID: UUID, reason: PTChannelLeaveReason) {
        Self.logger.info("Left channel \(channelUUID), reason: \(reason.rawValue)")

        Task { @MainActor in
            self.channelUUID = nil
            isTransmitting = false
            activeSpeaker = nil
            await room.disconnect()
        }
    }

    nonisolated func channelManager(_: PTChannelManager, failedToJoinChannel channelUUID: UUID, error: any Error) {
        Self.logger.error("Failed to join channel \(channelUUID): \(error)")
    }

    nonisolated func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didBeginTransmittingFrom source: PTChannelTransmitRequestSource) {
        Self.logger.info("Did begin transmitting, source: \(source.rawValue)")

        Task { @MainActor in
            isTransmitting = true
            do {
                // The engine only starts capturing once the system activates the audio session.
                try await room.localParticipant.setMicrophone(enabled: true)
            } catch {
                Self.logger.error("Failed to enable microphone: \(error)")
                channelManager.stopTransmitting(channelUUID: channelUUID)
            }
        }
    }

    nonisolated func channelManager(_: PTChannelManager, channelUUID _: UUID, didEndTransmittingFrom source: PTChannelTransmitRequestSource) {
        Self.logger.info("Did end transmitting, source: \(source.rawValue)")

        Task { @MainActor in
            isTransmitting = false
            do {
                try await room.localParticipant.setMicrophone(enabled: false)
            } catch {
                Self.logger.error("Failed to disable microphone: \(error)")
            }
        }
    }

    nonisolated func channelManager(_: PTChannelManager, failedToBeginTransmittingInChannel channelUUID: UUID, error: any Error) {
        Self.logger.error("Failed to begin transmitting in channel \(channelUUID): \(error)")
    }

    nonisolated func channelManager(_: PTChannelManager, receivedEphemeralPushToken pushToken: Data) {
        let token = pushToken.map { String(format: "%02x", $0) }.joined()
        Self.logger.info("Push token: \(token)")

        Task { @MainActor in
            self.pushToken = token
        }
    }

    nonisolated func incomingPushResult(channelManager _: PTChannelManager, channelUUID _: UUID, pushPayload: [String: Any]) -> PTPushResult {
        guard let activeSpeaker = pushPayload["activeSpeaker"] as? String else {
            return .leaveChannel
        }
        return .activeRemoteParticipant(PTParticipant(name: activeSpeaker, image: nil))
    }

    nonisolated func channelManager(_: PTChannelManager, didActivate _: AVAudioSession) {
        Self.logger.debug("Did activate audio session")

        do {
            try AudioManager.shared.setEngineAvailability(.default)
        } catch {
            Self.logger.critical("Failed to set engine availability: \(error)")
        }
    }

    nonisolated func channelManager(_: PTChannelManager, didDeactivate _: AVAudioSession) {
        Self.logger.debug("Did deactivate audio session")

        do {
            try AudioManager.shared.setEngineAvailability(.none)
        } catch {
            Self.logger.critical("Failed to set engine availability: \(error)")
        }
    }
}

// MARK: - PTChannelRestorationDelegate

extension PushToTalkManager: PTChannelRestorationDelegate {
    nonisolated func channelDescriptor(restoredChannelUUID _: UUID) -> PTChannelDescriptor {
        // Called synchronously off the main actor, so read the stored name instead of `channelName`.
        let name = UserDefaults.standard.string(forKey: Self.channelNameKey) ?? Self.defaultChannelName
        return PTChannelDescriptor(name: name, image: nil)
    }
}

// MARK: - RoomDelegate

extension PushToTalkManager: RoomDelegate {
    nonisolated func room(_: Room, didUpdateConnectionState connectionState: ConnectionState, from _: ConnectionState) {
        Task { @MainActor in
            await updateServiceStatus(for: connectionState)
        }
    }

    nonisolated func room(_: Room, participant _: RemoteParticipant, didPublishTrack _: RemoteTrackPublication) {
        Task { @MainActor in await updateActiveSpeaker() }
    }

    nonisolated func room(_: Room, participant _: RemoteParticipant, didUnpublishTrack _: RemoteTrackPublication) {
        Task { @MainActor in await updateActiveSpeaker() }
    }

    nonisolated func room(_: Room, participant _: Participant, trackPublication _: TrackPublication, didUpdateIsMuted _: Bool) {
        Task { @MainActor in await updateActiveSpeaker() }
    }

    nonisolated func room(_: Room, participantDidDisconnect _: RemoteParticipant) {
        Task { @MainActor in await updateActiveSpeaker() }
    }
}
