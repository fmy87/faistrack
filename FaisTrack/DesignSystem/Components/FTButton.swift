import SwiftUI

struct FTPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView().tint(.black)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(colors: [.ftAccent, .ftAccentOrange],
                               startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
        }
        .disabled(isLoading)
    }
}

struct FTSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.ftTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.ftTextSecondary, lineWidth: 1))
        }
    }
}
