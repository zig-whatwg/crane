# Debugging: A tree scan parses in path order, and a resolver keeps its results distinct

**Date**: 2026-11-22
**Lesson**: A directory walk lists entries in its file system's order - sorted on APFS, by hash on ext4 - so a tool whose result depends on the order it reads files (a memo that cuts cycles where it first meets them, a "first definition wins" table) gives macOS and Linux different answers for one tree; and a resolver that appends sub-results without removing duplicates can multiply them at every level.

**Why**: lint-hasdecl resolves a generic's type parameter through all its call sites, recursively, memoized, with a cycle reading "cannot be told". Its lists kept duplicates, so a type passed through a chain of generics called from two sites each doubled per level. On server1 (ext4) a cycle cut the expansion early and the run took 82 ms; on chat2 (APFS) the sorted order met no cut and the run grew to 12-14 GB resident and a 416 GB footprint before macOS killed it. The baseline count itself could have differed between the two.

**What Happened**: Measured with `/usr/bin/time -l` and `sample` on chat2 (lane tpg, 2026-11-22): every frame was lint_hasdecl.resolve recursing into ArrayList(*Scope).ensureTotalCapacity's memmove. Linux's `--time` line had looked healthy because Linux never took the expensive order.

**Fix**: scanTree collects the paths, sorts them and only then parses; `appendDistinct` adds each container to a resolution's list once. Tests: a probe reached through 2^5 call sites resolves to one container; sixteen files written in reverse are parsed in path order.

**Takeaway**: **Time a tool on both OSes before trusting it, sort what a walk returns before anything order-sensitive reads it, and dedupe at every merge of a recursive resolver - a duplicate that doubles per level is an exponential waiting for the order that does not cut it.**
