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

// enter your own LiveKit server url and token
let url = "ws://192.168.68.53:7880"
let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2NDg2MTAyOTgsImlzcyI6IkFQSTdSTVB5ZWdUN29lSCIsImp0aSI6InVzZXIxIiwibmJmIjoxNjQ2MDE4Mjk4LCJzdWIiOiJ1c2VyMSIsInZpZGVvIjp7InJvb20iOiJyb29tMSIsInJvb21Kb2luIjp0cnVlfX0.2PYh9r8Oa9p1ESdllY3v2TigebJQdp69T_0dk8tl2mE"

class RoomViewController: UIViewController {

    private var room: Room?
    private var collectionView: UICollectionView?

    override func viewWillLayoutSubviews() {
        print("viewWillLayoutSubviews...")
        super.viewWillLayoutSubviews()
        collectionView?.frame = view.bounds
        collectionView?.collectionViewLayout.invalidateLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateNavigationBar()
    }

    private func setParticipants() {
        DispatchQueue.main.async {
            self.collectionView?.reloadData()
        }
    }

    private func createCollectionView() -> UICollectionView? {
        print("creating UICollectionView...")
        let r = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        r.backgroundColor = .blue
        r.register(ParticipantCell.self, forCellWithReuseIdentifier: ParticipantCell.reuseIdentifier)
        r.delegate = self
        r.dataSource = room
        r.alwaysBounceVertical = true
        r.contentInsetAdjustmentBehavior = .never
        view.addSubview(r)
        return r
    }

    private func updateNavigationBar() {

        if let room = room {
            if case .connecting = room.connectionState {
                self.navigationItem.title = "Connecting..."
            } else if case .connected = room.connectionState {
                self.navigationItem.title = room.name
            }
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Disconnect",
                                                               style: .plain,
                                                               target: self,
                                                               action: #selector(onTapDisconnect(sender:)))
        } else {
            self.navigationItem.title = "Disconnected"
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Connect",
                                                               style: .plain,
                                                               target: self,
                                                               action: #selector(onTapConnect(sender:)))
        }
    }

    @objc func onTapConnect(sender: UIBarButtonItem) {

        navigationItem.leftBarButtonItem?.isEnabled = false

        let roomOptions = RoomOptions(
            adaptiveStream: true,
            dynacast: true
        )

        let room = Room(delegate: self)
        self.room = room

        room.connect(url, token, roomOptions: roomOptions).then { [weak self] room in
            guard let self = self else { return }
            print("connected to server version: \(String(describing: room.serverVersion))")
            DispatchQueue.main.async {
                self.collectionView = self.createCollectionView()
            }
            self.setParticipants()

        }.catch { error in
            print("failed to connect with error: \(error)")
            self.room = nil
            DispatchQueue.main.async {
                self.updateNavigationBar()
            }
        }
    }

    @objc func onTapDisconnect(sender: UIBarButtonItem) {

        guard let room = self.room else {
            return
        }

        navigationItem.leftBarButtonItem?.isEnabled = false

        room.disconnect().then {
            self.room = nil
            DispatchQueue.main.async {
                self.collectionView?.removeFromSuperview()
                self.collectionView = nil
                self.updateNavigationBar()
            }
        }
    }
}

extension RoomViewController: RoomDelegate {

    func room(_ room: Room, didUpdate connectionState: ConnectionState, oldValue: ConnectionState) {

        if !connectionState.isEqual(to: oldValue, includingAssociatedValues: false) {

            DispatchQueue.main.async {
                self.updateNavigationBar()
            }
        }
    }

    func room(_ room: Room, participantDidJoin participant: RemoteParticipant) {
        setParticipants()
    }

    func room(_ room: Room, participantDidLeave participant: RemoteParticipant) {
        setParticipants()
    }
}

extension RoomViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        print("sizeForItemAt...")

        let columns: CGFloat = 2
        let size = collectionView.bounds.width / columns
        return CGSize(width: size, height: size)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        .zero
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        0
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        0
    }

    // Optimizations
    // turn off rendering for off-screen cells
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        print("display: willDisplay")
        guard let participantCell = cell as? ParticipantCell else { return }
        participantCell.videoView.isEnabled = true
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        print("display: didEndDisplaying")
        guard let participantCell = cell as? ParticipantCell else { return }
        participantCell.videoView.isEnabled = false
    }
}

extension Room: UICollectionViewDataSource {

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // total number of participants to show (including local participant)
        print("numberOfItemsInSection...")
        return remoteParticipants.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        print("cellForItemAt...")

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ParticipantCell.reuseIdentifier,
                                                      for: indexPath)

        if let cell = cell as? ParticipantCell {

            if indexPath.row < remoteParticipants.count {
                let participant = Array(remoteParticipants.values)[indexPath.row]
                cell.participant = participant
            }
        }

        return cell
    }
}
