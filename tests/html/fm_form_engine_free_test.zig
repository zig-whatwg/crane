//! Native form algorithms must not require a JavaScript engine.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

const Scenario = enum { form, file_entry, control };

fn exercise(comptime scenario: Scenario) !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    const form = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("form"), .notPassed());
    defer dom.node_creation.destroyUninserted(form);
    const input = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("input"), .notPassed());
    _ = try interfaces.Node.call_appendChild(form, input);
    if (scenario == .file_entry) {
        try interfaces.HTMLInputElement.set_type(input, runtime.DOMString.initInterned("file"));
        try interfaces.HTMLInputElement.set_name(input, runtime.DOMString.initInterned("upload"));
        const data = try interfaces.FormData.call_constructor(&context, .notPassed(), .notPassed());
        defer runtime.Instance.deinit(data);
        try dom.form_submission.constructEntryList(form, null, data);
        const entries = interfaces.FormData.getEntriesForIterable(data).?;
        try testing.expectEqual(@as(usize, 1), entries.len);
        try testing.expectEqualStrings("upload", entries[0].name);
        try testing.expectEqualStrings("", entries[0].value.usvstring);
    } else if (scenario == .control) {
        try interfaces.HTMLInputElement.set_required(input, true);
        try testing.expect(!try interfaces.HTMLInputElement.call_checkValidity(input));
        try testing.expect(!try interfaces.HTMLInputElement.call_reportValidity(input));
        try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("valid"));
        try testing.expect(try interfaces.HTMLInputElement.call_checkValidity(input));
    } else {
        try interfaces.HTMLInputElement.set_required(input, true);
        try testing.expect(!try interfaces.HTMLFormElement.call_checkValidity(form));
        try testing.expect(!try interfaces.HTMLFormElement.call_reportValidity(form));
        try interfaces.HTMLFormElement.call_requestSubmit(form, .notPassed());
        try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("valid"));
        try testing.expect(try interfaces.HTMLFormElement.call_checkValidity(form));
    }
}
fn runOnThread(comptime scenario: Scenario) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise(scenario) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
test "invalid native form returns false without an engine" {
    try runOnThread(.form);
}
test "native form retains empty-file fallback without an engine" {
    try runOnThread(.file_entry);
}
test "invalid native input returns false without leaking an event" {
    try runOnThread(.control);
}
