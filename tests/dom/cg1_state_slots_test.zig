//! Dead attribute storage in generated States (lane cg1 batch 1, step 2).
//!
//! The codegen gave every non-static attribute of every non-Node interface a
//! slot in its generated State, whether or not anything read it. An IDL
//! attribute is an accessor (WebIDL 3.7.6): its getter runs the impl's steps,
//! and most impls compute the value or keep their own storage (lane rare1
//! found CSSStyleProperties' State 60 of 72 bytes of slots nothing read:
//! cssText, length, parentRule, cssFloat). The compile proof (every slot
//! dropped, everything compiled: the runners, every test binary, the tools)
//! named 48 files that read or write a slot - 47 impls and one test - in 44
//! interfaces; only those keep their slots (writer.zig
//! `state_storage_interfaces`), and a new reader of a dropped slot is a
//! compile error.
//!
//! RED at 01edfb83b0a: 824 interfaces keep slots; the table it prints is the
//! audit (each interface, its slots and their bytes).
const std = @import("std");
const testing = std.testing;
const interfaces = @import("interfaces");

const Row = struct { name: []const u8, slots: usize, bytes: usize };

/// An interface's own level's attribute slots: its `own` fields less the
/// [SameObject] caches and `_internal`.
fn slotsOf(comptime State: type) Row {
    const Own = @FieldType(State, "own");
    var row: Row = .{ .name = "", .slots = 0, .bytes = 0 };
    inline for (@typeInfo(Own).@"struct".field_names) |name| {
        if (comptime std.mem.startsWith(u8, name, "cached_") or std.mem.eql(u8, name, "_internal")) continue;
        row.slots += 1;
        row.bytes += @sizeOf(@FieldType(Own, name));
    }
    return row;
}

/// The generated State of the interface declared `decl`, or null.
fn stateOf(comptime decl: []const u8) ?type {
    const T = @field(interfaces, decl);
    if (@TypeOf(T) != type or @typeInfo(T) != .@"struct" or !@hasDecl(T, "State")) return null;
    const S = T.State;
    if (@typeInfo(S) != .@"struct" or !@hasField(S, "own")) return null;
    return S;
}

/// Every generated interface with attribute slots, at comptime.
const rows = rows: {
    @setEvalBranchQuota(10_000_000);
    const names = @typeInfo(interfaces).@"struct".decl_names;
    var count: usize = 0;
    for (names) |decl| {
        const S = stateOf(decl) orelse continue;
        if (slotsOf(S).slots != 0) count += 1;
    }
    var list: [count]Row = undefined;
    var i: usize = 0;
    for (names) |decl| {
        const S = stateOf(decl) orelse continue;
        var row = slotsOf(S);
        if (row.slots == 0) continue;
        row.name = decl;
        list[i] = row;
        i += 1;
    }
    const final = list;
    break :rows final;
};

test "only the 44 interfaces whose impls store their attributes in their State keep attribute slots" {
    var total: usize = 0;
    for (rows) |row| total += row.bytes;
    if (rows.len != 44) {
        std.debug.print("\ninterface, attribute slots, bytes (own level):\n", .{});
        for (rows) |row| std.debug.print("  {s} {d} {d}\n", .{ row.name, row.slots, row.bytes });
        std.debug.print("{d} interfaces keep {d} bytes of attribute slots\n", .{ rows.len, total });
        return error.DeadSlotsKept;
    }
}

test "CSSStyleDeclaration's and CSSStyleProperties' States hold no attribute slot" {
    // cssText 24 + length 4 + parentRule 8 (CSSStyleDeclaration) and
    // cssFloat 24 (CSSStyleProperties) at 01edfb83b0a: nothing read them;
    // the impl computes each (CSSOM 6.6.1).
    try testing.expectEqual(@as(usize, 0), slotsOf(interfaces.CSSStyleDeclaration.State).slots);
    try testing.expectEqual(@as(usize, 0), slotsOf(interfaces.CSSStyleProperties.State).slots);
    const S = interfaces.CSSStyleProperties.State;
    if (@sizeOf(S) > 16) {
        std.debug.print("CSSStyleProperties.State: {d} bytes (72 at 01edfb83b0a)\n", .{@sizeOf(S)});
        return error.SlotsKept;
    }
}
