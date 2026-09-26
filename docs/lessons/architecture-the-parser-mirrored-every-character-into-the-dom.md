# Architecture: The parser mirrored every character into the DOM, and a run of text cost O(N^2)

**Date**: 2026-09-25
**Lesson**: `TreeBuilder.insertCharacter` notified the DOM adapter after every character. The adapter answers a notification with `CharacterData.set_data`, which copies the whole string, so a run of N characters cost O(N^2).

**Why**: The tokenizer batches ASCII into `text_run` tokens only for static input. Every real page parses through an InputStreamManager, where batching is off. So every character of every page took the per-character path, and it was invisible on ordinary pages.

**What Happened**: `moving-between-documents/` frames hold two 100,000-character runs. One file spent 32 s of CPU in `CharacterData.replaceData`, and 40 of the 52 files ran past their 60 s ceiling. `sample` on the running process named it in one run.

**Fix**: Blink's design (`HTMLConstructionSite::pending_text_` / `FlushPendingText`). The tree builder marks the text node pending and tells the adapter once: before any other notification, before a script runs, and when `parse()` returns. Nothing script can observe changes. `tests/html/tree_builder_text_batching_test.zig` pins it, using non-ASCII text so that it takes the per-character path. One file: 30.6 s -> 6.1 s. A/B over 993 parser-heavy files: blocking 128 -> 118.

**Takeaway**: **When a file is slow, sample it before blaming the network or the test.** A 1-second server sleep does not take 30 seconds of CPU.
