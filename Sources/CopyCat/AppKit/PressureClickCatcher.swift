// PressureClickCatcher.swift
// CopyCat
//
// SwiftUI wrapper over an NSView that detects both a plain click and a
// Force Touch ("deep press", pressure stage ≥ 2) on macOS trackpads that
// support pressure sensing. On devices without pressure support, only the
// plain click fires — callers should provide a fallback (context menu,
// keyboard shortcut) to reach the deep-press action.

import AppKit
import SwiftUI

/// A SwiftUI view that detects a regular click and a Force Touch deep press.
///
/// Use this as an overlay on a row or card to get both tap-to-activate and
/// force-click-to-preview behavior without stacking multiple gesture
/// recognizers or relying on long-press.
struct PressureClickCatcher: NSViewRepresentable {
    /// Invoked on a regular mouse up when the click did not escalate to a deep press.
    var onClick: () -> Void

    /// Invoked when the pressure reaches the Force Touch threshold (stage ≥ 2).
    var onDeepPress: () -> Void

    func makeNSView(context: Context) -> PressureView {
        PressureView(onClick: onClick, onDeepPress: onDeepPress)
    }

    func updateNSView(_ nsView: PressureView, context: Context) {
        nsView.onClick = onClick
        nsView.onDeepPress = onDeepPress
    }

    /// Backing NSView that listens for mouse and pressure events.
    final class PressureView: NSView {
        var onClick: () -> Void
        var onDeepPress: () -> Void

        /// `true` once the current click has escalated to a deep press,
        /// so we don't also fire `onClick` on release.
        private var didDeepPress = false

        /// Origin of the current mouseDown, so we can distinguish a click
        /// from a drag on mouseUp.
        private var mouseDownLocation: NSPoint = .zero

        init(onClick: @escaping () -> Void, onDeepPress: @escaping () -> Void) {
            self.onClick = onClick
            self.onDeepPress = onDeepPress
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var acceptsFirstResponder: Bool { true }

        // Allow receiving clicks even when our hosting window is not key
        // (important since the popover window may not always be key first).
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            didDeepPress = false
            mouseDownLocation = convert(event.locationInWindow, from: nil)
        }

        override func mouseUp(with event: NSEvent) {
            guard !didDeepPress else { return }
            let current = convert(event.locationInWindow, from: nil)
            let movement = hypot(current.x - mouseDownLocation.x,
                                 current.y - mouseDownLocation.y)
            // Only treat as a click if the pointer didn't drift (≈ click slop).
            if movement < 5, bounds.contains(current) {
                onClick()
            }
        }

        override func pressureChange(with event: NSEvent) {
            guard !didDeepPress else { return }
            // stage 0: not pressing, 1: normal click, 2: force-click/deep press.
            if event.stage >= 2 {
                didDeepPress = true
                onDeepPress()
            }
        }
    }
}
