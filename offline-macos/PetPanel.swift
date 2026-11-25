import AppKit
import CoreGraphics

final class PetPanel: NSPanel {
    private let baseSize = NSSize(width: 344, height: 310)
    private let placementKey = "desktopPetPlacement"
    private var grabOffset: NSPoint?
    private(set) var scalePercent = 100
    var isDraggingPet: Bool { grabOffset != nil }

    init() {
        super.init(contentRect: NSRect(origin: .zero, size: baseSize),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    }

    override var canBecomeKey: Bool { false }

    private func displayID(_ screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }

    private var scaledSize: NSSize {
        let factor = CGFloat(scalePercent) / 100
        return NSSize(width: round(baseSize.width * factor), height: round(baseSize.height * factor))
    }

    private func fit(_ proposed: NSRect, on screen: NSScreen) {
        let bounds = screen.visibleFrame
        let x = max(bounds.minX, min(proposed.minX, bounds.maxX - proposed.width))
        let y = max(bounds.minY, min(proposed.minY, bounds.maxY - proposed.height))
        setFrame(NSRect(x: x, y: y, width: proposed.width, height: proposed.height), display: true)
    }

    func restorePlacement() {
        guard !isDraggingPet, let primary = NSScreen.main else { return }
        let saved = UserDefaults.standard.dictionary(forKey: placementKey)
        scalePercent = min(150, max(20, saved?["percent"] as? Int ?? 100))
        let target = NSScreen.screens.first { displayID($0) == (saved?["display"] as? String ?? "") } ?? primary
        let bounds = target.visibleFrame
        let size = scaledSize
        let freeWidth = max(0, bounds.width - size.width)
        let freeHeight = max(0, bounds.height - size.height)
        var origin = NSPoint(x: bounds.maxX - size.width - 12, y: bounds.minY + 12)
        if let x = saved?["x"] as? Double, let y = saved?["y"] as? Double, x.isFinite, y.isFinite {
            origin = NSPoint(x: bounds.minX + x * freeWidth, y: bounds.minY + y * freeHeight)
        }
        fit(NSRect(origin: origin, size: size), on: target)
    }

    private func savePlacement(on screen: NSScreen) {
        let bounds = screen.visibleFrame
        let saved: [String: Any] = [
            "percent": scalePercent, "display": displayID(screen) ?? "",
            "x": (frame.minX - bounds.minX) / max(1, bounds.width - frame.width),
            "y": (frame.minY - bounds.minY) / max(1, bounds.height - frame.height)
        ]
        UserDefaults.standard.set(saved, forKey: placementKey)
    }

    func resize(to percent: Int) {
        guard let target = screen ?? NSScreen.main else { return }
        scalePercent = min(150, max(20, percent))
        let size = scaledSize
        // Keep the lower-right corner still, like the upstream desktop app.
        let origin = NSPoint(x: frame.maxX - size.width, y: frame.minY)
        fit(NSRect(origin: origin, size: size), on: target)
        savePlacement(on: target)
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown where !ignoresMouseEvents:
            grabOffset = event.locationInWindow
        case .leftMouseDragged where isDraggingPet:
            if let grabOffset {
                let point = convertPoint(toScreen: event.locationInWindow)
                setFrameOrigin(NSPoint(x: point.x - grabOffset.x, y: point.y - grabOffset.y))
            }
        case .leftMouseUp where isDraggingPet:
            grabOffset = nil
            if let target = screen ?? NSScreen.main {
                fit(frame, on: target)
                savePlacement(on: target)
            }
        default:
            super.sendEvent(event)
        }
    }
}
