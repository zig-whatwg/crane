//! Generated from: web-animations-2.idl
//! Generated at: 2025-11-18T18:28:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AnimationTriggerImpl = @import("impls").AnimationTrigger;
const AnimationTriggerBehavior = @import("enums").AnimationTriggerBehavior;
const AnimationTriggerOptions = @import("dictionaries").AnimationTriggerOptions;
const AnimationTimeline = @import("interfaces").AnimationTimeline;

pub const AnimationTrigger = struct {
    pub const Meta = struct {
        pub const name = "AnimationTrigger";
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
            timeline: AnimationTimeline = undefined,
            behavior: AnimationTriggerBehavior = undefined,
            rangeStart: anyopaque = undefined,
            rangeEnd: anyopaque = undefined,
            exitRangeStart: anyopaque = undefined,
            exitRangeEnd: anyopaque = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AnimationTrigger, .{
        .deinit_fn = &deinit_wrapper,

        .get_behavior = &get_behavior,
        .get_exitRangeEnd = &get_exitRangeEnd,
        .get_exitRangeStart = &get_exitRangeStart,
        .get_rangeEnd = &get_rangeEnd,
        .get_rangeStart = &get_rangeStart,
        .get_timeline = &get_timeline,

        .set_behavior = &set_behavior,
        .set_exitRangeEnd = &set_exitRangeEnd,
        .set_exitRangeStart = &set_exitRangeStart,
        .set_rangeEnd = &set_rangeEnd,
        .set_rangeStart = &set_rangeStart,
        .set_timeline = &set_timeline,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        AnimationTriggerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AnimationTriggerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: AnimationTriggerOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try AnimationTriggerImpl.constructor(instance, options);
        
        return instance;
    }

    pub fn get_timeline(instance: *runtime.Instance) anyerror!AnimationTimeline {
        return try AnimationTriggerImpl.get_timeline(instance);
    }

    pub fn set_timeline(instance: *runtime.Instance, value: AnimationTimeline) anyerror!void {
        try AnimationTriggerImpl.set_timeline(instance, value);
    }

    pub fn get_behavior(instance: *runtime.Instance) anyerror!AnimationTriggerBehavior {
        return try AnimationTriggerImpl.get_behavior(instance);
    }

    pub fn set_behavior(instance: *runtime.Instance, value: AnimationTriggerBehavior) anyerror!void {
        try AnimationTriggerImpl.set_behavior(instance, value);
    }

    pub fn get_rangeStart(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationTriggerImpl.get_rangeStart(instance);
    }

    pub fn set_rangeStart(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try AnimationTriggerImpl.set_rangeStart(instance, value);
    }

    pub fn get_rangeEnd(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationTriggerImpl.get_rangeEnd(instance);
    }

    pub fn set_rangeEnd(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try AnimationTriggerImpl.set_rangeEnd(instance, value);
    }

    pub fn get_exitRangeStart(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationTriggerImpl.get_exitRangeStart(instance);
    }

    pub fn set_exitRangeStart(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try AnimationTriggerImpl.set_exitRangeStart(instance, value);
    }

    pub fn get_exitRangeEnd(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationTriggerImpl.get_exitRangeEnd(instance);
    }

    pub fn set_exitRangeEnd(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try AnimationTriggerImpl.set_exitRangeEnd(instance, value);
    }

};
