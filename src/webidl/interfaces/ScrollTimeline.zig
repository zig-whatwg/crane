//! Generated from: scroll-animations.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ScrollTimelineImpl = @import("impls").ScrollTimeline;
const AnimationTimeline = @import("interfaces").AnimationTimeline;
const Element = @import("interfaces").Element;
const AnimationEffect = @import("interfaces").AnimationEffect;
const CSSNumberish = @import("typedefs").CSSNumberish;
const Animation = @import("interfaces").Animation;
const ScrollTimelineOptions = @import("dictionaries").ScrollTimelineOptions;
const ScrollAxis = @import("enums").ScrollAxis;

pub const ScrollTimeline = struct {
    pub const Meta = struct {
        pub const name = "ScrollTimeline";
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
            axis: ScrollAxis = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ScrollTimeline, .{
        .deinit_fn = &deinit_wrapper,

        .get_axis = &get_axis,
        .get_currentTime = &get_currentTime,
        .get_duration = &get_duration,
        .get_source = &get_source,

        .call_play = &call_play,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return ScrollTimelineImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ScrollTimelineImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: ScrollTimelineOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ScrollTimelineImpl.constructor(instance, options);
        
        return instance;
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!f64 {
        return try ScrollTimelineImpl.get_currentTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!CSSNumberish {
        return try ScrollTimelineImpl.get_duration(instance);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!Element {
        return try ScrollTimelineImpl.get_source(instance);
    }

    pub fn get_axis(instance: *runtime.Instance) anyerror!ScrollAxis {
        return try ScrollTimelineImpl.get_axis(instance);
    }

    pub fn call_play(instance: *runtime.Instance, effect: AnimationEffect) anyerror!Animation {
        
        return try ScrollTimelineImpl.call_play(instance, effect);
    }

};
