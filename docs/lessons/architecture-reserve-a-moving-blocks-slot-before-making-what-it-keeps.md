# Architecture: Reserve a moving block's slot before making what it keeps

**Date**: 2026-11-10
**Lesson**: A block that grows by reallocation (a sparse rare block) breaks two rules at once if a writer takes a pointer into it and then builds the value: the build can re-enter and move the block (Blink 601c5205e1d5), and a failed insert after the build leaves an object nobody keeps. Reserve the field's bit first, build, then write through the holder read AFTER the build.

**Why**: The fixed ElementRareData never moved, so `ensureRare` handed out `*ElementRareData` and every writer made its object after it ("made before the object so that nothing can fail after it is"). Blink's sparse NodeRareData reallocates on growth, and its 2026 corruption was exactly an ensure that kept a slot pointer while the field's constructor re-entered the block. Blink's fix builds the field first and inserts it after (SetDisplayLockContext takes a built context) - but in Crane an insert can fail with OutOfMemory, and an element.style object, a shadow root or a NamedNodeMap must not exist unless the element keeps it.

**What Happened**: Lane rare1 b1 replaced the 312-byte fixed block with one sparse block (8-byte header, 8-byte popcount-indexed slots, 16 bytes for the first field). Every writer was rewritten around three calls: `keptReserve` (or `reserve`) gives the field its bits with zero slots - a cleared field, which may grow the block and may fail, before anything exists; the object is built (this may add other fields and move the block); `keptSet`/`putReserved` then writes in place through `holder.block`, read now, which cannot fail because the bits are there. Readers never see a pointer into the block: they take the element's holder by value and each field by value. A test adds fields from inside a field's construction under the poisoning DebugAllocator, and another keeps reading `el.style` while every other field is added.

**Fix**:
1. The API never returns a pointer into the block: `get(holder, field)` by value, writes through `*Holder` (the element's own word, which a grow refreshes).
2. Multi-word fields are blocks of their own whose address the slot holds (they never move).
3. For an object that must be kept or never exist: `reserve` the bits, build, write in place. For a plain value: build fully, then `put` (the insert reads the holder after the build).
4. Clearing keeps the bit (Blink's SetFieldToNullIfExists), so a reset never moves the block.
5. Pin: a construction that re-enters and adds fields, and a grow read under poison.

**Takeaway**: **With a block that moves, "made before the object" becomes "its slot reserved before the object": reserve, build, then write in place through the holder read after the build - never through a pointer taken before it.**
