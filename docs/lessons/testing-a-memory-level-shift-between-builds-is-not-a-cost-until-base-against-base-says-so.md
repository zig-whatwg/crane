# Testing: A memory level shift between two builds is not a cost until base against base says so

**Date**: 2026-11-18
**Lesson**: When a cost pair's memory row is over the bar with equal instructions, first run two builds of the SAME code against each other on that row. Then build leave-one-out consoles. A row whose launches sit on discrete levels can move by a whole level when code that never runs on the page changes.

**Why**: The collected figure (`perf_bench run --collected`) keeps the pages the launch's largest heap dirtied. macOS never takes those back from a running process (lesson testing-a-collection-removes-a-memory-rows-garbage-levels-not-the-allocators-high-water-tail.md). On the streams page those pages come in steps of about 4.5 MB: launches land at 81, 86, 91 or 95 MB collected. Which step a launch reaches depends on where the collector ran during the streaming bursts. That timing moves with code layout, so a build can change its share of the levels without one byte more live memory.

**What Happened**: Lane csp1's whole-suite window (chat.local, crane-376da8cd6c6 against crane-main-de371eae13b) put 8 streams/fetch memory figures over the bar: page.streams collected 1.051, the streams rows 1.03-1.05 steady, fetch.loopback-json 1.037. Instructions were 0.998-1.000. The lane's changes (CSP inline-check scope, parser nonce rules, the timer TrustedScript branch) do not run on those pages. Four measurements settled it:
1. Base against base: csp1's main console against css1's main console of the same code gave page.streams collected 0.896 (81 MB x7 / 91 MB x2 against 91 MB x9; "chance from one coin 0.002"). It gave page.fetch steady 1.035, over the bar, between two mains.
2. A second build of the tip tree in another mirror was not byte-identical: the repl differed by 624 bytes, the link-edit's object paths. But `nm -n` showed 0 of 173,818 symbols at a new address, so it was the same layout and sampled nothing.
3. Leave-one-out consoles, the same window, page.streams collected against main:
   - the tip: 1.053 (91 x3 / 95 x6)
   - minus the timer change: 0.999 (81 x9)
   - minus the parser change: 1.064 (81 x4 / 86 x4 / 90 x1)
   - minus the inline-scope change: 1.015 (91 x9)
   No single change carried it. "Never on the 81 level" needed two changes together, one of which runs no code on the page.
4. css1's window the same evening had a MAIN build visiting 91 and 95 MB on the same row.

**Fix** (the order to settle an over-bar memory row with equal instructions):
1. Read every launch, not the medians. Discrete levels with different shares per side are a level shift, not a cost.
2. Base against base on the row: two builds of the same code (another lane's main console, read-only, works). If they differ by as much as the pair, the row is build-sensitive.
3. Before calling a rebuild a second sample, compare the binaries' symbol addresses (`nm -n`, diff). A different sha with no moved symbol is the same layout.
4. Leave-one-out consoles, one change removed each, in the same window against the same base. A cost follows one change; a layout effect moves with all of them, or with none.
5. Take the evidence to main for a ruling. The memory rule's (a) and (b) do not clear a level shift whose levels the two sides do not share.

**Takeaway**: **Equal instructions and a memory row that moves by whole levels is a layout question first: base against base, then leave-one-out, before anyone looks for a leak.**
