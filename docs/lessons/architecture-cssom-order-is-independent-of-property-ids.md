# Architecture: CSSOM Order Is Independent of Property IDs

**Date**: 2026-10-22
**Lesson**: Sort CSSOM's property-name index at compile time instead of making internal property IDs encode lexicographic order.

**Why**: A dense longhand ID indexes several parallel tables. CSSOM requires enumeration by property name; it does not require those IDs themselves to be alphabetical. Conflating the two makes an unrelated property addition require coordinated insertions into every table.

**What Happened**: The CSS image lane appended cursor and list-style-image to avoid overlapping another lane's property-table changes. A compile-time assertion rejected the enum because cursor followed z-index. Moving the IDs would have conflicted with the granted append-only integration strategy even though the metadata tables were correctly aligned.

**Fix**: Build a separate array containing each Longhand once and sort it by Longhand.name() at comptime. Keep ordinal-indexed metadata unchanged. Test strict name order, complete unique membership, boundary names, and an appended property's position among existing names. The failed assertion supplied the red check; the standard focused CSS gate then passed 989 tests, including the new cursor suite and the enumeration invariant.

**Takeaway**: **A required external ordering belongs in an index, not in the identity of internal entries.** Compile-time construction preserves the CSSOM order without runtime sorting.
