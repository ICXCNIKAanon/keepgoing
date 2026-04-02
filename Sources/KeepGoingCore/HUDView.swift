import SwiftUI

public struct HUDView: View {
    let sessions: [NotificationSession]
    let onTap: (NotificationSession) -> Void

    public init(sessions: [NotificationSession], onTap: @escaping (NotificationSession) -> Void) {
        self.sessions = sessions
        self.onTap = onTap
    }

    public var body: some View {
        VStack(spacing: 4) {
            ForEach(sessions) { session in
                HUDRow(session: session)
                    .onTapGesture { onTap(session) }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: sessions.map(\.id))
    }
}

struct HUDRow: View {
    let session: NotificationSession

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
            Text(session.projectName)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            Text("— Claude is waiting")
                .foregroundStyle(.white.opacity(0.7))
        }
        .font(.system(size: 13))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.9))
        .background(Color.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}
