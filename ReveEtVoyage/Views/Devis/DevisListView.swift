import SwiftUI

struct DevisListView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(message: "Liste des devis (Phase 4)")
                .navigationTitle("Devis")
                .background(Color.revBackground.ignoresSafeArea())
        }
    }
}
