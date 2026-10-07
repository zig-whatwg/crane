# Spec Compliance: Prescan bounds apply to the stream, not each attribute

**Date**: 2026-10-07
**Lesson**: A short encoding label can occur inside a long, valid attribute value.

**Why**: HTML's 1024-byte prescan bound limits the byte stream being inspected. It does not permit truncating a meta content attribute or the surrounding whitespace of an encoding label.

**What Happened**: The sniffer kept at most 64 bytes per attribute. A long MIME parameter before charset caused a valid declaration within the prescan window to be ignored. A transport charset parameter had the same independent 64-byte restriction. Some upstream encoding tests obscured these questions by asserting offsetWidth, which requires layout.

**Fix**: Bound the prescan's attribute storage by the complete prescan window. Preserve the whole transport parameter before applying Encoding's whitespace trimming and label lookup. Test complete/incomplete declarations at byte 1024, long content attributes and padded labels; use decoded DOM text for script-visible evidence.

**Takeaway**: **Apply the specification's bound at the level it names, and measure decoding independently of layout.**
