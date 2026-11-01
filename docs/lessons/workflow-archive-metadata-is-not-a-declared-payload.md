# Workflow: Archive metadata is not a declared payload

**Date**: 2026-11-01
**Lesson**: Construct verified transfer archives from their declared members, rather than inheriting filesystem metadata.

**Why**: An archive command can add resource-fork or extended-attribute members that were never part of the source manifest. Strict receivers correctly reject those extra members.

**What Happened**: A row131 native-gate launch authenticated every payload file, but macOS tar added an AppleDouble `._.` member while packaging the directory. The receiver rejected the archive before source sync or compilation. The failure was a transport failure and supplied no native-test evidence.

**Fix**: Preserve the failed transfer and original command identity. Produce a separate archive containing only the manifest's regular-file names and bytes, with deliberate headers. Validate every emitted member's type, name and hash, including duplicates and traversal, before releasing the new command. Keep the receiver strict and leave source, dependency and runtime checks unchanged.

**Takeaway**: **A correct source manifest does not guarantee that an archive contains only those files; verify the emitted archive too.**
