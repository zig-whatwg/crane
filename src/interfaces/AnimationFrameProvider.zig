//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AnimationFrameProviderImpl = @import("../impls/AnimationFrameProvider.zig");

pub const AnimationFrameProvider = struct {
    pub const Meta = struct {
        pub const name = "AnimationFrameProvider";
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

    pub const vtable = runtime.buildVTable(AnimationFrameProvider, .{
        .deinit_fn = &deinit_wrapper,

        .call_cancelAnimationFrame = &call_cancelAnimationFrame,
        .call_requestAnimationFrame = &call_requestAnimationFrame,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        AnimationFrameProviderImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AnimationFrameProviderImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: anyopaque) u32 {
        const state = instance.getState(State);
        
        return AnimationFrameProviderImpl.call_requestAnimationFrame(state, callback);
    }

    pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) anyopaque {
        const state = instance.getState(State);
        
        return AnimationFrameProviderImpl.call_cancelAnimationFrame(state, handle);
    }

};
