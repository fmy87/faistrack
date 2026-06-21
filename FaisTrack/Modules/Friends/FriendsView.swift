import SwiftUI

struct FriendsView: View {
    @State private var showSearch = false
    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "person.2.fill").font(.system(size: 64)).foregroundColor(.ftAccent)
                    Text(NSLocalizedString("friends.empty.title", comment: ""))
                        .font(.system(size: 22, weight: .bold))
                    Text(NSLocalizedString("friends.empty.subtitle", comment: ""))
                        .foregroundColor(.ftTextSecondary).multilineTextAlignment(.center)
                    FTPrimaryButton(title: NSLocalizedString("friends.add", comment: "")) { showSearch = true }
                        .padding(.horizontal, 40)
                }.padding(32)
            }
            .navigationTitle(NSLocalizedString("tab.friends", comment: ""))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSearch = true } label: {
                        Image(systemName: "person.badge.plus").foregroundColor(.ftAccent)
                    }
                }
            }
        }
        .sheet(isPresented: $showSearch) { UserSearchView() }
    }
}
