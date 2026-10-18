# Spec Compliance: Location components need parser state and document encoding

**Date**: 2026-10-18
**Lesson**: A Location component setter must pass the specified parser state, and search must also pass the relevant Document's encoding.

**Why**: Full-URL parsing strips leading/trailing spaces and treats `#` as a fragment delimiter. Query-state parsing preserves those spaces and percent-encodes the hash. Its encoding is the target Document's; href, assign and replace instead use the entry Document's encoding and base URL.

**What Happened**: Location.search constructed and reparsed a complete URL, while href/assign/replace used UTF-8 regardless of the caller's encoding. The frozen BASE failed all three location-encoding-parse subtests. The isolated hash setter regression also turned a space into an empty fragment instead of `%20`.

**Fix**: Use the shared document encoding-parse helper for whole-URL setters. For search, copy the current URL and invoke the basic parser with query-state override and the relevant Document's encoding. For hash, use fragment-state override. Test different caller/target encodings, literal hashes, trailing spaces, and null versus empty query/fragment.

**Takeaway**: **Encoding, base URL and parser state are independent inputs; preserve all three specified by the API.**
