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

/// The insertText action with `value`.
pub fn action(edit: *Edit, value: []const u8, insert_paragraph: ParagraphAction) anyerror!bool {
    // Step 1: "Delete the selection, with strip wrappers false." Run only
    // for a non-collapsed range: on a collapsed one it only canonicalizes
    // the white-space around the caret, which step 11 does anyway (lane
    // editing2's measured behaviour, editing/run/inserttext.html).
    if (!try edit.rangeCollapsed()) try delete.deleteTheSelection(edit, true, false, .forward);
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
        while (iterator.nextCodepointSlice()) |code_point| _ = try action(edit, code_point, insert_paragraph);
        return true;
    }
    // Step 4: "If value is the empty string, return true."
    if (value.len == 0) return true;
    // Step 5: a newline is a new paragraph.
    if (std.mem.eql(u8, value, "\n")) {
        _ = try insert_paragraph(edit);
        return true;
    }
    // Step 6.
    var node = start.node;
    var offset = start.offset;
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
    } else {
        // Step 14.1: "If node has only one child, which is a collapsed line
        // break, remove its child from it."
        if ((try common.childCount(node)) == 1) {
            const only = (try common.firstChild(node)).?;
            if (try common.isCollapsedLineBreak(only)) try edit.removeNode(only);
        }
        // Steps 14.2-14.3: a new Text node at the active range.
        const text = try interfaces.Document.call_createTextNode(edit.document, DOMString.initInterned(value));
        const range = (try edit.activeRange()) orelse return true;
        try interfaces.Range.call_insertNode(range, text);
        edit.modified = true;
        // Steps 14.4-14.5: select it.
        try edit.collapse(text, 0);
        try edit.extend(text, length);
    }
    // Step 15: "Restore states and values from overrides."
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
