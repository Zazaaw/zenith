// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Zenith fork: the Sky section's options in Settings → Dynamic Island →
/// Content: how the times are worked out (method, Asr, names, the person's
/// minutes), where for (the weather's approximate location, a city, or a
/// typed position), what the island reminds of and how, and the golden hour.
/// Headings and rows are drawn here, with ZenithSwitchRow for every switch,
/// so Settings search never indexes labels it cannot find again.
struct SkySettingsView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var weather = WeatherService.shared
    @AppStorage(DefaultsKey.notchSkyMethod) private var method = PrayerMethod.kemenag.rawValue
    @AppStorage(DefaultsKey.notchSkyAsr) private var asr = PrayerAsrSchool.shafii.rawValue
    @AppStorage(DefaultsKey.notchSkyNames) private var names = PrayerTimesSupport.NameStyle.automatic.rawValue
    @AppStorage(DefaultsKey.notchSkyAdjustments) private var adjustments = SkySettings.defaultAdjustments
    @AppStorage(DefaultsKey.notchSkyLocationSource) private var source = SkyLocationSource.automatic.rawValue
    @AppStorage(DefaultsKey.notchSkyCity) private var city = SkyCity.defaultID
    @AppStorage(DefaultsKey.notchSkyLatitude) private var latitude = -6.2
    @AppStorage(DefaultsKey.notchSkyLongitude) private var longitude = 106.8
    @AppStorage(DefaultsKey.notchSkyReminded) private var reminded = SkySettings.defaultReminded
    @AppStorage(DefaultsKey.notchSkyPrayerActivity) private var prayerActivity = true
    @AppStorage(DefaultsKey.notchSkyPrayerLead) private var lead = PrayerTimesSupport.defaultLead
    @AppStorage(DefaultsKey.notchSkyPrayerSound) private var sound = false
    @AppStorage(DefaultsKey.notchSkyPrayerSoundFile) private var soundFile = ""
    @AppStorage(DefaultsKey.notchSkyGoldenActivity) private var goldenActivity = true

    private var text: ZenithSkyStrings { ZenithStrings.sky(l10n.language) }
    private var indonesian: Bool {
        PrayerTimesSupport.usesIndonesian(PrayerTimesSupport.NameStyle(rawValue: names) ?? .automatic)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The prayer times and the golden hour are each a place Settings search lands on.
            VStack(alignment: .leading, spacing: 10) {
                heading(text.calculation)
                calculation
                Divider().padding(.vertical, 2)
                heading(text.location)
                location
                Divider().padding(.vertical, 2)
                heading(text.reminders)
                remindersSection
            }
            .zenithSectionAnchor(.zenithPrayerTimes)
            Divider().padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 10) {
                heading(text.goldenTab)
                ZenithSwitchRow(text.goldenActivity, isOn: $goldenActivity) {
                    label(text.goldenActivity, caption: text.goldenActivityCaption)
                }
            }
            .zenithSectionAnchor(.zenithGoldenHour)
        }
        .zenithSectionAnchor(.zenithSky) // Settings search lands here
        .onAppear {
            weather.refreshAccess()
            SkyService.shared.viewShown()
        }
        .onChange(of: method) { _, _ in apply() }
        .onChange(of: asr) { _, _ in apply() }
        .onChange(of: names) { _, _ in apply() }
        .onChange(of: adjustments) { _, _ in apply() }
        .onChange(of: source) { _, _ in apply() }
        .onChange(of: city) { _, _ in apply() }
        .onChange(of: latitude) { _, _ in apply() }
        .onChange(of: longitude) { _, _ in apply() }
        .onChange(of: reminded) { _, _ in apply() }
        .onChange(of: prayerActivity) { _, _ in apply() }
        .onChange(of: lead) { _, _ in apply() }
        .onChange(of: sound) { _, _ in apply() }
        .onChange(of: goldenActivity) { _, _ in apply() }
    }

    private func apply() {
        SkyService.shared.preferencesChanged()
        NotchService.shared.syncWithPreferences()
    }

    // MARK: Calculation

    @ViewBuilder private var calculation: some View {
        let chosen = PrayerMethod(rawValue: method) ?? .kemenag
        HStack(alignment: .top, spacing: 12) {
            label(text.method, caption: chosen.parameters)
            Spacer(minLength: 12)
            Picker(text.method, selection: $method) {
                ForEach(PrayerMethod.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .labelsHidden()
            .fixedSize()
        }
        row(text.asr) {
            Picker(text.asr, selection: $asr) {
                Text(text.shafii).tag(PrayerAsrSchool.shafii.rawValue)
                Text(text.hanafi).tag(PrayerAsrSchool.hanafi.rawValue)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        row(text.names) {
            Picker(text.names, selection: $names) {
                Text(text.namesAutomatic).tag(PrayerTimesSupport.NameStyle.automatic.rawValue)
                Text(text.namesIndonesian).tag(PrayerTimesSupport.NameStyle.indonesian.rawValue)
                Text(text.namesApp).tag(PrayerTimesSupport.NameStyle.app.rawValue)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        VStack(alignment: .leading, spacing: 6) {
            label(text.adjustments, caption: text.adjustmentsCaption)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                      alignment: .leading, spacing: 4) {
                ForEach(Prayer.allCases) { prayer in adjustmentRow(prayer) }
            }
        }
    }

    private func adjustmentRow(_ prayer: Prayer) -> some View {
        let binding = Binding<Int>(
            get: { PrayerAdjustments.decode(adjustments)[prayer] },
            set: { value in
                var decoded = PrayerAdjustments.decode(adjustments)
                decoded[prayer] = value
                adjustments = decoded.encoded
            })
        let value = binding.wrappedValue
        let name = ZenithStrings.sky(l10n.language).name(prayer, indonesian: indonesian)
        return HStack(spacing: 8) {
            Text(name).lineLimit(1)
            Spacer(minLength: 4)
            Text(value == 0 ? "0" : (value > 0 ? "+\(value)" : "−\(-value)"))
                .font(ZenithType.mono(12))
                .foregroundStyle(value == 0 ? .secondary : .primary)
                .frame(minWidth: 26, alignment: .trailing)
            Stepper(name, value: binding, in: PrayerAdjustments.range)
                .labelsHidden()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Location

    @ViewBuilder private var location: some View {
        let chosen = SkyLocationSource(rawValue: source) ?? .automatic
        row(text.location) {
            Picker(text.location, selection: $source) {
                Text(text.sourceAutomatic).tag(SkyLocationSource.automatic.rawValue)
                Text(text.sourceCity).tag(SkyLocationSource.city.rawValue)
                Text(text.sourceCustom).tag(SkyLocationSource.custom.rawValue)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        switch chosen {
        case .automatic:
            accessNote
        case .city:
            row(text.sourceCity) {
                Picker(text.sourceCity, selection: $city) {
                    ForEach(SkyCity.all) { Text($0.name).tag($0.id) }
                }
                .labelsHidden()
                .fixedSize()
            }
            caption(text.manualCaption)
        case .custom:
            HStack(spacing: 12) {
                coordinateField(text.latitude, value: $latitude, range: -90...90)
                coordinateField(text.longitude, value: $longitude, range: -180...180)
            }
            caption(text.manualCaption)
        }
    }

    /// Where the approximate location stands: its source, or the button that
    /// asks for it (only when pressed), or the way to System Settings.
    @ViewBuilder private var accessNote: some View {
        let home = ZenithStrings.home(l10n.language)
        VStack(alignment: .leading, spacing: 6) {
            switch weather.access {
            case .granted:
                caption(text.automaticCaption)
            case .notDetermined:
                caption(text.needsLocation)
                Button(home.allowLocation) { weather.requestAccess() }
                    .controlSize(.small)
            case .denied:
                caption(text.locationDenied)
                Button(home.openSettings) { weather.openLocationSettings() }
                    .controlSize(.small)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            weather.refreshAccess()
        }
    }

    private func coordinateField(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(ZenithType.caption).foregroundStyle(.secondary)
            TextField(title, value: Binding(get: { value.wrappedValue },
                                            set: { value.wrappedValue = min(range.upperBound, max(range.lowerBound, $0)) }),
                      format: .number.precision(.fractionLength(0...4)).locale(Locale(identifier: "en_US_POSIX")))
                .textFieldStyle(.roundedBorder)
                .font(ZenithType.mono(12))
                .labelsHidden()
                .frame(maxWidth: 140)
        }
    }

    // MARK: Reminders

    @ViewBuilder private var remindersSection: some View {
        caption(text.remindersCaption)
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                  alignment: .leading, spacing: 6) {
            ForEach(Prayer.remindable) { prayer in
                let name = ZenithStrings.sky(l10n.language).name(prayer, indonesian: indonesian)
                ZenithSwitchRow(name, isOn: reminderBinding(prayer)) {
                    Label(name, systemImage: prayer.symbol).foregroundStyle(.secondary)
                }
            }
        }
        ZenithSwitchRow(text.prayerActivity, isOn: $prayerActivity) {
            label(text.prayerActivity, caption: text.prayerActivityCaption)
        }
        if prayerActivity {
            row(text.lead) {
                Picker(text.lead, selection: $lead) {
                    ForEach(PrayerTimesSupport.leadChoices, id: \.self) { minutes in
                        Text(text.minutes(minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .padding(.leading, 16)
        }
        ZenithSwitchRow(text.sound, isOn: $sound) {
            label(text.sound, caption: text.soundCaption)
        }
        if sound {
            HStack(spacing: 8) {
                Image(systemName: soundFile.isEmpty ? "speaker.wave.2" : "music.note")
                    .foregroundStyle(.secondary)
                Text(SkyService.customSoundURL == nil ? SkyService.systemSoundName : soundFile)
                    .font(ZenithType.mono(11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                Button { SkyService.shared.playSound() } label: { Image(systemName: "play.fill") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(text.sound)
                Spacer(minLength: 8)
                if !soundFile.isEmpty {
                    Button(text.systemSound) { SkyService.shared.removeSound() }
                }
                Button(text.chooseSound, action: chooseSound)
            }
            .padding(.leading, 16)
        }
    }

    private func reminderBinding(_ prayer: Prayer) -> Binding<Bool> {
        Binding(get: { SkySettings.decodeReminded(reminded).contains(prayer) }, set: { on in
            var set = SkySettings.decodeReminded(reminded)
            if on { set.insert(prayer) } else { set.remove(prayer) }
            reminded = SkySettings.encodeReminded(set)
        })
    }

    private func chooseSound() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.audio]
        panel.prompt = text.chooseSound.replacingOccurrences(of: "…", with: "").trimmingCharacters(in: .whitespaces)
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        SkyService.shared.installSound(from: url)
    }

    // MARK: Pieces

    private func heading(_ title: String) -> some View {
        Text(title).font(ZenithType.emphasis).accessibilityAddTraits(.isHeader)
    }

    private func row<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 12)
            control()
        }
    }

    private func label(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(caption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func caption(_ words: String) -> some View {
        Text(words).font(ZenithType.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
