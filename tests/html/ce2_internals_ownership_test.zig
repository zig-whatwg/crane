//! Engine-free owner teardown releases lazily allocated internals children.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const target = try interfaces.HTMLElement.init(testing.allocator, &context);
    defer dom.node_creation.destroyUninserted(target);
    // This native ownership fixture never invokes its constructor. Undefined
    // owns no engine resource (engine.Owned's release contract).
    const definition = try dom.custom_elements.Definition.init(testing.allocator, "ce2-native-form", "ce2-native-form", .{
        .function = .{ .value = .undefined },
        .context = null,
    });
    defer definition.deinit();
    definition.form_associated = true;
    try dom.custom_elements.initialize(target, null, null, .custom);
    dom.custom_elements.setDefinition(target, definition);
    const internals = try dom.custom_elements.ensureInternals(target);
    try testing.expectEqual(internals, try dom.custom_elements.ensureInternals(target));
    const states = try interfaces.ElementInternals.get_states(internals);
    try testing.expectEqual(states, try interfaces.ElementInternals.get_states(internals));
    try testing.expectEqual(states, try interfaces.CustomStateSet.call_add(states, runtime.DOMString.initInterned("ready")));
    try testing.expectEqual(@as(u32, 1), try interfaces.CustomStateSet.get_size(states));
    try testing.expect(try interfaces.CustomStateSet.call_has(states, runtime.DOMString.initInterned("ready")));
    try testing.expect(try interfaces.CustomStateSet.call_delete(states, runtime.DOMString.initInterned("ready")));
    try testing.expectEqual(@as(u32, 0), try interfaces.CustomStateSet.get_size(states));
    const validity = try interfaces.ElementInternals.get_validity(internals);
    try testing.expectEqual(validity, try interfaces.ElementInternals.get_validity(internals));
    try testing.expect(try interfaces.ValidityState.get_valid(validity));
    try interfaces.ElementInternals.call_setValidity(internals, .passed(.{ .customError = true }), .passed(runtime.DOMString.initInterned("bad\r\nvalue")), .notPassed());
    try testing.expect(!(try interfaces.ValidityState.get_valid(validity)));
    var message = try interfaces.ElementInternals.get_validationMessage(internals);
    defer message.deinit(testing.allocator);
    try testing.expectEqualStrings("bad\nvalue", message.asSlice());
    const labels = try interfaces.ElementInternals.get_labels(internals);
    try testing.expectEqual(labels, try interfaces.ElementInternals.get_labels(internals));
    try testing.expectEqual(@as(u32, 0), try interfaces.NodeList.get_length(labels));
    const value = try interfaces.FormData.call_constructor(&context, .notPassed(), .notPassed());
    defer runtime.Instance.deinit(value);
    try interfaces.FormData.call_append(value, "field", "original");
    try interfaces.ElementInternals.call_setFormValue(internals, .{ .form_data = value }, .notPassed());
    try interfaces.FormData.call_set(value, "field", "changed");
    const submitted = try interfaces.FormData.call_constructor(&context, .notPassed(), .notPassed());
    defer runtime.Instance.deinit(submitted);
    try dom.custom_elements.appendFormEntries(target, submitted);
    const entry = (try interfaces.FormData.call_get(submitted, "field")).?;
    try testing.expectEqualStrings("original", entry.usvstring);
    // Replacing the list releases both native copies; the final string's
    // submission/state allocations are then released by owner teardown.
    try interfaces.ElementInternals.call_setFormValue(internals, .{ .usvstring = "final" }, .notPassed());
}

test "CE2 internals: cached states, validity and labels release with their native owner" {
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
