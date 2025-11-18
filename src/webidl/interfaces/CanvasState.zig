//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasStateImpl = @import("impls").CanvasState;

pub const CanvasState = struct {
    pub const Meta = struct {
        pub const name = "CanvasState";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CanvasState, .{
        .deinit_fn = &deinit_wrapper,

        .call_isContextLost = &call_isContextLost,
        .call_reset = &call_reset,
        .call_restore = &call_restore,
        .call_save = &call_save,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CanvasStateImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasStateImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_restore(instance: *runtime.Instance) anyerror!void {
        return try CanvasStateImpl.call_restore(instance);
    }

    pub fn call_isContextLost(instance: *runtime.Instance) anyerror!bool {
        return try CanvasStateImpl.call_isContextLost(instance);
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        return try CanvasStateImpl.call_reset(instance);
    }

    pub fn call_save(instance: *runtime.Instance) anyerror!void {
        return try CanvasStateImpl.call_save(instance);
    }

};
