import SwiftUI

struct MoreView: View {
    @ObservedObject var appVM: AppViewModel
    @ObservedObject var dashVM: DashboardViewModel

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    ChatCoachView(appVM: appVM, dashVM: dashVM)
                } label: {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }

                NavigationLink {
                    ProgressDashboardView(appVM: appVM, dashVM: dashVM)
                } label: {
                    Label("Progress", systemImage: "chart.bar.xaxis")
                }

                NavigationLink {
                    SettingsView(appVM: appVM)
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }
            .navigationTitle("More")
        }
    }
}
