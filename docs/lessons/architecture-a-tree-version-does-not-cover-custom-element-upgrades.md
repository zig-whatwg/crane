# Architecture: A tree version does not cover custom-element upgrades

**Date**: 2026-10-12
**Lesson**: A collection cache must account for changes in element classification as well as tree and attribute mutations.

**Why**: Upgrading an undefined custom element to a form-associated custom element makes it listed. The constructor need not change any attribute or move any node, so a DOM tree mutation counter need not advance.

**What Happened**: Review M1 proposed caching form names and listed elements under Crane's document tree version. Native tests verified that form attributes, target IDs and parser association followed by insertion advance that version. A form-associated custom-element upgrade changed the form's names and length while leaving the version unchanged.

**Fix**: Under codex-lpo Q14, leave the existing indexed form collection uncached until its owner adds upgrade invalidation. The string-name cache also avoids reuse while its tree contains an undefined or precustomized element that can still upgrade. Keep the upgrade regression and its version-gap reproducer with the follow-up. No new node pointers or mutation hooks are needed for the conservative fallback.

The parser-association hook has a second gap: the inert parser calls it after insertion. A native regression warmed the cache first and reproduced stale names. The cache therefore includes the document's association-list count alongside the version; appending changes the count, while removals already accompany versioned mutations.

**Takeaway**: **Cache validity follows every input to the answer, including classification changes that do not mutate the tree.**
