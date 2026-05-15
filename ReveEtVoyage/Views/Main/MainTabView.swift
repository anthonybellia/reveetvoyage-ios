import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    enum Tab: Int, Hashable, CaseIterable {
        case home, voyages, devis, passengers, settings

        var title: String {
            switch self {
            case .home: return "Accueil"
            case .voyages: return "Voyages"
            case .devis: return "Devis"
            case .passengers: return "Passagers"
            case .settings: return "Profil"
            }
        }

        var systemImage: String {
            switch self {
            case .home: return "house.fill"
            case .voyages: return "airplane.circle.fill"
            case .devis: return "doc.text.fill"
            case .passengers: return "person.2.fill"
            case .settings: return "person.crop.circle.fill"
            }
        }
    }

    init() {
        // Style natif iOS de la TabBar — match brand
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)

        let itemAppearance = UITabBarItemAppearance()
        let normalColor = UIColor.secondaryLabel
        let selectedColor = UIColor(red: 0.941, green: 0.616, blue: 0.420, alpha: 1) // revOrange

        itemAppearance.normal.iconColor = normalColor
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        itemAppearance.selected.iconColor = selectedColor
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(onSwitchTab: { selectedTab = $0 })
                .tabItem { Label(Tab.home.title, systemImage: Tab.home.systemImage) }
                .tag(Tab.home)

            VoyageListView()
                .tabItem { Label(Tab.voyages.title, systemImage: Tab.voyages.systemImage) }
                .tag(Tab.voyages)

            DevisListView()
                .tabItem { Label(Tab.devis.title, systemImage: Tab.devis.systemImage) }
                .tag(Tab.devis)

            PassengerListView()
                .tabItem { Label(Tab.passengers.title, systemImage: Tab.passengers.systemImage) }
                .tag(Tab.passengers)

            SettingsView()
                .tabItem { Label(Tab.settings.title, systemImage: Tab.settings.systemImage) }
                .tag(Tab.settings)
        }
        .tint(.revOrange)
    }
}
