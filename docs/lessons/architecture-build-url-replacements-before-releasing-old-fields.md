# Architecture: Build URL replacements before releasing old fields

**Date**: 2026-10-18
**Lesson**: Commit an updated URL record only after every replacement field has been allocated successfully.

**Why**: A URL owns a buffer, a host and a path with separately allocated segments. Updating one field at a time can leave a mixture of freed, old and new fields when a later allocation fails. Cleanup then cannot safely destroy the record.

**What Happened**: applyContextToURL freed the old buffer, host and path before fallible replacement work. Its path loop also passed a newly duplicated segment directly to a fallible append. The normal record constructor already had correct unwinding for these same allocations.

**Fix**: Reuse buildURLRecord to construct a complete replacement, preserve the existing opaque blob entry, and only then deinitialize and replace the old record. Exercise every allocation failure for query, fragment, host and path updates, requiring byte-identical serialization on failure and no leaks.

**Takeaway**: **Reuse a failure-safe constructor, then swap; do not partially destroy an object while constructing its replacement.**
