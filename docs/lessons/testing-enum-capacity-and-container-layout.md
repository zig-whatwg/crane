# Testing: Enum Capacity and Container Layout Are Separate Invariants

**Date**: 2026-10-26
**Lesson**: Widening a growing ID enum needs a storage audit, reflected-count tests and measured containing-type sizes.

**Why**: The enum's integer type limits its capacity. Its users can independently truncate IDs, retain fixed-size arrays or grow when alignment changes. A successful compilation does not establish those properties for future entries.

**What Happened**: Concurrent CSS families needed more longhand IDs than an eight-bit tag could hold. All production containers already used the typed enum or its reflected count. Widening Longhand from one to two bytes enlarged the Property union from two to four bytes, while Declaration stayed 48 bytes and ComputedStyle stayed 6,432 bytes.

**Fix**: Audit casts, packed fields, bitsets and fixed-size arrays before editing. Pin the tag width and every count-derived container, round-trip every current ID through declaration storage and the cascade, and test allocation failures. Measure containing types before and after instead of inferring their sizes from the changed tag.

**Takeaway**: **Tag capacity, complete container coverage and per-element footprint each need their own evidence.**
