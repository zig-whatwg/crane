//! A retained ValidityState must reject a retired native control's slab slot.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

test {
    _ = @import("fm_validation_algorithms_test.zig");
    _ = @import("fm_file_input_test.zig");
    _ = @import("fm_output_teardown_test.zig");
    _ = @import("fm_options_collection_test.zig");
    _ = @import("fm_reset_snapshot_test.zig");
    _ = @import("fm_submit_event_test.zig");
}

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();

    inline for (.{ interfaces.HTMLInputElement, interfaces.HTMLButtonElement, interfaces.HTMLSelectElement, interfaces.HTMLTextAreaElement, interfaces.HTMLOutputElement, interfaces.HTMLFieldSetElement, interfaces.HTMLObjectElement }) |Control| {
        const element = try Control.init(testing.allocator, &context);
        defer dom.node_creation.destroyUninserted(element);
        const child = try Control.get_validity(element);
        try testing.expectEqual(child, try Control.get_validity(element));
        try testing.expect(try interfaces.ValidityState.get_valid(child));
        try Control.call_setCustomValidity(element, runtime.DOMString.initInterned("first\r\nsecond\rthird"));
        try testing.expect(try interfaces.ValidityState.get_customError(child));
        try testing.expect(!try interfaces.ValidityState.get_valid(child));
        try Control.call_setCustomValidity(element, .empty);
        try testing.expect(try interfaces.ValidityState.get_valid(child));
    }

    inline for (.{ interfaces.HTMLInputElement, interfaces.HTMLTextAreaElement }) |Control| {
        const element = try Control.init(testing.allocator, &context);
        defer dom.node_creation.destroyUninserted(element);
        try testing.expect(try dom.form_controls.userEdit(element, .{ .text = "first", .selection_start = 5, .selection_end = 5 }));
        var first = (try dom.form_controls.editorText(element)).?;
        defer first.deinit(testing.allocator);
        try testing.expect(try dom.form_controls.userEdit(element, .{ .text = "second", .selection_start = 6, .selection_end = 6 }));
        try testing.expectEqualStrings("first", first.asSlice());
        var second = (try dom.form_controls.editorText(element)).?;
        defer second.deinit(testing.allocator);
        try testing.expectEqualStrings("second", second.asSlice());
        try Control.set_value(element, runtime.DOMString.initInterned("script"));
        var script = (try dom.form_controls.editorText(element)).?;
        defer script.deinit(testing.allocator);
        try testing.expectEqualStrings("script", script.asSlice());
    }

    const control = try interfaces.HTMLInputElement.init(testing.allocator, &context);
    var control_live = true;
    defer if (control_live) dom.node_creation.destroyUninserted(control);
    const validity = try interfaces.ValidityState.init(testing.allocator, &context);
    defer runtime.Instance.deinit(validity);
    try dom.custom_elements.setValidityControl(validity, control);

    dom.node_creation.destroyUninserted(control);
    control_live = false;
    try testing.expectError(error.InvalidStateError, interfaces.ValidityState.get_customError(validity));
    try testing.expectError(error.InvalidStateError, interfaces.ValidityState.get_valid(validity));
}

test "native ValidityState rejects a stale control generation before reading the control" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
