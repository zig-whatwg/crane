# Testing: A timed window measures where the collection lands - compare with a collection between rounds

**Date**: 2026-10-09
**Lesson**: A timing page that times part of each round and does unmeasured work between rounds can report a regression that is only GC work moving from the unmeasured part into the measured one. Run the same page with `TestUtils.gc()` between rounds, outside the timed region, and time the unmeasured part too, before attributing the difference to the code under test.

**Why**: Collections happen at allocation, wherever that is. A change that keeps objects alive longer (correctly) moves their teardown later - out of the unmeasured setup, into the next round's measured work.

**What Happened**: Lane nodeholds made a static NodeList keep its nodes (Blink's semantics). crane/ed-qsa-timing.html replaces a 10,000-element tree by innerHTML each round and times querySelectorAll('*') plus iterating it: the iteration read 2,048 -> 2,825 ms (1.38x, bar 1.05x). The previous round's list is garbage but not yet collected, so it rescues the tree innerHTML replaces, and those wrapped trees were then torn down inside the next round's timed iteration (sample: GC -> second-pass callbacks -> Node.deinit under the indexed getter's wrap). A probe page timing innerHTML as well showed tip's innerHTML 330 ms faster (base had freed, during it, nodes a live list still named); with a GC between rounds the iteration was 1,343/1,370 ms on base and 1,300/1,258 ms on tip. The integrator accepted the GC-between-rounds numbers as the hold's own cost, with a test that dropped lists retain nothing past two collections.

**Fix**: Keep the probe's two variants (no GC, GC between rounds) and the unmeasured part's time beside any per-round timing of code that changes lifetimes; report all three.

**Takeaway**: **Before blaming the measured code for a timing regression, time the unmeasured part of the round too and rerun with a collection between rounds: lifetimes move GC work, they do not only add it.**
