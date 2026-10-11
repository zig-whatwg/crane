# Spec Compliance: DOM offsets are UTF-16 code units, and Crane's strings are WTF-8 bytes

**Date**: 2026-10-11
**Lesson**: Every length and offset the DOM, HTML and WebIDL expose is counted in UTF-16 code units (Infra §4.6). Crane holds a DOMString as its WTF-8 bytes, so a DOM offset is never a byte index into a Zig string. Convert it at the boundary with `infra.wtf8`.

**Why**: Infra defines a string as a sequence of 16-bit code units, and a node's length, substring data, replace data, range offsets, maxlength and the selection APIs all count them. Crane's DOMString is `[]const u8`. A lone surrogate is held as its three bytes ED A0..BF xx and a surrogate pair as one four-byte sequence, which is what V8's WriteUtf8 writes without REPLACE_INVALID_UTF8. A code unit can therefore take 1, 2, 3 or 4 bytes, and half of a four-byte sequence (one surrogate of a pair) has no byte offset at all. For ASCII text the two counts agree, so every ASCII test passes.

**What Happened**: CharacterData's state answered `length` with its byte count, so "A😀B".length was 6 and not 4. substringData, the four replace-data methods, splitText, normalize, the live-range steps and Range's stringifier all used byte offsets. CharacterData-surrogates.html passed 0 of its 8 subtests, and every non-ASCII case in CharacterData-* failed. Codex row 17 found it while writing Selection, which reads lengths through the same state. The forms helpers had a second variant of the same bug: `std.unicode.calcUtf16LeLen` rejects WTF-8 surrogates, and the code fell back to the byte count when it did, so a value holding a lone surrogate looked longer to maxlength.

**Fix** (lane utf16, design (b); storing UTF-16 or WebKit's 8/16-bit split were rejected because every reader of node data works on UTF-8 slices):
1. `src/infra/wtf8.zig` provides the code-unit view of WTF-8:
   - `codeUnitLength` and `positionOfCodeUnit`, both vectorised;
   - `Pieces` for substrings and splices;
   - `appendJoined` for concatenation.
2. Two rules keep the bytes canonical, so byte equality stays string equality:
   - an offset between the halves of a pair splits the four-byte sequence into its two three-byte surrogates;
   - a high and a low surrogate that meet at a seam become the pair again.
3. CharacterData's state keeps its code-unit count beside the byte length and is still 64 bytes. When the two are equal the text is ASCII and offsets are byte offsets, with no scan.
4. The forms helpers `form_associated.utf16Length` and `byteOffsetOfUtf16` use `infra.wtf8`.

**Takeaway**: **A DOM offset or length is UTF-16 code units, never bytes: never slice a DOMString with one. Map it with `infra.wtf8` (positionOfCodeUnit, Pieces, appendJoined). Test with an astral character AND a lone surrogate, because ASCII hides the bug and `std.unicode` rejects the surrogate.**
