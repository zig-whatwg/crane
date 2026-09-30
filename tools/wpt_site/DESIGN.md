---
name: Crane WPT Results
description: Crane's own web-platform-tests record, set as a living standard - numbered sections, conformance and tests boxes, every figure traced to a run.
colors:
  paper: "#ffffff"
  paper-2: "#f7f8f9"
  ink: "#202124"
  ink-2: "#5a5e63"
  rule: "#d9dce0"
  rule-strong: "#b9bec4"
  link: "#0b57a8"
  link-visited: "#5a3d99"
  focus: "#0b57a8"
  here: "#e8f0fa"
  select: "#cfe0f5"
  pass: "#2e7d32"
  pass-2: "#a9cfab"
  issue: "#b3261e"
  issue-wash: "#fbeceb"
  empty: "#c9cdd2"
  unrun: "#eceef0"
  note: "#f4ecd2"
  note-ink: "#5c4a12"
  note-rule: "#e2d5ab"
typography:
  display:
    fontFamily: "Source Serif 4, Iowan Old Style, Georgia, serif"
    fontSize: "clamp(2.1rem, 1.3rem + 2.6vw, 3.05rem)"
    fontWeight: 620
    lineHeight: 1.06
    letterSpacing: "-0.018em"
    fontVariation: "\"opsz\" 60"
  headline:
    fontFamily: "Source Serif 4, Iowan Old Style, Georgia, serif"
    fontSize: "1.6rem"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.01em"
    fontVariation: "\"opsz\" 36"
  body:
    fontFamily: "Source Serif 4, Iowan Old Style, Georgia, serif"
    fontSize: "1.0625rem"
    fontWeight: 400
    lineHeight: 1.6
  subtest-name:
    fontFamily: "Source Serif 4, Iowan Old Style, Georgia, serif"
    fontSize: "0.92rem"
    fontWeight: 400
    lineHeight: 1.4
  subtitle:
    fontFamily: "Public Sans, Segoe UI, system-ui, sans-serif"
    fontSize: "1.02rem"
    fontWeight: 500
    lineHeight: 1.4
  data:
    fontFamily: "Public Sans, Segoe UI, system-ui, sans-serif"
    fontSize: "0.9rem"
    fontWeight: 400
    lineHeight: 1.4
    fontFeature: "\"tnum\" 1"
  section-number:
    fontFamily: "Public Sans, Segoe UI, system-ui, sans-serif"
    fontSize: "1.05rem"
    fontWeight: 500
    lineHeight: 1
    fontFeature: "\"tnum\" 1"
  label:
    fontFamily: "Public Sans, Segoe UI, system-ui, sans-serif"
    fontSize: "0.8rem"
    fontWeight: 650
    lineHeight: 1.2
    letterSpacing: "0.02em"
  status-mark:
    fontFamily: "Public Sans, Segoe UI, system-ui, sans-serif"
    fontSize: "0.72rem"
    fontWeight: 650
    lineHeight: 1.4
    letterSpacing: "0.05em"
  path:
    fontFamily: "Source Code Pro, ui-monospace, SF Mono, Menlo, monospace"
    fontSize: "0.88em"
    fontWeight: 400
    fontFeature: "\"liga\" 0, \"calt\" 0"
  message:
    fontFamily: "Source Code Pro, ui-monospace, SF Mono, Menlo, monospace"
    fontSize: "0.78rem"
    fontWeight: 400
    lineHeight: 1.45
rounded:
  hairline: "1px"
  sm: "2px"
  md: "3px"
spacing:
  gutter: "3.25rem"
  rail: "17.5rem"
  measure: "68ch"
  doc-max: "78rem"
  box-inset: "1rem"
  stack: "1.5rem"
  section: "3rem"
components:
  box:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    typography: "{typography.data}"
    rounded: "{rounded.md}"
    padding: "0.85rem 1rem 1rem"
  box-title:
    textColor: "{colors.ink-2}"
    typography: "{typography.label}"
    padding: "0.7rem 1rem 0.6rem"
  meter:
    backgroundColor: "{colors.unrun}"
    rounded: "{rounded.hairline}"
    height: "0.5rem"
  meter-mini:
    backgroundColor: "{colors.unrun}"
    rounded: "{rounded.hairline}"
    height: "0.35rem"
    width: "4.5rem"
  gate-clean:
    textColor: "{colors.pass}"
    typography: "{typography.status-mark}"
    padding: "0.2rem 0.35rem"
  gate-quiet:
    textColor: "{colors.ink-2}"
    typography: "{typography.status-mark}"
    padding: "0.2rem 0.35rem"
  gate-blocking:
    backgroundColor: "{colors.issue-wash}"
    textColor: "{colors.issue}"
    typography: "{typography.status-mark}"
    rounded: "{rounded.sm}"
    padding: "0.2rem 0.35rem"
  mark-pass:
    textColor: "{colors.pass}"
    typography: "{typography.status-mark}"
  mark-fail:
    textColor: "{colors.ink}"
    typography: "{typography.status-mark}"
  mark-other:
    textColor: "{colors.ink-2}"
    typography: "{typography.status-mark}"
  note:
    backgroundColor: "{colors.note}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: "1rem 1.25rem 1.05rem"
  note-label:
    textColor: "{colors.note-ink}"
  filter-segment:
    textColor: "{colors.ink-2}"
    rounded: "{rounded.md}"
    padding: "0.3rem 0.55rem"
  filter-segment-pressed:
    backgroundColor: "{colors.here}"
    textColor: "{colors.link}"
  rail:
    backgroundColor: "{colors.paper-2}"
    textColor: "{colors.ink}"
    width: "{spacing.rail}"
  rail-entry:
    textColor: "{colors.ink}"
    padding: "0.3rem 1.25rem 0.3rem 1rem"
  rail-entry-current:
    backgroundColor: "{colors.here}"
    textColor: "{colors.link}"
  file-detail:
    backgroundColor: "{colors.paper}"
    rounded: "{rounded.md}"
    padding: "0.7rem 0.9rem 0.8rem"
  failure-message:
    backgroundColor: "{colors.paper-2}"
    textColor: "{colors.ink}"
    typography: "{typography.message}"
    rounded: "{rounded.sm}"
    padding: "0.35rem 0.5rem"
---

# Design System: Crane WPT Results

## Overview

**Creative North Star: "The Living Standard"**

The site reads as a specification document of the WHATWG and W3C kind, not a CI dashboard. It has a numbered contents rail, a header block that says which version this is, a "Status of this document" section that states scope before any number appears, one numbered section per suite, and a closing "Revision history" section. Spec-paper white, near-black ink, link blue and hairline rules carry the page. Colour is kept for meaning: conformance green, issue red and a pale amber for notes, each held to one job.

Density follows a working reference document: long-form serif prose at a comfortable measure, then compact tabular data in bordered boxes. Every total sits in a sentence or a box that also says what it counts. The build refuses the dashboard vocabulary: no stat cards, no hero figure and no headline pass percentage. The largest numeral on the page is a suite's subtest count at 1rem, set in its box. Drill-down happens in place: a suite's Tests box opens into directories, files and each file's subtests without leaving the document, and everything that opens has a permanent link.

Built code-led from the direction contract (THESIS / OWN-WORLD / STORY / FIRST VIEWPORT / FORM: "Living Standard"), with no approved comp. Where the contract and the build differ, this file records the build.

**Key Characteristics:**
- Spec-document grammar: front matter, numbered sections, back matter, numbered margins, ¶ self-links.
- Three faces, three jobs: book serif for prose, a workhorse sans with tabular figures for data, monospace for paths and messages.
- Colour is semantic and rationed. Green means passing, red means blocking and amber means a note.
- Flat paper with hairline borders; depth comes from rules and a faint grey tint, never from shadows.
- One authored motion: rows open in place.
- Light and dark renditions from the same token names.

## Colors

The palette is restrained: neutral paper and ink with a single blue for navigation, plus three rationed semantic hues (green, red and amber), each held to one meaning.

### Primary
- **Spec Link Blue** (`link`): every hyperlink, the focus ring (`focus` is the same value, kept as its own token), and the "you are here" state: the rail's current entry, the pressed filter segment and the spark-link text. Links underline at 1px, 0.18em offset, with the underline at 45% of the link colour until hover.
- **Visited Violet** (`link-visited`): visited links only.
- **Here Wash** (`here`): the pale blue behind the rail's current entry and the pressed filter segment, and the flash on a permalink target.
- **Selection Blue** (`select`): text selection only.

### Secondary
- **Conformance Green** (`pass`): files that pass every subtest (meter segment, legend key, the PASS gate word) and subtest PASS marks.
- **Partial Sage** (`pass-2`): files with some subtests failing, only as a meter or chart band and its key swatch. It is never used as text colour.

### Tertiary
- **Issue Red** (`issue`): blocking only (TIMEOUT, ERROR, CRASH and NONE-PASSED). This covers the blocking meter segment, chart band and key, blocking counts in the rail, rows and conformance box, the gate words for blocking files, the inline status words in prose, and the blocking column of the generations table.
- **Issue Wash** (`issue-wash`): the tinted ground behind a blocking gate word, so a blocking row can be found by scanning.
- **Note Amber** (`note`, with `note-rule` for its border and `note-ink` for its label): note boxes that explain method, and nothing else.

### Neutral
- **Spec Paper** (`paper`): the page and the inside of every box.
- **Rail Grey** (`paper-2`): the contents rail, sticky table heads, failure-message wells and row hover.
- **Ink** (`ink`): text, and the FAIL mark. A failed subtest is not red.
- **Secondary Ink** (`ink-2`, 6.5:1 on paper): metadata, section numbers, box titles, counts, the quiet gate words (PARTIAL, NO SUBTESTS, NOT RUN), and TIMEOUT / NOT RUN / PRECOND. subtest marks.
- **Hairline** (`rule`) and **Strong Hairline** (`rule-strong`): borders, section rules, the tree's indent guide, chart axes and the scrollbar thumb.
- **No-Subtests Grey** (`empty`) and **Not-Run Grey** (`unrun`): meter and chart segments for files that reported no subtests and files that have not run. `unrun` is also the empty track of every meter.

**Dark rendition.** The same token names are redefined under `@media (prefers-color-scheme: dark)` on `:root:not([data-theme="light"])`, and again on `:root[data-theme="dark"]`: paper #15171a, paper-2 #1c1f23, ink #e6e7e9, ink-2 #a9adb3, rule #33373c, rule-strong #4a4f55, link and focus #8fb8f0, link-visited #b9a3e8, pass #79c07d, pass-2 #3d6b40, issue #f08a80, issue-wash #3a2220, note #2d2818, note-ink #e6d7a4, note-rule #4c4326, empty #5b6067, unrun #2a2d31, here #1f2a38, select #2b4263. In dark, `pass-2` is darker than `pass`, so "some failing" recedes behind "passing" on either ground. Text contrast on paper is 14.5:1 for ink and 8.0:1 for ink-2. `theme-color` follows paper in each scheme.

### Named Rules
**The Issue Red Rule.** Issue red marks blocking and nothing else: the four blocking standings, their counts, their band and their gate words. A failed subtest is ink and a partial file is secondary ink. If a red element on the page does not name a blocking file, it is wrong. One divergence in the build is recorded here, not adopted: a failed data load (`.fetch-error`, "Could not load ...") is also set in issue red. It is a defect against this rule, not a precedent.

**The Earned Green Rule.** Conformance green appears only for passing: a file that passes every subtest, or a subtest that passed. "Some failing" gets the sage band in meters and charts, and its word stays grey.

**The Amber Is Editorial Rule.** Pale amber is the ground of notes that explain method or scope. It never carries data and never signals a status.

## Typography

**Display Font:** Source Serif 4 (with Iowan Old Style, Georgia)
**Body Font:** Source Serif 4 for prose; Public Sans (with Segoe UI, system-ui) for data
**Label/Mono Font:** Source Code Pro (with ui-monospace, SF Mono, Menlo)

**Character:** A printed standard's setting. Source Serif 4 is a transitional book face drawn for continuous screen reading, and its optical-size axis gives headings, prose and captions their own cuts. Public Sans was drawn for the U.S. Web Design System, a public-standards document system; it is neutral, with tabular lining figures for columns of counts. Source Code Pro shares Source Serif's proportions, so a path set inside a sentence does not jump. All three are self-hosted WOFF2 variable fonts (latin and latin-ext subsets, `font-display: swap`) under the SIL OFL. The serif and sans latin files are preloaded.

### Hierarchy
- **Display** (620, fluid 2.1-3.05rem, 1.06, opsz 60): the document title only. The title is split: "Crane" at 620, then the rest at 380 in the same size.
- **Headline** (600, 1.6rem, 1.2, opsz 36): section headings: Status of this document, each suite (set as its path in mono, `console/`) and Revision history.
- **Body** (400, 1.0625rem, 1.6; front-matter prose 1rem/1.58): prose, capped at the 68ch measure. Suite ledes are body-size serif sentences, not captions.
- **Subtest name** (serif 400, 0.92rem, 1.4): subtest names are read as sentences, so they stay in the prose face even inside data.
- **Subtitle** (sans 500, 1.02rem): the one line under the title.
- **Data** (sans 400, 0.9rem, 1.4, tabular figures): boxes, rows, tallies and the header's definition list (0.875rem). The rail is 0.875rem/1.35, and suite names in it are mono at 0.82rem.
- **Section number** (sans 500, 1.05rem, tabular, secondary ink): the numbered margin.
- **Label** (sans 650, 0.8rem, +0.02em, uppercase, secondary ink): only the titles of the rail and the boxes: CONTENTS, CONFORMANCE, TESTS.
- **Status mark** (sans 600-650, 0.72rem, +0.04-0.05em, uppercase words): gate words and subtest marks.
- **Path** (mono, 0.88em of its context, ligatures off): paths, file names, commit hashes and run ids. Paths carry `<wbr>` after `_ - . /` so they wrap at separators, never mid-word.
- **Message** (mono, 0.78rem, 1.45, pre-wrap): harness and subtest failure messages.
- Chart axis text is sans 400 at 11px in secondary ink. `strong` is 650. Headings use `text-wrap: balance` and paragraphs use `text-wrap: pretty`.

### Named Rules
**The Three Faces Rule.** Serif is for anything read as language (prose, headings, subtest names). Sans is for anything counted or labelled. Mono is for anything copied: paths, hashes, messages. A new element takes the face of what its content is, not where it sits.

**The Tabular Figures Rule.** Every number that can sit in a column (counts, section numbers, dates in the header, the generations table, chart ticks) uses tabular lining figures.

## Layout

**Frame.** A two-column grid with the contents rail (`spacing.rail`, 17.5rem) and the document. The rail is sticky, full viewport height and scrolls on its own. The document is padded `2.25rem clamp(1rem, 4vw, 3.5rem) 4rem` on the right and bottom. Its left padding is `gutter + clamp(1rem, 3vw, 2.5rem)`, which leaves the numbered margin free. The document is capped at 78rem.

**Document order.** The header block (title, subtitle, then a four-column definition list: This version, Runs, WPT revision, History with the sparkline) closes with a hairline. Next comes the unnumbered front matter, "Status of this document": prose at the measure beside the note box (a two-column grid of `measure` and 15-21rem). Then one numbered section per suite in contents order, each opened by a hairline and a flex row of heading plus lede. Last is the back matter, "Revision history", numbered one past the last suite, and the footer. Sections are spaced by `spacing.section` (3rem).

**Section interior.** The two boxes sit side by side: Conformance at 15-19rem, Tests taking the rest, with a 1.5rem gap. The Conformance box is sticky at 1rem while its Tests box scrolls past it.

**Responsive.**
- At 82rem and below, the front matter stacks (the note goes under the prose at the measure) and the header definition list becomes two columns.
- At 60rem and below, the boxes stack and Conformance stops being sticky.
- At 52rem and below, the gutter goes to 0 and section numbers move inline before the heading. The rail becomes a sticky top bar (a collapsed `details` on a 94% `paper-2` ground with a light backdrop blur, a one-off for this bar, not a surface treatment to reuse) that shows CONTENTS and the current section's number and name, opens to the full list, and closes when an entry is chosen. Scroll padding grows to 3.75rem to clear the bar. Row tallies wrap under the name, and subtest marks narrow to 3.3rem.
- Print hides the rail, filters and self-links, and prints every fold open.

**Rhythm.** Spacing is set per component in rem rather than drawn from a numeric scale. The recurring values are 1rem box inset, 1.5rem between boxes and around notes, and 3rem between sections, with the 68ch measure for prose everywhere, notes included.

### Named Rules
**The Numbered Margin Rule.** Section numbers hang in a 3.25rem left gutter, right-aligned 0.9rem before the heading, in secondary sans. Suites are 1..N in contents order, Revision history is N+1, the front matter is unnumbered, and a suite's top-level directories are numbered N.1, N.2 in their rows. The rail repeats the same numbers. At narrow widths the number joins the heading line instead of disappearing.

**The No Big Number Rule.** The page has no hero figure, stat card or site-wide pass percentage. Totals appear inside sentences that state their scope, or inside a suite's box beside the files they count. Subtest totals always travel with the `encoding/` share that dominates them.

**Known open item (finish review).** At 1440x900 the first viewport shows the header, the status section, and section 1's two boxes down to the top of the Conformance meter and about two test rows. The reviewer asked for three or four rows. Recorded as open, not resolved: the contract's first viewport is met in kind but short in depth.

## Elevation & Depth

The system is flat. Depth comes from hairlines (`rule`, 1px) and one tonal step: the rail, table heads and message wells are `paper-2` against `paper`. There are no drop shadows. The only `box-shadow` in the build is an inset 1px `rule-strong` outline that lets the pale Not-run key swatch show against paper. Stickiness (the rail, the Conformance box, the table heads, the narrow-width contents bar) does the work that layering would, without lifting anything.

### Named Rules
**The Hairline Rule.** Containers are a 1px `rule` border on paper with a 3px radius. If something needs to stand apart, give it a rule or the `paper-2` tint, never a shadow.

## Shapes

The corners are nearly square, as in a printed document. There are three radii: 1px for meters and key swatches, 2px for gate-word washes, message wells and the focus ring, and 3px for boxes, notes, file details and the filter segments. Nothing is pill-shaped or circular. The only drawn shapes are the twisty (a 16px stroked chevron in SVG, 1.6 stroke, round caps) and the chart bands. Meters are flat horizontal bars whose segments always run in one order: passing, some failing, no subtests, blocking, not run. The tree's nesting is drawn with a 1px left rule indented 1.05rem.

## Components

### Numbered section heading
Headline serif, with the section number in the margin and a ¶ self-link after the text. The ¶ is secondary sans at 0.95rem, hidden at rest and faded in over 120ms when the heading is hovered or the link is focused. On devices without hover it sits at 55% opacity. Suite headings are the suite path in mono (`xhr/`). Reserved ids (status, history, toc, main, suites, chart, gens) get a `suite-` prefix when a suite would collide with them.

### Contents rail (scroll-spy)
- **Style:** `paper-2` ground, a right hairline, and a CONTENTS label. Each entry is a three-column grid: a right-aligned number (2.1rem), the name (suites in mono) and a tabular file count in secondary ink. A blocking count in the rail would use issue red.
- **Current:** the current entry is the last section whose top has crossed a third of the way down the viewport. Reaching the bottom of the page selects the last entry. It is marked `aria-current="true"` and gets the here wash, link blue and a 600-weight name. The rail scrolls itself to keep the current entry at least 40px inside its edges.
- **Hover:** the here wash at 70%.
- **Narrow:** see Layout. The collapsed bar names the current section and carries a rotated-border chevron that turns over 180ms.

### Conformance box
- **Head:** CONFORMANCE label, then the file count on the right.
- **Body:** a 0.5rem meter, then a definition list with a key swatch (0.85 x 0.55rem) for each row: Passing every subtest, Some subtests failing, Blocking, then No subtests reported and Not run when non-zero. Counts are right-aligned at 600. The Blocking row turns red when non-zero and is followed by its breakdown (for example "37 NONE-PASSED, 1 ERROR", with the numbers in red).
- **Subtests:** after a hairline, "N of M subtests passed" (N at 1rem/600), with a note that the total includes the subtests of blocking files and, when the suite holds 25% or more of all reported subtests, that share.

### Tests box
- **Head:** TESTS label, and a two-part segmented filter: All files / Not passing. The pressed segment gets the here wash, link blue and a blue-tinted border.
- **Rows:** a directory row is a twisty, its N.i number (top level only), the path in mono at 600, then a tally (file count, a red "n blocking" when non-zero, and a 4.5rem mini meter) and a ¶. A file row is a twisty, the file name in mono, "pass / reported" with the pass count in ink 600, the gate word, and a ¶. Hover gives a faint `paper-2` wash.
- **Long lists:** a list of more than 24 files shows its first 12 and a "Show all N files in path/" segment button. The Not passing filter reveals every matching capped row.

### File detail
Opens inside the row: a bordered paper box indented under the file. The first line gives the run id, date, Crane commit link and a "Test source" link to the file at the pinned WPT revision. Next comes the harness message if any, then the subtests as a list with hairlines between them: mark column (4.6rem), serif name, ¶, and any failure message in a mono `paper-2` well (max 14rem, scrolls). The first 200 subtests are drawn, then a "Show all N subtests" button. Files with several test variants get a run head per variant (test URL, status, pass/total). Files without subtest detail say so in serif prose ("Subtest detail arrives with the next full run.") and give their counts.

### Status marks
- **File gate words:** PASS in green. PARTIAL, NO SUBTESTS and NOT RUN in secondary ink. NONE-PASSED, TIMEOUT, ERROR and CRASH in issue red on the issue wash with a 2px radius. A variant's non-OK harness status uses the blocking treatment.
- **Subtest marks:** PASS in green, FAIL in ink, TIMEOUT, NOT RUN and PRECOND. in secondary ink.
- **Inline:** in prose, the blocking words are set as 0.72rem uppercase sans status words in issue red.

### Note box
An amber ground, amber hairline and 3px radius, with 1rem 1.25rem padding and a 52rem maximum width. Its text is held to the measure. A sans 600 label in note ink (a sentence, not an eyebrow: "How to read a section", "Two changes of rule sit inside this history") opens serif prose. The front-matter note carries the standing legend as a definition list of key swatches.

### Disclosure motion
The one authored motion. A fold is a grid whose row animates from `0fr` to `1fr` over 260ms on `cubic-bezier(0.16, 1, 0.3, 1)`. Its inner block's visibility switches at the end of closing, so closed content leaves the tab order. The twisty rotates 90 degrees over 180ms on the same curve. A permalink target flashes the here wash, holds it for about a third of 2.4s and eases out. Under `prefers-reduced-motion: reduce` the folds, twisty and self-link fade are instant, and a target keeps a static here wash.

### Permalinks
Everything that opens has an address, and loading one opens its path and scrolls to it:
- `#status`, `#history`: front and back matter.
- `#<suite>`: a suite section (`#xhr`; `#suite-<name>` for reserved names).
- `#<dir>/`: a directory row, trailing slash (`#xhr/resources/`). Its ancestor directories open.
- `#<file>`: a file row, opened (`#xhr/send-data-blob.htm`).
- `#<file>?sub=<name>&run=<test url>`: one subtest, with the name and test URL percent-encoded. `run` appears only when the file has more than one variant. A capped subtest list is expanded to reach the target.

The target is scrolled to the top, flashed and focused (the row's toggle, or the subtest's ¶).

### History chart
- **Sparkline:** 168 x 30 in the header's History row, the same stacked drawing without axes. It links to #history with "N generations since <date>".
- **Chart:** stacked area bands of files by standing, one x step per generation, oldest at the left. The bands, bottom up, are passing (green), some failing (sage), blocking (red) and not run (unrun grey). The chart is `max(190, min(300, width x 0.34))` tall, with count ticks at the left and day ticks along the bottom, all in 11px secondary sans. Rule changes are dotted vertical lines, each labelled at the top ("live history begins", "NONE-PASSED blocks").
- **Readout:** an `aria-live` line above the chart describes the generation under the cursor, with the blocking count in red. The cursor follows the pointer, the chart is focusable, and arrow keys, Home and End move the cursor.
- **Around it:** a key, an amber note explaining the two changes of rule and why subtests are not charted, and a disclosure ("Every generation, newest first") holding the full table: sticky `paper-2` head, tabular right-aligned counts, the blocking column in red, and reconstructed generations in secondary ink.

## Do's and Don'ts

### Do:
- **Do** open every surface that shows totals with its scope in words (testharness only, rendering and layout excluded, the `encoding/` share) before or beside the numbers.
- **Do** give every new section a number in the margin and an entry in the rail, and every openable thing a permalink in the `#<path>` grammar.
- **Do** use issue red (#b3261e) only for TIMEOUT, ERROR, CRASH and NONE-PASSED, and conformance green (#2e7d32) only for passing.
- **Do** set subtest names and explanations in Source Serif 4, counts and labels in Public Sans with tabular figures, and paths and messages in Source Code Pro.
- **Do** contain data in 1px-hairline boxes with a 3px radius on paper, titled with an uppercase sans label.
- **Do** open content in place with the 260ms grid-row fold, and honour reduced motion.
- **Do** redefine colours through the token names for dark mode, and never hard-code a hex in a component.

### Don't:
- **Don't** add a headline pass percentage, a stat card or a hero figure anywhere on the site.
- **Don't** colour a FAIL mark, a partial file or a load message red to make it stand out: red means the file blocks.
- **Don't** use the note amber for anything but explanatory notes.
- **Don't** add drop shadows, gradients or elevated cards; use a hairline or the `paper-2` tint.
- **Don't** put an uppercase label above a heading as a kicker. The uppercase label is only ever the title of its own box or the rail.
- **Don't** set a path in the serif or sans, or let it break mid-word; wrap it only at `_ - . /`.
- **Don't** hide the section number at narrow widths; move it inline.
