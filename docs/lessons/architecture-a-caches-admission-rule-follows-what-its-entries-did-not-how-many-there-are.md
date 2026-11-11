# Architecture: A cache's admission rule follows what its entries did, not how many there are

**Date**: 2026-11-11
**Lesson**: When a bounded cache must stop keeping entries that are never used again, decide from what the entries it holds have done (how many of that kind ever served a hit), measured where the cache already looks at all of them (its prune). An entry count says how full the cache is, not whether a kind of entry repeats.

**Why**: Lane style1 b5 keyed an element's own declaration blocks (its style attribute, its presentational hints) by content in the matched-properties cache, so that equal blocks hit. A rule's block is one object for every element it matches, so its entry is reused by construction. An own block's content may be held by one element only: a row positioned by its own `margin-left` or `transform`. Kept, such a style costs a full entry (two style clones, a correspondence, a copy of the matched list, a snapshot of the block) and its share of a prune, and serves nothing. On the all-miss bench `gcsFull` (2,000 parents per round, each with a style attribute of its own) that was +5,748 instructions per parent, 1.0241 of main's count, where the user's ruling allowed no rise.

**What Happened**: The obvious cut is the cache-on-second-sighting rule (TinyLFU's doorkeeper): give a content its entry the second time it is seen. Applied always it costs every repeating content one hit, so it was tied to the entry count. Both ways were built and measured.
1. From the prune target (300 entries) on: `gcsFull` fell to 0.9945 of main's. But the AG Grid page's cache holds 437-445 entries, so the rule applied for most of that page, and it lost 7,987 of 1,188,349 hits (misses 1,227 -> 9,214). Its repeating contents come back after more than 256 other first sightings, so their tags in the 256-slot table were gone. The band between the prune target and the limit is where a real page's cache lives.
2. At the limit (500 entries) only, where the next entry forces a prune: the grid lost 9 hits, but `gcsFull` rose to 1.0159 of main's. Each rare second sighting at the limit forced a prune, and the 200 places the prune freed went straight to the next 200 unique blocks.

Neither count could work: the grid's cache and the flood's cache hold the same number of entries. What differs is what those entries did. On the grid nearly every own-block entry answers lookups; in the flood none does.

**Fix**:
1. Give each entry that can serve a hit a `served` flag, set by the lookup that hits it.
2. At a prune, before releasing anything, count the entries of the kind in question (here: made for a resolution with an own block) and how many of them served.
3. Switch the second-sighting rule on only when there is enough evidence and it is one-sided (here: at least a quarter of the limit in own-block entries, fewer than one in eight of them served). Otherwise keep every resolution as it comes, which is what Blink and WebKit do. Weigh again at the next prune; start over on a new generation.
4. Hold the sightings table only while the rule is on.
5. Test both directions: a flood turns the rule on and then makes no entry and no prune; a prune that finds its own-block entries serving, or too few of them to tell, leaves first sightings kept.

Measured at af473886ac5: the grid's misses are 1,227 with and without the rule, jquery's 26 and 26; on `gcsFull` the cache prunes once, then holds 315 entries.

**Takeaway**: **A threshold on the number of entries cannot tell a cache that is full of useful entries from one that is full of useless ones. Count what the entries did, at the prune, and let that switch the admission rule.**
