//! Generated from: css-animation-worklet.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AnimationWorkletGlobalScopeImpl = @import("../impls/AnimationWorkletGlobalScope.zig");
const WorkletGlobalScope = @import("WorkletGlobalScope.zig");

pub const AnimationWorkletGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "AnimationWorkletGlobalScope";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WorkletGlobalScope;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worklet", "AnimationWorklet" } } },
            .{ .name = "Exposed", .value = .{ .identifier = "AnimationWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .AnimationWorklet = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AnimationWorkletGlobalScope, .{
        .deinit_fn = &deinit_wrapper,

        .call_registerAnimator = &call_registerAnimator,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        AnimationWorkletGlobalScopeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AnimationWorkletGlobalScopeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_registerAnimator(instance: *runtime.Instance, name: runtime.DOMString, animatorCtor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AnimationWorkletGlobalScopeImpl.call_registerAnimator(state, name, animatorCtor);
    }

};
