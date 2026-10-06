//
//  TiltMotion.swift
//  Gameboxd
//
//  How far the phone is tilted, for effects that react to it (holographic stickers).
//  Motion updates run only while at least one view uses them.
//

import CoreMotion
import Observation

@Observable
final class TiltMotion {
    static let shared = TiltMotion()

    /// -1…1: left/right and towards/away from you, 0 when held normally.
    private(set) var x: Double = 0
    private(set) var y: Double = 0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var users = 0

    func start() {
        users += 1
        guard users == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let gravity = motion?.gravity else { return }
            // Held upright-ish, gravity.y sits around -0.7: centre on that.
            self.x = max(-1, min(1, gravity.x * 2))
            self.y = max(-1, min(1, (gravity.y + 0.7) * 2))
        }
    }

    func stop() {
        users = max(0, users - 1)
        if users == 0 { manager.stopDeviceMotionUpdates() }
    }
}
