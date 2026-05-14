import SwiftUI

struct ContentView: View {
    @StateObject private var model = BLEHarnessModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Session") {
                    Picker("Mode", selection: $model.mode) {
                        ForEach(HarnessMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    LabeledContent("Status", value: model.status)
                    LabeledContent("Peer", value: model.peerId ?? "None")
                }

                Section("Controls") {
                    HStack {
                        Button {
                            model.start()
                        } label: {
                            Label(model.mode.rawValue, systemImage: model.mode == .scan ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            model.stop()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        model.sendPing()
                    } label: {
                        Label("Ping Secure Peer", systemImage: "paperplane.fill")
                    }
                    .disabled(model.peerId == nil)
                }

                Section("Events") {
                    if model.events.isEmpty {
                        Text("No events")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.events) { event in
                            EventRow(event: event)
                        }
                    }
                }
            }
            .navigationTitle("MeshX BLE")
        }
        .onAppear {
            model.startFromLaunchArgumentsIfNeeded()
        }
    }
}

private struct EventRow: View {
    let event: HarnessEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.title)
                    .font(.body.weight(.medium))
                Spacer()
                Text(event.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(event.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView()
}
