# Spec Compliance: Control font selection uses displayed text

**Date**: 2026-10-23
**Lesson**: A control's DOM text, value and displayed text can select different web fonts.

**Why**: Font requests follow the characters a control renders and the font needed for its line metrics. A textarea's children can be stale after setting value, password values are masked, and an unselected option can still contribute to select sizing.

**What Happened**: The row117 three-browser probe compared unique font URLs with all-character, A-only and B-only Unicode ranges. All engines selected current input/textarea values over placeholders, ignored hidden controls and used every select option. Chrome/Firefox selected password mask glyphs rather than the real value. The integrator applied CSS Fonts' first-available-font rule (U+0020) to the observed broad-range request from empty controls. A Crane fixture reproduced 30 failures before control integration, including stale textarea requests and missing requests after value changes.

**Fix**: Read current control state through generated interfaces, use one shared source for UA labels/masking, and exclude textarea source children from ordinary text selection. Value changes request the existing rendering turn only when font interest exists. Do not add selectedness notifications when every option already contributes. Test Unicode ranges and changes after a settled fonts.ready, not just a broad-range download.

**Performance**: An early return can still charge every write for a registry lookup. Profiles attributed 34 of 2,801 input-range binding-callback samples to the new font notification/style-slot path, against zero in the baseline. Keep the monotonic “style state has existed” fact in the control state the setter already loaded. Mark it through a cold owner hook at first style creation; initialize it once from existing style when lazy control state is created later. Preserve every notification and test both orders, clones, resets, type changes, adoption, disconnection and visibility changes. This removed the per-write lookup without introducing a borrowed pointer with an unproved teardown lifetime. The bounded six-phase comparison then passed both 3% bars; input range writes were +2.540% by ratio of medians and +1.624% by median paired change. The earlier failures remain in row117 D118–D123.

**Takeaway**: **Prove which characters are displayed before using a DOM getter as a font-selection source.** Browser probe: tmp/analysis/integrator-probes-1023a/results/ctlfont-{chrome,firefox,safari}.json; scope and UA choices: row117 Q62/Q63/Q66.
