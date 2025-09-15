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

import LiveKit
import SwiftUI

struct ContentView: View {
    @StateObject var room = Room()
    @StateObject private var callManager = CallManager()

    @AppStorage("url") var url: String = ""
    @AppStorage("token") var token: String = ""

    @State var isMicEnabled: Bool = false

    var buttonTitle: String {
        if room.connectionState == .connecting {
            return "Connecting..."
        } else if room.connectionState == .connected {
            return "Disconnect"
        }

        return "Connect"
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("CallKit Example")
                .font(.title)
                .fontWeight(.bold)

            Form {
                Section("1. Connect to Room") {
                    TextField("URL", text: $url)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                        .disabled(room.connectionState != .disconnected)

                    SecureField("Token", text: $token)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .keyboardType(.asciiCapable)
                        .disabled(room.connectionState != .disconnected)

                    Button(buttonTitle) {
                        Task {
                            if room.connectionState == .disconnected {
                                do {
                                    try AudioManager.shared.setEngineAvailability(.none)
                                    // Connect to Room
                                    try await room.connect(url: url, token: token)
                                } catch {
                                    print("Connect room error: \(error.localizedDescription)")
                                }
                            } else if room.connectionState == .connected {
                                await room.disconnect()
                            }
                        }
                    }
                    .disabled(room.connectionState == .connecting)
                }

                Section("2. Publish audio") {
                    Toggle("Mic enabled", isOn: $isMicEnabled)
                }
                .disabled(room.connectionState != .connected)

                Section("3. Call") {
                    if callManager.hasActiveCall {
                        Button("End call") {
                            callManager.endCall()
                        }
                    } else {
                        Button("Start call") {
                            callManager.startCall(handle: "user1")
                        }
                        Button("Simulate incoming call") {
                            callManager.reportIncomingCall(from: "user2")
                        }
                    }
                }
                .disabled(room.connectionState != .connected)
            }
        }
        .padding()
        .onChange(of: room.connectionState) { _, newValue in
            if newValue == .disconnected {
                // Reset state on disconnect
                isMicEnabled = false
            }
        }
        .onChange(of: isMicEnabled) { oldValue, newValue in
            if room.connectionState == .connected {
                Task {
                    do {
                        if newValue {
                            try await room.localParticipant.setMicrophone(enabled: newValue)
                        } else {
                            await room.localParticipant.unpublishAll()
                        }
                    } catch {
                        print("Mic publish error: \(error.localizedDescription)")
                        // Revert to old value if failed
                        isMicEnabled = oldValue
                    }
                }
            }
        }
    }
}
