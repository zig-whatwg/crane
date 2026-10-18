const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;
const fixture = @import("fm3_fixture.zig");
const create = fixture.create;
const attribute = fixture.attribute;

fn exercise(document: *runtime.Instance) !void {
    const form = try create(document, "form");
    defer dom.node_creation.destroyUninserted(form);
    const textarea = try create(document, "textarea");
    _ = try interfaces.Node.call_appendChild(form, textarea);
    try attribute(textarea, "name", "message");
    try attribute(textarea, "cols", "7");
    try attribute(textarea, "wrap", "HaRd");
    try interfaces.HTMLTextAreaElement.set_value(textarea, runtime.DOMString.initInterned("hello world\r\nsecond line"));
    const data = try interfaces.FormData.call_constructor(document.ctx, .notPassed(), .notPassed());
    defer runtime.Instance.deinit(data);
    try dom.form_submission.constructEntryList(form, null, data);
    const entries = interfaces.FormData.getEntriesForIterable(data).?;
    try testing.expectEqual(@as(usize, 1), entries.len);
    const submitted = entries[0].value.usvstring;
    try testing.expect(!std.mem.eql(u8, submitted, "hello world\nsecond line"));
    var value = try interfaces.HTMLTextAreaElement.get_value(textarea);
    defer value.deinit(testing.allocator);
    try testing.expectEqualStrings("hello world\nsecond line", value.asSlice());
    var lines = std.mem.splitScalar(u8, submitted, '\n');
    while (lines.next()) |line| try testing.expect(std.mem.trimEnd(u8, line, "\r").len <= 7);
}

test "textarea wrapping is confined to form-entry values" {
    try fixture.run(exercise);
}
