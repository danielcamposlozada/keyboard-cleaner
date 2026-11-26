import Foundation

enum Settings {
    private static let defaults = UserDefaults.standard

    /// Auto-unlock choices, in seconds. There is deliberately no "never":
    /// the timer is the safety net if the unlock chord ever fails.
    static let autoUnlockChoices: [Int] = [30, 60, 120, 300, 600]

    static var autoUnlockSeconds: Int {
        get {
            let v = defaults.integer(forKey: "autoUnlockSeconds")
            return autoUnlockChoices.contains(v) ? v : 120
        }
        set { defaults.set(newValue, forKey: "autoUnlockSeconds") }
    }

    static var blockSystemKeys: Bool {
        get { defaults.object(forKey: "blockSystemKeys") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "blockSystemKeys") }
    }

    static var playSounds: Bool {
        get { defaults.object(forKey: "playSounds") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "playSounds") }
    }

    static func label(forSeconds s: Int) -> String {
        s < 60 ? "\(s) segundos" : (s == 60 ? "1 minuto" : "\(s / 60) minutos")
    }
}
