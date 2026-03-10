import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            FilterRulesTab()
                .tabItem {
                    Label("Filter Rules", systemImage: "line.3.horizontal.decrease.circle")
                }
        }
        .tabViewStyle(.automatic)
        .frame(width: 480, height: 360)
    }
}
