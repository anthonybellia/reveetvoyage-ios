import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Accueil")
                }
                .tag(0)

            VoyageListView()
                .tabItem {
                    Image(systemName: "suitcase.fill")
                    Text("Voyages")
                }
                .tag(1)

            DevisListView()
                .tabItem {
                    Image(systemName: "doc.text.fill")
                    Text("Devis")
                }
                .tag(2)

            PassengerListView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Passagers")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Paramètres")
                }
                .tag(4)
        }
        .accentColor(.revOrange)
    }
}
