//! "Canonical space sequences" (specs/w3c/execCommand.md): the canonical
//! space sequence and "canonicalize whitespace" at a boundary point.

const std = @import("std");
const common = @import("common.zig");

const Edit = common.Edit;
const Point = common.Point;
const Instance = common.Instance;

const nbsp: u16 = 0xA0;
const space: u16 = 0x20;

/// The "canonical space sequence" of length `n`, as UTF-16 code units
/// (U+0020 and U+00A0 only), appended to `out`.
pub fn canonicalSpaceSequence(out: *std.ArrayList(u16), allocator: std.mem.Allocator, n_in: u32, non_breaking_start: bool, non_breaking_end: bool) !void {
    var n = n_in;
    // Step 1.
    if (n == 0) return;
    // Step 2.
    if (n == 1 and !non_breaking_start and !non_breaking_end) return out.append(allocator, space);
    // Step 3.
    if (n == 1) return out.append(allocator, nbsp);
    // Steps 4-5.
    const repeated_pair: [2]u16 = if (non_breaking_start) .{ nbsp, space } else .{ space, nbsp };
    // Step 6.
    while (n > 3) : (n -= 2) try out.appendSlice(allocator, &repeated_pair);
    // Step 7.
    if (n == 3) {
        const triple: [3]u16 = if (!non_breaking_start and !non_breaking_end)
            .{ space, nbsp, space }
        else if (non_breaking_start and !non_breaking_end)
            .{ nbsp, nbsp, space }
        else if (!non_breaking_start and non_breaking_end)
            .{ space, nbsp, nbsp }
        else
            .{ nbsp, space, nbsp };
        return out.appendSlice(allocator, &triple);
    }
    // Step 8.
    const pair: [2]u16 = if (!non_breaking_end)
        .{ nbsp, space }
    else if (!non_breaking_start)
        .{ space, nbsp }
    else
        .{ nbsp, nbsp };
    try out.appendSlice(allocator, &pair);
}

/// The UTF-16 code unit at `offset` of a Text node's data, or null.
fn unitAt(node: *Instance, offset: u32) !?u16 {
    var data = try common.textData(node);
    defer data.deinit(node.ctx.allocator);
    return common.codeUnitAt(data.asSlice(), offset);
}

/// Whether a Text node's parent keeps spaces: its resolved white-space is
/// pre or pre-wrap (or break-spaces).
fn parentPreservesSpaces(node: *Instance) !bool {
    return (try common.whiteSpaceAround(node)).preservesSpaces();
}

/// "canonicalize whitespace" at (node, offset), with `fix_collapsed_space`.
pub fn canonicalizeWhitespace(edit: *Edit, point: Point, fix_collapsed_space: bool) !void {
    const node = point.node;
    const offset = point.offset;
    // Step 1.
    if (!try common.isEditableOrEditingHost(node)) return;
    // Step 2.
    var start_node = node;
    var start_offset = offset;
    // Step 3: to the beginning of the whitespace run.
    while (true) {
        // Step 3.1.
        if (try common.childBefore(start_node, start_offset)) |child| {
            if (try common.inSameEditingHost(start_node, child)) {
                start_node = child;
                start_offset = try common.nodeLength(child);
                continue;
            }
        }
        // Step 3.2.
        if (start_offset == 0 and !(try common.followsLineBreak(start_node))) {
            if (try common.parent(start_node)) |p| {
                if (try common.inSameEditingHost(start_node, p)) {
                    start_offset = try common.indexOf(start_node);
                    start_node = p;
                    continue;
                }
            }
        }
        // Step 3.3.
        if (common.isText(start_node) and !(try parentPreservesSpaces(start_node)) and start_offset != 0) {
            if (try unitAt(start_node, start_offset - 1)) |unit| {
                if (common.isSpaceOrNbsp(unit)) {
                    start_offset -= 1;
                    continue;
                }
            }
        }
        // Step 3.4.
        break;
    }
    // Step 4.
    var end_node = start_node;
    var end_offset = start_offset;
    // Step 5.
    var length: u32 = 0;
    // Step 6.
    var collapse_spaces = start_offset == 0 and try common.followsLineBreak(start_node);
    // Step 7: over the run, collapsing spaces at a line start.
    while (true) {
        // Step 7.1.
        if (try common.childAt(end_node, end_offset)) |child| {
            if (try common.inSameEditingHost(end_node, child)) {
                end_node = child;
                end_offset = 0;
                continue;
            }
        }
        // Step 7.2.
        if (end_offset == try common.nodeLength(end_node) and !(try common.precedesLineBreak(end_node))) {
            if (try common.parent(end_node)) |p| {
                if (try common.inSameEditingHost(end_node, p)) {
                    end_offset = 1 + try common.indexOf(end_node);
                    end_node = p;
                    continue;
                }
            }
        }
        // Step 7.3.
        if (common.isText(end_node) and !(try parentPreservesSpaces(end_node)) and end_offset != try common.nodeLength(end_node)) {
            if (try unitAt(end_node, end_offset)) |unit| {
                if (common.isSpaceOrNbsp(unit)) {
                    // Step 7.3.1.
                    if (fix_collapsed_space and collapse_spaces and unit == space) {
                        try edit.deleteData(end_node, end_offset, 1);
                        continue;
                    }
                    // Step 7.3.2.
                    collapse_spaces = unit == space;
                    // Steps 7.3.3-7.3.4.
                    end_offset += 1;
                    length += 1;
                    continue;
                }
            }
        }
        // Step 7.4.
        break;
    }
    // Step 8: strip collapsed trailing whitespace.
    if (fix_collapsed_space) {
        while (try common.pointIsBefore(.{ .node = start_node, .offset = start_offset }, .{ .node = end_node, .offset = end_offset })) {
            // Step 8.1.
            if (try common.childBefore(end_node, end_offset)) |child| {
                if (try common.inSameEditingHost(end_node, child)) {
                    end_node = child;
                    end_offset = try common.nodeLength(child);
                    continue;
                }
            }
            // Step 8.2.
            if (end_offset == 0) {
                if (try common.parent(end_node)) |p| {
                    if (try common.inSameEditingHost(end_node, p)) {
                        end_offset = try common.indexOf(end_node);
                        end_node = p;
                        continue;
                    }
                }
            }
            // Step 8.3.
            if (common.isText(end_node) and !(try parentPreservesSpaces(end_node)) and end_offset == try common.nodeLength(end_node) and end_offset != 0) {
                const last = (try unitAt(end_node, end_offset - 1)) orelse break;
                if (last == space and try common.precedesLineBreak(end_node)) {
                    end_offset -= 1;
                    length -= 1;
                    try edit.deleteData(end_node, end_offset, 1);
                    continue;
                }
            }
            // Step 8.4.
            break;
        }
    }
    // Step 9: the replacement.
    var replacement: std.ArrayList(u16) = .empty;
    defer replacement.deinit(edit.allocator);
    const non_breaking_start = start_offset == 0 and try common.followsLineBreak(start_node);
    // "non-breaking end is true if end offset is end node's length and end
    // node precedes a line break" - any node: a run that ends before a br
    // ends at (br, 0), and a space there would collapse
    // (`<p><a href=foo>foo&nbsp;[]<br><br></a></p>` keeps its no-break space
    // on insertParagraph in Chrome 156, Firefox 158 and Safari 27,
    // editing/run/insertparagraph.html at wpt.fyi 5af3c135c9).
    const non_breaking_end = end_offset == (try common.nodeLength(end_node)) and try common.precedesLineBreak(end_node);
    try canonicalSpaceSequence(&replacement, edit.allocator, length, non_breaking_start, non_breaking_end);
    var next_unit: usize = 0;
    // Step 10: write it over the run, one code unit at a time.
    while (try common.pointIsBefore(.{ .node = start_node, .offset = start_offset }, .{ .node = end_node, .offset = end_offset })) {
        // Step 10.1.
        if (try common.childAt(start_node, start_offset)) |child| {
            start_node = child;
            start_offset = 0;
            continue;
        }
        // Step 10.2.
        if (!common.isText(start_node) or start_offset == try common.nodeLength(start_node)) {
            start_offset = 1 + try common.indexOf(start_node);
            start_node = (try common.parent(start_node)) orelse break;
            continue;
        }
        // Step 10.3.
        if (next_unit >= replacement.items.len) break;
        const element = replacement.items[next_unit];
        next_unit += 1;
        const current = (try unitAt(start_node, start_offset)) orelse break;
        if (element != current) {
            // Steps 10.3.2.1-2: insert then delete, keeping range boundaries.
            const text: []const u8 = if (element == nbsp) "\u{A0}" else " ";
            try edit.insertData(start_node, start_offset, text);
            try edit.deleteData(start_node, start_offset + 1, 1);
        }
        // Step 10.3.3.
        start_offset += 1;
    }
}

test "canonical space sequence" {
    const allocator = std.testing.allocator;
    const Case = struct { n: u32, start: bool, end: bool, expected: []const u16 };
    const cases = [_]Case{
        .{ .n = 0, .start = false, .end = false, .expected = &.{} },
        .{ .n = 1, .start = false, .end = false, .expected = &.{space} },
        .{ .n = 1, .start = true, .end = false, .expected = &.{nbsp} },
        .{ .n = 2, .start = false, .end = false, .expected = &.{ nbsp, space } },
        .{ .n = 2, .start = false, .end = true, .expected = &.{ space, nbsp } },
        .{ .n = 2, .start = true, .end = true, .expected = &.{ nbsp, nbsp } },
        .{ .n = 3, .start = false, .end = false, .expected = &.{ space, nbsp, space } },
        .{ .n = 3, .start = true, .end = false, .expected = &.{ nbsp, nbsp, space } },
        .{ .n = 3, .start = false, .end = true, .expected = &.{ space, nbsp, nbsp } },
        .{ .n = 3, .start = true, .end = true, .expected = &.{ nbsp, space, nbsp } },
        .{ .n = 4, .start = false, .end = false, .expected = &.{ space, nbsp, nbsp, space } },
        .{ .n = 5, .start = true, .end = true, .expected = &.{ nbsp, space, nbsp, space, nbsp } },
    };
    for (cases) |case| {
        var out: std.ArrayList(u16) = .empty;
        defer out.deinit(allocator);
        try canonicalSpaceSequence(&out, allocator, case.n, case.start, case.end);
        try std.testing.expectEqualSlices(u16, case.expected, out.items);
    }
}
