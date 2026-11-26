import ArgumentParser
import Foundation
import KeylockCore

struct Command: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "keylock",
        abstract: "Lock the keyboard (and optionally the trackpad) so you can clean it."
    )

    @Flag(name: .shortAndLong, help: "Enable debug mode.")
    var debug = false

    @Option(name: .shortAndLong, help: "Exit after a specified number of seconds.")
    var timer: Int?

    @Flag(name: .shortAndLong, help: "Lock only the keyboard; leave the trackpad/mouse usable.")
    var keyboardOnly = false

    @Flag(help: "Leave media/system keys (brightness, volume, play) unlocked.")
    var allowSystemKeys = false

    func run() throws {
        let locker = InputLocker()
        if debug { locker.log = { print($0) } }
        locker.onUnlockChord = {
            print("Input devices unlocked")
            CFRunLoopStop(CFRunLoopGetCurrent())
        }

        guard InputLocker.hasAccessibilityPermission(prompt: true) else {
            FileHandle.standardError.write(Data("""
            Accessibility permission is required.
            Grant it in System Settings → Privacy & Security → Accessibility, then try again.\n
            """.utf8))
            throw ExitCode.failure
        }

        try locker.lock(options: LockOptions(
            blockPointer: !keyboardOnly,
            blockSystemKeys: !allowSystemKeys
        ))

        if let timer {
            let t = Timer(timeInterval: TimeInterval(timer), repeats: false) { _ in
                FileHandle.standardError.write(Data("Timer expired ⏱️\n".utf8))
                CFRunLoopStop(CFRunLoopGetCurrent())
            }
            RunLoop.current.add(t, forMode: .common)
        }

        print("""

        ╭────────────────────────────────────────╮
        │                                        │
        │          Input Devices Locked          │
        │                                        │
        │        Press Ctrl + U to Unlock        │
        │                                        │
        ╰────────────────────────────────────────╯

        """)
        CFRunLoopRun()
        locker.unlock()
    }
}
