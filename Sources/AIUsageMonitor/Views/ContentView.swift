import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(appState: appState)
                .padding()

            Divider()

            // Services List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(appState.services) { service in
                        ServiceCardView(service: service)
                    }
                }
                .padding()
            }
            .frame(maxHeight: 400)

            Divider()

            // Footer
            FooterView(appState: appState)
                .padding()
        }
        .frame(width: 360)
        .sheet(isPresented: $appState.showingSettings) {
            SettingsView(appState: appState)
        }
    }
}

struct HeaderView: View {
    @Bindable var appState: AppState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Usage Monitor")
                    .font(.headline)

                if let lastRefresh = appState.lastRefreshDate {
                    Text("Updated \(lastRefresh, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not yet refreshed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: {
                Task {
                    await appState.refresh()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(appState.isRefreshing)
            .opacity(appState.isRefreshing ? 0.5 : 1)
        }
    }
}

struct FooterView: View {
    @Bindable var appState: AppState

    var body: some View {
        HStack {
            if let error = appState.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("\(appState.services.count) services configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: {
                appState.showingSettings = true
            }) {
                Image(systemName: "gear")
                    .font(.title3)
            }
            .buttonStyle(.plain)

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "power")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
    }
}

