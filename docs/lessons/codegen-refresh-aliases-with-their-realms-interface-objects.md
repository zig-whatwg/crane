# Codegen: Refresh aliases with their realm's interface objects

**Date**: 2026-10-22
**Lesson**: Replacing interface objects after snapshot restoration also requires refreshing their aliases, without defeating lazy creation.

**Why**: A snapshot alias is an ordinary reference to the old function object. Replacing the target's global property does not update it. Reading that global property later is also insufficient: script may replace or delete it before reading the alias.

**What Happened**: Restored Windows had `HTMLDocument !== Document` and `webkitURL !== URL`. The restore path refreshed constructors and legacy factory functions, but left aliases pointing at snapshot functions. Refreshing every alias eagerly would also materialize geometry interfaces that a child Window otherwise creates only on demand.

**Fix**: Refresh the existing aliases with the same eager/lazy policy as their interfaces. A lazy alias uses V8's lazy data property mechanism and resolves generated metadata to the interface template's per-context constructor. It does not read a mutable global target. Check identity in both read orders, deletion and replacement of the target, prototype identity, and data-property descriptor flags on fresh, restored and child Windows. Measure iframe creation after changing this path.

**Takeaway**: **An alias names the realm's interface object, not the current contents of another global property.**
