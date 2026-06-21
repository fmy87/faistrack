import SwiftUI

struct FTStatBadge: View {
    let value: String
    let label: String
    var color: Color = .ftAccent

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.ftTextSecondary)
        }
    }
}
