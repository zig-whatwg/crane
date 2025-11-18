//! Generated from: web-animations.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DocumentTimelineImpl = @import("../impls/DocumentTimeline.zig");
const AnimationTimeline = @import("AnimationTimeline.zig");

pub const DocumentTimeline = struct {
    pub const Meta = struct {
        pub const name = "DocumentTimeline";
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DocumentTimeline, .{
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
        DocumentTimelineImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DocumentTimelineImpl.deinit(state);
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
        try DocumentTimelineImpl.constructor(state, options);
        
        return instance;
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DocumentTimelineImpl.get_currentTime(state);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DocumentTimelineImpl.get_currentTime(state);
    }

    pub fn get_duration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DocumentTimelineImpl.get_duration(state);
    }

    pub fn call_play(instance: *runtime.Instance, effect: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return DocumentTimelineImpl.call_play(state, effect);
    }

};
