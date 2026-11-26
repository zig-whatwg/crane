//! The Editing spec's insertText command (specs/w3c/execCommand.md, "The
//! insertText command"): the action every typed character runs, from
//! document.execCommand("insertText") and from the keyboard (root.zig
//! typeByKey).
//!
//! The overrides are what make typing keep a style: step 9 records the
//! Document's state and value overrides (a bold run with a collapsed
//! selection, a deleted wrapper's style), step 15 restores them onto the
//! inserted character by taking each command's action on it.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const dom = @import("dom");
const common = @import("common.zig");
const delete = @import("delete.zig");
const whitespace = @import("whitespace.zig");
const overrides = @import("overrides.zig");

const Edit = common.Edit;
const Instance = common.Instance;
const DOMString = runtime.DOMString;

/// The insertParagraph action, reached through the dispatch (lane
/// editing4's, blocks.zig).
pub const ParagraphAction = *const fn (edit: *Edit) anyerror!bool;

/// After insertText's deletion, where the text goes, as all three
/// browsers put it: into the text that follows when the deletion left the
/// caret at the end of the text before it (its downstream point) and no
/// typing style is pending - `abc[<b><i>de]f</i></b>ghi` + "d", "e" types
/// `abc<b><i>def</i></b>ghi` (editing/run/inserttext.html, PPP at wpt.fyi
/// 2358bd4835; Blink's InsertTextCommand inserts at the selection's
/// downstream start) - and never into a link the deletion emptied: `foo<a
/// href=...>[bar</a>baz]` + "a" types `fooa` (PPP; Blink
/// PositionAvoidingSpecialElementBoundary). The spec inserts at the
/// deletion's caret. Golden rule 2, no newer spec.
fn moveToInsertionPoint(edit: *Edit, end_link: ?*Instance) !void {
    if (!try edit.rangeCollapsed()) return;
    var caret = (try edit.rangeStart()) orelse return;
    // An emptied link goes, the caret where it was - when the selection
    // ran past it: text typed over a selection inside a link stays in it
    // (`foo<a href=...>[bar]</a>baz` + "a" -> `foo<a href=...>a</a>baz`, PPP).
    var current: ?*Instance = caret.node;
    while (current) |c| : (current = try common.parent(c)) {
        if (!try common.isEditable(c)) break;
        if (!common.isInlineNode(c)) break;
        if ((try common.isHtmlElementNamed(c, "a")) and c != end_link and !try common.isVisible(c)) {
            const p = (try common.parent(c)) orelse break;
            const index = try common.indexOf(c);
            try edit.removeNode(c);
            try edit.collapse(p, index);
            caret = .{ .node = p, .offset = index };
            break;
        }
    }
    if (try overrides.hasOverrides(edit)) return;
    const downstream = try common.lastEquivalentPoint(caret);
    if (downstream.eql(caret) or !common.isText(downstream.node)) return;
    if ((try common.parent(downstream.node)) == (try common.parent(caret.node))) return;
    try edit.collapse(downstream.node, downstream.offset);
}

/// A line break that holds an empty line open: a br, or a preserved line
/// feed (white-space pre, pre-wrap, pre-line), at the end of its block.
const Padding = union(enum) {
    br: *Instance,
    line_feed: common.Point,
};

/// The line break at `caret` that only holds the caret's line open: the
/// caret starts its line (after a forced break or at its block's start, with
/// nothing visible between) and the next thing is a line break that ends
/// its block (endsItsBlock). Typed text fills the line, so the line
/// break becomes unnecessary and goes once the text is in: Blink's
/// InsertTextCommand removes it (ComputePlaceholderToRemove: a line break at
/// the caret's downstream position when the caret is at the start of its
/// paragraph and the end of its block, then RemovePlaceholderAt - a br, or
/// the "\n" of a Text that preserves newlines), and Gecko its padding line
/// break for an empty last line. `<div style="white-space:pre">[]\n</div>` +
/// "X" gives `X`, and typing into the empty line insertLineBreak made in
/// `<p><b>AB[]</b></p>` gives `AB\na` (editing/plaintext-only/
/// insertText.html, editing/run/inserttext.html, editing/other/inserttext-
/// before-unnecessary-linebreak.html: PPP at wpt.fyi 2358bd4835); the spec
/// removes only a collapsed br that is the node's sole child (step 14.1).
/// Golden rule 2, no newer spec. A line break after text on its line stays
/// (`<p>abc[]<br></p>` + "x" keeps it, all three).
fn paddingLineBreakAt(caret: common.Point) !?Padding {
    if (!try startsLine(caret)) return null;
    const down = try common.lastEquivalentPoint(caret);
    if (common.isText(down.node)) {
        var data = try common.textData(down.node);
        defer data.deinit(down.node.ctx.allocator);
        const length = try common.nodeLength(down.node);
        if (down.offset < length) {
            // A preserved line feed, the Text's last character, with nothing
            // visible after it in its block.
            if ((common.codeUnitAt(data.asSlice(), down.offset) orelse return null) != '\n') return null;
            if (down.offset + 1 != length) return null;
            if (!(try common.whiteSpaceAround(down.node)).preservesNewlines()) return null;
            if (!try endsItsBlock(down.node)) return null;
            return .{ .line_feed = down };
        }
        const next = (try common.nextSibling(down.node)) orelse return null;
        return try brPadding(next);
    }
    const after = (try common.childAt(down.node, down.offset)) orelse return null;
    return try brPadding(after);
}

/// `node` as a padding br: a br at the end of its block.
fn brPadding(node: *Instance) !?Padding {
    if (!try common.isHtmlElementNamed(node, "br")) return null;
    if (!try common.isEditable(node)) return null;
    if (!try endsItsBlock(node)) return null;
    return .{ .br = node };
}

/// Whether nothing visible and no block follows `node` before the end of
/// the block that holds it - Blink's IsEndOfBlock for the placeholder: a br
/// before a child block stays (`<div>{}<br><p>p</p></div>` + "x" keeps it,
/// Chrome and Safari; editing/other/inserttext-before-unnecessary-
/// linebreak.html, Firefox alone removes it).
fn endsItsBlock(node: *Instance) !bool {
    var current = node;
    while (true) {
        var next = try common.nextSibling(current);
        while (next) |n| : (next = try common.nextSibling(n)) {
            if (common.isBlockNode(n)) return false;
            if (try common.isVisible(n)) return false;
        }
        const p = (try common.parent(current)) orelse return true;
        if (common.isBlockNode(p) or try common.isEditingHost(p)) return true;
        current = p;
    }
}

/// Whether `point` starts its line: after a forced break (a br, a preserved
/// line feed) or at its block's start, with nothing visible between.
fn startsLine(point: common.Point) !bool {
    if (common.isText(point.node)) {
        if (point.offset > 0) {
            var data = try common.textData(point.node);
            defer data.deinit(point.node.ctx.allocator);
            if ((common.codeUnitAt(data.asSlice(), point.offset - 1) orelse return false) != '\n') return false;
            return (try common.whiteSpaceAround(point.node)).preservesNewlines();
        }
        return try common.followsLineBreak(point.node);
    }
    if (try common.childBefore(point.node, point.offset)) |before| {
        if (try common.isHtmlElementNamed(before, "br")) return true;
        if (common.isBlockNode(before)) return true;
        return false;
    }
    if (try common.childAt(point.node, point.offset)) |at| return try common.followsLineBreak(at);
    return try common.isBlockBoundaryPoint(point);
}

/// Remove the padding line break once the text is in (`into`, `at`: where
/// `length` code units were inserted).
fn removePadding(edit: *Edit, padding: Padding, into: *Instance, at: u32, length: u32) !void {
    switch (padding) {
        .br => |br| {
            if ((try common.parent(br)) == null) return;
            if (!try common.isEditable(br)) return;
            try edit.removeNode(br);
        },
        .line_feed => |point| {
            var offset = point.offset;
            if (point.node == into and at <= offset) offset += length;
            if (offset >= try common.nodeLength(point.node)) return;
            var data = try common.textData(point.node);
            defer data.deinit(point.node.ctx.allocator);
            if ((common.codeUnitAt(data.asSlice(), offset) orelse return) != '\n') return;
            try edit.deleteData(point.node, offset, 1);
        },
    }
}

/// Whether Blink and WebKit replace the selection in place, in the Text node
/// that holds it, instead of deleting it first: Blink's InsertTextCommand::
/// PerformTrivialReplace and CompositeEditCommand::ReplaceSelectedTextInNode
/// (third_party/blink/renderer/core/editing/commands/insert_text_command.cc
/// and composite_edit_command.cc, chromium 1f3d2bc10d1; WebKit has the same
/// pair). Its conditions, in its order: the value is not empty; the
/// selection is a range; the value holds no tab, space or line feed; not a
/// one-character value over a selection that covers the whole content of
/// the link around it; the range starts and ends in one Text node (Blink
/// also refuses its own tab-span Text nodes, which Crane never makes). The
/// caller has checked the range is not collapsed.
fn isTrivialReplace(edit: *Edit, value: []const u8) !bool {
    if (value.len == 0) return false;
    if (std.mem.indexOfAny(u8, value, "\t \n") != null) return false;
    const start = (try edit.rangeStart()) orelse return false;
    const end = (try edit.rangeEnd()) orelse return false;
    if (!common.isText(start.node) or start.node != end.node) return false;
    if (common.utf16Length(value) <= 1) {
        // "if the text is surrounded by a hyperlink and all the contents of
        // the link are selected", the link goes with the selection: the
        // whole Text selected, and nothing else in the link around it.
        if (start.offset == 0 and end.offset == try common.nodeLength(start.node)) {
            var current = start.node;
            while (try common.parent(current)) |p| : (current = p) {
                if ((try common.childCount(p)) != 1) break;
                if (try common.isHtmlElementNamed(p, "a")) return false;
            }
        }
    }
    return true;
}

/// The insertText action with `value`.
pub fn action(edit: *Edit, value: []const u8, insert_paragraph: ParagraphAction) anyerror!bool {
    return actionReplacing(edit, value, insert_paragraph, false);
}

/// The insertText action; `in_place`: the value replaces a selection inside
/// one Text node, as Blink and WebKit do it (isTrivialReplace) - for each
/// character of a longer value too.
fn actionReplacing(edit: *Edit, value: []const u8, insert_paragraph: ParagraphAction, in_place: bool) anyerror!bool {
    var replaced_in_place = in_place;
    // Step 1: "Delete the selection, with strip wrappers false." Run only
    // for a non-collapsed range: on a collapsed one it only canonicalizes
    // the white-space around the caret, which step 11 does anyway (lane
    // editing2's measured behaviour, editing/run/inserttext.html).
    if (!try edit.rangeCollapsed()) {
        replaced_in_place = try isTrivialReplace(edit, value);
        // The link the selection ends in, if any (see moveToInsertionPoint).
        var end_link: ?*Instance = null;
        if (try edit.rangeEnd()) |end| {
            var up: ?*Instance = end.node;
            while (up) |u| : (up = try common.parent(u)) {
                if (try common.isHtmlElementNamed(u, "a")) {
                    end_link = u;
                    break;
                }
            }
        }
        try delete.deleteTheSelection(edit, true, false, .forward);
        try moveToInsertionPoint(edit, end_link);
    }
    // Step 2: "If the active range's start node is neither editable nor an
    // editing host, return true."
    const start = (try edit.rangeStart()) orelse return true;
    if (!try common.isEditableOrEditingHost(start.node)) return true;
    // Step 3: more than one character - one insertion per character. Per
    // code point rather than per UTF-16 code unit: a surrogate pair split
    // in two cannot be stored in a Crane string, and every browser inserts
    // a non-BMP character whole (editing/other/insert-text-with-surrogate-
    // pairs.html, all three pass).
    if ((std.unicode.utf8CountCodepoints(value) catch 1) > 1) {
        var iterator = std.unicode.Utf8Iterator{ .bytes = value, .i = 0 };
        while (iterator.nextCodepointSlice()) |code_point| _ = try actionReplacing(edit, code_point, insert_paragraph, replaced_in_place);
        return true;
    }
    // Step 4: "If value is the empty string, return true."
    if (value.len == 0) return true;
    // Step 5: a newline is a new paragraph.
    if (std.mem.eql(u8, value, "\n")) {
        _ = try insert_paragraph(edit);
        return true;
    }
    // A br that only held an empty line open goes once text fills the line,
    // and one before the caret that draws nothing (an extraneous line
    // break) is replaced by the text: all three browsers type `abc<br>{}
    // <br>` + "d" into `abc<br>d` and `<span contenteditable=false>abc
    // </span><br>{}` + "d" into `<span contenteditable="false">abc</span>d`
    // (editing/run/inserttext.html, PPP at wpt.fyi 2358bd4835); the spec
    // removes only a collapsed line break that is the node's sole child
    // (step 14.1). Gecko: the padding <br> for an empty line is removed when
    // the line gets content (HTMLEditor::InsertTextWithTransaction's
    // padding-br handling). Golden rule 2, no newer spec.
    if (!common.isText(start.node)) {
        const before = try common.childBefore(start.node, start.offset);
        const after = try common.childAt(start.node, start.offset);
        if (before != null and after == null and (try common.isEditable(before.?)) and (try common.isHtmlElementNamed(before.?, "br")) and try common.isExtraneousLineBreak(before.?)) {
            try edit.removeNode(before.?);
        } else if (after != null and (try common.isEditable(after.?)) and (try common.isCollapsedLineBreak(after.?)) and !(try common.isExtraneousLineBreak(after.?)) and (try common.nextSibling(after.?)) == null and before != null) {
            // Only the br ending its block, after other content: one before
            // a block keeps its line (`<p>foo</p>{}<br><p>baz</p>` types
            // `X<br>`), and a sole br is step 14.1's.
            try edit.removeNode(after.?);
        }
    }
    const caret = (try edit.rangeStart()) orelse return true;
    // The line break that only holds the caret's empty line open, which the
    // text makes unnecessary (see paddingLineBreakAt) - except after a
    // replacement in place, which removes no placeholder: Blink and WebKit
    // return from PerformTrivialReplace before their placeholder step, so
    // `<p>[abc]\n</p>` + "x" keeps its line feed (editing/other/inserttext-
    // before-unnecessary-linebreak.html, Chrome and Safari pass, Firefox
    // fails; golden rule 2, the majority).
    const padding = if (replaced_in_place) null else try paddingLineBreakAt(caret);
    // Step 6.
    var node = caret.node;
    var offset = caret.offset;
    // Step 7: a Text node just before the point takes the text at its end.
    if (try common.childBefore(node, offset)) |before| {
        if (common.isText(before)) {
            node = before;
            offset = try common.nodeLength(before);
        }
    }
    // Step 8: else a Text node just after it, at its start.
    if (try common.childAt(node, offset)) |at| {
        if (common.isText(at)) {
            node = at;
            offset = 0;
        }
    }
    // Step 9: "Record current overrides".
    const recorded = try overrides.recordCurrentOverrides(edit);
    // Step 10: "Call collapse(node, offset) on the context object's
    // selection."
    try edit.collapse(node, offset);
    // Step 11: "Canonicalize whitespace at (node, offset)."
    try whitespace.canonicalizeWhitespace(edit, .{ .node = node, .offset = offset }, true);
    // Step 12: "Let (node, offset) be the active range's start."
    const point = (try edit.rangeStart()) orelse return true;
    node = point.node;
    offset = point.offset;
    const length = common.utf16Length(value);
    if (common.isText(node)) {
        // Step 13: insert into the Text node and select the character.
        try edit.insertData(node, offset, value);
        try edit.collapse(node, offset);
        try edit.extend(node, offset + length);
        if (padding) |p| try removePadding(edit, p, node, offset, length);
    } else {
        // Step 14.1: "If node has only one child, which is a collapsed line
        // break, remove its child from it."
        if ((try common.childCount(node)) == 1) {
            const only = (try common.firstChild(node)).?;
            if (try common.isCollapsedLineBreak(only)) try edit.removeNode(only);
        }
        // Steps 14.2-14.3: a new Text node at the active range.
        const range = (try edit.activeRange()) orelse return true;
        const text = try interfaces.Document.call_createTextNode(edit.document, DOMString.initInterned(value));
        {
            errdefer dom.node_creation.destroyUninserted(text);
            try edit.insertNode(range, text);
        }
        // Steps 14.4-14.5: select it.
        try edit.collapse(text, 0);
        try edit.extend(text, length);
        if (padding) |p| try removePadding(edit, p, text, 0, length);
    }
    // Step 15: "Restore states and values from overrides."
    edit.applying_typing_style = true;
    defer edit.applying_typing_style = false;
    try overrides.restoreStatesAndValues(edit, recorded);
    // Steps 16-17: canonicalize whitespace at the range's start and end,
    // fix collapsed space false.
    if (try edit.rangeStart()) |s| try whitespace.canonicalizeWhitespace(edit, s, false);
    if (try edit.rangeEnd()) |e| try whitespace.canonicalizeWhitespace(edit, e, false);
    // Step 18 ("If value is a space character, autolink the active range's
    // start") is not taken: no browser autolinks typed text - the WPT
    // expectations leave "http://a[]" + " " as "http://a&nbsp;"
    // (editing/data/inserttext.js), and Chrome, Firefox and Safari produce
    // that. Golden rule 2, no newer spec: the browsers decide.
    // Step 19: "Call collapseToEnd() on the context object's selection."
    try edit.collapseToEnd();
    // Step 20.
    return true;
}
