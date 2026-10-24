# Testing: Two wrong string conversions can cancel

**Date**: 2026-10-21
**Lesson**: Test the native bytes on both sides of a ByteString boundary; a JavaScript round trip can hide two matching errors.

**Why**: ByteString and USVString both use `[]const u8` in Crane, but ByteString holds octets and USVString holds UTF-8. Their Zig type alone cannot select the conversion.

**What Happened**: Input conversion checked that code units fit in a byte but retained their UTF-8 encoding. Output conversion decoded those bytes as UTF-8. A header set and read by script could look correct while an HTTP response containing the same octets produced replacement characters. The native test for all 256 octets found 384 bytes after input conversion.

**Fix**: Preserve IDL type metadata through codegen. Validate ByteString input, then isomorphically encode it into owned octets. Convert output octets into one JavaScript code unit each. Test scalar, nullable, optional, sequence and dictionary inputs, native output bytes, wire-originated values, and neighboring USVString values. Exercise allocation failure after conversion begins.

**Takeaway**: **A round trip proves agreement between two conversions, not that either conversion is correct.**
