//! Generated from: scroll-animations.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ViewTimelineImpl = @import("impls").ViewTimeline;
const ScrollTimeline = @import("interfaces").ScrollTimeline;
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const ViewTimelineOptions = @import("dictionaries").ViewTimelineOptions;
const Element = @import("interfaces").Element;

pub const ViewTimeline = struct {
    pub const Meta = struct {
        pub const name = "ViewTimeline";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ScrollTimeline;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            subject: Element = undefined,
            startOffset: CSSNumericValue = undefined,
            endOffset: CSSNumericValue = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ViewTimeline, .{
        .deinit_fn = &deinit_wrapper,

        .get_axis = &get_axis,
        .get_currentTime = &get_currentTime,
        .get_currentTime = &get_currentTime,
        .get_duration = &get_duration,
        .get_endOffset = &get_endOffset,
        .get_source = &get_source,
        .get_startOffset = &get_startOffset,
        .get_subject = &get_subject,

        .call_play = &call_play,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ViewTimelineImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ViewTimelineImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: ViewTimelineOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ViewTimelineImpl.constructor(instance, options);
        
        return instance;
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try ViewTimelineImpl.get_currentTime(instance);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try ViewTimelineImpl.get_currentTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!anyopaque {
        return try ViewTimelineImpl.get_duration(instance);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!anyopaque {
        return try ViewTimelineImpl.get_source(instance);
    }

    pub fn get_axis(instance: *runtime.Instance) anyerror!ScrollAxis {
        return try ViewTimelineImpl.get_axis(instance);
    }

    pub fn get_subject(instance: *runtime.Instance) anyerror!Element {
        return try ViewTimelineImpl.get_subject(instance);
    }

    pub fn get_startOffset(instance: *runtime.Instance) anyerror!CSSNumericValue {
        return try ViewTimelineImpl.get_startOffset(instance);
    }

    pub fn get_endOffset(instance: *runtime.Instance) anyerror!CSSNumericValue {
        return try ViewTimelineImpl.get_endOffset(instance);
    }

    pub fn call_play(instance: *runtime.Instance, effect: anyopaque) anyerror!Animation {
        
        return try ViewTimelineImpl.call_play(instance, effect);
    }

};
