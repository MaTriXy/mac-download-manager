import SwiftUI

struct FilterRulesTab: View {
    @State private var viewModel = SettingsViewModel()
    @State private var newExtension = ""

    var body: some View {
        Form {
            interceptToggleSection
            fileTypesSection
            minimumSizeSection
            resetSection
        }
        .formStyle(.grouped)
    }

    private var interceptToggleSection: some View {
        Section {
            Toggle("Enable Download Interception", isOn: $viewModel.interceptEnabled)
        } footer: {
            Text("When enabled, matching links from the browser extension will be captured automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var fileTypesSection: some View {
        Section("File Types") {
            FlowLayout(spacing: 6) {
                ForEach(viewModel.fileTypesArray, id: \.self) { ext in
                    extensionTag(ext)
                }
            }

            HStack {
                TextField("Add extension...", text: $newExtension)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addExtension() }

                Button {
                    addExtension()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newExtension.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func extensionTag(_ ext: String) -> some View {
        HStack(spacing: 4) {
            Text(".\(ext)")
                .font(.caption)

            Button {
                removeExtension(ext)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
    }

    private var minimumSizeSection: some View {
        Section("Minimum File Size") {
            HStack {
                Slider(
                    value: Binding(
                        get: { Double(viewModel.interceptMinSizeMB) },
                        set: { viewModel.interceptMinSizeMB = Int($0) }
                    ),
                    in: 1...100,
                    step: 1
                )

                Text("\(viewModel.interceptMinSizeMB) MB")
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }

    private var resetSection: some View {
        Section {
            Button("Reset to Defaults") {
                viewModel.resetFilterDefaults()
            }
        }
    }

    private func addExtension() {
        let cleaned = newExtension
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ".", with: "")

        guard !cleaned.isEmpty, !viewModel.fileTypesArray.contains(cleaned) else { return }
        var types = viewModel.fileTypesArray
        types.append(cleaned)
        viewModel.fileTypesArray = types
        newExtension = ""
    }

    private func removeExtension(_ ext: String) {
        var types = viewModel.fileTypesArray
        types.removeAll { $0 == ext }
        viewModel.fileTypesArray = types
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
            rowHeight = max(rowHeight, size.height)
        }

        return (CGSize(width: maxX, height: currentY + rowHeight), positions)
    }
}
