import SwiftUI

struct GeneralSettingsTab: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            segmentsSection
            downloadDirectorySection
            bandwidthSection
            loginSection
            aboutSection
        }
        .formStyle(.grouped)
        .onAppear {
            viewModel = SettingsViewModel(aria2: container.aria2Client)
        }
    }

    private var segmentsSection: some View {
        Section("Downloads") {
            Stepper(
                "Default Segments: \(viewModel.defaultSegments)",
                value: $viewModel.defaultSegments,
                in: 1...32
            )
        }
    }

    private var downloadDirectorySection: some View {
        Section("Save Location") {
            HStack {
                TextField("Download Directory", text: $viewModel.defaultDownloadDir)
                    .textFieldStyle(.roundedBorder)
                    .truncationMode(.head)

                Button("Browse...") {
                    viewModel.selectDownloadDirectory()
                }
            }
        }
    }

    private var bandwidthSection: some View {
        Section("Bandwidth") {
            Toggle("Limit Download Speed", isOn: $viewModel.bandwidthLimited)

            if viewModel.bandwidthLimited {
                HStack {
                    TextField(
                        "Speed",
                        value: $viewModel.maxBandwidth,
                        format: .number
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)

                    Text("KB/s")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Apply") {
                        Task { await viewModel.applyBandwidthLimit() }
                    }
                }
            }
        }
    }

    private var loginSection: some View {
        Section {
            Toggle("Launch at Login", isOn: Binding(
                get: { viewModel.launchAtLogin },
                set: { _ in viewModel.toggleLaunchAtLogin() }
            ))
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: viewModel.appVersion)
            if !viewModel.buildNumber.isEmpty {
                LabeledContent("Build", value: viewModel.buildNumber)
            }
        }
    }
}
