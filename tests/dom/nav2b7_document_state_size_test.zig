//! Document's state is allocated from the state arena
//! (runtime.InstanceRegistry -> arena.create(InternalState)). Its classes were
//! powers of two, and one byte past a class doubled every Document's block
//! (feature queue, PERFORMANCE, 2026-10-18: createHTMLDocument x10,000 went
//! +4.58% when row 76 crossed 2048); lane nav2 batch 7 measured 2168 bytes, in
//! the 4096-byte class. Since lane perf2 batch 5 the classes are exact to 16
//! bytes up to 4 KiB: the block holds the state with less than 16 bytes to
//! spare.
//!
//! Lane perf2 batch 7: what few Documents set is the Document's rare data
//! (dom.document_rare_data), made on first use - measured over a 1-in-16
//! sample of the 0.1 worklist, 15,601 Documents: each set on at most 3.5% of
//! them, most on none (tmp/plans/perf2-evidence/batch7/document-field-counts.txt) - and
//! two fields nothing ever set are gone (the string pool, the CSP self-origin
//! fallback). The state's size is pinned exactly, in every build mode the
//! tests build (Debug: the std lists' safety lock words included,
//! docs/lessons/testing-a-std-safety-field-moves-size-pins-in-safe-builds.md).
const std = @import("std");
const builtin = @import("builtin");
const runtime = @import("runtime");
const document_state = @import("dom").document_state;

fn printLayout(comptime T: type) void {
    @setEvalBranchQuota(100_000);
    std.debug.print("\n{s}: {d} bytes, align {d} (mode {s})\n", .{ @typeName(T), @sizeOf(T), @alignOf(T), @tagName(builtin.mode) });
    inline for (@typeInfo(T).@"struct".field_names) |name| {
        const F = @FieldType(T, name);
        std.debug.print("  {s:<44} {d:>6} {d:>6}  {s}\n", .{ name, @offsetOf(T, name), @sizeOf(F), @typeName(F) });
    }
}

test "Document's state stays inside the arena's exact classes, its block within 16 bytes of it" {
    const size = @sizeOf(document_state.InternalState);
    try std.testing.expect(size <= 4096);
    try std.testing.expect(runtime.ArenaAllocator.heldBytes(size, @alignOf(document_state.InternalState)) - size < 16);
}

/// The fields few Documents set (the Document's rare data) and the two
/// nothing set (gone).
const rare_or_gone = .{
    "string_pool",                "csp_self_origin",
    "import_map_imports",         "import_map_integrity",
    "import_map_scopes",          "prefetch_hints",
    "frozen_base_url",            "pragma_language",
    "target_element",             "hovered_element",
    "pointed_element",            "activated_element",
    "template_owner_document",    "template_owner_generation",
    "fullscreen_element",         "pointer_lock_element",
    "picture_in_picture_element", "parser_form_associations",
};

test "Document's state keeps none of what few Documents set: that is its rare data" {
    const T = document_state.InternalState;
    var kept: usize = 0;
    inline for (rare_or_gone) |name| {
        if (@hasField(T, name)) {
            std.debug.print("Document's state still has `{s}`\n", .{name});
            kept += 1;
        }
    }
    if (kept != 0) {
        printLayout(T);
        return error.FieldKept;
    }
}

test "Document's state is 1,680 bytes in a safe build (2,168 before its rare data; 1,704 before perf2 b8 kept its [SameObject] children once; 1,672 before the wrapper redesign's P6 listed its parsers on the native stack)" {
    const T = document_state.InternalState;
    if (!std.debug.runtime_safety) return;
    if (@sizeOf(T) != 1680) {
        printLayout(T);
        std.debug.print("Document's state: {d} bytes, pinned 1680\n", .{@sizeOf(T)});
        return error.SizePinMoved;
    }
}
