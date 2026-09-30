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
  listing:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    typography: "{typography.data}"
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

Density follows a working reference document: long-form serif prose at a comfortable measure, then compact tabular data in bordered boxes. The page opens with its numbers: the WPT subtests passing out of those reported, in large type, with failed, timed out, not run, test files and blocking files beneath it (the user's requirement, 2026-09-30). Every suite, directory and test file then opens with its own subtest numbers. There are no stat cards and no pass percentage. Drill-down is a set of pages that mirror the WPT tree: a page per directory and a page per test file, each with a stable URL, and on a test file's page each failed subtest opens in place to its message.

Every page is finished HTML written by the generator (tools/wpt_site/pages.zig): no page needs script for any of its content, and the site carries no script at all. Built code-led from the direction contract (THESIS / OWN-WORLD / STORY / FIRST VIEWPORT / FORM: "Living Standard"), with no approved comp; the static rewrite (2026-09-30) kept the world and replaced the client-rendered mechanics. Where the contract and the build differ, this file records the build.

**Key Characteristics:**
- Spec-document grammar: front matter, numbered sections, back matter, numbered margins, ¶ self-links.
- Three faces, three jobs: book serif for prose, a workhorse sans with tabular figures for data, monospace for paths and messages.
- Colour is semantic and rationed. Green means passing, red means blocking and amber means a note.
- Flat paper with hairline borders; depth comes from rules and a faint grey tint, never from shadows.
- One authored motion: a failed subtest's chevron turns as its message opens in place (native `<details>`).
- Light and dark renditions from the same token names.

## Colors

The palette is restrained: neutral paper and ink with a single blue for navigation, plus three rationed semantic hues (green, red and amber), each held to one meaning.

### Primary
- **Spec Link Blue** (`link`): every hyperlink, the focus ring (`focus` is the same value, kept as its own token), and the "you are here" state: the rail's current entry and the spark-link text. Links underline at 1px, 0.18em offset, with the underline at 45% of the link colour until hover.
- **Visited Violet** (`link-visited`): visited links only.
- **Here Wash** (`here`): the pale blue behind the rail's current entry, and behind a targeted table row or subtest.
- **Selection Blue** (`select`): text selection only.

### Secondary
- **Conformance Green** (`pass`): Clean files, whose every reported subtest passed (meter segment, chart band, legend key, the Clean standing word), and subtest PASS marks.
- **Partial Sage** (`pass-2`): files with some subtests failing, only as a meter or chart band and its key swatch. It is never used as text colour.

### Tertiary
- **Issue Red** (`issue`): blocking only (TIMEOUT, ERROR, CRASH and NONE-PASSED). This covers the blocking meter segment, chart band and key, blocking counts in the rail, rows and conformance box, the gate words for blocking files, the inline status words in prose, and the blocking column of the generations table.
- **Issue Wash** (`issue-wash`): the tinted ground behind a blocking gate word, so a blocking row can be found by scanning.
- **Note Amber** (`note`, with `note-rule` for its border and `note-ink` for its label): note boxes that explain method, and nothing else.

### Neutral
- **Spec Paper** (`paper`): the page and the inside of every box.
- **Rail Grey** (`paper-2`): the contents rail, sticky table heads, failure-message wells and row hover.
- **Ink** (`ink`): text, and the FAIL mark. A failed subtest is not red.
- **Secondary Ink** (`ink-2`, 6.5:1 on paper): metadata, section numbers, box titles, counts, the quiet standing words (With failures, No subtests, Not run), and TIMEOUT / NOT RUN / PRECOND. subtest marks.
- **Hairline** (`rule`) and **Strong Hairline** (`rule-strong`): borders, section rules, the tree's indent guide, chart axes and the scrollbar thumb.
- **No-Subtests Grey** (`empty`) and **Not-Run Grey** (`unrun`): meter and chart segments for files that reported no subtests and files that have not run. `unrun` is also the empty track of every meter.

**Dark rendition.** The same token names are redefined under `@media (prefers-color-scheme: dark)` on `:root:not([data-theme="light"])`, and again on `:root[data-theme="dark"]`: paper #15171a, paper-2 #1c1f23, ink #e6e7e9, ink-2 #a9adb3, rule #33373c, rule-strong #4a4f55, link and focus #8fb8f0, link-visited #b9a3e8, pass #79c07d, pass-2 #3d6b40, issue #f08a80, issue-wash #3a2220, note #2d2818, note-ink #e6d7a4, note-rule #4c4326, empty #5b6067, unrun #2a2d31, here #1f2a38, select #2b4263. In dark, `pass-2` is darker than `pass`, so "some failing" recedes behind "passing" on either ground. Text contrast on paper is 14.5:1 for ink and 8.0:1 for ink-2. `theme-color` follows paper in each scheme.

### Named Rules
**The Issue Red Rule.** Issue red marks blocking and nothing else: the four blocking standings, their counts, their band and their gate words. A failed subtest is ink and a partial file is secondary ink. If a red element on the page does not name a blocking file, it is wrong. (The script-rendered build's red "Could not load" message went with the script.)

**The Earned Green Rule.** Conformance green appears only for passing: a Clean file, or a subtest that passed. "Some failing" gets the sage band in meters and charts, and its word stays grey.

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
- **Label** (sans 600-650, 0.74-0.82rem, +0.02-0.08em, uppercase, secondary ink): the titles of the rail and the boxes (CONTENTS, CONFORMANCE, TESTS) and the caption under a figure (WPT SUBTESTS PASSING), which names the number above it.
- **Headline figure** (serif 600, fluid 2.4-4.4rem, tabular lining): passed, then " / reported" at 400 in secondary ink. A section's figure is the same at 1.7-2.3rem.
- **Status mark** (sans 600-650, 0.72rem, +0.04-0.05em, uppercase words): gate words and subtest marks.
- **Path** (mono, 0.88em of its context, ligatures off): paths, file names, commit hashes and run ids. Paths carry `<wbr>` after `_ - . /` so they wrap at separators, never mid-word.
- **Message** (mono, 0.78rem, 1.45, pre-wrap): harness and subtest failure messages.
- Chart axis text is sans 400 at 11px in secondary ink. `strong` is 650. Headings use `text-wrap: balance` and paragraphs use `text-wrap: pretty`.

### Named Rules
**The Three Faces Rule.** Serif is for anything read as language (prose, headings, subtest names). Sans is for anything counted or labelled. Mono is for anything copied: paths, hashes, messages. A new element takes the face of what its content is, not where it sits.

**The Tabular Figures Rule.** Every number that can sit in a column (counts, section numbers, dates in the header, the generations table, chart ticks) uses tabular lining figures.

## Layout

**Pages.** `index.html` is the record. Each directory of the WPT tree has a page at `<dir>/` (`dom/nodes/`), and each test file one at `<dir>/<file>/` (`dom/nodes/Node-cloneNode.html/`): the WPT path is the URL, as on wpt.fyi. Links are relative, so the site works under any base. Only index.html changes when a generation records nothing new; directory and file pages change only with their own results, the worklist or the WPT revision.

**Frame.** A two-column grid: the contents rail (`spacing.rail`, 17.5rem) and the document. The document comes first in the source, so every reader meets the numbers first; the grid places the rail in the left column. The rail is sticky, full viewport height and scrolls on its own. The document is padded `2.25rem clamp(1rem, 4vw, 3.5rem) 4rem` on the right and bottom; its left padding is `gutter + clamp(1rem, 3vw, 2.5rem)`, which leaves the numbered margin free. The document is capped at 78rem.

**Index order.** The title; the headline (passed / reported, its caption, then failed, timed out, not run, test files and blocking files), between hairlines; the subtitle with the last-updated date; a four-column definition list (This version, Runs, WPT revision, History with the sparkline). Then the unnumbered front matter, "Status of this document": prose at the measure beside the note box. Then "Contents", a numbered list of the suites with each one's subtests passing, files and blocking count. Then one numbered section per suite, and last the back matter, "Revision history", numbered one past the last suite, and the footer. Sections are spaced by `spacing.section` (3rem).

**Section interior.** A suite section opens with its heading (a link to the suite's page) and its own figures, then the two boxes side by side: Conformance at 15-19rem, Tests taking the rest, with a 1.5rem gap. The Conformance box is sticky at 1rem while its Tests box scrolls past it. A directory page has the same shape under a breadcrumb and a heading of its path. A test file page has its figures, a definition list (Standing, Run, Test source), the harness message if any, and its subtests.

**Responsive.**
- At 82rem and below, the front matter stacks (the note goes under the prose at the measure) and the header definition list becomes two columns.
- At 60rem and below, the boxes stack and Conformance stops being sticky; the contents list drops its files column.
- At 52rem and below, the gutter goes to 0 and section numbers move inline before the heading. The rail leaves the left column and follows the document as its closing contents list. Each table row becomes two lines, the name above its numbers and standing; the chart swaps to its narrow drawing.
- Print hides the rail and the self-links.

**Rhythm.** Spacing is set per component in rem rather than drawn from a numeric scale. The recurring values are 1rem box inset, 1.5rem between boxes and around notes, and 3rem between sections, with the 68ch measure for prose everywhere, notes included.

### Named Rules
**The Numbered Margin Rule.** Section numbers hang in a 3.25rem left gutter, right-aligned 0.9rem before the heading, in secondary sans. Suites are 1..N in contents order, Revision history is N+1, the front matter and contents are unnumbered, and a suite's top-level directories are numbered N.1, N.2 in its table and on their own pages. The rail and the contents list repeat the same numbers. At narrow widths the number joins the heading line instead of disappearing.

**The Numbers First Rule.** (It replaced the first build's No Big Number Rule, at the user's insistence, 2026-09-30.) The index opens with the WPT subtests passing out of those reported, in large type, and beneath it failed, timed out, not run, test files and blocking files. Every suite, directory and test file opens with its own subtest numbers. File categories are plain labels (Clean, With failures, Blocking, No subtests, Not run), never "passing every subtest". There is no pass percentage unless the user asks for one; the `encoding/` share of all reported subtests is stated beside the totals, because it dominates them.

**The Static Rule.** No page needs script for any content, and the site ships none. Crawlers and readers with script off get the same page. `pages.needsScript` is run over every page the generator's tests emit.

**The Quiet Rail Rule.** The rail is on every page, so it carries nothing that changes with results (suite names, numbers and file counts only). Were it to carry a blocking count, every regeneration would rewrite all five thousand pages on gh-pages.

## Elevation & Depth

The system is flat. Depth comes from hairlines (`rule`, 1px) and one tonal step: the rail, table heads and message wells are `paper-2` against `paper`. There are no drop shadows. The only `box-shadow` in the build is an inset 1px `rule-strong` outline that lets the pale Not-run key swatch show against paper. Stickiness (the rail, the Conformance box, the generations table head) does the work that layering would, without lifting anything.

### Named Rules
**The Hairline Rule.** Containers are a 1px `rule` border on paper with a 3px radius. If something needs to stand apart, give it a rule or the `paper-2` tint, never a shadow.

## Shapes

The corners are nearly square, as in a printed document. There are three radii: 1px for meters and key swatches, 2px for gate-word washes, message wells and the focus ring, and 3px for boxes and notes. Nothing is pill-shaped or circular. The only drawn shapes are the chevrons (the generations table's 16px stroked SVG twisty, and the subtests' and breadcrumb's rotated 1.4px borders) and the chart bands. Meters are flat horizontal bars whose segments always run in one order: passing, some failing, no subtests, blocking, not run.

## Components

### Numbered section heading
Headline serif, with the section number in the margin and a ¶ self-link after the text. The ¶ is secondary sans at 0.95rem, hidden at rest and faded in over 120ms when the heading is hovered or the link is focused. On devices without hover it sits at 55% opacity. Suite headings are the suite path in mono (`xhr/`), linking to the suite's page. Reserved ids (status, contents, history, main, toc, gens, chart) get a `suite-` prefix when a suite would collide with them.

### Figures
The headline (index) and a section's figures share one grammar: passed at weight 600, " / reported" at 400 in secondary ink, the caption WPT SUBTESTS PASSING, then a row of definition pairs with the number above its label (Failed, Timed out, Not run, Test files, Blocking files). A non-zero blocking count is issue red. A test file's figures omit the file counts.

### Contents rail
- **Style:** `paper-2` ground, a right hairline, and a CONTENTS label. Entries: Subtest totals (the top of the index), Status of this document, each suite (a right-aligned number, the name in mono, a tabular file count) and Revision history. Every entry links into the index.
- **Current:** on a directory or file page, the suite the page belongs to is `aria-current="page"`, with the here wash, link blue and a 600-weight name. There is no scroll-spy; the index marks no entry.
- **Hover:** the here wash at 70%.
- **Narrow:** see Layout.

### Contents list
A numbered list under "Contents", a hairline between rows: number, suite path (a link to its section), then "passed / reported subtests", files and a red "n blocking". At 60rem the files column drops and the figures wrap under the name.

### Conformance box
- **Head:** CONFORMANCE label, then the file count on the right.
- **Body:** a 0.5rem meter (widths written by the generator as inline percentages), then a definition list with a key swatch (0.85 x 0.55rem) for each row: Clean, With failures, Blocking, then No subtests and Not run when non-zero. Counts are right-aligned at 600. The Blocking row turns red when non-zero and is followed by its breakdown (for example "37 NONE-PASSED, 1 ERROR", with the numbers in red).

### Tests tables
- **Head:** TESTS label, and on the index a link to the suite's page; on a directory page, how many directories and files it holds.
- **Directories:** Directory (its N.i number when the list is a suite's, the path in mono at 600, a link), Subtests passing (passed in ink 600, " / reported"), Test files, Standing (a red "n blocking" or a quiet "none blocking", and a 4.5rem mini meter).
- **Test files:** Test file (the name in mono, a link to its page), Subtests passing, Failed, Standing (the file's word, below).
- **Long lists:** on the index, a suite with more than 24 files directly in it names them in one summary row ("309 test files directly in xhr/: passed / reported subtests passing, n blocking") that links to the suite's page, which lists them all. Rows on the index carry the path as their id, so `#xhr/resources/` still lands on its row.
- Sticky-free `paper-2` column heads; row hover is a faint `paper-2` wash; a targeted row takes the here wash.

### Test file page
A breadcrumb (Crane WPT results › each directory › the file), the file name as the heading, its figures, then Standing (the word, and the runner's own status), Run (the run id, its date and Crane commit link) and Test source (the file at the pinned WPT revision). The harness message, if any, sits in a mono `paper-2` well. Under "Subtests", each test URL of the file (each global and variant) has a head with its URL, status and passed / total when there is more than one, or when its status is not OK. Subtests are a list in the harness's order with hairlines: a chevron column, the mark (4.6rem), and the serif name, then a ¶. A subtest with a message is a native `<details>`: its summary is the row, and it opens in place to the message in a mono `paper-2` well (max 18rem, scrolls). Past 500 subtests, only those that did not pass are listed, and the page says how many passing ones it counts. A file without per-subtest data says so, with its counts.

### Status words
- **File standing:** Clean in green; With failures, No subtests and Not run in secondary ink; NONE-PASSED, TIMEOUT, ERROR and CRASH in issue red on the issue wash with a 2px radius. A test URL's non-OK status uses the blocking treatment.
- **Subtest marks:** PASS in green, FAIL in ink, TIMEOUT, NOT RUN and PRECOND. in secondary ink.
- **Inline:** in prose, the blocking words are set as 0.72rem uppercase sans status words in issue red.

### Note box
An amber ground, amber hairline and 3px radius, with 1rem 1.25rem padding and a 52rem maximum width. Its text is held to the measure. A sans 600 label in note ink (a sentence, not an eyebrow: "How to read a section", "Two changes of rule sit inside this history") opens serif prose. The front-matter note carries the standing legend as a definition list of key swatches.

### Disclosure
The one authored motion: a failed subtest's chevron (a rotated 1.4px border in secondary ink) turns 90 degrees over 180ms on `cubic-bezier(0.16, 1, 0.3, 1)` as its `<details>` opens; the generations table's twisty does the same. Under `prefers-reduced-motion: reduce` it is instant.

### Addresses
- `/crane/`: the index; `#status`, `#contents`, `#history`, `#<suite>` (`#suite-<name>` for reserved names), and `#<path>` for the directory and file rows of a suite's table.
- `/crane/<dir>/`: a directory page.
- `/crane/<dir>/<file>/`: a test file page; `#s-<hash>` a subtest on it (a hash of its test URL and name, suffixed when a name repeats).
The first build's hash permalinks into the index (`#<dir>/<file>`) resolve only for rows a suite's table shows on the index.

### History chart
- **Sparkline:** 168 x 30 in the header's History row, the same stacked drawing without axes. It links to #history with "N generations since <date>".
- **Chart:** inline SVG drawn by the generator (chart.zig): stacked area bands of files by standing, one x step per generation, oldest at the left; bottom up, clean (green), with failures (sage), blocking (red) and not run (unrun grey). Two drawings, 960 x 300 and 480 x 260, one shown per width. Count ticks at the left and day ticks along the bottom, 11px secondary sans; rule changes are dotted vertical lines labelled at the top ("live history begins", "NONE-PASSED blocks"). Each generation's column carries a native tooltip (`<title>`) with its numbers and a faint wash on hover. The drawing carries no colour: bands take the page's tokens by class, so the dark rendition follows.
- **Around it:** a key, an amber note explaining the two changes of rule and why subtests are not charted, and a disclosure ("Every generation, newest first") holding the full table: sticky `paper-2` head, tabular right-aligned counts, the blocking column in red, and reconstructed generations in secondary ink.

### Social card
`card.png`, 1200 x 630, named by og:image and twitter:image (summary_large_image) with a `?v=` of its hash. On paper white: the title in the display serif, the passed count at 132px, " / reported" at 60px in secondary ink, the WPT SUBTESTS PASSING caption, a hairline, the five counts under their labels (blocking in issue red when non-zero), a hairline, and the site's address with the scope line. The numbers are composited by card.zig from a glyph atlas of Source Serif 4 drawn once by headless Chrome (card/README.md).

## Do's and Don'ts

### Do:
- **Do** open every page with its own WPT subtest numbers, passed / reported first, and state the scope (testharness only, rendering and layout excluded, the `encoding/` share) beside the totals.
- **Do** write every number, name and message into the markup; the generator's tests fail a page that needs script.
- **Do** give every new section a number in the margin and an entry in the rail and the contents list, and every page a stable URL that mirrors the WPT path.
- **Do** use issue red (#b3261e) only for TIMEOUT, ERROR, CRASH and NONE-PASSED, and conformance green (#2e7d32) only for passing.
- **Do** set subtest names and explanations in Source Serif 4, counts and labels in Public Sans with tabular figures, and paths and messages in Source Code Pro.
- **Do** contain data in 1px-hairline boxes with a 3px radius on paper, titled with an uppercase sans label.
- **Do** keep results out of anything every page carries (the rail, the head, the footer), so an unchanged file writes an unchanged page.
- **Do** redefine colours through the token names for dark mode, and never hard-code a hex in a component.

### Don't:
- **Don't** add a pass percentage, or the phrase "passing every subtest"; file categories are the plain labels.
- **Don't** render content from script, add a loading state, or ship JSON for a page to fetch.
- **Don't** colour a FAIL mark or a With failures file red to make it stand out: red means the file blocks.
- **Don't** use the note amber for anything but explanatory notes.
- **Don't** add drop shadows, gradients or elevated cards; use a hairline or the `paper-2` tint.
- **Don't** put an uppercase label above a heading as a kicker. The uppercase label is only the title of its own box or the rail, or the caption beneath a figure.
- **Don't** set a path in the serif or sans, or let it break mid-word; wrap it only at `_ - . /`.
- **Don't** hide the section number at narrow widths; move it inline.
