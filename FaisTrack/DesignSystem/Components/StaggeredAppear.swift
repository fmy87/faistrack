import SwiftUI

/// Fades and slides content in with a short per-item delay based on its
/// index in a list — used on Drives and Garage so those lists feel more
/// alive on first appearance instead of the whole thing popping in at once.
struct StaggeredAppear<Content: View>: View {
    let index: Int
    @ViewBuilder let content: () -> Content
    @State private var appeared = false

    var body: some View {
        content()
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.04)) {
                    appeared = true
                }
            }
    }
}
