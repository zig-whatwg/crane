# Architecture: A collector told a tenth of an object collects a tenth as often - the figure it is given must be the block the object really holds

**Date**: 2026-11-15

**Status** (2026-11-15, lane nm2 batch 2): the same rule bites when an object SHRINKS. A node's State block went 144 -> 128 bytes (Text 128 -> 112), so the figure V8 is told for a parsed document fell 9.2% (it counts the slot and the State block), while the document's real bytes fell 6.3% (its text, attribute values and allocator overhead are not in the figure). V8 then let about 3% more dead documents build before each collection: parser.dom-parser read steady memory 1.077 and instructions 1.071 of main while its neighbour on the same page, parser.document-write, read 0.877 and 0.966 (one collection and its tree teardown had moved between them), the whole page 0.877. Per document the work was unchanged (+0.5% instructions with forced collections) and 24 kept documents cost 6.3% less. So: after any change to the counted part of an object, compare "told per object" with "kept per object" again, and read a row over the bar beside its neighbours on the page before reading it as a cost.
**Lesson**: An account of external memory paces the collector exactly as well as its figure is true. Lane wrap1's batch 3 told V8 112 B for each wrapped Event (its slab slot, its generated State block, the cache's record) of the about 1.2 KB an Event holds: its dispatch state is a separate 1.1 KB block the figure left out. V8 was paced ten times too slowly for Events, and the row that the account was written to fix stayed over the bar.

**Why**: V8 asks for a full collection when what it counts (old generation + C++ heap + external memory) passes a limit. A young collection is asked for by JS bytes only. A 16 B wrapper with a 1.2 KB instance behind it fills the young space slowly, so dead instances wait; the external account is the only thing that can ask for a collection sooner, and it asks in proportion to the bytes it is told. In Blink the object is on the C++ heap and V8 counts all of it.

**What Happened**: 650,000 `new Event('x')` made and dropped, resident memory at the end, production gc_bench, main ceb3c5098a0 against the lane (2026-11-15, three or more runs a side):

| | chat.local back to back / loop | server1 back to back / loop |
|---|---|---|
| main (24 B wrapper, no account) | 87.2 / 76.2 MB | 87.3 / 78.8 MB |
| 16 B wrapper, account off | 101.8 / 74.7 | 103.7 / 80.7 |
| 16 B wrapper, told 112 B | 88.5 / 74.1 | 99.1 / 84.2 |
| 16 B wrapper, told the state block too | 31.1 / 22.4 | 55.2 / 47.0 |

The 112 B account was measured, was better than no account, and was called a floor in its own comment - and for a day the open question was "why are the Event rows still over main on server1". Two diagnosis builds answered it in an hour: one with the account off (worse: so the account helps), one with an Event told at its whole size (three times lower: so the figure was the lever). V8 then runs 48 to 65 small full collections instead of 1 full and 15 young ones, at equal wall time on this loop. The same change turned the one accepted loss of the batch (a URLSearchParams with an expando, which waits for a full collection: +176% over main) into +1.6%.

**Fix**:
1. The figure is one function of the instance (wrapper_cache.zig `instanceHeldBytes`) and now adds each internal state block the instance's generated State names (interface_bindings.zig `stateBlocksOf`: read at compile time from the State's types, counted while the pointer is set). No impl is named and there is no per-interface list.
2. When an account exists and a make-and-drop row is still high, test the figure before the mechanism: build one variant with the account off and one that tells the true size of the row's object (a one-line patch each), and read resident memory and collection counts for both.
3. Print what the collector is told beside what a kept object holds, for every shape measured (tests/v8/wrap1_platform_anchor_test.zig prints "V8 is told N B for ..."; gc_bench's kept rows give the other number). A ratio far from 1 is the finding.

**Takeaway**: **A "floor" is not a safe direction for a figure that schedules collections: told too little, the collector waits. Tell it the blocks the object owns, and check the told figure against the kept bytes per shape.**
