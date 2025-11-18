//! Generated from: streams.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WritableStreamImpl = @import("../impls/WritableStream.zig");

pub const WritableStream = struct {
    pub const Meta = struct {
        pub const name = "WritableStream";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            locked: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WritableStream, .{
        .deinit_fn = &deinit_wrapper,

        .get_locked = &get_locked,

        .call_abort = &call_abort,
        .call_close = &call_close,
        .call_getWriter = &call_getWriter,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        WritableStreamImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WritableStreamImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, underlyingSink: anyopaque, strategy: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try WritableStreamImpl.constructor(state, underlyingSink, strategy);
        
        return instance;
    }

    pub fn get_locked(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WritableStreamImpl.get_locked(state);
    }

    pub fn call_getWriter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WritableStreamImpl.call_getWriter(state);
    }

    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WritableStreamImpl.call_abort(state, reason);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WritableStreamImpl.call_close(state);
    }

};
