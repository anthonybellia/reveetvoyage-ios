import SwiftUI

struct PassengerListView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(message: "Liste des passagers (Phase 4)")
                .navigationTitle("Passagers")
                .background(Color.revBackground.ignoresSafeArea())
        }
    }
}
