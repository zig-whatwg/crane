//! Generated from: WEBGL_lose_context.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_lose_contextImpl = @import("../impls/WEBGL_lose_context.zig");

pub const WEBGL_lose_context = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_lose_context";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WEBGL_lose_context, .{
        .deinit_fn = &deinit_wrapper,

        .call_loseContext = &call_loseContext,
        .call_restoreContext = &call_restoreContext,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        WEBGL_lose_contextImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WEBGL_lose_contextImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_loseContext(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WEBGL_lose_contextImpl.call_loseContext(state);
    }

    pub fn call_restoreContext(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WEBGL_lose_contextImpl.call_restoreContext(state);
    }

};
