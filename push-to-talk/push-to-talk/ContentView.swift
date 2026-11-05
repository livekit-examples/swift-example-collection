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

import LiveKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var manager = PushToTalkManager.shared
    @ObservedObject var room = PushToTalkManager.shared.room

    @AppStorage("url") var url = ""
    @AppStorage("token") var token = ""
    @AppStorage(PushToTalkManager.channelNameKey) var channelName = PushToTalkManager.defaultChannelName

    @State private var isTalkPressed = false

    private var isJoined: Bool {
        manager.channelUUID != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Room") {
                    TextField("URL", text: $url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    SecureField("Token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .disabled(isJoined)

                Section("Channel") {
                    TextField("Channel name", text: $channelName)
                        .disabled(isJoined)

                    LabeledContent("Room state", value: String(describing: room.connectionState))

                    if isJoined {
                        Button("Leave channel", role: .destructive) {
                            manager.leaveChannel()
                        }
                    } else {
                        Button("Join channel") {
                            Task { await manager.joinChannel() }
                        }
                        .disabled(url.isEmpty || token.isEmpty)
                    }
                }

                Section("Talk") {
                    talkButton
                    LabeledContent("Speaking", value: speakingText)
                }

                Section("Push token") {
                    if let pushToken = manager.pushToken {
                        Text(pushToken)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    } else {
                        Text("Join a channel to receive a token")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Push-to-Talk")
        }
    }

    private var speakingText: String {
        if manager.isTransmitting {
            return "You"
        }
        return manager.activeSpeaker?.displayName ?? "No one"
    }

    private var talkButton: some View {
        let isEnabled = isJoined && room.connectionState == .connected && manager.activeSpeaker == nil

        return Text(manager.isTransmitting ? "Talking" : "Hold to talk")
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(manager.isTransmitting ? Color.red : Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? 1 : 0.4)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isTalkPressed else { return }
                        isTalkPressed = true
                        manager.beginTransmitting()
                    }
                    .onEnded { _ in
                        isTalkPressed = false
                        manager.stopTransmitting()
                    }
            )
            .disabled(!isEnabled)
    }
}
