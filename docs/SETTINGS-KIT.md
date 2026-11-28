# Settings kit

The components every Settings page is built from, in
`Sources/Vorssaint/UI/Settings/Kit/`. Each one has a usage example in its doc
comment. Reference pages: **Mechakey** (`MechakeySettingsPage.swift`, a feature
page) and **General** (`GeneralSettings.swift`, a system page).

## Components

| Component | Use it for |
|---|---|
| `ZenithHero(title:subtitle:chips:isOn:switchLabel:switchHint:category:icon:animation:)` | A feature page's opening: big icon on a breathing aura in the category tint, twinkling stars, the feature's own animation, category label, title, subtitle, chips, and the master switch as the "On" pill. |
| `ZenithSystemHeader(title:subtitle:icon:showsIcon:) { accessory }` | A system page's opening (General, Appearance, Shortcuts, Advanced, About): 50 pt icon, title, one muted line. |
| `ZenithStage(caption:hint:states:selection:height:) { art } footer: { … }` | A preview on the tinted gradient, with state pills under it and a caption beside them. |
| `ZenithSection(_ title:anchor:footer:) { rows }` | A titled group: the title outside a grouped card, 40 pt rows, hairlines between them. `anchor` makes it a search destination. |
| `ZenithRow` | One row. Variants by initializer: `isOn:` (switch), `selection: { options }` (pop-up menu), `value:in:valueLabel:minimumSymbol:maximumSymbol:` (slider), `value:in:step:format:` with an `Int` (stepper), `shortcut: { recorder }`, `button:action:`, `value:navigate:` (row with ›), and `{ trailing }` for anything else. Every variant takes `info:` (behind the ⓘ) and most take `essential:` (under the title). The base row also takes `warning:`. |
| `ZenithMoreOptions(id:anchors:) { rows }` | Advanced rows, folded. Last child of a section. It starts closed, each `id` remembers being opened, and it opens itself when search lands on one of `anchors`. |
| `ZenithVisualPicker(_ title:selection:options:) { value, selected in art }` | A choice shown as pictures: tiles on the stage gradient, label under, accent ring on the chosen one. `ZenithPickerOption(value, label, detail:)`. |
| `ZenithCallout(.info / .warning / .error / .success, title:, text) { actions }` | Something to know or do: a missing permission, a problem, a success. Style Kit 10/20/100 status form. |
| `ZenithFootnote(text)` | The quiet line under a section: a credit, where a setting moved. |
| `ZenithChip(text, dot:)` | A fact in a capsule, for hero chips. Status dots use `ZenithStatus`. |
| `ZenithSectionTitle`, `ZenithRowStack`, `ZenithRowSeparator`, `.zenithGroupBackground()` | Building blocks, for a custom card that should still look like a section. |
| `ZenithKitClock { t, moving in … }` | The clock for your own moving art (see the animation rules). |

## Captions: ⓘ or essential

An explanation goes behind the ⓘ (`info:`). Hovering shows it as a tooltip,
clicking opens it in a popover, and VoiceOver reads it as the row's hint. Keep a
line under the title (`essential:`) only when the person must read it to use the
row: a permission, why the row is off, a consequence they cannot undo. A current
problem with the row's value (a refused shortcut) goes in `warning:`. Anything
longer, or with a button, is a `ZenithCallout`.

`ZenithCaptionRule` holds this decision. Old `SettingsRow(caption:)` calls follow
it too: the caption becomes the ⓘ unless you pass `essential: true`.

## Recipes

Pages are a `ScrollView` with a `VStack(alignment: .leading, spacing: 18)`,
`.frame(maxWidth: 760).frame(maxWidth: .infinity).padding(22)`. Settings puts no
title above a page that draws its own; add the page to `ownHeader` in
`SettingsView.zenithPageTitle` when you give it a hero or header.

**Feature page** (one feature with a master switch: Mechakey, Translate,
Meetings, Batteries, Lock Screen, Shelf, …)

1. `ZenithHero(…, isOn: enabled, switchLabel: "Enable X", animation: .x)` with
   `.zenithSectionAnchor(.zenithX, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)`
   when the page's main anchor used to sit on its header. Chips: two or three short
   facts (current choice, a count, the shortcut). The On/Off chip is added for you.
2. A `ZenithCallout(.warning, …)` for a missing permission, only while it is missing.
3. The preview: the page's existing `…PreviewCard` (it already draws on the stage),
   or a `ZenithStage` with art of its own.
4. The main choice as a `ZenithVisualPicker` when it is visual (packs, styles, layouts).
5. `ZenithSection`s of `ZenithRow`s, advanced rows in `ZenithMoreOptions` at the
   end of the last one, with their anchors in `anchors:`.
6. Credits and notes as `ZenithFootnote`.

**System page** (General, Appearance, Shortcuts, Advanced, About)

1. `ZenithSystemHeader(title:subtitle:)`.
2. The preview card, if the page has one.
3. `ZenithSection`s; an untitled one is fine for the first, short group.

**Tool collection page** (several tools on one page: Sleep, Brightness, System Monitor)

1. `ZenithSystemHeader`, or a `ZenithHero` without `isOn` when the page reads as one feature.
2. The shared preview card, whose states pick the tool.
3. One `ZenithSection(tool name, anchor: .tool)` per tool, its switch as the first
   row, its options after it, rarely used ones in `ZenithMoreOptions(id: "page.tool")`.

**List page** (Kill Process, Port Manager, Uninstaller, Homebrew, exclusion lists)

1. `ZenithSystemHeader` with the list's main action as the accessory (Refresh, Add).
2. Optional preview.
3. A `ZenithSection` per list: a search or filter row first, then one row per item
   (`ZenithRow(name, info: path) { actions }`, or a custom row) inside a `ForEach`.
   Long lists keep their own `List`/`LazyVStack` inside `.zenithGroupBackground()`.
4. The empty state as `ZenithCallout(.info, …)`.

Grouped `Form` pages already draw their sections outside rounded boxes and get the
new title and stage without edits. Converting one means replacing the `Form` with
the recipe above. Keep every `settingsFormSectionAnchor` as a `ZenithSection(anchor:)`
or a `.zenithSectionAnchor`.

## Category tints

`ZenithCategoryTint.of(group)` in `ZenithKitSupport.swift` is the one table: a
pair (`light`, `deep`), a three-stop Dark Mode stage and pastel Light Mode stops
for each `SettingsSidebarGroup`. The tiles and Zenith's own pages share the
indigo-to-coral stage of the General mockup. From Orbit is amber (the hero
mockup). The sidebar's fallback symbols read the same table (grey for Zenith's
own pages).

Components take the tint of the page Settings shows (`\.zenithTint`, from
`\.settingsPageIcon`). Wrap a view in `.zenithCategory(.island)` to show another
category's tint, and pass `category: "AI"` to a hero to word its label differently.
Colour stays calm: tints are for the aura, the stage and the label only. Status
uses `ZenithStatus`, controls use the system accent.

## Hero animations

A feature's animation is a type conforming to `ZenithHeroAnimation` plus a static
member, so a page writes `animation: .mechakey`. It draws on a 190 pt square
centred on the icon with `ZenithHeroArtContext`: `t` (seconds), `tint`, `dark`,
`icon` (the page's icon at 88 pt from the bitmap cache) and `base` (its empty
squircle, for art that draws its own glyph). Available: `.icon` (default, gentle
float), `.mechakey`, `.translate`, `.meetings`, `.shelf`, `.batteries`,
`.lockScreen`. Add new ones to `ZenithHeroAnimations.swift`. The Everyday and
Devices pages keep theirs in `ZenithHeroAnimationsEveryday.swift`: `.clipboard`,
`.finderTools`, `.mediaTools`, `.urlCleaner`, `.textSnippets`, `.pocket`,
`.remote`, `.faceUnlock`. Orbit wave 2's are in `ZenithHeroAnimationsWave2.swift`:
`.removeBackground`, `.emojiPicker`, `.calculator`. The Privacy pages keep theirs
in `ZenithHeroAnimationsPrivacy.swift`: `.appLock`, and Privacy Blur's in
`ZenithHeroAnimationsBlur.swift`: `.privacyBlur`. The System and Apps pages keep
theirs in `ZenithHeroAnimationsSystem.swift`: `.systemMonitor`, `.fanControl`,
`.sleep`, `.brightness`, `.menuBar`, `.commandBar`, `.cleaner`, `.uninstaller`,
`.homebrew`, `.appUpdates`, `.killProcess`, `.portManager`.

Rules:

- One `TimelineView` drives the hero (`ZenithKitClock`). It runs only while the
  page is shown and the window is visible and unoccluded, and never under Reduce
  Motion or while Appearance's battery saver is saving (`ZenithKitMotionRule`).
  Otherwise it holds `t = 1.1`, so make that frame read well on its own.
- No timers, `@State` animations, `.repeatForever` or blur in art. Draw a few
  shapes from `t`. Loops of 0.5, 1, 1.6, 2, 4 or 8 s (the clock wraps at 80 s).
- Big icons always come from the bitmap cache (`context.icon`, `ZenithHeroIcon`,
  `SettingsDestinationIcon(rich: true)`), never a live `OrbitIconView`.
- Stage art that moves uses `ZenithKitClock` too (see `MechakeyStageArt`).

## What changed globally

These old components now draw in the kit's style, so every page changed at once:

| Old | Now |
|---|---|
| `SettingsCard(title:)` | Section title outside, grouped card (14 pt inset, 14 pt radius). Content and explicit `Divider()`s are kept as they were. |
| `SettingsRow(symbol:title:badge:caption:)` | No icon tile (`symbol` is ignored). Caption → ⓘ, or under the title with `essential: true`. `settingsRowTextInset` is 0. |
| `SettingsPageHeader`, `ZenithPageTitle` | `ZenithSystemHeader` (also the title Settings puts above Form pages). |
| `ZenithSettingsPreviewCard` (every page preview) | Drawn on `ZenithStage` in the page's tint: the picture centred at its aspect ratio (230 pt high at most), state pills, caption, the outlined part as an accent hint. States, highlight and click-to-jump work as before. The fold is gone; `id` is kept for callers. |

## Accessibility

Check Light and Dark Mode, Increase Contrast (stronger hairlines and borders),
Reduce Transparency (opaque cards), Reduce Motion (still hero), keyboard focus
(pills, tiles, ⓘ, More options and switches are focusable buttons) and VoiceOver
(the master pill and row switches read as switches named by their title, tiles as
selected buttons, the ⓘ text as the row's hint).

## Checking a page

`nice -n 15 ./build.sh --dev`, then `ONLY=kit Tools/IslandCatalog/render.sh <folder>`
renders the kit's pages offscreen in Dark and Light Mode. Add your page to
`CatalogKitShots.swift` to render it too. `./build.sh --dev --test-suite=settings-kit`
tests the kit's rules.
