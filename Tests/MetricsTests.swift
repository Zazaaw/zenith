// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

// The runner lists every independently selectable suite. A filtered run says
// exactly which suites ran; an unknown or empty selection is an error.
@main
struct MetricsTests {
    static func main() {
        let suite = TestSuite()
        let groups: [(String, () -> Void)] = [
            ("harness", {
                TestHarnessTests.run(suite)
                PreferenceNamespaceTests.run(suite)
            }),
            ("metrics", {
                MetricsFeatureTests.run(suite)
                DiskCapacityTests.run(suite)
                MenuBarBatteryWarningTests.run(suite)
                ProcessNameContract.run(suite)
                SystemMonitorCPUTests.run(suite)
                SystemMonitorPlanTests.run(suite)
                SystemSectionBreakdownTests.run(suite)
            }),
            ("clipboard", {
                ClipboardFeatureTests.run(suite)
                PastePlainTests.run(suite)
            }),
            ("pointer-input", {
                PointerOnDisplayContract.run(suite)
                PointerInputFeatureTests.run(suite)
                MouseSpacesGestureTapTests.run(suite)
                SmoothScrollRoutingTests.run(suite)
                KeyboardDebounceTapTests.run(suite)
                PointerDisplayLookupContract.run(suite)
                SuperKeyTapContract.run(suite)
                PointerScreenContract.run(suite)
            }),
            ("scroll-modifier", {
                ScrollHorizontalModifierTests.run(suite)
                ScrollZoomFocusTests.run(suite)
            }),
            ("scroll-speed", { ScrollSpeedTests.run(suite) }),
            ("linear-scroll", { LinearScrollTapTests.run(suite) }),
            ("preferences", { PreferencesFeatureTests.run(suite) }),
            ("app-management", {
                AppManagementFeatureTests.run(suite)
                DiskImageHomebrewTests.run(suite)
            }),
            ("window-layout", { WindowLayoutFeatureTests.run(suite) }),
            ("media", { MediaFeatureTests.run(suite) }),
            ("media-layout", { MediaWorkspaceLayoutTests.run(suite) }),
            ("mixer", {
                MixerRenderContinuityTests.run(suite)
                MixerNativeDragTests.run(suite)
                MixerOutputAdjustmentContract.run(suite)
                MixerHeadphonesDisconnectContract.run(suite)
                MixerLevelCompensationContract.run(suite)
                MixerTapConfigurationTests.run(suite)
                MixerGainRampContract.run(suite)
                SoundOutputSwitchContract.run(suite)
                MixerUniversalRoutingContract.run(suite)
                AirPlayRingBufferContract.run(suite)
                AirPlayRouteContract.run(suite)
                AirPlayMixLimiterContract.run(suite)
                AirPlayStreamRegistryContract.run(suite)
                AirPlayFeedDriverContract.run(suite)
                AirPlayRateChangeContract.run(suite)
                AirPlayPrivateAPIContract.run(suite)
                AirPlayAvailabilityContract.run(suite)
                AirPlayConcurrentLanesContract.run(suite)
                AirPlayBacklogContract.run(suite)
                AirPlayIdleContract.run(suite)
                MixerInputVolumeContract.run(suite)
                MixerPercentKeyTests.run(suite)
                MixerFeatureTests.run(suite)
            }),
            ("audio-priority", { AudioPriorityTests.run(suite) }),
            ("shelf", { ShelfFeatureTests.run(suite) }),
            ("overlays", { OverlayPanelTests.run(suite) }),
            ("updates", {
                UpdateFeatureTests.run(suite)
                LaunchAtLoginSettingsTests.run(suite)
                PostUpdateStatusItemRecoveryTests.run(suite)
                UpdateAdminInstallContract.run(suite)
                UpdateHighlightsTests.run(suite)
                UpdateIntroFlowTests.run(suite)
                ReleaseDigestTests.run(suite)
            }),
            ("repository", { RepositoryFeatureTests.run(suite) }),
            ("screenshots", {
                ScreenshotClipboardTests.run(suite)
                ScreenshotAutoCopyTests.run(suite)
                ScreenshotCanvasSupportTests.run(suite)
                ScreenshotImageLayerTests.run(suite)
                ScreenshotImageImportTests.run(suite)
                ScreenshotImageFileTests.run(suite)
                ScreenshotCanvasModelTests.run(suite)
                ScreenTextCompletionTests.run(suite)
                ScreenshotOCRControlTests.run(suite)
                ScreenshotPreviewHoverTests.run(suite)
                ScreenshotWatermarkTests.run(suite)
                ScreenshotFeatureTests.run(suite)
                RecentCapturePanelTests.run(suite)
                ScreenshotSpotlightEditingTests.run(suite)
                ScreenshotShareCompletionTests.run(suite)
                ScreenshotAutoShelfTests.run(suite)
                ScreenshotScrollingCaptureTests.run(suite)
                ScreenshotAttachedCaptureTests.run(suite)
                ScreenCaptureToolPickerTests.run(suite)
            }),
            ("recorder", {
                RecorderGIFWriterTests.run(suite)
                RecorderFastGIFWriterTests.run(suite)
                RecorderFeatureTests.run(suite)
                RecorderZoomAimingTests.run(suite)
                RecorderExportSpeedTests.run(suite)
                RecorderExportControlsTests.run(suite)
                RecorderExportRenderingTests.run(suite)
                RecorderFastGIFExportTests.run(suite)
            }),
            ("command-bar", {
                CommandBarFeatureTests.run(suite)
                CommandBarSelectionTests.run(suite)
            }),
            ("transient-paste", { TransientPasteTests.run(suite) }),
            ("notch-music", { NotchMusicExtrasTests.run(suite) }),
            ("notch", {
                NotchTests.run(suite)
                NotchCompactTests.run(suite)
                NotchCapsuleTests.run(suite)
                PlainTextLineMoverTests.run(suite)
                NotchVolumeKeyTests.run(suite)
                NotchSettingsTabRowTests.run(suite)
                NotchPresentationProbeArgumentTests.run(suite)
                ZenithIslandTests.run(suite) // Zenith fork
            }),
            ("switcher-model", { SwitcherModelFeatureTests.run(suite) }),
            ("agents", { NotchAgentTests.run(suite) }),
            ("features", {
                FeatureCatalogTests.run(suite)
                MenuPanelSectionGateContract.run(suite)
            }),
            ("shortcut-clearing", { ShortcutClearingTests.run(suite) }),
            ("utilities", {
                UtilitiesFeatureTests.run(suite)
                TextSnippetExpansionTests.run(suite)
                QuickTogglesAlertTests.run(suite)
                QuickTogglesQuitAllTests.run(suite)
                QuitAppsRuntimeTests.run(suite)
                PortManagerRefreshTests.run(suite)
            }),
            ("settings", {
                SettingsFeatureTests.run(suite)
                SettingsSearchCoverageTests.run(suite)
                RadialFilePickerTests.run(suite)
                SettingsWindowTests.run { suite.expect($0, $1) }
                NotchSettingsChoiceTests.run(suite)
                MonitorTokenTests.run(suite)
                ZenithAboutTests.run(suite) // Zenith fork
            }),
            ("feature-hub-layout", { FeatureHubLayoutTests.run(suite) }),
            ("display-restoration", {
                DisplayRestorationTests.run(suite)
                BrightnessStepTests.run(suite)
                BrightnessKeyRoutingTests.run(suite)
            }),
            ("speaker-volume", {
                DisplaySpeakerVolumeTests.run(suite)
                MonitorVolumeKeySettingsTests.run(suite)
            }),
            ("software-dimming", { SoftwareDimmingRouteTests.run { suite.expect($0, $1) } }),
            ("capture", {
                ScreenshotSelectionRefreshContract.run(suite)
                ScreenshotCountdownTests.run(suite)
            }),
            ("keyboard", {
                KeyboardFeatureTests.run(suite)
                AssistiveKeyboardTests.run(suite)
                ScreenshotToolShortcutTests.run(suite)
            }),
            ("storage", {
                RecentCaptureStoreTests.run(suite)
                RecorderPresetImageStoreTests.run(suite)
                StorageFeatureTests.run(suite)
                ScratchpadStoreContractTests.run(suite)
            }),
            ("quit-protection", {
                QuitProtectionHUD.progressChecks(suite)
                QuitProtectionRoutingContract.QuitProtectionService.routingChecks(suite)
            }),
            ("scratchpad", { ScratchpadMarkTests.run { suite.expect($0, $1) } }),
            ("recording", {
                RecorderPreparationTests.run(suite)
                RecorderSampleTimingTests.run(suite)
                RecorderWriterTests.run(suite)
                RecorderExportChipTests.run { suite.expect($0, $1) }
            }),
            ("network", {
                NetworkFeatureTests.run(suite)
                SpeedTestTests.run(suite)
                NetworkAddressTests.run { suite.expect($0, $1) }
            }),
            ("app-updates", {
                AppUpdateHandoffTests.run(suite)
                AppUpdatesContract.run(suite)
                AppUpdateRulesContract.run(suite)
            }),
            ("localization", {
                LocalizationTests.run(suite)
                LocalizationFeatureContractTests.run(suite)
            }),
            ("cleaner", {
                CleanerEligibilityTests.run(suite)
                CleanerLastRunContract.run(suite)
                CleanerScanFlowTests.run(suite)
                CleanerLayoutTests.run(suite)
            }),
            ("uninstaller", {
                HomebrewOwnershipTests.run(suite)
                HomebrewOperationLogRetentionTests.run(suite)
                UninstallerFlowTests.run(suite)
                UninstallerTrashTests.run(suite)
                UninstallerBulkSelectionTests.run(suite)
                MixedStateCheckboxTests.run(suite)
                UninstallerCommandBarCleanupTests.run(suite)
                SelfUninstallContract.run(suite)
            }),
            ("force-quit", { ProcessForceQuitTests.run(suite) }),
            ("launcher", { QuickLauncherContract.run(suite) }),
            ("dock-autohide", {
                DockPreviewPositionTests.run(suite)
                DockPreviewScrollTests.run(suite)
                DockAutohideHoldTests.run(suite)
                DockPreviewFrameRestorationTests.run(suite)
            }),
            ("spaces-order", { SpacesOrderTests.run(suite) }),
            ("switcher", {
                SwitcherHoverSelectionTests.run(suite)
                SwitcherAllWindowsTests.run(suite)
                AXWindowResolverTests.run(suite)
                SwitcherSearchLayoutTests.run(suite)
                SwitcherScrollContract.run(suite)
                SwitcherActivationTests.run(suite)
                AXHiddenSpaceLookupTests.run(suite)
                SwitcherWindowCloseTests.run(suite)
                WindowServerCaptureContract.run(suite)
            }),
            ("keep-awake", {
                KeepAwakeCatalogContract.run(suite)
                MenuPanelToggleLabelContract.run(suite)
                KeepAwakeLidSleepTests.run { suite.expect($0, $1) }
                KeepAwakeTimerHandoffTests.run { suite.expect($0, $1) }
            }),
            ("wallpaper", {
                WallpaperContract.run(suite)
                WallpaperThumbnailTests.run(suite)
            }),
            ("emoji", { CommandBarEmojiContract.run(suite) }),
            // Zenith fork.
            ("wakatime", { WakaTimeTests.run(suite) }),
            ("lockscreen-widgets", { LockScreenWidgetsTests.run(suite) }),
            ("lockscreen-terminal", { LockScreenTerminalTests.run(suite) }),
            ("lockscreen-v2", { LockScreenV2Tests.run(suite) }),
            ("lockscreen-settings", { LockScreenSettingsTests.run(suite) }),
            ("lockscreen-jobs", { LockScreenJobFeedTests.run(suite) }),
            ("vercel", { VercelTests.run(suite) }),
            ("gh", { GitHubTests.run(suite) }),
            ("command-activity", { CommandActivityTests.run(suite) }),
            ("export-tracker", { ExportTrackerTests.run(suite) }),
            ("claude-hooks", { ClaudeHooksTests.run(suite) }),
            ("photo-actions", { PhotoActionsTests.run(suite) }),
            ("watermark", { WatermarkTests.run(suite) }),
            ("design-overlay", { DesignOverlayTests.run(suite) }),
            ("screenshot-beautify", { ScreenshotBeautifyTests.run(suite) }),
            ("menubar-hider", { MenuBarHiderTests.run(suite) }),
            ("notices", { ZenithNoticeTests.run(suite) }),
            ("island-room", { IslandRoundThreeTests.run(suite) }),
            ("island-motion", { IslandMotionTests.run(suite) }),
            ("lock-island", { LockIslandTests.run(suite) }),
            ("island-floor", { IslandFloorTests.run(suite) }),
            ("island-fit", { IslandFitTests.run(suite) }), // Zenith fork
            ("reply", { ReplyTests.run(suite) }),
            ("home-layout", { HomeLayoutTests.run(suite) }),
            ("tab-bar", { TabBarTests.run(suite) }),
            ("drop-zones", { DropZonesTests.run(suite) }),
            ("card-import", { CardImportTests.run(suite) }),
            ("card-backup", { BackupTests.run(suite) }), // Zenith fork
            ("dev-servers", { DevServersTests.run(suite) }),
            ("recap", { RecapTests.run(suite) }),
            ("sky", { SkyTests.run(suite) }),
            ("qr", { QRTests.run(suite) }),
            ("workspaces", { WorkspacesTests.run(suite) }),
            ("repo-status", { GitTests.run(suite) }), // the Git page
            ("prompter", { PrompterTests.run(suite) }),
            ("fork-settings-search", { ForkSettingsSearchTests.run(suite) }),
            ("remote-lock", { RemoteControlTests.run(suite) }), // Zenith fork: lock and status from an iPhone
            ("face-unlock-recognition", { FaceUnlockRecognitionTests.run(suite) }), // Zenith fork
            ("face-unlock-liveness", { FaceUnlockLivenessTests.run(suite) }), // Zenith fork: Glance's liveness self-test
        ]
        var selected = Set<String>()
        var listOnly = false
        for argument in CommandLine.arguments.dropFirst() {
            if argument == "--list" {
                listOnly = true
                continue
            }
            guard argument.hasPrefix("--suite="),
                  groups.contains(where: { $0.0 == String(argument.dropFirst(8)) }) else {
                fputs("Unknown test selection: \(argument)\n", stderr)
                exit(2)
            }
            selected.insert(String(argument.dropFirst(8)))
        }
        if listOnly {
            groups.forEach { print($0.0) }
            exit(0)
        }
        // notch-music is a focused subset already executed by notch. Running it
        // twice in an unfiltered pass also repeats stateful adapter fixtures.
        for (name, body) in groups where (selected.isEmpty && name != "notch-music") || selected.contains(name) {
            suite.run(name, body)
        }
        suite.finish()
    }
}
