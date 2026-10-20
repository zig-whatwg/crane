//! Forms remainder regressions through generated interfaces, with leak checking.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

const support = @import("fm4_row92_support.zig");
const create = support.create;
const withDocument = support.withDocument;

fn optionNamespace(document: *runtime.Instance) !void {
    const option = try create(document, "option");
    defer dom.node_creation.destroyUninserted(option);
    const script = try interfaces.Document.call_createElementNS(document, null, runtime.DOMString.initInterned("script"), .notPassed());
    _ = try interfaces.Node.call_appendChild(option, script);
    try interfaces.Node.set_textContent(script, runtime.DOMString.initInterned(" visible "));
    var text = try interfaces.HTMLOptionElement.get_text(option);
    defer text.deinit(testing.allocator);
    try testing.expectEqualStrings("visible", text.asSlice());
}

test "option text includes null namespace script content" {
    try withDocument(optionNamespace);
}
