//! Generated from: scroll-animations.idl
//! Generated at: 2025-12-05T20:30:47Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ScrollTimelineImpl = @import("impls").ScrollTimeline;
const mixins = @import("mixins");
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
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = AnimationTimeline.State;
        pub const ParentInterface = AnimationTimeline;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "source", "get_source", null },
            .{ "axis", "get_axis", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "play",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "source", "get_source", null },
            .{ "axis", "get_axis", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            source: ?*runtime.Instance = null,
            axis: ScrollAxis = undefined,
            _internal: ?*ScrollTimelineImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_axis = &get_axis,
        .get_source = &get_source,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ScrollTimelineImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ScrollTimelineImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, options: webidl.Opt(ScrollTimelineOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ScrollTimelineImpl.call_constructor(allocator, ctx, options);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ScrollTimelineImpl.get_source(instance);
    }

    pub fn get_axis(instance: *runtime.Instance) anyerror!ScrollAxis {
        return try ScrollTimelineImpl.get_axis(instance);
    }
};
