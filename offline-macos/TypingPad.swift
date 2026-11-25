import AppKit
import Carbon

// This view receives only the events AppKit dispatches to its own key window.
// It has no text storage, text-input client, pasteboard access or event monitor.
final class TypingPad: NSView {
    var keyChanged: ((Int, Bool, Bool) -> Void)?
    var lostFocus: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override func resignFirstResponder() -> Bool {
        lostFocus?()
        return super.resignFirstResponder()
    }

    var canShowKeys: Bool {
        guard let window else { return false }
        return NSApp.isActive && window.isKeyWindow && window.firstResponder === self && !IsSecureEventInputEnabled()
    }

    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }

    private func forward(_ event: NSEvent, down: Bool, repeatKey: Bool = false) {
        guard canShowKeys, event.window === window else { lostFocus?(); return }
        guard let vk = Self.keycaps[event.keyCode] else { return }
        keyChanged?(vk, down, repeatKey)
    }

    override func keyDown(with event: NSEvent) { forward(event, down: true, repeatKey: event.isARepeat) }
    override func keyUp(with event: NSEvent) { forward(event, down: false) }
    override func flagsChanged(with event: NSEvent) {
        // Device-dependent flags distinguish left and right when both are held.
        guard let mask = Self.modifierMasks[event.keyCode] else { return }
        forward(event, down: event.modifierFlags.rawValue & mask != 0)
    }

    private static let modifierMasks: [UInt16: UInt] = [
        0x38: 0x0002, 0x3c: 0x0004, 0x3b: 0x0001, 0x3e: 0x2000,
        0x37: 0x0008, 0x36: 0x0010, 0x3a: 0x0020, 0x3d: 0x0040,
        0x39: NSEvent.ModifierFlags.capsLock.rawValue
    ]

    // Physical macOS key positions mapped to the existing K98 renderer.
    private static let keycaps: [UInt16: Int] = [
        0x00: 0x41, // A
        0x0B: 0x42, // B
        0x08: 0x43, // C
        0x02: 0x44, // D
        0x0E: 0x45, // E
        0x03: 0x46, // F
        0x05: 0x47, // G
        0x04: 0x48, // H
        0x22: 0x49, // I
        0x26: 0x4A, // J
        0x28: 0x4B, // K
        0x25: 0x4C, // L
        0x2E: 0x4D, // M
        0x2D: 0x4E, // N
        0x1F: 0x4F, // O
        0x23: 0x50, // P
        0x0C: 0x51, // Q
        0x0F: 0x52, // R
        0x01: 0x53, // S
        0x11: 0x54, // T
        0x20: 0x55, // U
        0x09: 0x56, // V
        0x0D: 0x57, // W
        0x07: 0x58, // X
        0x10: 0x59, // Y
        0x06: 0x5A, // Z
        0x1D: 0x30, // 0
        0x12: 0x31, // 1
        0x13: 0x32, // 2
        0x14: 0x33, // 3
        0x15: 0x34, // 4
        0x17: 0x35, // 5
        0x16: 0x36, // 6
        0x1A: 0x37, // 7
        0x1C: 0x38, // 8
        0x19: 0x39, // 9
        0x1B: 0xBD, // -
        0x18: 0xBB, // =
        0x21: 0xDB, // [
        0x1E: 0xDD, // ]
        0x2A: 0xDC, // \
        0x29: 0xBA, // ;
        0x27: 0xDE, // '
        0x2B: 0xBC, // ,
        0x2F: 0xBE, // .
        0x2C: 0xBF, // /
        0x32: 0xC0, // `
        0x35: 0x1B, // Esc
        0x30: 0x09, // Tab
        0x31: 0x20, // Space
        0x24: 0x0D, // Return
        0x4C: 0x10D, // Numpad Enter
        0x33: 0x08, // Backspace (Delete)
        0x75: 0x2E, // Forward Delete
        0x39: 0x14, // CapsLock
        0x47: 0x90, // Clear / NumLock
        0x4B: 0x6F, // Numpad /
        0x43: 0x6A, // Numpad *
        0x4E: 0x6D, // Numpad -
        0x45: 0x6B, // Numpad +
        0x41: 0x6E, // Numpad .
        0x52: 0x60, // Numpad 0
        0x53: 0x61, // Numpad 1
        0x54: 0x62, // Numpad 2
        0x55: 0x63, // Numpad 3
        0x56: 0x64, // Numpad 4
        0x57: 0x65, // Numpad 5
        0x58: 0x66, // Numpad 6
        0x59: 0x67, // Numpad 7
        0x5B: 0x68, // Numpad 8
        0x5C: 0x69, // Numpad 9
        0x38: 0xA0, // LShift
        0x3C: 0xA1, // RShift
        0x3B: 0xA2, // LCtrl
        0x3E: 0xA3, // RCtrl
        0x3A: 0xA4, // LOption (Alt)
        0x3D: 0xA5, // ROption (Alt)
        0x37: 0x5B, // LCommand (Win)
        0x36: 0x5C, // RCommand (Win)
        0x7B: 0x25, // Left
        0x7C: 0x27, // Right
        0x7D: 0x28, // Down
        0x7E: 0x26, // Up
        0x73: 0x24, // Home
        0x77: 0x23, // End
        0x74: 0x21, // PgUp
        0x79: 0x22, // PgDn
        0x7A: 0x70, // F1
        0x78: 0x71, // F2
        0x63: 0x72, // F3
        0x76: 0x73, // F4
        0x60: 0x74, // F5
        0x61: 0x75, // F6
        0x62: 0x76, // F7
        0x64: 0x77, // F8
        0x65: 0x78, // F9
        0x6D: 0x79, // F10
        0x67: 0x7A, // F11
        0x6F: 0x7B, // F12
        0x72: 0x2d, // Help / Insert
        0x69: 0x2c, // F13 / Print Screen
        0x6b: 0x91  // F14 / Scroll Lock
    ]
}
