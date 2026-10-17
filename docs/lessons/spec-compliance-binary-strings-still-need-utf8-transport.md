# Spec Compliance: Binary strings still need UTF-8 transport

**Date**: 2026-10-17
**Lesson**: A byte-per-code-unit string must be isomorphically decoded before it enters a UTF-8 string representation.

**Why**: File API's BinaryString result describes JavaScript code units, not the bytes used to transport that string through Crane's binding. Treating arbitrary bytes as UTF-8 can combine several bytes into one character or replace them.

**What Happened**: FileReaderSync's package-data helper returned a raw byte copy as a DOMString. The UTF-8 bytes for a multibyte character became one character, while the API required one code unit per original byte. The synchronous helper also lagged FileReader's MIME/encoding/BOM handling and default DataURL media type.

**Fix**: Put package data once in `src/file/algorithms/package_data.zig`. Use `infra.bytes.isomorphicDecodeToUtf8` for BinaryString and the existing Encoding legacy decode for Text. Both readers use this helper. Return allocated strings as owned DOMStrings, and create engine ArrayBuffers directly so no native copy is discarded. Pin bytes above 127, label/MIME/BOM precedence, and partial-allocation cleanup with `std.testing.allocator`.

**Takeaway**: **The string's specified code units and its internal transport encoding are separate contracts; satisfy both.**
