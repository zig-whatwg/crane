# Architecture: Flat per-element storage makes every property cost every element

**Date**: 2026-10-27
**Lesson**: A computed style with one slot per supported property makes each new property cost every element, whether anything touches it or not. Storing groups that are shared with the parent or the initial values, and copied on first write, makes an untouched property free.

**Why**: With a flat array, every element allocates, initialises, defaults, copies (for logical longhands) and releases every slot. The cost is per supported property, not per declared one. Blink (ComputedStyleBase groups), WebKit (RenderStyle's DataRef groups) and Stylo (style structs behind Arc, StyleStructRef Borrowed -> Owned) all avoid it the same way.

**What Happened**: Crane's ComputedStyle held 250 Values (8,048 B).
- Row 124's 40 longhands cost image_computed +5%.
- Lane cascadefast2 measured the flat cost per element per added longhand: 131.8 instructions (inherited) and 98.7 (non-inherited), and 250/216 under the runner's allocator. The largest part was teardown: an 8 KB stack copy and 250 out-of-line Value.release calls.
- It also found that five more longhands would push the struct over DebugAllocator's 8,192 B class into 16 KiB, adding 20% to an empty cascade.
- Grouped storage instead:
  - 17 groups, each inherited-only or non-inherited-only;
  - the held bit says which groups a style holds a reference on;
  - set() skips identical writes;
  - the cascade visits only declared longhands;
  - logical longhands are mapped at get().
- Results:
  - per added longhand: 3.9 / 3.4 instructions;
  - per element: -74% to -80% (the runner's allocator);
  - per element storage: 8,048 B -> 184 B plus the groups written.

**Fix**: See src/css/computed_style.zig (Storage) and src/css/computed_groups.zig. The ownership rule:
- A style holds one reference on each held group and on no other.
- A group copy retains every counted value it copies.
- The last release of a group releases those values and frees the group with its own allocator.
- Static initial groups are never written and never freed.
- The held bit, never an address comparison, is the truth.

**Takeaway**: **Per-element storage should cost what the element writes, not what the engine supports: share untouched groups by pointer and copy on first write.**
