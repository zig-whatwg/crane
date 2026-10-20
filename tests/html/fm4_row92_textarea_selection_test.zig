//! Forms remainder regressions through generated interfaces, with leak checking.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

const support = @import("fm4_row92_support.zig");
const create = support.create;
const withDocument = support.withDocument;

fn textareaClamp(document: *runtime.Instance) !void {
    const textarea = try create(document, "textarea");
    defer dom.node_creation.destroyUninserted(textarea);
    try interfaces.HTMLTextAreaElement.set_defaultValue(textarea, runtime.DOMString.initInterned("abcdef"));
    try interfaces.HTMLTextAreaElement.set_selectionStart(textarea, 3);
    try interfaces.HTMLTextAreaElement.set_selectionEnd(textarea, 5);
    const removed_text = (try interfaces.Node.get_firstChild(textarea)).?;
    defer dom.node_creation.destroyUninserted(removed_text);
    // No intervening getter: clamping must happen at the mutation, not on read.
    try interfaces.HTMLTextAreaElement.set_defaultValue(textarea, runtime.DOMString.initInterned("another value"));
    try testing.expectEqual(@as(u32, 0), try interfaces.HTMLTextAreaElement.get_selectionStart(textarea));
    try testing.expectEqual(@as(u32, 0), try interfaces.HTMLTextAreaElement.get_selectionEnd(textarea));
}

test "textarea child replacement permanently clamps clean selection" {
    try withDocument(textareaClamp);
}
