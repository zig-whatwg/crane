# Testing: A reuse test frees a block for every allocation its stimulus makes

**Date**: 2026-11-10
**Lesson**: A test that asks "does X ever take a freed block of class C" must free as many C blocks as its stimulus allocates from C before X - otherwise an earlier allocation of the same operation takes the freed block and the test passes on the very bug it was written for.

**Why**: A size-class free list is LIFO and shared by everything of that size. An operation rarely allocates only the object under test: making an element allocates its own State block before it names the element, and that block can be in the same class as the name record the test watches.

**What Happened**: Lane nd2 batch 1-fix's red test for review finding F3 ("a name record never takes a freed node block") freed one div block (272-byte class), checked that the next div took it back (the arena does reuse synchronously), freed that div, then made an element whose interned name record is 264 bytes - the same class - and checked the record's address. On batch 1's tip, where records DO come from the arena's class lists, it passed: the new element's own block, allocated before its name, took the one freed block, and the record got a fresh slot. Freeing two div blocks (both reissued to two new divs first, to prove the premise) made it red on the tip and green on the fix.

**Fix**: Count the stimulus's allocations from the class (here: the element's block, then its record), free that many blocks, check the premise (each freed block is reissued) and then check the subject against every freed address. Run the test on the unfixed tree before trusting it: a reuse test that passes red proves nothing.

**Takeaway**: **Free one block per allocation the stimulus makes from that class, and see the test fail on the unfixed tree - a free list hands its block to whoever asks first.**
