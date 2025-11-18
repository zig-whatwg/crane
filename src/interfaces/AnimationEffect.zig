//! Generated from: web-animations.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AnimationEffectImpl = @import("../impls/AnimationEffect.zig");

pub const AnimationEffect = struct {
    pub const Meta = struct {
        pub const name = "AnimationEffect";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            parent: ?GroupEffect = null,
            previousSibling: ?AnimationEffect = null,
            nextSibling: ?AnimationEffect = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AnimationEffect, .{
        .deinit_fn = &deinit_wrapper,

        .get_nextSibling = &get_nextSibling,
        .get_parent = &get_parent,
        .get_previousSibling = &get_previousSibling,

        .call_after = &call_after,
        .call_before = &call_before,
        .call_getComputedTiming = &call_getComputedTiming,
        .call_getTiming = &call_getTiming,
        .call_remove = &call_remove,
        .call_replace = &call_replace,
        .call_updateTiming = &call_updateTiming,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        AnimationEffectImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AnimationEffectImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_parent(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AnimationEffectImpl.get_parent(state);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AnimationEffectImpl.get_previousSibling(state);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AnimationEffectImpl.get_nextSibling(state);
    }

    pub fn call_updateTiming(instance: *runtime.Instance, timing: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AnimationEffectImpl.call_updateTiming(state, timing);
    }

    pub fn call_replace(instance: *runtime.Instance, effects: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AnimationEffectImpl.call_replace(state, effects);
    }

    pub fn call_before(instance: *runtime.Instance, effects: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AnimationEffectImpl.call_before(state, effects);
    }

    pub fn call_after(instance: *runtime.Instance, effects: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AnimationEffectImpl.call_after(state, effects);
    }

    pub fn call_remove(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AnimationEffectImpl.call_remove(state);
    }

    pub fn call_getTiming(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AnimationEffectImpl.call_getTiming(state);
    }

    pub fn call_getComputedTiming(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AnimationEffectImpl.call_getComputedTiming(state);
    }

};
