//! Generated from: web-animations-2.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AnimationTriggerImpl = @import("impls").AnimationTrigger;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AnimationTriggerBehavior = @import("enums").AnimationTriggerBehavior;
const AnimationTriggerOptions = @import("dictionaries").AnimationTriggerOptions;
const AnimationTimeline = @import("interfaces").AnimationTimeline;

pub const AnimationTrigger = struct {
    pub const Meta = struct {
        pub const name = "AnimationTrigger";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "timeline", "get_timeline", "set_timeline" },
            .{ "behavior", "get_behavior", "set_behavior" },
            .{ "rangeStart", "get_rangeStart", "set_rangeStart" },
            .{ "rangeEnd", "get_rangeEnd", "set_rangeEnd" },
            .{ "exitRangeStart", "get_exitRangeStart", "set_exitRangeStart" },
            .{ "exitRangeEnd", "get_exitRangeEnd", "set_exitRangeEnd" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "timeline", "get_timeline", "set_timeline" },
            .{ "behavior", "get_behavior", "set_behavior" },
            .{ "rangeStart", "get_rangeStart", "set_rangeStart" },
            .{ "rangeEnd", "get_rangeEnd", "set_rangeEnd" },
            .{ "exitRangeStart", "get_exitRangeStart", "set_exitRangeStart" },
            .{ "exitRangeEnd", "get_exitRangeEnd", "set_exitRangeEnd" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            timeline: *runtime.Instance = undefined,
            behavior: enums.AnimationTriggerBehavior = undefined,
            rangeStart: runtime.JSValue = undefined,
            rangeEnd: runtime.JSValue = undefined,
            exitRangeStart: runtime.JSValue = undefined,
            exitRangeEnd: runtime.JSValue = undefined,
            _internal: ?*AnimationTriggerImpl.InternalState = null,
        },
    );

    const delegates = .{

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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AnimationTriggerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return AnimationTriggerImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AnimationTriggerImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, options: webidl.Opt(AnimationTriggerOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AnimationTriggerImpl.call_constructor(ctx, options);
    }

    pub fn get_timeline(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AnimationTriggerImpl.get_timeline(instance);
    }

    pub fn set_timeline(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try AnimationTriggerImpl.set_timeline(instance, value);
    }

    pub fn get_behavior(instance: *runtime.Instance) anyerror!AnimationTriggerBehavior {
        return try AnimationTriggerImpl.get_behavior(instance);
    }

    pub fn set_behavior(instance: *runtime.Instance, value: AnimationTriggerBehavior) anyerror!void {
        try AnimationTriggerImpl.set_behavior(instance, value);
    }

    pub fn get_rangeStart(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try AnimationTriggerImpl.get_rangeStart(instance);
    }

    pub fn set_rangeStart(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try AnimationTriggerImpl.set_rangeStart(instance, value);
    }

    pub fn get_rangeEnd(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try AnimationTriggerImpl.get_rangeEnd(instance);
    }

    pub fn set_rangeEnd(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try AnimationTriggerImpl.set_rangeEnd(instance, value);
    }

    pub fn get_exitRangeStart(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try AnimationTriggerImpl.get_exitRangeStart(instance);
    }

    pub fn set_exitRangeStart(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try AnimationTriggerImpl.set_exitRangeStart(instance, value);
    }

    pub fn get_exitRangeEnd(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try AnimationTriggerImpl.get_exitRangeEnd(instance);
    }

    pub fn set_exitRangeEnd(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try AnimationTriggerImpl.set_exitRangeEnd(instance, value);
    }

};
