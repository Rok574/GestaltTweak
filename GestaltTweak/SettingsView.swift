//
//  SettingsView.swift
//  GestaltTweak
//
//  Settings sheet modeled after rooootdev/mond's SettingsView (AGPL-3.0).
//  Licensed under the MIT License.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: GestaltViewModel

    @AppStorage("method") private var method = "bad_query"
    @AppStorage("atomic_write") private var persistAfterReboot = true

    @State private var showsRespringConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section { appInfoRow }

                Section {
                    Picker("Method", selection: $method) {
                        Text("bad_query").tag("bad_query")
                        Text("cmg").tag("cmg")
                    }
                    .pickerStyle(.segmented)

                    Button {
                        viewModel.runExploit()
                        dismiss()
                    } label: {
                        Text("Run Exploit")
                    }
                } header: {
                    Label("Exploit", systemImage: "wrench.and.screwdriver")
                } footer: {
                    Text(method == "cmg"
                        ? "CMG: Supports iOS 27.0 b1 - b4. Only MobileGestalt works with this method. Use it when bad_query is not working for you."
                        : "bad_query: Supports iOS 27.0 b1 - b4. By forcequit.")
                }

                Section {
                    Toggle("Persist after reboot", isOn: $persistAfterReboot)
                } header: {
                    Label("Settings", systemImage: "gear")
                } footer: {
                    Text("When enabled, MobileGestalt is written in-place on the same inode, which (hopefully) prevents iOS from regenerating the cache on reboot. Disable to use atomic file replacement instead.")
                }

                Section {
                    Button {
                        showsRespringConfirmation = true
                    } label: {
                        Text("Respring")
                    }
                } header: {
                    Label("Tools", systemImage: "hammer")
                } footer: {
                    Text("Respring method by neonmodder123, Swift implementation by skadz108.")
                }

                Section {
                    CreditsRow(name: "frs0n", role: "GestaltEdit", profile: URL(string: "https://github.com/frs0n")!)
                    CreditsRow(name: "forcequit", role: "bad_query exploit", profile: URL(string: "https://github.com/forcequitOS")!)
                    CreditsRow(name: "roooot", role: "mond", profile: URL(string: "https://github.com/rooootdev")!)
                    CreditsRow(name: "leminlimez", role: "Nugget (tweak keys)", profile: URL(string: "https://github.com/leminlimez")!)
                    CreditsRow(name: "neonmodder123", role: "Respring method", profile: URL(string: "https://github.com/neonmodder123")!)
                    CreditsRow(name: "skadz108", role: "Respring Swift port", profile: URL(string: "https://github.com/skadz108")!)
                } header: {
                    Label("Credits", systemImage: "person.3.fill")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Are you sure?", isPresented: $showsRespringConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Confirm") { viewModel.respring() }
            } message: {
                Text("Confirm that you want to respring.")
            }
        }
    }

    private var appInfoRow: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 45, height: 45)
                .overlay {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .font(.system(size: 20, weight: .medium))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("GestaltTweak Everywhere")
                    .font(.headline)
                Text(versionText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var versionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }
}

struct CreditsRow: View {
    let name: String
    let role: String
    let profile: URL

    var body: some View {
        HStack(alignment: .top) {
            AsyncImage(url: avatarURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                Text(role)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.open(profile)
        }
    }

    private var avatarURL: URL {
        URL(string: profile.absoluteString + ".png") ?? profile
    }
}