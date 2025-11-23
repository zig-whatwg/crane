//! V8 Element Integration Tests
//!
//! Demonstrates Element interface with V8 bindings:
//! - V8Context bidirectional mapping
//! - Type conversion (Zig ↔ V8)
//! - Persistent handles for long-lived objects
//! - EventListener management
//! - Complete workflow simulation

const std = @import("std");
const runtime = @import("runtime");
const mock_js = @import("mock_jsengine.zig");

// Import generated interfaces
const Element = @import("interfaces").Element;

// V8 bindings modules
const V8Context = runtime.V8Context;
const v8_types = runtime.v8_types;
const v8_persistent = runtime.v8_persistent;
const v8_eventlistener = runtime.v8_eventlistener;

test "V8 Element - Context bidirectional mapping" {
    const allocator = std.testing.allocator;

    // Initialize V8Context
    const v8_context = try V8Context.init(allocator);
    defer v8_context.deinit();

    // Create Element instance
    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const ctx = context.asRuntimeContext();

    const elem_instance = try Element.init(allocator, ctx);

    // Create mock V8 object handle
    const v8_object = @as(usize, 0x1000);

    // Register Instance → V8Object mapping
    try v8_context.setObject(elem_instance, v8_object);

    // Verify round-trip
    const retrieved_obj = v8_context.getObject(elem_instance);
    try std.testing.expectEqual(v8_object, retrieved_obj.?);

    const retrieved_inst = v8_context.getInstance(v8_object);
    try std.testing.expectEqual(elem_instance, retrieved_inst.?);
}

test "V8 Element - Type conversion Zig to V8" {
    const allocator = std.testing.allocator;

    // Convert Zig values to V8
    const v8_str = try v8_types.toV8(allocator, "hello");
    try std.testing.expect(v8_str.isString());
    try std.testing.expectEqualStrings("hello", v8_str.string);

    const v8_num = try v8_types.toV8(allocator, @as(i32, 42));
    try std.testing.expect(v8_num.isNumber());
    try std.testing.expectEqual(@as(i32, 42), v8_num.int32);

    const v8_bool = try v8_types.toV8(allocator, true);
    try std.testing.expect(v8_bool.isBoolean());
    try std.testing.expectEqual(true, v8_bool.boolean);
}

test "V8 Element - Type conversion V8 to Zig" {
    const allocator = std.testing.allocator;

    // Convert V8 values to Zig
    const v8_str = v8_types.V8Value{ .string = "world" };
    const zig_str = try v8_types.fromV8([]const u8, allocator, v8_str);
    defer allocator.free(zig_str);
    try std.testing.expectEqualStrings("world", zig_str);

    const v8_num = v8_types.V8Value{ .int32 = 99 };
    const zig_num = try v8_types.fromV8(i32, allocator, v8_num);
    try std.testing.expectEqual(@as(i32, 99), zig_num);

    const v8_bool = v8_types.V8Value{ .boolean = false };
    const zig_bool = try v8_types.fromV8(bool, allocator, v8_bool);
    try std.testing.expectEqual(false, zig_bool);
}

test "V8 Element - Sequence type conversion" {
    const allocator = std.testing.allocator;

    // Convert Zig slice to V8 array
    const nums = [_]i32{ 1, 2, 3, 4, 5 };
    const v8_arr = try v8_types.sequenceToV8(allocator, i32, &nums);
    defer {
        v8_arr.array.deinit();
        allocator.destroy(v8_arr.array);
    }

    try std.testing.expect(v8_arr.isArray());
    try std.testing.expectEqual(@as(u32, 5), v8_arr.array.length());

    // Convert V8 array back to Zig slice
    const result = try v8_types.sequenceFromV8(i32, allocator, v8_arr);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 5), result.len);
    for (nums, result) |expected, actual| {
        try std.testing.expectEqual(expected, actual);
    }
}

test "V8 Element - Union type conversion" {
    const allocator = std.testing.allocator;

    const StringOrLong = union(enum) {
        string: []const u8,
        long: i32,
    };

    // Convert union with string variant to V8
    const str_variant = StringOrLong{ .string = "test" };
    const v8_str = try v8_types.unionToV8(allocator, str_variant);
    try std.testing.expect(v8_str.isString());
    try std.testing.expectEqualStrings("test", v8_str.string);

    // Convert union with long variant to V8
    const long_variant = StringOrLong{ .long = 42 };
    const v8_long = try v8_types.unionToV8(allocator, long_variant);
    try std.testing.expect(v8_long.isNumber());
    try std.testing.expectEqual(@as(i32, 42), v8_long.int32);

    // Convert V8 back to union
    const result = try v8_types.unionFromV8(StringOrLong, allocator, v8_long);
    try std.testing.expect(result == .long);
    try std.testing.expectEqual(@as(i32, 42), result.long);
}

test "V8 Element - Persistent handle lifecycle" {
    const allocator = std.testing.allocator;

    // Create PersistentRegistry
    var registry = v8_persistent.PersistentRegistry.init(allocator);
    defer registry.deinit();

    // Create Element instance
    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const ctx = context.asRuntimeContext();

    const elem_instance = try Element.init(allocator, ctx);

    // Create persistent handle (survives HandleScope)
    const v8_object = @as(usize, 0x2000);
    const handle_id = try registry.create(v8_object, elem_instance);

    // Verify handle is registered
    const handle = registry.get(handle_id);
    try std.testing.expect(handle != null);
    try std.testing.expectEqual(v8_object, handle.?.v8_value);
    try std.testing.expectEqual(elem_instance, handle.?.instance);

    // Destroy persistent handle
    registry.destroy(handle_id);

    // Verify handle is removed
    const removed = registry.get(handle_id);
    try std.testing.expectEqual(@as(?v8_persistent.PersistentHandle, null), removed);
}

test "V8 Element - EventListener registration" {
    const allocator = std.testing.allocator;

    // Create EventListenerRegistry
    var registry = v8_eventlistener.EventListenerRegistry.init(allocator);
    defer registry.deinit();

    // Create Element instance
    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const ctx = context.asRuntimeContext();

    const elem_instance = try Element.init(allocator, ctx);

    // Create mock callback function
    var callback_fn = v8_persistent.PersistentFunction.init(allocator, @as(usize, 0x3000));
    defer callback_fn.deinit();

    // Register event listener (element.addEventListener("click", fn))
    const listener = v8_eventlistener.EventListener{
        .callback = &callback_fn,
        .options = .{},
    };

    try registry.addEventListener(elem_instance, "click", listener);

    // Verify listener is registered
    const listeners = registry.getEventListeners(elem_instance, "click");
    try std.testing.expect(listeners != null);
    try std.testing.expectEqual(@as(usize, 1), listeners.?.len);

    // Remove listener
    registry.removeEventListener(elem_instance, "click", &callback_fn);

    // Verify listener is removed
    const removed_listeners = registry.getEventListeners(elem_instance, "click");
    try std.testing.expect(removed_listeners == null or removed_listeners.?.len == 0);
}

test "V8 Element - EventListener with 'once' option" {
    const allocator = std.testing.allocator;

    // Create EventListenerRegistry
    var registry = v8_eventlistener.EventListenerRegistry.init(allocator);
    defer registry.deinit();

    // Create Element instance
    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const ctx = context.asRuntimeContext();

    const elem_instance = try Element.init(allocator, ctx);

    // Create callback with 'once' option
    var callback_fn = v8_persistent.PersistentFunction.init(allocator, @as(usize, 0x4000));
    defer callback_fn.deinit();

    const listener = v8_eventlistener.EventListener{
        .callback = &callback_fn,
        .options = .{ .once = true },
    };

    try registry.addEventListener(elem_instance, "load", listener);

    // Dispatch event
    const event = v8_eventlistener.Event{
        .type = "load",
        .target = elem_instance,
        .phase = .target,
    };
    registry.dispatchEvent(elem_instance, event);

    // Verify listener was automatically removed after first call
    const listeners = registry.getEventListeners(elem_instance, "load");
    try std.testing.expect(listeners == null or listeners.?.len == 0);
}

test "V8 Element - Complete workflow simulation" {
    const allocator = std.testing.allocator;

    // Initialize all V8 infrastructure
    const v8_context = try V8Context.init(allocator);
    defer v8_context.deinit();

    var persistent_registry = v8_persistent.PersistentRegistry.init(allocator);
    defer persistent_registry.deinit();

    var event_registry = v8_eventlistener.EventListenerRegistry.init(allocator);
    defer event_registry.deinit();

    // Create Element instance
    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const ctx = context.asRuntimeContext();

    const elem_instance = try Element.init(allocator, ctx);

    // 1. Wrap Element in V8 object
    const v8_object = @as(usize, 0x5000);
    try v8_context.setObject(elem_instance, v8_object);

    // Verify mapping
    try std.testing.expectEqual(v8_object, v8_context.getObject(elem_instance).?);
    try std.testing.expectEqual(elem_instance, v8_context.getInstance(v8_object).?);

    // 2. Create persistent handle (for long-lived objects)
    const handle_id = try persistent_registry.create(v8_object, elem_instance);
    try std.testing.expect(persistent_registry.get(handle_id) != null);

    // 3. Register event listener
    var callback_fn = v8_persistent.PersistentFunction.init(allocator, @as(usize, 0x6000));
    defer callback_fn.deinit();

    const listener = v8_eventlistener.EventListener{
        .callback = &callback_fn,
        .options = .{ .once = false, .capture = false, .passive = false },
    };
    try event_registry.addEventListener(elem_instance, "click", listener);

    // Verify listener registered
    const listeners = event_registry.getEventListeners(elem_instance, "click");
    try std.testing.expectEqual(@as(usize, 1), listeners.?.len);

    // 4. Type conversions - simulating JavaScript interop
    const js_string = try v8_types.toV8(allocator, "element-id");
    try std.testing.expectEqualStrings("element-id", js_string.string);

    const js_number = try v8_types.toV8(allocator, @as(i32, 100));
    try std.testing.expectEqual(@as(i32, 100), js_number.int32);

    // 5. Cleanup (in reverse order)
    event_registry.removeEventListener(elem_instance, "click", &callback_fn);
    persistent_registry.destroy(handle_id);

    // Verify cleanup
    try std.testing.expect(persistent_registry.get(handle_id) == null);
}
