//
//  ConnectivityManager.swift
//  watch_metronome
//
//  Created by Itsuki & Gemini on 2026/05/20.
//

import WatchConnectivity
import Observation

@available(iOS 16.7, watchOS 10.6, *)
@Observable
final class ConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = ConnectivityManager()
    
    var session: WCSession = .default
    
    // 同期したいデータ
    var remoteBpm: Int?
    var remoteNumerator: Int?
    var remoteDenominator: Int?
    
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
        }
    }
}
