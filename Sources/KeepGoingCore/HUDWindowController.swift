import AppKit
import SwiftUI

@MainActor
public final class HUDWindowController {
    private var window: NSWindow?
    private let sessionStore: SessionStore
    private let onTap: (NotificationSession) -> Void
    private var observation: Any?

    public init(sessionStore: SessionStore, onTap: @escaping (NotificationSession) -> Void) {
        self.sessionStore = sessionStore
        self.onTap = onTap
        startObserving()
    }

    private func startObserving() {
        observation = withObservationTracking {
            _ = sessionStore.sessions
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateVisibility()
                self?.startObserving()
            }
        }
    }

    private func updateVisibility() {
        if sessionStore.isEmpty {
            hideWindow()
        } else {
            showWindow()
        }
    }

    private func showWindow() {
        if window == nil {
            let hudView = HUDView(sessions: sessionStore.sessions, onTap: onTap)
            let hostingView = NSHostingView(rootView: hudView)
            hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 50)

            let w = NSWindow(
                contentRect: hostingView.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            w.level = .floating
            w.backgroundColor = .clear
            w.isOpaque = false
            w.hasShadow = false
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            w.contentView = hostingView
            w.ignoresMouseEvents = false

            self.window = w
        }

        // Update content
        let hudView = HUDView(sessions: sessionStore.sessions, onTap: onTap)
        let hostingView = NSHostingView(rootView: hudView)
        window?.contentView = hostingView

        // Size to fit content
        let fittingSize = hostingView.fittingSize
        window?.setContentSize(fittingSize)

        // Position top center
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - fittingSize.width / 2
            let y = screenFrame.maxY - 80
            window?.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window?.orderFront(nil)
    }

    private func hideWindow() {
        window?.orderOut(nil)
        window = nil
    }
}
