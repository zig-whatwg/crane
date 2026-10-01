# Codegen: The model must not depend on the order files are read in

**Date**: 2026-10-01
**Lesson**: Codegen read specs/idl in directory-enumeration order, and that order decided overload numbering, which of two duplicate definitions won, which partial namespace survived and member order - so the committed tree was a function of macOS's APFS name-hash order.

**Why**: The IR merged incrementally: the first definition seen became the base, a later "better" duplicate was prepended onto it (its loser's members leaked in), extended attributes kept the first [Exposed] seen, and namespaces were `put` (last file wins). Every one of those is order-dependent, and APFS returns entries in name-hash order, which no other filesystem reproduces.

**What Happened**: Splitting specs/idl from specs/supplementary changed the read order and 200+ generated files changed: Document.requestStorageAccess's overloads swapped call_X/call_X__1 (breaking its impl), AudioTrack's [Exposed] came from a partial, CSS had animationWorklet OR escape, never both. Reproducing the committed tree needed the old single directory's `ls -f` order.

**Fix**: Each add records an occurrence (file, position); the name's merged definition is rebuilt from all occurrences sorted by (file name, position): definition first, partials after, partial namespaces merged, the definition's extended attributes winning, includes applied in (file, position) order. Duplicate definitions resolve only through an explicit table from webref's curated idlnames (duplicates.zig) or fail. A test reads the same fixture files forward, reversed and shuffled and requires byte-identical output.

**Takeaway**: **If a generator's output can change when its inputs are only reordered, it is wrong - test it with shuffled input, and resolve every conflict by a rule, never by arrival order.**
