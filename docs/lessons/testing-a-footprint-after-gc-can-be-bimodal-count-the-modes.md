# Testing: A footprint after GC can be bimodal - count the modes over ten runs before blaming a change

**Date**: 2026-11-11
**Lesson**: A page's physical footprint read after forced collections can sit in one of two modes ~10% apart with the same live bytes; three runs a side can put the base in one mode and the tip in the other and read as a regression the change did not make.

**Why**: The modes are the allocator's, not the objects': libc malloc keeps a page dirty while any block on it lives, so which pages a session's last frees empty depends on the order of teardown and collection, and the footprint lands high or low by chance. `vmmap -summary` shows it: the malloc zone's ALLOCATED is the same in both modes and only its FRAG (dirty minus allocated) differs.

**What Happened**: Lane cg1 (N1 and the dead-slot removal) measured the AG Grid framework page x3 alternating and read +7.6 MB (96.3 vs 88.7). The malloc zone's allocated bytes were equal and its FRAG was +5 MB, so the first suspect was the change's new 16-byte rare blocks pinning pages. A four-console run (base, N1 only, tip, tip with rare blocks from the state arena) showed every console in both modes (base 85.9/84.6/95.8, N1 82.1/83.5/97.8), and a malloc_history census found the same live blocks in every size class (N1 added 291 blocks of 16 bytes, ~9 KB). Ten alternating runs each settled it: base high 4/10, mean 90.7 MB; tip high 4/10, mean 91.2 MB. The arena candidate, built to fix a cause that was not there, was not landed.

**Fix**:
1. Read the malloc zone row (allocated, frag) with every footprint: equal allocated plus different frag is an allocator mode, not new objects.
2. Before attributing a footprint difference, run 10 alternating runs per side and report the high-mode count and the mean, not one median of three.
3. Census live blocks by size (MallocStackLogging=lite + malloc_history -allBySize) once per console: a change that moves no blocks cannot own a fragmentation mode.

**Takeaway**: **Equal allocated bytes with different fragmentation is a mode, not a regression: count how often each side lands in the high mode over ten runs before blaming the change.**
