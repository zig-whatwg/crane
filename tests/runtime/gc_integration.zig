//! Integration tests for GC callbacks and Instance lifecycle
//!
//! These tests verify the complete lifecycle of WebIDL instances:
//! - Instance creation via generated interface
//! - Custom deinit logic execution
//! - GC finalizer callback (onObjectFreed)
//! - VTable deinit_fn invocation
//! - Memory cleanup
//!
//! NOTE ON anyopaque USAGE:
//! The `instance.state` field is typed as `*anyopaque` in the runtime because
//! it stores type-erased state for arbitrary WebIDL interface types. The casts
//! in these tests (e.g., `@as(*anyopaque, @ptrCast(state))`) are testing this
//! runtime behavior. This is a legitimate use case - the runtime layer intentionally
//! uses type erasure for heterogeneous instance storage.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");

// Mock implementation for testing
const TestImpl = struct {
    cleanup_called: bool = false,
    custom_data: ?[]const u8 = null,
    instance_ptr: ?*runtime.Instance = null,
};

// Test interface state that includes TestImpl
const TestState = struct {
    impl: TestImpl = .{},
    some_field: i32 = 0,
};

test "GC integration: onObjectFreed calls deinit_wrapper with Instance" {
    // Initialize allocators
    runtime.SlabAllocator.init(testing.allocator);
    defer runtime.SlabAllocator.deinit();

    runtime.ArenaAllocator.init(testing.allocator);
    defer runtime.ArenaAllocator.deinit();

    // Create a test implementation with deinit logic
    const Impl = struct {
        fn deinit(instance: *runtime.Instance) void {
            const state = instance.getState(TestState);

            // Verify we receive the correct instance pointer
            std.debug.assert(instance.state == @as(*anyopaque, @ptrCast(state)));

            // Mark cleanup as called
            state.impl.cleanup_called = true;
        }
    };

    // Create VTable with deinit wrapper
    const delegates = .{}; // Empty delegates struct - no methods needed
    const vtable = runtime.VTable{
        .deinit = &Impl.deinit,
        .methods_ptr = &delegates,
    };

    // Allocate instance
    const instance = try runtime.SlabAllocator.get().alloc(&vtable);

    // Allocate state in arena
    const state = try runtime.ArenaAllocator.get().create(TestState);
    state.* = .{};
    instance.state = @ptrCast(state);

    // Verify cleanup not yet called
    try testing.expect(!state.impl.cleanup_called);

    // Simulate JS engine GC finalizer callback
    runtime.gc.onObjectFreed(instance);

    // Verify deinit was called
    try testing.expect(state.impl.cleanup_called);
}

test "GC integration: full lifecycle with custom cleanup" {
    runtime.SlabAllocator.init(testing.allocator);
    defer runtime.SlabAllocator.deinit();

    runtime.ArenaAllocator.init(testing.allocator);
    defer runtime.ArenaAllocator.deinit();

    const allocator = testing.allocator;

    // Realistic implementation with custom resources
    const Impl = struct {
        fn init(
            alloc: std.mem.Allocator,
            comptime StateType: type,
            vt: *const runtime.VTable,
        ) !*runtime.Instance {
            const instance = try runtime.Instance.init(alloc, StateType, vt, undefined);
            const state = instance.getState(StateType);

            // Allocate custom resource (simulating owned memory)
            state.impl.custom_data = try alloc.dupe(u8, "test data");

            return instance;
        }

        fn deinit(instance: *runtime.Instance) void {
            const state = instance.getState(TestState);

            // Clean up custom resource
            if (state.impl.custom_data) |data| {
                testing.allocator.free(data);
                state.impl.custom_data = null;
            }

            // Mark cleanup called
            state.impl.cleanup_called = true;

            // NOTE: Don't call runtime.Instance.deinit() here
            // onObjectFreed already does that for us
        }
    };

    // Create VTable
    const delegates = .{}; // Empty delegates struct - no methods needed
    const vtable = runtime.VTable{
        .deinit = &Impl.deinit,
        .methods_ptr = &delegates,
    };

    // Initialize instance (simulating generated interface init)
    const instance = try Impl.init(allocator, TestState, &vtable);
    const state = instance.getState(TestState);

    // Verify instance is properly initialized
    try testing.expect(instance.vtable == &vtable);
    try testing.expect(state.impl.custom_data != null);
    try testing.expectEqualStrings("test data", state.impl.custom_data.?);

    // Simulate GC finalizer
    runtime.gc.onObjectFreed(instance);

    // Verify cleanup was called
    try testing.expect(state.impl.cleanup_called);
    try testing.expect(state.impl.custom_data == null);
}

test "GC integration: onObjectFreed handles null deinit_fn gracefully" {
    runtime.SlabAllocator.init(testing.allocator);
    defer runtime.SlabAllocator.deinit();

    runtime.ArenaAllocator.init(testing.allocator);
    defer runtime.ArenaAllocator.deinit();

    // Create VTable with null deinit_fn
    const delegates = .{}; // Empty delegates struct - no methods needed
    const vtable = runtime.VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    const instance = try runtime.SlabAllocator.get().alloc(&vtable);
    const state = try runtime.ArenaAllocator.get().create(TestState);
    state.* = .{};
    instance.state = @ptrCast(state);

    // Should not crash
    runtime.gc.onObjectFreed(instance);

    // Cleanup was not called
    try testing.expect(!state.impl.cleanup_called);
}

test "GC integration: multiple instances with different vtables" {
    runtime.SlabAllocator.init(testing.allocator);
    defer runtime.SlabAllocator.deinit();

    runtime.ArenaAllocator.init(testing.allocator);
    defer runtime.ArenaAllocator.deinit();

    // Track cleanup using state field instead of closure
    const Impl1 = struct {
        fn deinit(instance: *runtime.Instance) void {
            const state = instance.getState(TestState);
            state.some_field += 1;
        }
    };

    const Impl2 = struct {
        fn deinit(instance: *runtime.Instance) void {
            const state = instance.getState(TestState);
            state.some_field += 10;
        }
    };

    // Create two different VTables
    const delegates = .{}; // Empty delegates struct - no methods needed
    const vtable1 = runtime.VTable{
        .deinit = &Impl1.deinit,
        .methods_ptr = &delegates,
    };
    const vtable2 = runtime.VTable{
        .deinit = &Impl2.deinit,
        .methods_ptr = &delegates,
    };

    // Create instances with different vtables
    const instance1 = try runtime.SlabAllocator.get().alloc(&vtable1);
    const instance2 = try runtime.SlabAllocator.get().alloc(&vtable2);
    const instance3 = try runtime.SlabAllocator.get().alloc(&vtable1);

    const state1 = try runtime.ArenaAllocator.get().create(TestState);
    const state2 = try runtime.ArenaAllocator.get().create(TestState);
    const state3 = try runtime.ArenaAllocator.get().create(TestState);

    state1.* = .{};
    state2.* = .{};
    state3.* = .{};

    instance1.state = @ptrCast(state1);
    instance2.state = @ptrCast(state2);
    instance3.state = @ptrCast(state3);

    // Finalize all instances
    runtime.gc.onObjectFreed(instance1); // +1
    runtime.gc.onObjectFreed(instance2); // +10
    runtime.gc.onObjectFreed(instance3); // +1

    // Verify correct deinit functions were called
    try testing.expectEqual(@as(i32, 1), state1.some_field);
    try testing.expectEqual(@as(i32, 10), state2.some_field);
    try testing.expectEqual(@as(i32, 1), state3.some_field);
}

test "GC integration: onGCSweep resets arena after finalizers" {
    runtime.SlabAllocator.init(testing.allocator);
    defer runtime.SlabAllocator.deinit();

    runtime.ArenaAllocator.init(testing.allocator);
    defer runtime.ArenaAllocator.deinit();

    const arena = runtime.ArenaAllocator.get();

    // Allocate some instances
    const delegates = .{}; // Empty delegates struct - no methods needed
    const vtable = runtime.VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    const instance1 = try runtime.SlabAllocator.get().alloc(&vtable);
    const instance2 = try runtime.SlabAllocator.get().alloc(&vtable);

    // Allocate states in arena
    const state1 = try arena.create(TestState);
    const state2 = try arena.create(TestState);
    state1.* = .{};
    state2.* = .{};

    instance1.state = @ptrCast(state1);
    instance2.state = @ptrCast(state2);

    const stats_before = arena.stats();
    try testing.expect(stats_before.total_allocations >= 2);

    // Simulate GC cycle: finalize objects then sweep
    runtime.gc.onObjectFreed(instance1);
    runtime.gc.onObjectFreed(instance2);
    runtime.gc.onGCSweep();

    // Arena should be reset (stats are cumulative)
    const stats_after = arena.stats();
    try testing.expectEqual(stats_before.total_allocations, stats_after.total_allocations);

    // Can still allocate after sweep
    const new_state = try arena.create(TestState);
    new_state.* = .{};
    try testing.expectEqual(@as(i32, 0), new_state.some_field);
}

test "GC integration: instrumented callbacks track stats" {
    runtime.SlabAllocator.init(testing.allocator);
    defer runtime.SlabAllocator.deinit();

    runtime.ArenaAllocator.init(testing.allocator);
    defer runtime.ArenaAllocator.deinit();

    runtime.gc.GCStats.reset();

    const delegates = .{}; // Empty delegates struct - no methods needed
    const vtable = runtime.VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    // Create and finalize instances
    const instance1 = try runtime.SlabAllocator.get().alloc(&vtable);
    const instance2 = try runtime.SlabAllocator.get().alloc(&vtable);
    instance1.state = undefined;
    instance2.state = undefined;

    runtime.gc.onObjectFreedInstrumented(instance1);
    runtime.gc.onObjectFreedInstrumented(instance2);
    runtime.gc.onGCSweepInstrumented();

    const stats = runtime.gc.GCStats.get();
    try testing.expectEqual(@as(usize, 2), stats.objects_finalized);
    try testing.expectEqual(@as(usize, 1), stats.gc_sweeps);
}

test "GC integration: deinit_fn receives correct Instance pointer" {
    runtime.SlabAllocator.init(testing.allocator);
    defer runtime.SlabAllocator.deinit();

    runtime.ArenaAllocator.init(testing.allocator);
    defer runtime.ArenaAllocator.deinit();

    const Impl = struct {
        fn deinit(instance: *runtime.Instance) void {
            const state = instance.getState(TestState);
            // Store the instance pointer in state
            state.impl.instance_ptr = instance;
        }
    };

    const delegates = .{}; // Empty delegates struct - no methods needed
    const vtable = runtime.VTable{
        .deinit = &Impl.deinit,
        .methods_ptr = &delegates,
    };

    const instance = try runtime.SlabAllocator.get().alloc(&vtable);
    const state = try runtime.ArenaAllocator.get().create(TestState);
    state.* = .{};
    instance.state = @ptrCast(state);

    // Call finalizer
    runtime.gc.onObjectFreed(instance);

    // Verify we received the exact same instance pointer
    try testing.expect(state.impl.instance_ptr != null);
    try testing.expectEqual(instance, state.impl.instance_ptr.?);
}

test "GC integration: simulating full JS engine lifecycle" {
    // This test simulates what a real JS engine would do:
    // 1. Create WebIDL instances
    // 2. Use them
    // 3. GC marks them unreachable
    // 4. GC calls finalizers (onObjectFreed)
    // 5. GC sweeps (onGCSweep)

    runtime.SlabAllocator.init(testing.allocator);
    defer runtime.SlabAllocator.deinit();

    runtime.ArenaAllocator.init(testing.allocator);
    defer runtime.ArenaAllocator.deinit();

    runtime.gc.GCStats.reset();

    const allocator = testing.allocator;

    // Simulated EventTarget implementation
    const EventTargetImpl = struct {
        fn init(
            alloc: std.mem.Allocator,
            comptime StateType: type,
            vt: *const runtime.VTable,
        ) !*runtime.Instance {
            const instance = try runtime.Instance.init(alloc, StateType, vt, undefined);
            const state = instance.getState(StateType);

            // Allocate some owned data
            state.impl.custom_data = try alloc.dupe(u8, "EventTarget data");

            return instance;
        }

        fn deinit(instance: *runtime.Instance) void {
            const state = instance.getState(TestState);

            // Clean up owned data
            if (state.impl.custom_data) |data| {
                testing.allocator.free(data);
                state.impl.custom_data = null;
            }

            state.impl.cleanup_called = true;

            // NOTE: Don't call runtime.Instance.deinit() here
            // onObjectFreed already handles freeing the instance
        }
    };

    // Create VTable
    const delegates = .{}; // Empty delegates struct - no methods needed
    const vtable = runtime.VTable{
        .deinit = &EventTargetImpl.deinit,
        .methods_ptr = &delegates,
    };

    // Phase 1: JS creates objects
    const obj1 = try EventTargetImpl.init(allocator, TestState, &vtable);
    const obj2 = try EventTargetImpl.init(allocator, TestState, &vtable);
    const obj3 = try EventTargetImpl.init(allocator, TestState, &vtable);

    // Phase 2: JS uses objects
    const state1 = obj1.getState(TestState);
    const state2 = obj2.getState(TestState);
    const state3 = obj3.getState(TestState);

    state1.some_field = 1;
    state2.some_field = 2;
    state3.some_field = 3;

    try testing.expect(state1.impl.custom_data != null);
    try testing.expect(state2.impl.custom_data != null);
    try testing.expect(state3.impl.custom_data != null);

    // Phase 3: JS GC marks objects unreachable

    // Phase 4: JS GC calls finalizers
    runtime.gc.onObjectFreedInstrumented(obj1);
    runtime.gc.onObjectFreedInstrumented(obj2);
    runtime.gc.onObjectFreedInstrumented(obj3);

    // Verify cleanup was called for all
    try testing.expect(state1.impl.cleanup_called);
    try testing.expect(state2.impl.cleanup_called);
    try testing.expect(state3.impl.cleanup_called);

    // Verify custom data was freed
    try testing.expect(state1.impl.custom_data == null);
    try testing.expect(state2.impl.custom_data == null);
    try testing.expect(state3.impl.custom_data == null);

    // Phase 5: JS GC sweeps and batch-frees arena memory
    runtime.gc.onGCSweepInstrumented();

    // Verify stats
    const stats = runtime.gc.GCStats.get();
    try testing.expectEqual(@as(usize, 3), stats.objects_finalized);
    try testing.expectEqual(@as(usize, 1), stats.gc_sweeps);
}
