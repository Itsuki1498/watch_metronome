//
//  ConnectivityManager.swift
//  watch_metronome
//
//  Created by Itsuki & Gemini on 2026/05/20.
//

import WatchConnectivity
import Combine

@available(iOS 16.7, watchOS 10.6, *)
final class ConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = ConnectivityManager()
    
    var session: WCSession = .default
    
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
            session.delegate = self
            session.activate()
        }
    }
    
    func sendStatus(bpm: Int, numerator: Int, denominator: Int) {
        guard session.activationState == .activated else { return }
        let data: [String: Any] = [
            "bpm": bpm,
            "numerator": numerator,
            "denominator": denominator
        ]
        session.transferUserInfo(data)
    }

    func sendProgram(_ program: MetronomeProgram) {
        guard session.activationState == .activated else { return }
        guard let payload = try? JSONEncoder().encode(program) else { return }
        session.transferUserInfo(["program": payload])
    }

    func sendQueuedChange(_ change: QueuedMetronomeChange?) {
        guard session.activationState == .activated else { return }
        if let change, let payload = try? JSONEncoder().encode(change) {
            session.transferUserInfo(["queuedChange": payload])
        } else {
            session.transferUserInfo(["clearQueuedChange": true])
        }
    }

    func sendTransportCommand(_ command: String) {
        guard session.activationState == .activated else { return }
        session.transferUserInfo(["transport": command])
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Handle activation
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
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
