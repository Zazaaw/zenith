// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

/// Zenith fork: capsule notices: battery thresholds and their hysteresis, the
/// queue (priority, one at a time, coalescing, superseding, expiry), audio
/// battery matching, formatting, sizes, settings and the strings.
enum ZenithNoticeTests {
    static func run(_ suite: TestSuite) {
        batteryBaseline(suite)
        lowBatteryHysteresis(suite)
        criticalBattery(suite)
        chargeLimit(suite)
        charger(suite)
        smallNotice(suite)
        queueOrder(suite)
        queueCoalescing(suite)
        queueSuperseding(suite)
        queueCapacityAndExpiry(suite)
        audio(suite)
        formatting(suite)
        layout(suite)
        settings(suite)
        strings(suite)
    }

    private static func on(_ percent: Int) -> ZenithBatteryReading {
        ZenithBatteryReading(percent: percent, external: false, charging: false)
    }

    private static func plugged(_ percent: Int, charging: Bool = true) -> ZenithBatteryReading {
        ZenithBatteryReading(percent: percent, external: true, charging: charging)
    }

    /// Feeds readings in order and collects every event they raise.
    private static func run(_ readings: [ZenithBatteryReading], settings: ZenithBatterySettings = .init(),
                            state: inout ZenithBatteryNoticeState) -> [ZenithBatteryEvent] {
        readings.flatMap { state.update($0, settings: settings) }
    }

    private static func run(_ readings: [ZenithBatteryReading],
                            settings: ZenithBatterySettings = .init()) -> [ZenithBatteryEvent] {
        var state = ZenithBatteryNoticeState()
        return run(readings, settings: settings, state: &state)
    }

    // MARK: Battery

    private static func batteryBaseline(_ suite: TestSuite) {
        suite.expect(run([on(15)]).isEmpty && run([on(15), on(14), on(13)]).isEmpty,
                     "a Mac already below 20% at launch stays quiet until it recovers")
        suite.expect(run([on(15), on(25), on(20)]) == [.low(percent: 20, critical: false)],
                     "after recovering past the threshold, crossing it again warns")
        var state = ZenithBatteryNoticeState()
        let events = state.update(on(20), previous: on(21), settings: .init())
        suite.expect(events == [.low(percent: 20, critical: false)],
                     "the reading before the first one is its baseline, so the first crossing counts")
        suite.expect(run([ZenithBatteryReading(percent: nil, external: false, charging: false), on(50)]).isEmpty,
                     "a reading without a percentage is a baseline, not a crossing")
    }

    private static func lowBatteryHysteresis(_ suite: TestSuite) {
        suite.expect(run([on(30), on(21), on(20)]) == [.low(percent: 20, critical: false)],
                     "reaching 20% while discharging warns once")
        suite.expect(run([on(30), on(20), on(21), on(20), on(22), on(19), on(21), on(20)])
                        == [.low(percent: 20, critical: false)],
                     "a charge wavering around 20% does not warn again")
        suite.expect(run([on(30), on(20), on(23), on(20)])
                        == [.low(percent: 20, critical: false), .low(percent: 20, critical: false)],
                     "three points above the threshold arm it again")
        suite.expect(run([on(30), on(20), plugged(20), on(20)]) == [
            .low(percent: 20, critical: false), .charging(percent: 20), .unplugged(percent: 20)],
                     "a charger plugged in and out at the same level does not repeat the warning")
        suite.expect(run([on(30), plugged(25), plugged(19), on(19)])
                        == [.charging(percent: 25), .unplugged(percent: 19), .low(percent: 19, critical: false)],
                     "below the threshold on the charger, no warning; pulled out there, the warning not yet given is")
        var custom = ZenithBatterySettings()
        custom.low = 25
        suite.expect(run([on(40), on(26), on(25)], settings: custom) == [.low(percent: 25, critical: false)],
                     "the low threshold follows the setting")
        custom.lowOn = false
        suite.expect(run([on(40), on(25), on(20)], settings: custom).isEmpty,
                     "the low notice switched off says nothing")
    }

    private static func criticalBattery(_ suite: TestSuite) {
        suite.expect(run([on(30), on(20), on(15), on(10)])
                        == [.low(percent: 20, critical: false), .low(percent: 10, critical: true)],
                     "20% and 10% each warn once")
        suite.expect(run([on(40), on(8)]) == [.low(percent: 8, critical: true)],
                     "one reading past both thresholds, as after sleep, gives only the deeper warning")
        suite.expect(run([on(40), on(8), on(9), on(10), on(12)]) == [.low(percent: 8, critical: true)],
                     "after the deeper warning, nothing repeats below 13%")
        var noCritical = ZenithBatterySettings()
        noCritical.criticalOn = false
        suite.expect(run([on(40), on(8)], settings: noCritical) == [.low(percent: 8, critical: false)],
                     "with the very low notice off, the low one still covers a jump past both")
        suite.expect(run([on(30), on(20), on(10)], settings: noCritical) == [.low(percent: 20, critical: false)],
                     "with the very low notice off, 10% says nothing more")
        var critical15 = ZenithBatterySettings()
        critical15.critical = 15
        suite.expect(run([on(30), on(20), on(15)], settings: critical15)
                        == [.low(percent: 20, critical: false), .low(percent: 15, critical: true)],
                     "the very low threshold follows the setting")
    }

    private static func chargeLimit(_ suite: TestSuite) {
        suite.expect(run([plugged(70), plugged(79), plugged(80)])
                        == [.chargeLimit(percent: 80)],
                     "charging past 80% hints once")
        suite.expect(run([plugged(70), plugged(80), plugged(79), plugged(80), plugged(78), plugged(81)])
                        == [.chargeLimit(percent: 80)],
                     "a charge held around 80% does not hint again")
        suite.expect(run([plugged(70), plugged(80), plugged(77), plugged(80)])
                        == [.chargeLimit(percent: 80), .chargeLimit(percent: 80)],
                     "dropping three points below the threshold arms it again")
        suite.expect(run([plugged(85), plugged(90)]).isEmpty,
                     "a Mac plugged in above the threshold says nothing")
        suite.expect(run([on(70), on(85)]).isEmpty, "the hint is only for charging")
        suite.expect(run([plugged(98), plugged(100)]).isEmpty && run([plugged(99, charging: false), plugged(100)]).isEmpty,
                     "plugged in above the threshold, reaching full is left to the small notice")
        var high90 = ZenithBatterySettings()
        high90.high = 90
        suite.expect(run([plugged(70), plugged(85), plugged(90)], settings: high90) == [.chargeLimit(percent: 90)],
                     "the charge threshold follows the setting")
        high90.highOn = false
        suite.expect(run([plugged(70), plugged(90)], settings: high90).isEmpty, "the hint switched off says nothing")
    }

    private static func charger(_ suite: TestSuite) {
        suite.expect(run([on(46), plugged(46), on(46)]) == [.charging(percent: 46), .unplugged(percent: 46)],
                     "plugging in and pulling out each show")
        var off = ZenithBatterySettings()
        off.chargerOn = false
        suite.expect(run([on(46), plugged(46), on(46)], settings: off).isEmpty, "the charger notice switched off says nothing")
        suite.expect(run([on(46), ZenithBatteryReading(percent: nil, external: true, charging: true)])
                        == [.charging(percent: nil)],
                     "a charger without a percentage still shows")
        suite.expect(run([on(140), plugged(140)]) == [.charging(percent: 100)], "a percentage out of range is clamped")
    }

    private static func smallNotice(_ suite: TestSuite) {
        let all = ZenithBatterySettings()
        var none = ZenithBatterySettings()
        none.lowOn = false; none.criticalOn = false; none.chargerOn = false
        suite.expect(ZenithBatteryNoticeState.replacesSmallNotice(before: on(46), after: plugged(46), settings: all)
                     && !ZenithBatteryNoticeState.replacesSmallNotice(before: on(46), after: plugged(46), settings: none),
                     "the capsule replaces the island’s small charger notice only while it is on")
        suite.expect(ZenithBatteryNoticeState.replacesSmallNotice(before: on(21), after: on(20), settings: all)
                     && !ZenithBatteryNoticeState.replacesSmallNotice(before: on(21), after: on(20), settings: none),
                     "and its small low battery notice")
        suite.expect(!ZenithBatteryNoticeState.replacesSmallNotice(before: plugged(99), after: plugged(100, charging: false),
                                                                     settings: all),
                     "a full charge keeps the small notice")
    }

    // MARK: Queue

    private static func notice(_ kind: ZenithNotice.Kind, _ key: String? = nil, title: String = "") -> ZenithNotice {
        ZenithNotice(kind: kind, key: key ?? kind.rawValue, title: title.isEmpty ? kind.rawValue : title, subtitle: "")
    }

    private static func queueOrder(_ suite: TestSuite) {
        var queue = ZenithNoticeQueue()
        _ = queue.enqueue(notice(.download, "a"), now: 0)
        _ = queue.enqueue(notice(.download, "b"), now: 0)
        _ = queue.enqueue(notice(.batteryLow), now: 0)
        _ = queue.enqueue(notice(.audio), now: 0)
        let first = queue.next(now: 1)
        suite.expect(first?.kind == .batteryLow && queue.current == first,
                     "the highest priority shows first and becomes the current notice")
        queue.finishCurrent()
        suite.expect(queue.next(now: 1)?.kind == .audio, "then the next priority")
        queue.finishCurrent()
        suite.expect(queue.next(now: 1)?.key == "a", "equal priorities show in arrival order")
        queue.finishCurrent()
        suite.expect(queue.next(now: 1)?.key == "b" && queue.isEmpty, "one at a time until none waits")
        queue.finishCurrent()
        suite.expect(queue.next(now: 1) == nil && queue.current == nil, "an empty queue shows nothing")

        var busy = ZenithNoticeQueue()
        _ = busy.enqueue(notice(.download, "d"), now: 0)
        _ = busy.next(now: 0)
        suite.expect(busy.enqueue(notice(.batteryCritical, ZenithNoticeKey.batteryLow), now: 0) == .preempts,
                     "a higher priority notice cuts a lower one short")
        suite.expect(busy.enqueue(notice(.download, "e"), now: 0) == .queued
                     && busy.enqueue(notice(.chargeLimit), now: 0) == .queued,
                     "an equal or lower one waits")
    }

    private static func queueCoalescing(_ suite: TestSuite) {
        var queue = ZenithNoticeQueue()
        _ = queue.enqueue(notice(.audio, "audio.airpods pro", title: "40"), now: 0)
        suite.expect(queue.enqueue(notice(.audio, "audio.airpods pro", title: "80"), now: 0) == .coalesced
                     && queue.pending.count == 1 && queue.pending.first?.notice.title == "80",
                     "a duplicate waiting notice is updated in place, not queued twice")
        _ = queue.next(now: 0)
        suite.expect(queue.enqueue(notice(.audio, "audio.airpods pro", title: "90"), now: 0) == .updatedCurrent
                     && queue.current?.title == "90" && queue.isEmpty,
                     "a duplicate of the notice on screen updates it")

        var battery = ZenithNoticeQueue()
        _ = battery.enqueue(notice(.batteryLow, ZenithNoticeKey.batteryLow), now: 0)
        _ = battery.next(now: 0)
        suite.expect(battery.enqueue(notice(.batteryCritical, ZenithNoticeKey.batteryLow), now: 0) == .updatedCurrent
                     && battery.current?.kind == .batteryCritical,
                     "the very low warning takes over the low one on screen")
        suite.expect(ZenithNoticeKey.audio(" AirPods Pro ") == ZenithNoticeKey.audio("airpods pro")
                     && ZenithNoticeKey.download(URL(fileURLWithPath: "/tmp/a/../a/x.jpg"))
                        == ZenithNoticeKey.download(URL(fileURLWithPath: "/tmp/a/x.jpg")),
                     "keys ignore case, spacing and path spelling")
    }

    private static func queueSuperseding(_ suite: TestSuite) {
        var queue = ZenithNoticeQueue()
        _ = queue.enqueue(notice(.download, "busy"), now: 0)
        _ = queue.next(now: 0)
        _ = queue.enqueue(notice(.batteryLow, ZenithNoticeKey.batteryLow), now: 0)
        _ = queue.enqueue(notice(.charging, ZenithNoticeKey.power), now: 0)
        suite.expect(!queue.pending.contains { $0.notice.key == ZenithNoticeKey.batteryLow },
                     "plugging in makes a waiting low battery warning moot")
        _ = queue.enqueue(notice(.chargeLimit, ZenithNoticeKey.chargeLimit), now: 0)
        _ = queue.enqueue(notice(.unplugged, ZenithNoticeKey.power), now: 0)
        suite.expect(!queue.pending.contains { $0.notice.key == ZenithNoticeKey.chargeLimit }
                     && queue.pending.filter { $0.notice.key == ZenithNoticeKey.power }.count == 1
                     && queue.pending.first { $0.notice.key == ZenithNoticeKey.power }?.notice.kind == .unplugged,
                     "pulling the charger out ends the charge hint, and the latest power state wins")
    }

    private static func queueCapacityAndExpiry(_ suite: TestSuite) {
        var queue = ZenithNoticeQueue()
        _ = queue.enqueue(notice(.batteryLow, ZenithNoticeKey.batteryLow), now: 0)
        for index in 0..<ZenithNoticeQueue.capacity { _ = queue.enqueue(notice(.download, "d\(index)"), now: 0) }
        suite.expect(queue.pending.count == ZenithNoticeQueue.capacity
                     && queue.pending.contains { $0.notice.kind == .batteryLow }
                     && !queue.pending.contains { $0.notice.key == "d0" },
                     "a full queue drops its oldest least important notice")
        var stale = ZenithNoticeQueue()
        _ = stale.enqueue(notice(.audio), now: 0)
        _ = stale.enqueue(notice(.batteryLow, ZenithNoticeKey.batteryLow), now: 0)
        suite.expect(stale.next(now: 20)?.kind == .batteryLow, "a low battery warning waits longer for the island")
        stale.finishCurrent()
        suite.expect(stale.next(now: 20) == nil, "headphones that waited too long are no longer news")
        var waiting = ZenithNoticeQueue()
        _ = waiting.enqueue(notice(.audio), now: 0)
        waiting.prune(now: 5)
        let kept = !waiting.isEmpty
        waiting.prune(now: 13)
        suite.expect(kept && waiting.isEmpty, "a queue waiting on a busy island empties once its notices are stale")
        var removed = ZenithNoticeQueue()
        _ = removed.enqueue(notice(.audio), now: 0)
        _ = removed.enqueue(notice(.download), now: 0)
        removed.removeAll { $0.kind == .audio }
        suite.expect(removed.pending.map(\.notice.kind) == [.download], "turning a notice off drops what waits for it")
    }

    // MARK: Audio and formatting

    private static func audio(_ suite: TestSuite) {
        let devices: [(name: String, percent: Int)] = [("AirPods Pro", 80), ("airpods pro ", 64), ("Magic Mouse", 12),
                                                       ("AirPods Pro", 140)]
        suite.expect(ZenithAudioNotice.batteryPercent(named: "AirPods Pro", in: devices) == 64,
                     "the lowest valid reading of the device is the one shown")
        suite.expect(ZenithAudioNotice.batteryPercent(named: "Beats Studio", in: devices) == nil
                     && ZenithAudioNotice.batteryPercent(named: " ", in: devices) == nil,
                     "a device without a reading has no ring")
        suite.expect(["airpods", "airpodspro", "airpodsmax", "headphones", "hifispeaker"].allSatisfy(ZenithAudioNotice.isAudio)
                     && !["keyboard", "computermouse", "gamecontroller", "car"].contains(where: ZenithAudioNotice.isAudio),
                     "only headphones and speakers get the audio notice")
        suite.expect(ZenithAudioNotice.isAudio(symbol: NotchAccessorySupport.symbol(name: "AirPods Pro", majorClass: 0x04, minorClass: 0x01))
                     && ZenithAudioNotice.isAudio(symbol: NotchAccessorySupport.symbol(name: "Kitchen", majorClass: 0x04, minorClass: 0x05))
                     && !ZenithAudioNotice.isAudio(symbol: NotchAccessorySupport.symbol(name: "Keys", majorClass: 0x05, minorClass: 0x10)),
                     "the accessory catalog’s symbols decide what counts as audio")
    }

    private static func formatting(_ suite: TestSuite) {
        suite.expect(ZenithNoticeFormat.filling("%d% Battery", percent: 20) == "20% Battery"
                     && ZenithNoticeFormat.filling("%%d pil", percent: 20) == "%20 pil"
                     && ZenithNoticeFormat.filling("Batterie %d %", percent: 120) == "Batterie 100 %",
                     "the battery title places the percentage where the language puts it")
        suite.expect(ZenithNoticeFormat.titled("Charging", percent: 80) == "Charging · 80%"
                     && ZenithNoticeFormat.titled("Charging", percent: nil) == "Charging",
                     "a title with its percentage after a middle dot")
        suite.expect(ZenithNoticeFormat.batteryTone(100) == .green && ZenithNoticeFormat.batteryTone(21) == .green
                     && ZenithNoticeFormat.batteryTone(20) == .amber && ZenithNoticeFormat.batteryTone(11) == .amber
                     && ZenithNoticeFormat.batteryTone(10) == .red && ZenithNoticeFormat.batteryTone(0) == .red,
                     "green while there is plenty, amber when low, red when very low")
        let size = ByteCountFormatter.string(fromByteCount: 1_600_000, countStyle: .file)
        suite.expect(ZenithNoticeFormat.downloadDetail(bytes: 1_600_000, folder: "Downloads") == size + " · Downloads"
                     && ZenithNoticeFormat.downloadDetail(bytes: nil, folder: "Downloads") == "Downloads"
                     && ZenithNoticeFormat.downloadDetail(bytes: 10, folder: "") == ByteCountFormatter.string(fromByteCount: 10, countStyle: .file),
                     "a download reads its size and folder, or the folder alone")
        suite.expect(ZenithNoticeTiming.duration(.download) == 4 && ZenithNoticeTiming.duration(.batteryLow) > 4
                     && ZenithNoticeTiming.contentDelay < ZenithNoticeTiming.springResponse
                     && ZenithNoticeTiming.stagger == 0.04,
                     "about four seconds on screen, longer for a low battery; content starts while the shape grows")
    }

    private static func layout(_ suite: TestSuite) {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let floating = ZenithNoticeLayout.frame(screen: screen, centerX: screen.midX, closedWidth: 200, floats: true,
                                                top: 2, stripHeight: 24)
        suite.expect(floating.width == 380 && floating.height == 62 && floating.maxY == screen.maxY - 2
                     && floating.midX == screen.midX,
                     "a floating capsule is 380 × 62, centred where the island floats")
        suite.expect((360...420).contains(floating.width) && (56...64).contains(floating.height),
                     "within the measured range")
        let hanging = ZenithNoticeLayout.frame(screen: screen, centerX: screen.midX, closedWidth: 480, floats: false,
                                               top: 0, stripHeight: 32)
        suite.expect(hanging.width == ZenithNoticeLayout.maximumWidth && hanging.maxY == screen.maxY
                     && hanging.height == 32 + ZenithNoticeLayout.rowHeight - 6
                     && ZenithNoticeLayout.rowTop(floats: false, stripHeight: 32) + ZenithNoticeLayout.rowHeight == hanging.height,
                     "a hanging capsule keeps the island's width up to 420 and puts its row below the camera")
        let narrow = CGRect(x: 0, y: 0, width: 300, height: 600)
        let fitted = ZenithNoticeLayout.frame(screen: narrow, centerX: 150, closedWidth: 100, floats: true, top: 0, stripHeight: 24)
        suite.expect(fitted.width == 276 && fitted.minX >= narrow.minX + 12 && fitted.maxX <= narrow.maxX - 12,
                     "a narrow display keeps the capsule inside its edges")
    }

    private static func settings(_ suite: TestSuite) {
        let registered = Defaults.registeredDefaults
        suite.expect(registered[DefaultsKey.notchNoticeBatteryLow] as? Bool == true
                     && registered[DefaultsKey.notchNoticeBatteryCritical] as? Bool == true
                     && registered[DefaultsKey.notchNoticeBatteryHigh] as? Bool == true
                     && registered[DefaultsKey.notchNoticeCharger] as? Bool == true
                     && registered[DefaultsKey.notchNoticeAudio] as? Bool == true
                     && registered[DefaultsKey.notchNoticeDownload] as? Bool == true
                     && registered[DefaultsKey.notchNoticeBatteryLowLevel] as? Int == 20
                     && registered[DefaultsKey.notchNoticeBatteryCriticalLevel] as? Int == 10
                     && registered[DefaultsKey.notchNoticeBatteryHighLevel] as? Int == 80,
                     "every notice is on by default, at 20%, 10% and 80%, and registered so it joins backups")
        let suiteName = "ZenithNoticeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { return suite.expect(false, "test defaults") }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.register(defaults: registered)
        suite.expect(ZenithBatterySettings.current(in: defaults) == ZenithBatterySettings(), "the defaults read back")
        defaults.set(25, forKey: DefaultsKey.notchNoticeBatteryLowLevel)
        defaults.set(7, forKey: DefaultsKey.notchNoticeBatteryCriticalLevel)
        defaults.set(false, forKey: DefaultsKey.notchNoticeBatteryHigh)
        let read = ZenithBatterySettings.current(in: defaults)
        suite.expect(read.low == 25 && read.critical == 10 && !read.highOn && read.high == 80,
                     "a chosen level reads back; a level outside the choices falls back")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.notices(language)
            let all = [text.section, text.caption, text.lowBattery, text.veryLowBattery, text.chargeReaches, text.chargeHint,
                       text.charger, text.audio, text.download, text.batteryTitle, text.lowPowerAction, text.lowPowerOn,
                       text.charging, text.chargerConnected, text.onBattery, text.chargerRemoved, text.connected]
            suite.expect(all.allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("\u{2014}") },
                         "\(language.rawValue): notice strings are filled, with curly apostrophes and no em dash")
            suite.expect(text.batteryTitle.contains("%d") && !ZenithNoticeFormat.filling(text.batteryTitle, percent: 20).contains("%d")
                         && ZenithNoticeFormat.filling(text.batteryTitle, percent: 20).contains("20"),
                         "\(language.rawValue): the battery title places the percentage")
        }
    }
}
