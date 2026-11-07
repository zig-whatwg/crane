# Debugging: A smaller node can raise memory when the engine is told less

**Date**: 2026-11-07
**Lesson**: When a change shrinks per-node storage and the perf window's memory goes UP on garbage-heavy rows, check what the engine is told the DOM holds before suspecting retention: V8 schedules DOM-driven collections from the reported external memory, and a figure that undercounts - and then shrinks - delays every collection.

**Why**: V8 collects when its own heap grows. A wrapper is a few dozen bytes of that heap and holds a native tree alive, so the host reports the DOM's native bytes (runtime.gc.ExternalMemory -> the engine protocol's AgentOptions.external_memory -> Isolate::AdjustAmountOfExternalAllocatedMemory). If the report counts only part of a node, shrinking that part shrinks the report by a larger fraction than the node: V8 sees less pressure, runs fewer collections, and the garbage it leaves is measured as steady memory.

**What Happened**: Lane perf2 batch 4 took NodeBase from 472 to 208 B (gc_bench: -264 B per retained node, RSS -254..-293). The Crane-only perf window then read MEMORY 1.032, with load.docs steady 1.990, page-growth 1.533, document-write 1.397, clone-node 1.300 - and the binding loops 0.861. instance_bridge.storageBytes reported a div as slot + State block + NodeBase: 632 B at main, 368 B at the tip (-42%), while the div held ~2,450 B; its InternalState blocks (1,600 B) had never been counted. The tip console with storageBytes + 264 (main's figure, a temporary experiment in the same window) read MEMORY 0.953 against main, every regression gone.

**Fix**: Count what a node really holds where it is made and freed: each InternalState block at its arena class (OwnState and InstanceRegistry, nodes only - a worker's EventTargets must not touch the window agent's figure), the NodeBase's rare data and observer entries; storageBytes keeps the registration's share. A div is reported as ~1,840 B. Pinned by tests/html/perf2b4_dom_memory_test.zig (a div is reported as more than its slot, State and NodeBase; nodes with and without rare data return the total to where it was at teardown).

**Takeaway**: **A memory row that moves the wrong way after a storage cut is usually the collector's schedule: compare the bytes the engine is told with the bytes the node holds, and prove it by restoring the old report in one console.**
