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
import Logging
import SwiftUI

struct ContentView: View {
    @ObservedObject private var callManager = CallManager.shared
    @StateObject var room: Room = CallManager.shared.room

    @AppStorage("url") var url: String = ""
    @AppStorage("token") var token: String = ""

    @State var showTokenCopiedToast: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            Text("CallKit Example")
                .font(.title)
                .fontWeight(.bold)

            Form {
                Section("States") {
                    Text("Room state: \(String(describing: room.connectionState))")
                    Text("Call state: \(String(describing: callManager.callState))")
                }

                Section("1. Room for testing") {
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
                }

                Section("3. VoIP Push Token") {
                    if let token = callManager.voipToken {
                        Button(action: {
                            UIPasteboard.general.string = token
                            showTokenCopiedToast = true
                        }) {
                            HStack {
                                Text(token)
                                    .font(.caption)
                                    .monospaced()
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "doc.on.clipboard")
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("No VoIP token available")
                            .foregroundColor(.gray)
                    }
                }

                Section("4. Call") {
                    if callManager.hasActiveCall {
                        Button("End call") {
                            Task {
                                await callManager.endCall()
                            }
                        }
                    } else {
                        Button("Start call") {
                            Task {
                                await callManager.startCall(handle: "user1")
                            }
                        }
                        Button("Simulate incoming call") {
                            Task {
                                try await callManager.reportIncomingCallAsync(from: "user2", callerName: "Tommie Sunshine")
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .overlay(
            Group {
                if showTokenCopiedToast {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Token copied to clipboard")
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                        .padding(.bottom, 50)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showTokenCopiedToast)
        )
        .onChange(of: showTokenCopiedToast) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showTokenCopiedToast = false
                }
            }
        }
    }
}
