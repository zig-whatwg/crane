# Testing: WPT Sweep Chunks May Use Different Stream Layouts

**Date**: 2026-10-17
**Lesson**: Assemble subtest evidence separately for each sweep chunk because its runner allocation can change between single-process and sharded execution.

**Why**: The measurement wrapper assigns available runner tokens to each chunk. A single-process chunk writes `journal.wptreport.jsonl`; a sharded chunk writes `journal.shard*.wptreport.jsonl`. One glob over the entire sweep can silently omit one kind of chunk.

**What Happened**: The scripting lane retained every raw chunk but initially combined only the sharded streams. Its complete 3,119-source journal was unchanged, while the combined subtest evidence held only 2,155 of the actual 4,017 expanded result records. A per-chunk audit found the omission before handoff. Python's `splitlines()` also falsely split some valid JSON records at Unicode line separators inside strings.

**Fix**: For each chunk, select its shard streams when present, otherwise its single stream. Preserve and validate every selected record, then concatenate them beside the source journal. Split JSONL on byte LF, not the broader Unicode line-boundary rules of `splitlines()`. Record chunk counts and validate the assembled stream; preserve an incorrect earlier aggregate as diagnostic evidence rather than overwriting the raw inputs.

**Takeaway**: **Complete source counts do not prove complete subtest evidence; account for every chunk's actual stream layout.**
