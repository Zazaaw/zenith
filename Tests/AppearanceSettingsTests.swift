// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import IOKit.ps

/// Zenith fork: Settings → Appearance. Templates and Custom resolve and clamp
/// as the island reads them; a slider moves the motion to Custom from what it
/// showed; battery saving starts when it should; the island's old glass
/// switches become the glass style once and the old key follows it; the
/// power reading parses IOKit's description; the page's sections are found
/// by search, Theme and Liquid Glass on Appearance rather than General.
enum AppearanceSettingsTests {
    static func run(_ suite: TestSuite) {
        resolution(suite)
        editing(suite)
        saving(suite)
        glassMigration(suite)
        powerReading(suite)
        preview(suite)
        tint(suite)
        search(suite)
        backup(suite)
    }

    private static func withDefaults(_ name: String, _ body: (UserDefaults) -> Void) {
        let domain = "com.vorssaint.tests.appearance.\(name).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        body(defaults)
    }

    // MARK: Presets and Custom

    private static func resolution(_ suite: TestSuite) {
        withDefaults("resolution") { defaults in
            let standard = IslandMotionSettings.load(from: defaults)
            suite.expect(standard == .standard && standard.preset == .zenith,
                         "with nothing saved the island moves in the Zenith style at 1×")
            defaults.set(IslandMotionPreset.snappy.rawValue, forKey: ZenithAppearanceDefaults.motionPreset)
            defaults.set(0.9, forKey: ZenithAppearanceDefaults.motionBounce)
            let snappy = IslandMotionSettings.load(from: defaults)
            suite.expect(snappy.values == IslandMotionPreset.snappy.values,
                         "a template ignores Custom's sliders: \(snappy.values)")
            defaults.set(IslandMotionPreset.custom.rawValue, forKey: ZenithAppearanceDefaults.motionPreset)
            defaults.set(40.0, forKey: ZenithAppearanceDefaults.motionBlur)
            defaults.set(-3.0, forKey: ZenithAppearanceDefaults.motionContentPace)
            let custom = IslandMotionSettings.load(from: defaults)
            suite.expect(custom.values.bounce == 0.9 && custom.values.blur == IslandMotionValues.blurRange.upperBound
                            && custom.values.contentPace == IslandMotionValues.paceRange.lowerBound,
                         "Custom reads its sliders, each clamped to its range: \(custom.values)")
            defaults.set("bogus", forKey: ZenithAppearanceDefaults.motionPreset)
            defaults.set(Double.nan, forKey: ZenithAppearanceDefaults.motionSpeed)
            let bogus = IslandMotionSettings.load(from: defaults)
            suite.expect(bogus.preset == .zenith && bogus.speed == 1,
                         "an unknown style falls back to Zenith and an unreadable speed to 1×")
            defaults.set(9.0, forKey: ZenithAppearanceDefaults.motionSpeed)
            suite.expect(IslandMotionSettings.load(from: defaults).speed == IslandMotionSettings.speedRange.upperBound,
                         "speed is clamped to 2×")
        }
    }

    private static func editing(_ suite: TestSuite) {
        withDefaults("editing") { defaults in
            ZenithAppearanceStore.selectPreset(.calm, in: defaults)
            let calm = IslandMotionSettings.load(from: defaults)
            ZenithAppearanceStore.editCustom(from: calm, in: defaults) { $0.bounce = 0.5 }
            let moved = IslandMotionSettings.load(from: defaults)
            suite.expect(moved.preset == .custom && moved.values.bounce == 0.5
                            && moved.values.blur == IslandMotionPreset.calm.values.blur
                            && moved.values.contentPace == IslandMotionPreset.calm.values.contentPace,
                         "moving Bounce on Calm switches to Custom and keeps Calm's blur and pace: \(moved.values)")
            ZenithAppearanceStore.editCustom(from: moved, in: defaults) { $0.blur = 99 }
            suite.expect(IslandMotionSettings.load(from: defaults).values.blur == IslandMotionValues.blurRange.upperBound,
                         "a slider is clamped before it is stored")
            ZenithAppearanceStore.selectPreset(.snappy, in: defaults)
            ZenithAppearanceStore.setSpeed(1.5, in: defaults)
            let snappy = IslandMotionSettings.load(from: defaults)
            suite.expect(snappy.preset == .snappy && snappy.speed == 1.5,
                         "Speed applies to a template without switching it to Custom")
            ZenithAppearanceStore.selectPreset(.custom, in: defaults)
            let custom = IslandMotionSettings.load(from: defaults)
            suite.expect(custom.values.bounce == 0.5 && custom.values == ZenithAppearanceStore.customValues(in: defaults),
                         "choosing Custom again brings back its sliders, as its tile previews them")
            ZenithAppearanceStore.setSpeed(-1, in: defaults)
            suite.expect(IslandMotionSettings.load(from: defaults).speed == IslandMotionSettings.speedRange.lowerBound,
                         "speed is clamped before it is stored")
        }
        withDefaults("custom-fresh") { defaults in
            suite.expect(ZenithAppearanceStore.customValues(in: defaults) == IslandMotionPreset.zenith.values,
                         "Custom never moved starts from Zenith's values")
        }
    }

    // MARK: Battery saving

    private static func saving(_ suite: TestSuite) {
        let automatic = IslandBatterySaver.automatic
        suite.expect(automatic.isSaving(lowPowerMode: true, onBattery: false, batteryPercent: 90),
                     "Automatic saves in Low Power Mode, even on power")
        suite.expect(automatic.isSaving(lowPowerMode: false, onBattery: true, batteryPercent: 20)
                        && !automatic.isSaving(lowPowerMode: false, onBattery: true, batteryPercent: 21),
                     "Automatic saves on battery at 20% or less, not above")
        suite.expect(!automatic.isSaving(lowPowerMode: false, onBattery: false, batteryPercent: 5),
                     "a low battery that is charging does not save")
        suite.expect(!automatic.isSaving(lowPowerMode: false, onBattery: true, batteryPercent: nil),
                     "a Mac with no battery reading does not save")
        suite.expect(IslandBatterySaver.on.isSaving(lowPowerMode: false, onBattery: false, batteryPercent: 100)
                        && !IslandBatterySaver.off.isSaving(lowPowerMode: true, onBattery: true, batteryPercent: 1),
                     "On always saves and Off never does")
        withDefaults("saver") { defaults in
            suite.expect(IslandBatterySaver.load(from: defaults) == .automatic, "battery saving starts on Automatic")
            MainActor.assumeIsolated {
                let appearance = ZenithAppearance(defaults: defaults)
                appearance.updatePower(lowPowerMode: false, onBattery: true, batteryPercent: 15)
                let savesLow = appearance.isSavingBattery
                ZenithAppearanceStore.setBatterySaver(.off, in: defaults)
                appearance.reload()
                suite.expect(savesLow && !appearance.isSavingBattery,
                             "the island saves on a low battery, and stops when saving is turned off")
            }
        }
    }

    // MARK: The old glass switches

    private static func glassMigration(_ suite: TestSuite) {
        func migrated(liquid: Bool?, translucent: Bool?) -> (IslandGlassStyle, Bool) {
            var result: (IslandGlassStyle, Bool) = (.black, false)
            withDefaults("glass") { defaults in
                if let liquid { defaults.set(liquid, forKey: DefaultsKey.notchLiquidGlassEnabled) }
                if let translucent { defaults.set(translucent, forKey: DefaultsKey.notchTranslucentBackground) }
                ZenithAppearanceStore.migrateLegacyGlass(in: defaults)
                result = (IslandGlassSettings.load(from: defaults).style,
                          defaults.bool(forKey: DefaultsKey.notchLiquidGlassEnabled))
            }
            return result
        }
        suite.expect(migrated(liquid: true, translucent: nil) == (.liquid, true),
                     "an island with Liquid Glass on keeps it as the Liquid Glass style")
        suite.expect(migrated(liquid: true, translucent: true) == (.liquid, true),
                     "Liquid Glass wins over the translucent background, as it did on the island")
        suite.expect(migrated(liquid: false, translucent: true) == (.gradient, false),
                     "the translucent background becomes Gradient")
        suite.expect(migrated(liquid: nil, translucent: nil) == (.black, false), "a new Mac starts Black")

        withDefaults("glass-once") { defaults in
            defaults.set(true, forKey: DefaultsKey.notchLiquidGlassEnabled)
            ZenithAppearanceStore.migrateLegacyGlass(in: defaults)
            ZenithAppearanceStore.setGlassStyle(.gradient, in: defaults)
            suite.expect(!defaults.bool(forKey: DefaultsKey.notchLiquidGlassEnabled),
                         "choosing Gradient turns the old Liquid Glass key off, for the controls that read it")
            defaults.set(true, forKey: DefaultsKey.notchLiquidGlassEnabled)
            ZenithAppearanceStore.migrateLegacyGlass(in: defaults)
            suite.expect(IslandGlassSettings.load(from: defaults).style == .gradient
                            && !defaults.bool(forKey: DefaultsKey.notchLiquidGlassEnabled),
                         "once a style is saved it leads: the old key follows it rather than migrating again")
            ZenithAppearanceStore.setGlassStyle(.liquid, in: defaults)
            suite.expect(defaults.bool(forKey: DefaultsKey.notchLiquidGlassEnabled),
                         "choosing Liquid Glass turns the old key on")
            // An older backup carries the old key and no style; importing clears the style.
            defaults.removeObject(forKey: ZenithAppearanceDefaults.glassStyle)
            defaults.set(false, forKey: DefaultsKey.notchLiquidGlassEnabled)
            MainActor.assumeIsolated {
                let appearance = ZenithAppearance(defaults: defaults)
                suite.expect(appearance.glass.style == .black,
                             "a backup from before Appearance migrates its glass when the island reloads")
            }
        }
        withDefaults("glass-clamp") { defaults in
            ZenithAppearanceStore.setGradientHeight(4, in: defaults)
            ZenithAppearanceStore.setTint(.nan, in: defaults)
            let glass = IslandGlassSettings.load(from: defaults)
            suite.expect(glass.gradientHeight == 1 && glass.tint == IslandGlassSettings.standard.tint,
                         "gradient height and tint are stored clamped, an unreadable value as the default")
        }
    }

    // MARK: Power

    private static func powerReading(_ suite: TestSuite) {
        let onBattery: [String: Any] = [kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSIsPresentKey: true,
                                        kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue,
                                        kIOPSCurrentCapacityKey: 18, kIOPSMaxCapacityKey: 100]
        suite.expect(ZenithPowerReading.reading(from: [onBattery]) == ZenithPowerReading(onBattery: true, percent: 18),
                     "the internal battery reads as on battery at its charge")
        var charging = onBattery
        charging[kIOPSPowerSourceStateKey] = kIOPSACPowerValue
        charging[kIOPSCurrentCapacityKey] = 3
        charging[kIOPSMaxCapacityKey] = 4
        suite.expect(ZenithPowerReading.reading(from: [charging]) == ZenithPowerReading(onBattery: false, percent: 75),
                     "on power the battery is not in use, and a non-percent capacity becomes a percent")
        let ups: [String: Any] = [kIOPSTypeKey: kIOPSUPSType, kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue,
                                  kIOPSCurrentCapacityKey: 5, kIOPSMaxCapacityKey: 100]
        suite.expect(ZenithPowerReading.reading(from: [ups]) == .noBattery
                        && ZenithPowerReading.reading(from: []) == .noBattery,
                     "a Mac without an internal battery reads as on power, with no percent")
    }

    // MARK: The tile preview

    private static func preview(_ suite: TestSuite) {
        let zenith = IslandMotionPreview(settings: .standard)
        suite.expect(zenith.frame(at: 0).shape == 0 && zenith.frame(at: 0).content == 0, "the preview starts closed")
        let peak = stride(from: 0.0, to: zenith.opening, by: 0.005).map { zenith.frame(at: $0).shape }.max() ?? 0
        suite.expect(peak > 1.01, "Zenith's preview overshoots before it settles (\(peak))")
        let snappy = IslandMotionPreview(settings: IslandMotionSettings(preset: .snappy, values: IslandMotionPreset.snappy.values,
                                                                       speed: 1))
        let snappyPeak = stride(from: 0.0, to: snappy.opening, by: 0.005).map { snappy.frame(at: $0).shape }.max() ?? 0
        suite.expect(snappyPeak <= 1.0001, "Snappy lands without a bounce (\(snappyPeak))")
        suite.expect(snappy.frame(at: snappy.opening).content > 0.99 && zenith.frame(at: zenith.opening + 0.1) == .open,
                     "content has arrived by the end of the opening, and the island holds open")
        suite.expect(zenith.frame(at: zenith.cycle + 0.0001).shape < 0.01, "the preview loops back to closed")
        let slow = IslandMotionPreview(settings: IslandMotionSettings(preset: .zenith, values: IslandMotionPreset.zenith.values,
                                                                     speed: 0.5))
        suite.expect(slow.opening > zenith.opening && slow.closing > zenith.closing,
                     "a slower speed slows the preview too")
    }

    // MARK: Gradient glass

    private static func tint(_ suite: TestSuite) {
        let standard = NotchTranslucentTint.gradient(height: 200, stripHeight: 32, gradientHeight: 0.6, tint: 0.3)
        suite.expect(abs(standard.clearance - NotchTranslucentTint.clearance) < 1e-9
                        && abs(standard.rampLength - 168 * 0.6) < 1e-9,
                     "the default tint clears the glass as the old translucent background did, over 60% of the body")
        let dark = NotchTranslucentTint.gradient(height: 200, stripHeight: 32, gradientHeight: 0, tint: 1)
        suite.expect(dark.rampLength == NotchTranslucentTint.minimumRamp && dark.clearance < standard.clearance,
                     "a 0% gradient still eases over a few points, and more tint keeps more black")
        let bottom = NotchTranslucentTint.opacity(atDepth: 200, stripHeight: 32, openness: 1, increasedContrast: false,
                                                  rampLength: dark.rampLength, clearance: dark.clearance)
        suite.expect(bottom > 0.8 && NotchTranslucentTint.opacity(atDepth: 20, stripHeight: 32, openness: 1,
                                                                   increasedContrast: false, rampLength: 50,
                                                                   clearance: 0.8) == 1,
                     "full tint stays nearly black for legibility, and the camera strip stays black")
    }

    // MARK: Search

    private static func search(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.appearance-search"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let state = SettingsSearchState(defaults: defaults, hardware: .init(
            battery: true, notchedDisplay: true, plainDisplay: false,
            keyboardLight: true, bluetoothSleep: true, brightnessOSD: true))
        let all: (AppFeature) -> Bool = { _ in true }
        func routes(_ query: String, language: AppLanguage = .enUS) -> [FeatureSettingsDestination] {
            let items = SettingsDirectory.searchItems(Strings.localized(language), language: language, state: state)
            return SettingsSearchSupport.groupedMatchingItems(query: query, items: items, isAvailable: all)
                .flatMap { ($0.parentMatches ? [$0.parentSuggestion] : []) + $0.suggestions }
                .prefix(ForkSettingsSearchTests.top)
                .map { SettingsSearchSupport.route(for: $0, isAvailable: all).destination }
        }
        let anchored = { (anchor: SettingsSectionAnchor) in FeatureSettingsDestination(.appearance, sectionAnchor: anchor) }
        let expectations: [(String, FeatureSettingsDestination)] = [
            ("appearance", FeatureSettingsDestination(.appearance)), ("tampilan", FeatureSettingsDestination(.appearance)),
            ("theme", anchored(.zenithAppearanceTheme)), ("dark", anchored(.zenithAppearanceTheme)),
            ("light", anchored(.zenithAppearanceTheme)), ("tema", anchored(.zenithAppearanceTheme)),
            ("mode gelap", anchored(.zenithAppearanceTheme)), ("liquid glass", anchored(.zenithAppearanceTheme)),
            ("other windows and panels", anchored(.zenithAppearanceTheme)),
            ("liquid glass", anchored(.zenithAppearanceGlass)), ("kaca", anchored(.zenithAppearanceGlass)),
            ("gradient", anchored(.zenithAppearanceGlass)), ("tint", anchored(.zenithAppearanceGlass)),
            ("motion", anchored(.zenithAppearanceMotion)), ("content pace", anchored(.zenithAppearanceMotion)),
            ("snappy", anchored(.zenithAppearanceMotion)), ("animasi", anchored(.zenithAppearanceMotion)),
            ("kecepatan", anchored(.zenithAppearanceMotion)),
            ("save battery", anchored(.zenithAppearanceBattery)), ("hemat baterai", anchored(.zenithAppearanceBattery)),
            ("low power mode", anchored(.zenithAppearanceBattery)),
        ]
        for (query, destination) in expectations {
            let found = routes(query)
            suite.expect(found.contains(destination), "searching \"\(query)\" offers \(destination): \(found)")
        }
        for query in ["dark", "liquid glass", "theme"] {
            suite.expect(!routes(query).contains(FeatureSettingsDestination(.general)),
                         "\"\(query)\" no longer lands on General, where the theme used to be")
        }
        // The theme's words stay localized: German finds it by its own word for Dark.
        let german = FeatureStrings.appearance(.de)
        suite.expect(routes(german.dark, language: .de).contains(anchored(.zenithAppearanceTheme)),
                     "the theme is found by its localized words (\(german.dark))")
    }

    // MARK: Backup

    private static func backup(_ suite: TestSuite) {
        let keys = SettingsBackupSupport.exportKeys()
        suite.expect(ZenithAppearanceDefaults.all.allSatisfy(keys.contains),
                     "every Appearance preference follows settings backups")
        suite.expect(SettingsBackupSupport.keysToClear(whenImporting: [DefaultsKey.notchEnabled: true])
                        .contains(ZenithAppearanceDefaults.glassStyle),
                     "importing an older backup clears the glass style, so its old glass switch migrates again")
    }
}
