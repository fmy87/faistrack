import SwiftUI

struct UserSearchView: View {
    @State private var query = ""
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                VStack {
                    TextField(NSLocalizedString("friends.search.placeholder", comment: ""), text: $query)
                        .padding(14).background(Color.ftCard).cornerRadius(12).padding()
                    Spacer()
                }
            }
            .navigationTitle(NSLocalizedString("friends.search.title", comment: ""))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("general.cancel", comment: "")) { dismiss() }
                }
            }
        }
    }
}
