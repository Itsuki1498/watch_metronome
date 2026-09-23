//
//  ConnectivityManager.swift
//  watch_metronome
//
//  Created by Itsuki & Gemini on 2026/05/20.
//

import WatchConnectivity
import Combine

@available(iOS 26.0, watchOS 10.0, *)
final class ConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = ConnectivityManager()
    
    var session: WCSession = .default
    private var isSessionSupported = false
    private var pendingPayloads: [[String: Any]] = []
    
    // 同期したいデータ
    @Published var remoteBpm: Int?
    @Published var remoteNumerator: Int?
    @Published var remoteDenominator: Int?
    @Published var remoteProgram: MetronomeProgram?
    @Published var remoteQueuedChange: QueuedMetronomeChange?
    @Published var remoteTransportCommand: String?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            isSessionSupported = true
            session.delegate = self
            session.activate()
        }
    }
    
    func sendStatus(bpm: Int, numerator: Int, denominator: Int) {
        let data: [String: Any] = [
            "bpm": bpm,
            "numerator": numerator,
            "denominator": denominator
        ]
        send(data)
    }

    func sendProgram(_ program: MetronomeProgram) {
        guard let payload = try? JSONEncoder().encode(program) else { return }
        send(["program": payload])
    }

    func sendQueuedChange(_ change: QueuedMetronomeChange?) {
        if let change, let payload = try? JSONEncoder().encode(change) {
            send(["queuedChange": payload])
        } else {
            send(["clearQueuedChange": true])
        }
    }

    func sendTransportCommand(_ command: String) {
        send(["transport": command])
    }

    private func send(_ userInfo: [String: Any]) {
        guard isSessionSupported else { return }
        guard session.activationState == .activated else {
            pendingPayloads.append(userInfo)
            return
        }
        guard session.isReachable else {
            session.transferUserInfo(userInfo)
            return
        }
        session.sendMessage(userInfo, replyHandler: nil) { [weak self] _ in
            self?.session.transferUserInfo(userInfo)
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated, error == nil else { return }
        DispatchQueue.main.async {
            let pending = self.pendingPayloads
            self.pendingPayloads.removeAll()
            pending.forEach(self.send)
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        receive(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        receive(userInfo)
    }

    private func receive(_ userInfo: [String: Any]) {
        DispatchQueue.main.async {
            if let bpm = userInfo["bpm"] as? Int { self.remoteBpm = bpm }
            if let num = userInfo["numerator"] as? Int { self.remoteNumerator = num }
            if let den = userInfo["denominator"] as? Int { self.remoteDenominator = den }
            if let data = userInfo["program"] as? Data,
               let program = try? JSONDecoder().decode(MetronomeProgram.self, from: data) {
                self.remoteProgram = program
            }
            if let data = userInfo["queuedChange"] as? Data,
               let change = try? JSONDecoder().decode(QueuedMetronomeChange.self, from: data) {
                self.remoteQueuedChange = change
            }
            if userInfo["clearQueuedChange"] as? Bool == true {
                self.remoteQueuedChange = nil
            }
            if let command = userInfo["transport"] as? String {
                self.remoteTransportCommand = command
            }
        }
    }
}
