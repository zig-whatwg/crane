# Debugging: Inspect the DOM before changing a serializer

**Date**: 2026-10-07
**Lesson**: A serialization assertion can expose a missing tree-construction rule rather than a serializer defect.

**Why**: Serialization reports the DOM it receives. Removing characters from output would hide incorrect text nodes and make DOM text APIs disagree with the markup.

**What Happened**: All eight checks in initial-linefeed-pre.html failed with one extra newline. The parser had never discarded the first LF token after pre/listing/textarea, and textarea also lacked its in-body RCDATA transition. The serializer correctly reproduced those incorrect text nodes.

**Fix**: Pin the parser's actual tree with std.testing.allocator, including doubled newlines, CRLF, character references, intervening comments, and fragment contexts. Keep the one-token suppression state in the tree builder and apply the complete textarea start-tag algorithm. Verify live DOM text as well as the original serialization assertions.

**Takeaway**: **Locate the first incorrect representation before repairing a later observable result.**
