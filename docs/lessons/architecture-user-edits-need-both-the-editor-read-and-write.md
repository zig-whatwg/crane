# Architecture: User edits need both the editor read and write

**Date**: 2026-10-09
**Lesson**: A user-edit hook must expose the editor's current text as well as accept the next text; the public value may already have discarded incomplete input.

**Why**: A number input can display `1e` while its value is empty. HTML's badInput flag describes the editor, while script value assignment sanitizes immediately and does not set badInput. Length constraints likewise distinguish a user edit from a script write.

**What Happened**: Crane's typing and deletion paths read `input.value` and called the IDL value setter or setRangeText. Adding a user-edit write alone could preserve `1e` in the control, but the next keystroke would still read an empty value and replace the editor with only that key. Routing through IDL also erased the provenance needed for tooLong and tooShort.

**Fix**: Input and textarea install user_edit and editor_text in the existing control hook table. The write records raw text, the derived API value, and user provenance. Script writes clear that provenance. The read returns an owned copy, since a beforeinput listener or the next write can replace the source buffer. Keep the read and the beforeinput/input dispatches in their existing order. Test incomplete exponent completion, deletion, script replacement, length constraints, and a read that survives the following write under std.testing.allocator.

**Takeaway**: **The editor and the exposed value are distinct state. Preserve the complete read-edit-write path, not just its final write.**
