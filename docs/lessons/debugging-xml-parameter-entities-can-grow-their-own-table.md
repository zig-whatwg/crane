# Debugging: XML Parameter Entities Can Grow Their Own Table

**Date**: 2026-10-21
**Lesson**: Reacquire hash-map entries after recursively processing input that can insert into the same map.

**Why**: An XML parameter entity can declare more parameter entities. Processing its replacement text can rehash the table while the outer entity remains active; its recursion flag belongs to the relocated entry.

**What Happened**: `Parser.parameterReference` kept `parameter_entities.getPtr(name)` across `declarations`. Its deferred `entity.in_use = false` wrote into freed storage. A native test declaring 48 entities inside another crashed on that write under `std.testing.allocator`. A script-visible test expanding the outer entity twice instead reported a false recursive-entity error; Chrome accepted it.

**Fix**: Copy the entity value before expanding it, retaining the arena-owned replacement text. Look up the map entry separately to set and clear its recursion flag. Expand the same entity again after growth in the regression test, checking both memory safety and guard reset.

**Takeaway**: **Map entries are temporary across recursive registration, even when their names and text have stable storage.**
