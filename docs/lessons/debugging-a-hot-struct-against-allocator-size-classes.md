# Debugging: Measure a hot struct against allocator size classes

**Date**: 2026-10-18
**Lesson**: A small field can double a hot object's allocation and zeroing cost when it crosses the allocator's size-class boundary.

**Why**: Crane's ArenaAllocator uses power-of-two classes and zeroes the entire selected block, not just the requested bytes (src/runtime/arena_allocator.zig:85-101,178-193). Source-level field size alone does not describe its allocation cost.

**What Happened**: Adding a ?WallTime to Document.InternalState raised its request from 2,040 to 2,056 bytes, proven by disassembling Registry.createIn in the exact frozen BASE and TIP runners. The allocation bucket therefore grew from 2,048 to 4,096 bytes. Seven alternating priority pairs measured createHTMLDocument x10,000 at 126.5 versus 132.3 ms (+4.58%); seven BASE-versus-BASE pairs gave a -0.67% noise floor. One-second samples and source inspection found no clock or timezone work during construction: time conversion stayed in the getter.

**Fix**: Keep the optional construction argument and exact source-time semantics, but store a plain WallTime with a known flag among the existing booleans. Pin epoch zero, positive and pre-epoch source values, implicit unknown and explicit null through the public interfaces; use no sentinel or truncated timestamp. Verify the rebuilt runner's requested size by disassembly and rerun all cost pairs. Change only the new field's representation, without altering the allocator or moving other fields. A later rare-data design is separate work.

**Takeaway**: **Compare the compiled request with the allocator's actual bucket; a 16-byte field can cost 2 KiB per object.**
