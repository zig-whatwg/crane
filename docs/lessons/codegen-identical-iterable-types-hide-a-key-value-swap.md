# Codegen: Identical iterable types hide a key/value swap

**Date**: 2026-10-21
**Lesson**: Pin iterable key and value metadata with distinct types in both orders, including async iterables.

**Why**: A generator can reverse the two fields of a pair iterable without changing interfaces whose keys and values have the same type.

**What Happened**: Headers and URLSearchParams both hid a generator inversion. FormData emitted a USVString value type and FormDataEntryValue key type. Selecting a ByteString conversion from that metadata exposed the wrong meaning; the same inversion existed in async metadata.

**Fix**: Emit a pair's first IDL type as its key and second type as its value. Emit the sole type as the value for a single-value iterable. Test ByteString/USVString and the reverse, plus a single-value control, for sync and async declarations. Regenerate the complete tree and audit every metadata consumer for compensation for the old inversion.

**Takeaway**: **Use asymmetric test data when the contract distinguishes two positions.**
