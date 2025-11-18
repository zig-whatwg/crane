//! Generated from: pointer-animations.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PointerTimelineImpl = @import("../impls/PointerTimeline.zig");
const AnimationTimeline = @import("AnimationTimeline.zig");

pub const PointerTimeline = struct {
    pub const Meta = struct {
        pub const name = "PointerTimeline";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AnimationTimeline;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            source: ?Element = null,
            axis: PointerAxis = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PointerTimeline, .{
        .deinit_fn = &deinit_wrapper,

        .get_axis = &get_axis,
        .get_currentTime = &get_currentTime,
        .get_currentTime = &get_currentTime,
        .get_duration = &get_duration,
        .get_source = &get_source,

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
        PointerTimelineImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PointerTimelineImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try PointerTimelineImpl.constructor(state, options);
        
        return instance;
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerTimelineImpl.get_currentTime(state);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerTimelineImpl.get_currentTime(state);
    }

    pub fn get_duration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerTimelineImpl.get_duration(state);
    }

    pub fn get_source(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerTimelineImpl.get_source(state);
    }

    pub fn get_axis(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PointerTimelineImpl.get_axis(state);
    }

    pub fn call_play(instance: *runtime.Instance, effect: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PointerTimelineImpl.call_play(state, effect);
    }

};
