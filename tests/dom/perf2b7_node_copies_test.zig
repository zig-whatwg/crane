//! A node's layout, part 4 (lane perf2, batch 7): the last per-node copies.
//!
//! - DocumentFragment's, DocumentType's and ShadowRoot's allocator copies (16
//!   bytes each): a node's creation allocator IS its Browser's - asserted
//!   where every node is made (Node's initOwn, lane perf2 batch 6) - so what
//!   they allocate and free goes through `runtime.allocatorOf(instance)`,
//!   found from the node's address
//!   (docs/lessons/architecture-a-nodes-creation-allocator-is-its-browsers-only-inside-a-browser.md).
//! - EventTarget's `current_event` (8 bytes on every target): DOM 2.3's
//!   "current event" is a Window's ("Each Window object has an associated current
//!   event"), and only a Window's was ever set. It is in Window's state, as
//!   Blink keeps it on LocalDOMWindow (current_event_) and Gecko on the inner
//!   window (nsGlobalWindowInner::mEvent).
//!
//! They name generated States and src/dom types only (an embedded state is its
//! State's `_embedded` field type), and compile at the base, where they fail.

const std = @import("std");
const builtin = @import("builtin");
const interfaces = @import("interfaces");

fn printLayout(comptime T: type) void {
    @setEvalBranchQuota(100_000);
    std.debug.print("\n{s}: {d} bytes, align {d} (mode {s})\n", .{ @typeName(T), @sizeOf(T), @alignOf(T), @tagName(builtin.mode) });
    inline for (@typeInfo(T).@"struct".field_names) |name| {
        const F = @FieldType(T, name);
        std.debug.print("  {s:<36} {d:>6} {d:>6}  {s}\n", .{ name, @offsetOf(T, name), @sizeOf(F), @typeName(F) });
    }
}

fn Embedded(comptime State: type) type {
    return @FieldType(State, "_embedded");
}

fn expectNoField(comptime T: type, comptime names: anytype) !void {
    var kept: usize = 0;
    inline for (names) |name| {
        if (@hasField(T, name)) {
            std.debug.print("{s} still has `{s}`\n", .{ @typeName(T), name });
            kept += 1;
        }
    }
    if (kept != 0) {
        printLayout(T);
        return error.FieldKept;
    }
}

fn expectSize(comptime T: type, expected: usize) !void {
    if (@sizeOf(T) != expected) {
        printLayout(T);
        std.debug.print("{s}: {d} bytes, pinned {d}\n", .{ @typeName(T), @sizeOf(T), expected });
        return error.SizePinMoved;
    }
}

test "DocumentFragment's embedded state keeps no allocator copy: its template host and that host's generation, 16 bytes" {
    const E = Embedded(interfaces.DocumentFragment.State);
    try expectNoField(E, .{"allocator"});
    try expectSize(E, 16);
}

test "DocumentType's embedded state keeps no allocator copy: its name, public ID and system ID, 48 bytes" {
    const E = Embedded(interfaces.DocumentType.State);
    try expectNoField(E, .{"allocator"});
    try expectSize(E, 48);
}

test "ShadowRoot's embedded state keeps no allocator copy" {
    try expectNoField(Embedded(interfaces.ShadowRoot.State), .{"allocator"});
}

test "EventTarget's embedded state keeps no current event: 8 bytes" {
    const E = Embedded(interfaces.EventTarget.State);
    try expectNoField(E, .{ "allocator", "current_event" });
    // One pointer to the listener block (lane lis1): 24 with the listener
    // list 8, the handler map 8 and listeners_watched 1 (padded to 8).
    try expectSize(E, 8);
}
