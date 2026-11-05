# PushToTalk example

This example demonstrates how to use the LiveKit Swift SDK with Apple's [PushToTalk](https://developer.apple.com/documentation/pushtotalk) framework.

Joining a channel connects to a LiveKit room. Holding the in-app talk button, or using the talk button in the system UI, publishes the microphone while transmitting and mutes it afterwards. Other participants see the talker's unmuted microphone and report them to the system with `setActiveRemoteParticipant(_:channelUUID:)`.

### Requirements

* A physical iPhone running iOS 16 or later. PushToTalk does not work in the Simulator.
* The `com.apple.developer.push-to-talk` entitlement, enabled for your App ID in the Apple Developer portal.
* The `audio`, `push-to-talk` and `voip` background modes (already set in `Info.plist`).

Enter a LiveKit server URL and a token in the app, then join a channel. Run the app on two devices with tokens for the same room to talk between them.

### Key points when integrating LiveKit SDK with PushToTalk

Like CallKit, the PushToTalk framework activates and deactivates the `AVAudioSession` on behalf of your app. See the [CallKit example](../callkit) for the same model.

Early in the process, disable automatic `AVAudioSession` configuration and keep the SDK's internal `AVAudioEngine` from starting:
```swift
AudioManager.shared.audioSession.isAutomaticConfigurationEnabled = false
try AudioManager.shared.setEngineAvailability(.none)
```

The system activates the session with the category that is already set, so set `.playAndRecord` before the first transmission:
```swift
try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
```

Then allow the engine to run only between `channelManager(_:didActivate:)` and `channelManager(_:didDeactivate:)`:
```swift
func channelManager(_: PTChannelManager, didActivate _: AVAudioSession) {
    try? AudioManager.shared.setEngineAvailability(.default)
}

func channelManager(_: PTChannelManager, didDeactivate _: AVAudioSession) {
    try? AudioManager.shared.setEngineAvailability(.none)
}
```
> **NOTE:** Don't call `session.setActive(true)` yourself. The system activates the session when transmission begins and when you set an active remote participant.

The system also activates the session just to play a remote speaker. The default microphone mute mode keeps mic input running while muted, so this example uses the `.restart` mute mode, which runs the engine without mic input while the microphone is muted:
```swift
try AudioManager.shared.set(microphoneMuteMode: .restart)
```

Transmission maps to the microphone:
* `channelManager(_:channelUUID:didBeginTransmittingFrom:)` calls `setMicrophone(enabled: true)`. The engine starts capturing once the system activates the session.
* `channelManager(_:channelUUID:didEndTransmittingFrom:)` calls `setMicrophone(enabled: false)`.

### What a real app needs server side

This example only logs the ephemeral PushToTalk push token and shows it in the app. It does not send pushes. To receive audio while the app is in the background or not running, a real app also needs:

* **Token registration.** Send the token from `channelManager(_:receivedEphemeralPushToken:)` to your server along with the channel and user. The token is only valid while the app is in the channel, so register it each time this method is called.
* **Floor control.** Decide who may talk in a channel. When someone starts talking, send a PushToTalk push to the other members, for example with an `activeSpeaker` key. This example's `incomingPushResult(channelManager:channelUUID:pushPayload:)` returns `.activeRemoteParticipant` for that key and `.leaveChannel` otherwise.
* **APNs delivery.** Send the push with the `pushtotalk` push type, the `<bundle ID>.voip-ptt` topic and priority 10.
* **Room tokens.** Issue LiveKit tokens for the channel's room. A channel can be restored after the app relaunches, so the app may need to fetch a fresh token instead of reusing a stored one.

### References

[PushToTalk](https://developer.apple.com/documentation/pushtotalk)
[Creating a push-to-talk app](https://developer.apple.com/documentation/pushtotalk/creating-a-push-to-talk-app)
