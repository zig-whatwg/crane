# Architecture: Bits kept inside a struct die with every whole-struct write

**Date**: 2026-11-16
**Lesson**: A flag moved from a word of its own into a spare byte of an existing struct is overwritten by every statement that writes that struct whole - its initializer and its poison - unless each one carries the byte across.

**Why**: Lane nm3 moved a node's State chain live bits (runtime.OwnState: "is this level's state made") from a 4-byte word beside the NodeBase into `NodeBase.live`, the byte `node_type` gave up. Two statements write a NodeBase whole. Node's `initOwn` runs `internal.* = .{ .base = .{ ... } }` AFTER `Registry.create` set Node's own bit - the struct literal's default would have cleared it, and every `Registry.get` of the node would have answered null. Node's `releaseNodeBase` fills the NodeBase with the poison byte (0xaa) in the builds that poison - which sets bits 1, 3, 5 and 7: levels torn down long before would have read as live again, and a level still to be swept would have lost nothing but luck.

**What Happened**: Both were found by reading the two functions before the first compile, not by a test: the first would have failed every node test at once, the second only in the bug-finding runner and only for a level above Node's that outlives Node's release.

**Fix**:
1. `initOwn` reads the byte into a local before the whole-struct write and names it in the literal (`.live = live`). A local, not `internal.base.live` inside the literal: the literal is built in place.
2. `releaseNodeBase` saves the byte, poisons, and writes it back; Node's own bit is cleared after, by `Registry.remove`.
3. tests/dom/nm3_node_listeners_rare_test.zig pins the bits of a div and a Text after construction (0b111) and that every level reads torn down after its deinit.

**Takeaway**: **When state moves into a struct, list every statement that assigns, zeroes, copies or poisons that struct whole - grep for `.* = .{` and `@memset(std.mem.asBytes(` on its type - and decide for each whether the new state survives it.**
