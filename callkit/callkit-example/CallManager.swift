/*
 * Copyright 2025 LiveKit
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
import CallKit
import Combine
import Foundation
import LiveKit

class CallManager: NSObject, ObservableObject {
    private let callController = CXCallController()
    private let provider: CXProvider

    @Published var hasActiveCall = false
    @Published var isCallConnected = false

    private var activeCall: UUID?

    override init() {
        //
        let configuration = CXProviderConfiguration()
        configuration.supportedHandleTypes = [.generic]
        configuration.maximumCallsPerCallGroup = 1
        configuration.maximumCallGroups = 1
        configuration.supportsVideo = true

        provider = CXProvider(configuration: configuration)

        super.init()

        provider.setDelegate(self, queue: nil)
    }

    func startCall(handle: String) {
        let callUUID = UUID()
        activeCall = callUUID

        let handle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: callUUID, handle: handle)
        let transaction = CXTransaction(action: startCallAction)

        Task {
            do {
                try await callController.request(transaction)
                print("Started call")
            } catch {
                print("Failed to start call: \(error)")
            }
        }
    }

    func endCall() {
        guard let callUUID = activeCall else { return }

        let endCallAction = CXEndCallAction(call: callUUID)
        let transaction = CXTransaction(action: endCallAction)

        Task {
            do {
                try await callController.request(transaction)
                print("Ended call")
            } catch {
                print("Failed to end call: \(error)")
            }
        }
    }

    func reportIncomingCall(from caller: String) {
        let callUUID = UUID()
        activeCall = callUUID

        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = CXHandle(type: .generic, value: caller)
        callUpdate.hasVideo = false

        Task {
            do {
                try await provider.reportNewIncomingCall(with: callUUID, update: callUpdate)
                print("Reported incoming call")
            } catch {
                print("Failed to report incoming call: \(error)")
            }
        }
    }
}

extension CallManager: CXProviderDelegate {
    func providerDidReset(_: CXProvider) {
        DispatchQueue.main.async {
            self.hasActiveCall = false
            self.isCallConnected = false
        }
        activeCall = nil
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        DispatchQueue.main.async {
            self.hasActiveCall = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isCallConnected = true
            provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
        }

        action.fulfill()
    }

    func provider(_: CXProvider, perform action: CXAnswerCallAction) {
        DispatchQueue.main.async {
            self.hasActiveCall = true
            self.isCallConnected = true
        }

        action.fulfill()
    }

    func provider(_: CXProvider, perform action: CXEndCallAction) {
        DispatchQueue.main.async {
            self.hasActiveCall = false
            self.isCallConnected = false
        }

        activeCall = nil
        action.fulfill()
    }

    func provider(_: CXProvider, perform action: CXSetMutedCallAction) {
        // TODO: Handle mute
        action.fulfill()
    }

    func provider(_: CXProvider, didActivate session: AVAudioSession) {
        // Audio session can now be activated.
        print("didActivate: \(session)")

        do {
            try AudioManager.shared.setEngineAvailability(.default)
        } catch {
            print("Failed to set engine permissions: \(error.localizedDescription)")
        }
    }

    func provider(_: CXProvider, didDeactivate session: AVAudioSession) {
        // Audio session will need to be deactivated.
        print("didDeactivate: \(session)")

        do {
            try AudioManager.shared.setEngineAvailability(.none)
        } catch {
            print("Failed to set engine permissions: \(error.localizedDescription)")
        }
    }
}
