// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import EventKit
import SwiftUI

/// Zenith fork: Settings → Meetings, a feature page in the kit
/// (docs/SETTINGS-KIT.md). The hero with the switch for the whole feature,
/// the calendar access and calendars it shares with the island's Calendar
/// (the same picker, the same access request), when the notice shows, the
/// strip during calls, and the providers. Off by default; while off, nothing
/// of it runs. Every change asks MeetingsService to sync.
struct MeetingsSettingsPage: View {
    @AppStorage(DefaultsKey.zenithMeetingsEnabled) private var enabled = false
    @AppStorage(DefaultsKey.zenithMeetingsLeadMinutes) private var leadMinutes = MeetingsSettings.defaultLeadMinutes
    @AppStorage(DefaultsKey.zenithMeetingsShowsStrip) private var showsStrip = true
    @AppStorage(DefaultsKey.zenithMeetingsDisabledProviders) private var disabledProviders = ""
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var features = FeatureRuntime.shared

    private let text = ZenithStrings.meetings(.enUS)

    var body: some View {
        let lead = MeetingsSettings.leadMinutes(leadMinutes)
        let providers = MeetingProvider.allCases.count - MeetingsSettings.disabled(disabledProviders).count
        ZenithToolPage {
            ZenithHero(title: text.title, subtitle: text.subtitle,
                       chips: [ZenithChip(text.minutes(lead)), ZenithChip("\(providers) \(text.providers.lowercased())")],
                       isOn: $enabled, switchLabel: text.enable, switchHint: text.enableHint, animation: .meetings)
                .zenithSectionAnchor(.zenithMeetings, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
            // Kept in view while Meetings is off, greyed, so the page reads
            // the same whichever way the switch is.
            VStack(alignment: .leading, spacing: 18) {
                calendars
                VStack(alignment: .leading, spacing: 18) {
                    ZenithSection(text.before) {
                        ZenithRow(text.lead, selection: Binding(get: { lead }, set: { leadMinutes = $0 }),
                                  info: text.leadHint) {
                            ForEach(MeetingsSettings.leadChoices, id: \.self) { minutes in
                                Text(text.minutes(minutes)).tag(minutes)
                            }
                        }
                    }
                    ZenithSection(text.during) {
                        ZenithRow(text.showsStrip, isOn: $showsStrip, info: text.showsStripHint,
                                  essential: showsStrip && !features.isAvailable(.micMute) ? text.muteNeedsFeature : nil)
                    }
                }
                .zenithSectionAnchor(.zenithMeetingsCalls, cornerRadius: ZenithKitSurface.groupRadius + 6, inset: 6)
                providersSection
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
        .onChange(of: enabled) { _, _ in MeetingsService.shared.syncWithPreferences() }
        .onChange(of: leadMinutes) { _, _ in MeetingsService.shared.syncWithPreferences() }
        .onChange(of: showsStrip) { _, _ in MeetingsService.shared.syncWithPreferences() }
        .onChange(of: disabledProviders) { _, _ in MeetingsService.shared.syncWithPreferences() }
        .onChange(of: permissions.calendarAccess) { _, _ in MeetingsService.shared.syncWithPreferences() }
    }

    // MARK: Calendar

    @ViewBuilder private var calendars: some View {
        let granted = permissions.calendarAccess == .fullAccess
        let refused = permissions.calendarAccess == .denied || permissions.calendarAccess == .restricted
        if granted {
            ZenithSection(text.calendars, footer: text.calendarsHint) {
                ZenithRow(text.calendarAccess, info: text.calendarAccessHint) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ZenithStatus.success)
                        .help(text.calendarAccessGranted)
                        .accessibilityLabel(text.calendarAccessGranted)
                }
                NotchCalendarSelection()
                    .padding(.vertical, 10)
            }
        } else {
            ZenithCallout(.warning, title: text.calendarAccess, text.calendarAccessMissing) {
                if refused {
                    Button(text.openPrivacy, action: permissions.openCalendarSettings)
                } else {
                    Button(text.allowAccess, action: permissions.requestCalendar)
                        .disabled(permissions.requestingCalendar)
                }
            }
        }
    }

    // MARK: Providers

    private var providersSection: some View {
        let disabled = MeetingsSettings.disabled(disabledProviders)
        return ZenithSection(text.providers, anchor: .zenithMeetingsProviders, footer: text.providersHint) {
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                      alignment: .leading, spacing: 10) {
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
                            Text(provider.name).font(ZenithType.body).lineLimit(1)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .accessibilityLabel(provider.name)
                }
            }
            .padding(.vertical, 12)
        }
    }
}
