/*
 * Copyright 2022 LiveKit
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

import UIKit
import LiveKit

class ParticipantCell: UICollectionViewCell {

    public static let reuseIdentifier: String = "ParticipantCell"

    public let videoView: VideoView = {
        let r = VideoView()
        r.layoutMode = .fill
        r.backgroundColor = .black
        r.clipsToBounds = true
        return r
    }()

    public let labelView: UILabel = {
        let r = UILabel()
        r.textColor = .white
        return r
    }()

    // weak reference to the Participant
    public private(set) weak var participant: Participant?

    override init(frame: CGRect) {
        super.init(frame: frame)
        print("\(String(describing: self)) init")

        backgroundColor = .brown

        contentView.addSubview(videoView)
        contentView.addSubview(labelView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        print("\(String(describing: self)) deinit")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        print("prepareForReuse")

        if let previousParticipant = participant {
            // un-listen previous participant's events
            // in case this cell gets reused.
            previousParticipant.remove(delegate: self)
        }

        labelView.text = ""
        videoView.isHidden = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoView.frame = contentView.bounds
        videoView.setNeedsLayout()
        print("videoView setNeedsLayout")

        labelView.sizeToFit()
        labelView.frame = CGRect(x: (contentView.bounds.width - labelView.bounds.width) / 2,
                                 y: contentView.bounds.height - labelView.bounds.height,
                                 width: labelView.bounds.width,
                                 height: labelView.bounds.height)
    }

    public func set(participant: Participant) {

        // keep reference to current participant
        self.participant = participant

        // listen for events
        participant.add(delegate: self)

        labelView.text = participant.identity

        setFirstVideoTrack()

        // make sure the cell will call layoutSubviews()
        videoView.isHidden = false
        setNeedsLayout()
    }

    private func setFirstVideoTrack() {
        if let track = participant?.videoTracks.first?.track as? VideoTrack {
            print("set track")
            DispatchQueue.main.async {
                self.videoView.track = track
            }
        }
    }
}

extension ParticipantCell: ParticipantDelegate {

    func participant(_ participant: RemoteParticipant, didSubscribe publication: RemoteTrackPublication, track: Track) {
        print("didSubscribe")
        setFirstVideoTrack()
    }

    func participant(_ participant: RemoteParticipant, didUnsubscribe publication: RemoteTrackPublication, track: Track) {
        print("didUnsubscribe")
        setFirstVideoTrack()
    }
}
