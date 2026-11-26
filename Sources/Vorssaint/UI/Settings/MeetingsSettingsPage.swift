// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import EventKit
import SwiftUI

/// Zenith fork: Settings → Meetings. The switch for the whole feature, the
/// calendar access and calendars it shares with the island's Calendar (the
/// same picker, the same access request), when the notice shows, the strip
/// during calls, and the providers. Off by default; while off, nothing of it
/// runs. Every change asks MeetingsService to sync.
struct MeetingsSettingsPage: View {
    @AppStorage(DefaultsKey.zenithMeetingsEnabled) private var enabled = false
    @AppStorage(DefaultsKey.zenithMeetingsLeadMinutes) private var leadMinutes = MeetingsSettings.defaultLeadMinutes
    @AppStorage(DefaultsKey.zenithMeetingsShowsStrip) private var showsStrip = true
    @AppStorage(DefaultsKey.zenithMeetingsDisabledProviders) private var disabledProviders = ""
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var features = FeatureRuntime.shared

    private let text = ZenithStrings.meetings(.enUS)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsPageHeader(title: text.title, subtitle: text.subtitle) {
                    HStack(spacing: 10) {
                        Text(text.enable).font(ZenithType.rowTitle).fixedSize()
                        ZenithSwitch(isOn: $enabled)
                    }
                    .accessibilityRepresentation { Toggle(text.enable, isOn: $enabled) }
                    .help(text.enableHint)
                }
                .zenithSectionAnchor(.zenithMeetings)
                // Kept in view while Meetings is off, greyed, so the page
                // reads the same whichever way the switch is.
                VStack(alignment: .leading, spacing: 22) {
                    accessCard
                    callsCard.zenithSectionAnchor(.zenithMeetingsCalls)
                    providersCard.zenithSectionAnchor(.zenithMeetingsProviders)
                }
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.5)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onChange(of: enabled) { _, _ in MeetingsService.shared.syncWithPreferences() }
        .onChange(of: leadMinutes) { _, _ in MeetingsService.shared.syncWithPreferences() }
        .onChange(of: showsStrip) { _, _ in MeetingsService.shared.syncWithPreferences() }
        .onChange(of: disabledProviders) { _, _ in MeetingsService.shared.syncWithPreferences() }
        .onChange(of: permissions.calendarAccess) { _, _ in MeetingsService.shared.syncWithPreferences() }
    }

    // MARK: Calendar

    private var accessCard: some View {
        let granted = permissions.calendarAccess == .fullAccess
        let refused = permissions.calendarAccess == .denied || permissions.calendarAccess == .restricted
        return SettingsCard(title: text.calendars) {
            SettingsRow(symbol: "calendar", title: text.calendarAccess, caption: text.calendarAccessHint) {
                if granted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ZenithStatus.success)
                        .help(text.calendarAccessGranted)
                        .accessibilityLabel(text.calendarAccessGranted)
                }
            }
            if granted {
                Text(text.calendarsHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, settingsRowTextInset)
                NotchCalendarSelection()
                    .padding(.leading, settingsRowTextInset)
            } else {
                HStack(spacing: 10) {
                    Text(text.calendarAccessMissing)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    if refused {
                        Button(text.openPrivacy, action: permissions.openCalendarSettings).controlSize(.small)
                    } else {
                        Button(text.allowAccess, action: permissions.requestCalendar)
                            .controlSize(.small)
                            .disabled(permissions.requestingCalendar)
                    }
                }
                .padding(.leading, settingsRowTextInset)
            }
        }
    }

    // MARK: Before and during

    private var callsCard: some View {
        let lead = MeetingsSettings.leadMinutes(leadMinutes)
        let muteAvailable = features.isAvailable(.micMute)
        return VStack(alignment: .leading, spacing: 22) {
            SettingsCard(title: text.before) {
                SettingsChoiceRow(symbol: "bell.badge", title: text.lead, selection: Binding(
                    get: { lead }, set: { leadMinutes = $0 })) {
                    ForEach(MeetingsSettings.leadChoices, id: \.self) { minutes in
                        Text(text.minutes(minutes)).tag(minutes)
                    }
                }
                caption(text.leadHint)
            }
            SettingsCard(title: text.during) {
                SettingsRow(symbol: "waveform", title: text.showsStrip, caption: text.showsStripHint) {
                    ZenithSwitch(isOn: $showsStrip)
                        .accessibilityRepresentation { Toggle(text.showsStrip, isOn: $showsStrip) }
                }
                if showsStrip, !muteAvailable {
                    caption(text.muteNeedsFeature)
                }
            }
        }
    }

    // MARK: Providers

    private var providersCard: some View {
        let disabled = MeetingsSettings.disabled(disabledProviders)
        return SettingsCard(title: text.providers) {
            caption(text.providersHint).padding(.leading, -settingsRowTextInset)
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                      alignment: .leading, spacing: 8) {
                ForEach(MeetingProvider.allCases) { provider in
                    Toggle(isOn: Binding(get: { !disabled.contains(provider) }, set: { on in
                        MeetingsSettings.setProvider(provider, on: on)
                        disabledProviders = UserDefaults.standard.string(forKey: DefaultsKey.zenithMeetingsDisabledProviders) ?? ""
                    })) {
                        HStack(spacing: 6) {
                            Image(systemName: provider.symbol)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(ZenithIslandPalette.color(hex: provider.tint))
                                .frame(width: 16)
                            Text(provider.name).lineLimit(1)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .accessibilityLabel(provider.name)
                }
            }
        }
    }

    private func caption(_ line: String) -> some View {
        Text(line)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, settingsRowTextInset)
    }
}
