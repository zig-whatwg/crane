//! Generated from: web-animations.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AnimationTimelineImpl = @import("../impls/AnimationTimeline.zig");

pub const AnimationTimeline = struct {
    pub const Meta = struct {
        pub const name = "AnimationTimeline";
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
            currentTime: ?f64 = null,
            currentTime: ?CSSNumberish = null,
            duration: ?CSSNumberish = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AnimationTimeline, .{
        .deinit_fn = &deinit_wrapper,

        .get_currentTime = &get_currentTime,
        .get_currentTime = &get_currentTime,
        .get_duration = &get_duration,

        .call_play = &call_play,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        AnimationTimelineImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AnimationTimelineImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AnimationTimelineImpl.get_currentTime(state);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AnimationTimelineImpl.get_currentTime(state);
    }

    pub fn get_duration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AnimationTimelineImpl.get_duration(state);
    }

    pub fn call_play(instance: *runtime.Instance, effect: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AnimationTimelineImpl.call_play(state, effect);
    }

};
