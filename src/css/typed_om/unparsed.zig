//! CSS Typed OM 1 §§4.1, 6.1: serialization over existing object slots.
const std = @import("std");

pub const Segment = union(enum) {
    string: []const u8,
    variable: struct { name: []const u8, fallback: ?usize },
};

/// §3: a custom property NAME STRING starts with two dashes. This is not
/// CSS identifier parsing: spaces, escapes and the bare "--" are allowed.
pub fn isCustomPropertyName(name: []const u8) bool {
    return std.mem.startsWith(u8, name, "--");
}

/// Reader supplies length(id), segment(id, index) and release(segment).
/// Its strings remain valid until release; all graph links are borrowed.
///
/// Chrome 156 / Safari 27, 2026-10-27 (liaison Q16): raw segments and raw
/// variable names split 1–1, so unchanged §6.1 decides; both shippers omit
/// the fallback comma's space. Houdini issues 1021 / 1148 remain open.
/// WebKit Source/WebCore/css/typedom/{CSSUnparsedValue,
/// CSSOMVariableReferenceValue}.cpp implements those raw forms.
///
/// Cycles return the WHOLE empty string (liaison Q10). Design follows
/// Blink CSSUnparsedValue::AppendUnparsedString / ToStringInternal,
/// chromium 9ef64552f77b59e11090cdb22ce4c72592c52ddd, and Houdini #1158.
/// Only the active path detects cycles: a DAG may visit one child twice.
/// Frames replace native recursion, including for deeply nested fallbacks.
pub fn serialize(allocator: std.mem.Allocator, root: usize, reader: anytype) ![]u8 {
    const Frame = struct { id: usize, index: usize = 0, close: bool = false };
    var frames: std.ArrayList(Frame) = .empty;
    defer frames.deinit(allocator);
    var active: std.AutoHashMapUnmanaged(usize, void) = .empty;
    defer active.deinit(allocator);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try frames.append(allocator, .{ .id = root });
    try active.put(allocator, root, {});
    while (frames.items.len != 0) {
        const top = &frames.items[frames.items.len - 1];
        if (top.index == try reader.length(top.id)) {
            if (top.close) try out.append(allocator, ')');
            _ = active.remove(top.id);
            _ = frames.pop();
            continue;
        }
        const item = try reader.segment(top.id, top.index);
        defer reader.release(item);
        top.index += 1;
        switch (item) {
            .string => |string| try out.appendSlice(allocator, string),
            .variable => |variable| {
                try out.appendSlice(allocator, "var(");
                try out.appendSlice(allocator, variable.name);
                if (variable.fallback) |fallback| {
                    if (active.contains(fallback)) return allocator.dupe(u8, "");
                    try out.append(allocator, ',');
                    try active.put(allocator, fallback, {});
                    try frames.append(allocator, .{ .id = fallback, .close = true });
                } else try out.append(allocator, ')');
            },
        }
    }
    return out.toOwnedSlice(allocator);
}
