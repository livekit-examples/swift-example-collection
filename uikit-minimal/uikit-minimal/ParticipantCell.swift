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
        r.layoutMode = .fit
        r.backgroundColor = .black
        r.clipsToBounds = true
        r.debugMode = true
        return r
    }()

    public let labelView: UILabel = {
        let r = UILabel()
        r.textColor = .white
        return r
    }()

    // weak reference to the Participant
    public weak var participant: Participant? {
        didSet {
            guard oldValue != participant else { return }

            if let oldValue = oldValue {
                // un-listen previous participant's events
                // in case this cell gets reused.
                oldValue.remove(delegate: self)
                videoView.track = nil
                labelView.text = ""
            }

            if let participant = participant {
                // listen to events
                participant.add(delegate: self)
                setFirstVideoTrack()
                labelView.text = participant.identity

                // make sure the cell will call layoutSubviews()
                setNeedsLayout()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        print("\(String(describing: self)) init")
        backgroundColor = .blue
        contentView.addSubview(videoView)
        contentView.addSubview(labelView)

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        print("\(String(describing: self)) deinit")
    }

    @objc func onTap() {
        print("toggle isEnabled")
        videoView.isEnabled = !videoView.isEnabled
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        print("prepareForReuse")

        participant = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoView.frame = contentView.bounds
        videoView.setNeedsLayout()

        labelView.sizeToFit()
        labelView.frame = CGRect(x: (contentView.bounds.width - labelView.bounds.width) / 2,
                                 y: contentView.bounds.height - labelView.bounds.height,
                                 width: labelView.bounds.width,
                                 height: labelView.bounds.height)
    }

    private func setFirstVideoTrack() {
        let track = participant?.videoTracks.first?.track as? VideoTrack
        self.videoView.track = track
    }
}

extension ParticipantCell: ParticipantDelegate {

    func participant(_ participant: RemoteParticipant, didSubscribe publication: RemoteTrackPublication, track: Track) {
        print("didSubscribe")
        DispatchQueue.main.async { [weak self] in
            self?.setFirstVideoTrack()
        }
    }

    func participant(_ participant: RemoteParticipant, didUnsubscribe publication: RemoteTrackPublication, track: Track) {
        print("didUnsubscribe")
        DispatchQueue.main.async { [weak self] in
            self?.setFirstVideoTrack()
        }
    }
}
