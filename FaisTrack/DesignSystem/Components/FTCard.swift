import SwiftUI

struct FTCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .background(Color.ftCard)
            .cornerRadius(16)
    }
}
