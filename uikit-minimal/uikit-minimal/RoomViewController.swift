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
let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2NTQwMDc3MjEsImlzcyI6IkFQSTdSTVB5ZWdUN29lSCIsIm5iZiI6MTY1MTQxNTcyMSwic3ViIjoidXNlcjEiLCJ2aWRlbyI6eyJyb29tIjoicm9vbTEiLCJyb29tSm9pbiI6dHJ1ZX19.tlpPu_ejnmAfRsrNhpWnsoQbh_J6wd2ExZpPwkE5ZBw"

class RoomViewController: UIViewController {

    private lazy var room: Room = {
        Room(delegate: self)
    }()

    private lazy var collectionView: UICollectionView = {
        print("creating UICollectionView...")
        let r = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        r.backgroundColor = .black
        r.register(ParticipantCell.self, forCellWithReuseIdentifier: ParticipantCell.reuseIdentifier)
        r.delegate = self
        r.dataSource = self
        r.alwaysBounceVertical = true
        r.contentInsetAdjustmentBehavior = .never
        return r
    }()

    private var remoteParticipants = [RemoteParticipant]()

    override func viewWillLayoutSubviews() {
        print("viewWillLayoutSubviews...")
        super.viewWillLayoutSubviews()
        collectionView.frame = view.bounds
        collectionView.collectionViewLayout.invalidateLayout()
    }

    override func loadView() {
        super.loadView()
        view.addSubview(collectionView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateNavigationBar()
    }

    private func setParticipants() {
        DispatchQueue.main.async {
            self.remoteParticipants = Array(self.room.remoteParticipants.values)
            self.collectionView.reloadData()
            self.updateNavigationBar()
        }
    }

    private func updateNavigationBar() {

        self.navigationItem.title = nil
        self.navigationItem.leftBarButtonItem = nil
        self.navigationItem.rightBarButtonItem = nil

        switch room.connectionState {
        case .disconnected:
            self.navigationItem.title = "Disconnected"
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Connect",
                                                               style: .plain,
                                                               target: self,
                                                               action: #selector(onTapConnect(sender:)))
        case .connecting:
            self.navigationItem.title = "Connecting..."
        case .reconnecting:
            self.navigationItem.title = "Re-Connecting..."
        case .connected:
            self.navigationItem.title = "\(room.name ?? "No name") (\(room.remoteParticipants.count))"
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Disconnect",
                                                               style: .plain,
                                                               target: self,
                                                               action: #selector(onTapDisconnect(sender:)))
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Shuffle",
                                                                style: .plain,
                                                                target: self,
                                                                action: #selector(onTapShuffle(sender:)))

        }
    }

    @objc func onTapConnect(sender: UIBarButtonItem) {

        navigationItem.leftBarButtonItem?.isEnabled = false

        let roomOptions = RoomOptions(
            adaptiveStream: true,
            dynacast: true
        )

        room.connect(url, token, roomOptions: roomOptions).then { [weak self] room in
            guard let self = self else { return }
            print("connected to server version: \(String(describing: room.serverVersion))")
            self.setParticipants()
        }.catch { error in
            print("failed to connect with error: \(error)")
            DispatchQueue.main.async {
                self.updateNavigationBar()
            }
        }
    }

    @objc func onTapDisconnect(sender: UIBarButtonItem) {

        navigationItem.leftBarButtonItem?.isEnabled = false

        room.disconnect().then {
            DispatchQueue.main.async {
                self.updateNavigationBar()
            }
        }
    }

    @objc func onTapShuffle(sender: UIBarButtonItem) {
        DispatchQueue.main.async {
            self.remoteParticipants.shuffle()
            self.collectionView.reloadData()
        }
    }
}

extension RoomViewController: RoomDelegate {

    func room(_ room: Room, didUpdate connectionState: ConnectionState, oldValue: ConnectionState) {
        print("connection state did update")
        DispatchQueue.main.async {
            if case .disconnected = connectionState {
                self.remoteParticipants = []
                self.collectionView.reloadData()
            }

            self.updateNavigationBar()
        }
    }

    func room(_ room: Room, participantDidJoin participant: RemoteParticipant) {
        print("participant did join")
        setParticipants()
    }

    func room(_ room: Room, participantDidLeave participant: RemoteParticipant) {
        print("participant did leave")
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

extension RoomViewController: UICollectionViewDataSource {

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
                let participant = remoteParticipants[indexPath.row]
                cell.participant = participant
            }
        }

        return cell
    }
}
