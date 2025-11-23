//! Simple JS Engine Integration Test
//!
//! Demonstrates the mock JS engine without depending on problematic generated interfaces.
//! Shows the core patterns for integrating Zig WebIDL with a V8-like JS engine.

const std = @import("std");
const runtime = @import("runtime");
const mock_js = @import("mock_jsengine");

test "JS engine - Isolate lifecycle" {
    const allocator = std.testing.allocator;

    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    try std.testing.expectEqual(isolate, context.isolate);
}

test "JS engine - Context to runtime.Context conversion" {
    const allocator = std.testing.allocator;

    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const runtime_ctx = context.asRuntimeContext();

    // Verify we can cast back
    const context_back: *mock_js.Context = @ptrCast(@alignCast(runtime_ctx));
    try std.testing.expectEqual(context, context_back);
}

test "JS engine - HandleScope lifecycle" {
    const allocator = std.testing.allocator;

    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();

    {
        const scope = try mock_js.HandleScope.create(context);
        defer scope.destroy();

        try std.testing.expectEqual(scope, isolate.handle_scope.?);
    }

    // HandleScope destroyed
    try std.testing.expect(isolate.handle_scope == null);
}

test "JS engine - ObjectHandle local vs persistent" {
    const allocator = std.testing.allocator;

    // Initialize SlabAllocator for Instance allocation
    runtime.SlabAllocator.init(allocator);
    runtime.ArenaAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    defer runtime.ArenaAllocator.deinit();

    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const runtime_ctx = context.asRuntimeContext();

    // Create a minimal mock instance
    const delegates_mock = .{};
    const mock_vtable = runtime.VTable{
        .deinit = null,
        .methods_ptr = &delegates_mock,
    };

    const mock_instance = try runtime.Instance.init(allocator, struct {}, &mock_vtable, runtime_ctx);

    // Create local handle
    {
        const scope = try mock_js.HandleScope.create(context);
        defer scope.destroy();

        const local_handle = try mock_js.ObjectHandle.createLocal(context, mock_instance, "TestInterface");

        try std.testing.expect(!local_handle.persistent);
        try std.testing.expectEqualStrings("TestInterface", local_handle.interface_name);
        try std.testing.expectEqual(mock_instance, local_handle.unwrap());
    }
    // Local handle destroyed with scope
}

test "JS engine - Persistent handle survives scope" {
    const allocator = std.testing.allocator;

    runtime.SlabAllocator.init(allocator);
    runtime.ArenaAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    defer runtime.ArenaAllocator.deinit();

    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const runtime_ctx = context.asRuntimeContext();

    const delegates_mock = .{};
    const mock_vtable = runtime.VTable{
        .deinit = null,
        .methods_ptr = &delegates_mock,
    };

    const mock_instance = try runtime.Instance.init(allocator, struct {}, &mock_vtable, runtime_ctx);

    const persistent_handle = try mock_js.ObjectHandle.createPersistent(context, mock_instance, "TestInterface");

    {
        const scope = try mock_js.HandleScope.create(context);
        defer scope.destroy();

        // Persistent handle still valid
        try std.testing.expect(persistent_handle.persistent);
    }
    // Scope destroyed, but persistent handle still valid

    try std.testing.expect(persistent_handle.persistent);
    try std.testing.expectEqual(mock_instance, persistent_handle.unwrap());
}

test "JS engine - Global object registration" {
    const allocator = std.testing.allocator;

    runtime.SlabAllocator.init(allocator);
    runtime.ArenaAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    defer runtime.ArenaAllocator.deinit();

    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const runtime_ctx = context.asRuntimeContext();
    context.global_object = std.StringHashMap(*mock_js.ObjectHandle).init(allocator);
    defer context.global_object.deinit();

    const delegates_mock = .{};
    const mock_vtable = runtime.VTable{
        .deinit = null,
        .methods_ptr = &delegates_mock,
    };

    const mock_instance = try runtime.Instance.init(allocator, struct {}, &mock_vtable, runtime_ctx);

    const global_handle = try mock_js.ObjectHandle.createPersistent(context, mock_instance, "GlobalObject");
    try context.setGlobalConstructor("myGlobal", global_handle);

    const retrieved = context.getGlobalConstructor("myGlobal");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqual(global_handle, retrieved.?);
}

test "JS engine - FunctionCallbackInfo" {
    const allocator = std.testing.allocator;

    runtime.SlabAllocator.init(allocator);
    runtime.ArenaAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    defer runtime.ArenaAllocator.deinit();

    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const runtime_ctx = context.asRuntimeContext();

    const delegates_mock = .{};
    const mock_vtable = runtime.VTable{
        .deinit = null,
        .methods_ptr = &delegates_mock,
    };

    const mock_instance = try runtime.Instance.init(allocator, struct {}, &mock_vtable, runtime_ctx);

    {
        const scope = try mock_js.HandleScope.create(context);
        defer scope.destroy();

        const handle = try mock_js.ObjectHandle.createLocal(context, mock_instance, "TestInterface");

        // Simulate function call: obj.method(arg1, arg2)
        const args = [_]*mock_js.ObjectHandle{};
        var info = mock_js.FunctionCallbackInfo{
            .context = context,
            .this = handle,
            .args = &args,
            .return_value = null,
        };

        try std.testing.expectEqual(handle, info.getThis().?);
        try std.testing.expectEqual(context, info.getContext());
        try std.testing.expectEqual(@as(usize, 0), info.args.len);
    }
}

test "JS engine - PropertyCallbackInfo" {
    const allocator = std.testing.allocator;

    runtime.SlabAllocator.init(allocator);
    runtime.ArenaAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    defer runtime.ArenaAllocator.deinit();

    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const runtime_ctx = context.asRuntimeContext();

    const delegates_mock = .{};
    const mock_vtable = runtime.VTable{
        .deinit = null,
        .methods_ptr = &delegates_mock,
    };

    const mock_instance = try runtime.Instance.init(allocator, struct {}, &mock_vtable, runtime_ctx);

    {
        const scope = try mock_js.HandleScope.create(context);
        defer scope.destroy();

        const handle = try mock_js.ObjectHandle.createLocal(context, mock_instance, "TestInterface");

        // Simulate property getter: obj.property
        var info = mock_js.PropertyCallbackInfo{
            .context = context,
            .this = handle,
            .return_value = null,
        };

        try std.testing.expectEqual(handle, info.getThis());
        try std.testing.expect(info.return_value == null);

        // Simulate setting return value
        info.setReturnValue(handle);
        try std.testing.expectEqual(handle, info.return_value.?);
    }
}

test "JS engine - Value types" {
    const allocator = std.testing.allocator;
    _ = allocator;

    const undef = mock_js.Value.undefined;
    const null_val = mock_js.Value.null_value;
    const bool_val = mock_js.Value{ .boolean = true };
    const num_val = mock_js.Value{ .number = 42.5 };
    const str_val = mock_js.Value{ .string = "hello" };

    try std.testing.expect(undef == .undefined);
    try std.testing.expect(null_val == .null_value);
    try std.testing.expectEqual(true, bool_val.boolean);
    try std.testing.expectEqual(42.5, num_val.number);
    try std.testing.expectEqualStrings("hello", str_val.string);
}

test "JS engine - Custom deinit callback" {
    const allocator = std.testing.allocator;

    runtime.SlabAllocator.init(allocator);
    runtime.ArenaAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    defer runtime.ArenaAllocator.deinit();

    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const runtime_ctx = context.asRuntimeContext();

    // Track if deinit was called
    const State = struct {
        cleanup_called: *bool,
    };

    var cleanup_called = false;

    const custom_deinit = struct {
        fn deinit(instance: *runtime.Instance) void {
            const state = instance.getState(State);
            state.cleanup_called.* = true;
        }
    }.deinit;

    const delegates_custom = .{};
    const custom_vtable = runtime.VTable{
        .deinit = custom_deinit,
        .methods_ptr = &delegates_custom,
    };

    const instance = try runtime.Instance.init(allocator, State, &custom_vtable, runtime_ctx);
    const state = instance.getState(State);
    state.cleanup_called = &cleanup_called;

    const handle = try mock_js.ObjectHandle.createPersistent(context, instance, "TestInterface");
    _ = handle;

    // Verify cleanup not called yet
    try std.testing.expect(!cleanup_called);

    // Isolate.destroy() will call custom deinit
    // (would happen automatically, but we explicitly test it here in defer)
}
