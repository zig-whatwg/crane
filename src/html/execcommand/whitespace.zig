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

/// Byte offset in UTF-8 `bytes` corresponding to UTF-16 `unit_offset` for a
/// Text node of UTF-16 `node_len`. Pure ASCII (`bytes.len == node_len`) and
/// endpoints resolve in O(1) without scanning from byte 0.
fn byteOffsetInText(bytes: []const u8, unit_offset: u32, node_len: u32) usize {
    if (unit_offset == 0) return 0;
    if (unit_offset >= node_len) return bytes.len;
    if (bytes.len == node_len) return @min(@as(usize, unit_offset), bytes.len);
    return common.byteOffsetOfUnits(bytes, unit_offset);
}

/// Decode one UTF-16 code unit (or space/nbsp) at code-point boundary `pos`
/// of UTF-8 `bytes`, returning the unit and byte length (or null at EOF).
/// Only used for single-unit characters inside whitespace runs (spaces/nbsps);
/// supplementary code points advance by their full 4-byte sequence.
fn decodeUnitAtByte(bytes: []const u8, pos: usize) ?struct { unit: u16, byte_len: usize } {
    if (pos >= bytes.len) return null;
    const b0 = bytes[pos];
    if (b0 < 0x80) return .{ .unit = b0, .byte_len = 1 };
    if (b0 == 0xC2 and pos + 1 < bytes.len and bytes[pos + 1] == 0xA0) return .{ .unit = nbsp, .byte_len = 2 };
    const len = std.unicode.utf8ByteSequenceLength(b0) catch 1;
    if (pos + len > bytes.len) return null;
    const cp = std.unicode.utf8Decode(bytes[pos .. pos + len]) catch 0xFFFD;
    const unit: u16 = if (cp >= 0x10000) @intCast(0xD800 + ((cp - 0x10000) >> 10)) else @intCast(cp);
    return .{ .unit = unit, .byte_len = len };
}

/// Whether a Text node's parent keeps spaces: its resolved white-space is
/// pre or pre-wrap (or break-spaces).
fn parentPreservesSpaces(node: *Instance) !bool {
    return (try common.whiteSpaceAround(node)).preservesSpaces();
}

/// Whether the next node after `node` in its line - its next sibling, or
/// an inline ancestor's - is a white-space-only Text node (a "whitespace
/// node"): no block edge and no editing host is crossed to reach it.
fn followedByWhitespaceNode(node: *Instance) !bool {
    var current = node;
    while ((try common.nextSibling(current)) == null) {
        current = (try common.parent(current)) orelse return false;
        if (common.isBlockNode(current) or try common.isEditingHost(current)) return false;
    }
    const next = (try common.nextSibling(current)) orelse return false;
    return common.isText(next) and try common.isWhitespaceNode(next);
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
        // Step 3.3: scan backward over the entire contiguous space/nbsp run
        // in this Text node with one textData read (avoiding O(N^2) copies).
        if (common.isText(start_node) and !(try parentPreservesSpaces(start_node)) and start_offset != 0) {
            const node_len = try common.nodeLength(start_node);
            var data = try common.textData(start_node);
            defer data.deinit(start_node.ctx.allocator);
            const bytes = data.asSlice();
            var pos = byteOffsetInText(bytes, start_offset, node_len);
            while (start_offset > 0) {
                if (pos >= 1 and bytes[pos - 1] == space) {
                    pos -= 1;
                    start_offset -= 1;
                } else if (pos >= 2 and bytes[pos - 2] == 0xC2 and bytes[pos - 1] == 0xA0) {
                    pos -= 2;
                    start_offset -= 1;
                } else break;
            }
            if (start_offset == 0) continue;
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
        // Step 7.2. The run must reach back to `point`: step 3 can walk
        // backward out of a white-space-only Text node that a deletion
        // left ("abc <span>def</span>[ ]" after "ghi" went), and that node
        // makes "def" "precede a line break" (it is a collapsed whitespace
        // node), so the spec's walk forward stops at "def" and never
        // canonicalizes the space at `point`. Until the walk is back at
        // `point`, it climbs over the end of a node that only a white-space-
        // only Text node follows in its line (never past a br or a block
        // edge: those are line breaks). Blink rebalances
        // the Text node holding the position (CompositeEditCommand::
        // RebalanceWhitespaceAt), Gecko the white-space run around it
        // (WhiteSpaceVisibilityKeeper): both keep that space visible as a
        // no-break space, and editing/whitespaces/delete-word-around-
        // span.html's "abc <span>def</span> ghi[]" (Chrome 157, Firefox 160,
        // Safari 27.2 at wpt.fyi 24ddf405a0) compares it with "abc def
        // ghi[]", whose single Text node the spec's walk does reach.
        // (A deletion of collapsed spaces in 7.3.1 can shorten `point`'s
        // node: compare with its offset clamped to the node's length.)
        const target = Point{ .node = node, .offset = @min(offset, try common.nodeLength(node)) };
        const short_of_point = try common.pointIsBefore(.{ .node = end_node, .offset = end_offset }, target);
        if (end_offset == try common.nodeLength(end_node) and
            ((short_of_point and try followedByWhitespaceNode(end_node)) or !(try common.precedesLineBreak(end_node))))
        {
            if (try common.parent(end_node)) |p| {
                if (try common.inSameEditingHost(end_node, p)) {
                    end_offset = 1 + try common.indexOf(end_node);
                    end_node = p;
                    continue;
                }
            }
        }
        // Step 7.3: scan forward through this Text node's space/nbsp run with
        // one textData read and batch contiguous collapsed U+0020 deletions.
        if (common.isText(end_node) and !(try parentPreservesSpaces(end_node))) {
            const node_len = try common.nodeLength(end_node);
            if (end_offset != node_len) {
                var data = try common.textData(end_node);
                defer data.deinit(end_node.ctx.allocator);
                const bytes = data.asSlice();
                var pos = byteOffsetInText(bytes, end_offset, node_len);
                var progressed = false;
                while (pos < bytes.len) {
                    const next_unit: u16, const char_len: usize = if (bytes[pos] == space)
                        .{ space, 1 }
                    else if (pos + 1 < bytes.len and bytes[pos] == 0xC2 and bytes[pos + 1] == 0xA0)
                        .{ nbsp, 2 }
                    else
                        break;
                    progressed = true;
                    // Step 7.3.1: every consecutive U+0020 while collapse_spaces
                    // is true collapses; delete the whole contiguous run at once.
                    if (fix_collapsed_space and collapse_spaces and next_unit == space) {
                        var del_count: u32 = 1;
                        pos += 1;
                        while (pos < bytes.len and bytes[pos] == space) {
                            pos += 1;
                            del_count += 1;
                        }
                        try edit.deleteData(end_node, end_offset, del_count);
                        continue;
                    }
                    // Step 7.3.2.
                    collapse_spaces = next_unit == space;
                    // Steps 7.3.3-7.3.4.
                    end_offset += 1;
                    length += 1;
                    pos += char_len;
                }
                if (progressed and pos == bytes.len) continue;
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
            // Step 8.3: delete all trailing collapsed U+0020 in this Text node in one call.
            if (common.isText(end_node) and !(try parentPreservesSpaces(end_node))) {
                const node_len = try common.nodeLength(end_node);
                if (end_offset == node_len and end_offset != 0 and try common.precedesLineBreak(end_node)) {
                    var data = try common.textData(end_node);
                    defer data.deinit(end_node.ctx.allocator);
                    const bytes = data.asSlice();
                    const min_offset: u32 = if (start_node == end_node) start_offset else 0;
                    var del_count: u32 = 0;
                    var pos = bytes.len;
                    while (end_offset > min_offset and pos >= 1 and bytes[pos - 1] == space) {
                        pos -= 1;
                        end_offset -= 1;
                        del_count += 1;
                    }
                    if (del_count > 0) {
                        length -= del_count;
                        try edit.deleteData(end_node, end_offset, del_count);
                        continue;
                    }
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
    //
    // A run that ends where its editing host's editable content stops - the
    // next node is not in the same editing host (a contenteditable=false
    // element) - is given a non-breaking end too: what follows can be taken
    // away by script, and a plain space would then collapse. All three
    // browsers keep a space typed before such an element visible after the
    // element is removed (editing/whitespaces/keep-typed-collapsible-white-
    // space-visible-after-muation.html, wpt.fyi 2358bd4835: Chrome 157,
    // Firefox 160 and Safari 27.2 pass); Blink and WebKit emit the no-break
    // space when typing, as their whitespace rebalancing ends a run at its
    // Text node's end with one (CompositeEditCommand::
    // RebalanceWhitespaceOnTextSubstring's should_emit_nbsp_before_end).
    const before_non_editable = if (try common.childAt(end_node, end_offset)) |next| !(try common.inSameEditingHost(end_node, next)) else false;
    const non_breaking_end = (end_offset == (try common.nodeLength(end_node)) and try common.precedesLineBreak(end_node)) or before_non_editable;
    try canonicalSpaceSequence(&replacement, edit.allocator, length, non_breaking_start, non_breaking_end);
    var next_unit: usize = 0;
    // Step 10: write it over the run, reading each Text node's data once.
    while (try common.pointIsBefore(.{ .node = start_node, .offset = start_offset }, .{ .node = end_node, .offset = end_offset })) {
        // Step 10.1.
        if (try common.childAt(start_node, start_offset)) |child| {
            start_node = child;
            start_offset = 0;
            continue;
        }
        // Step 10.2.
        const node_len = if (common.isText(start_node)) try common.nodeLength(start_node) else 0;
        if (!common.isText(start_node) or start_offset == node_len) {
            start_offset = 1 + try common.indexOf(start_node);
            start_node = (try common.parent(start_node)) orelse break;
            continue;
        }
        // Step 10.3: process the whole covered span of this Text node in one pass.
        if (next_unit >= replacement.items.len) break;
        const limit: u32 = if (start_node == end_node) end_offset else node_len;
        var data = try common.textData(start_node);
        defer data.deinit(start_node.ctx.allocator);
        const bytes = data.asSlice();
        var pos = byteOffsetInText(bytes, start_offset, node_len);
        while (start_offset < limit and next_unit < replacement.items.len) {
            const decoded = decodeUnitAtByte(bytes, pos) orelse break;
            pos += decoded.byte_len;
            const element = replacement.items[next_unit];
            next_unit += 1;
            if (element != decoded.unit) {
                // Steps 10.3.2.1-2: insert then delete, keeping range boundaries.
                const text: []const u8 = if (element == nbsp) "\u{A0}" else " ";
                try edit.insertData(start_node, start_offset, text);
                try edit.deleteData(start_node, start_offset + 1, 1);
            }
            // Step 10.3.3.
            start_offset += 1;
        }
        if (next_unit >= replacement.items.len) break;
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
