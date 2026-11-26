import ApplicationServices
import CoreGraphics
import Foundation

/// What to block while locked.
public struct LockOptions: Equatable {
    /// Also block trackpad / mouse clicks, movement and scrolling.
    public var blockPointer: Bool
    /// Also block media and system keys (brightness, volume, play/pause, etc.).
    public var blockSystemKeys: Bool

    public init(blockPointer: Bool = false, blockSystemKeys: Bool = true) {
        self.blockPointer = blockPointer
        self.blockSystemKeys = blockSystemKeys
    }
}

public enum InputLockerError: Error, LocalizedError {
    case accessibilityPermissionMissing
    case eventTapFailed

    public var errorDescription: String? {
        switch self {
        case .accessibilityPermissionMissing:
            return "Accessibility permission is required to block input."
        case .eventTapFailed:
            return "Could not create the event tap."
        }
    }
}

/// Swallows keyboard (and optionally pointer) events at the HID level until
/// the unlock chord (Control + U) is pressed or `unlock()` is called.
///
/// Must be used from a thread with a running run loop (the main thread in an app).
public final class InputLocker {
    /// Virtual key code for "U" (ANSI).
    public static let unlockKeyCode: CGKeyCode = 0x20

    /// `NX_SYSDEFINED`: media keys, brightness, volume, etc.
    private static let systemDefinedType = CGEventType(rawValue: 14)!

    public private(set) var isLocked = false
    public private(set) var options = LockOptions()

    /// Called on the locker's run loop when the user presses Control + U.
    public var onUnlockChord: (() -> Void)?
    /// Optional debug log.
    public var log: ((String) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var controlDown = false

    public init() {}

    deinit { unlock() }

    // MARK: Permission

    public static func hasAccessibilityPermission(prompt: Bool = false) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    // MARK: Lock / unlock

    public func lock(options: LockOptions) throws {
        if isLocked { unlock() }
        guard Self.hasAccessibilityPermission() else {
            throw InputLockerError.accessibilityPermissionMissing
        }
        self.options = options
        controlDown = false

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.mask(for: options),
            callback: inputLockerCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw InputLockerError.eventTapFailed
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.source = source
        isLocked = true
        log?("Locked (pointer: \(options.blockPointer), system keys: \(options.blockSystemKeys))")
    }

    public func unlock() {
        guard isLocked else { return }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        tap = nil
        source = nil
        isLocked = false
        log?("Unlocked")
    }

    // MARK: Event handling

    private static func mask(for options: LockOptions) -> CGEventMask {
        var types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
        if options.blockSystemKeys {
            types.append(systemDefinedType)
        }
        if options.blockPointer {
            types += [
                .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
                .otherMouseDown, .otherMouseUp, .mouseMoved, .scrollWheel,
                .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            ]
        }
        return types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS disables slow taps; turn it back on so the lock holds.
            if let tap, isLocked { CGEvent.tapEnable(tap: tap, enable: true) }
            log?("Event tap re-enabled")
            return Unmanaged.passUnretained(event)

        case .flagsChanged:
            controlDown = event.flags.contains(.maskControl)
            return nil

        case .keyDown:
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let control = controlDown || event.flags.contains(.maskControl)
            log?("Key down: \(keyCode) control: \(control)")
            if control && keyCode == Self.unlockKeyCode {
                onUnlockChord?()
            }
            return nil

        default:
            return isLocked ? nil : Unmanaged.passUnretained(event)
        }
    }
}

private func inputLockerCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let locker = Unmanaged<InputLocker>.fromOpaque(refcon).takeUnretainedValue()
    return locker.handle(type: type, event: event)
}
