//! Generated from: pointer-animations.idl
//! Generated at: 2025-11-28T22:33:21Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PointerTimelineImpl = @import("impls").PointerTimeline;
const mixins = @import("mixins");
const AnimationTimeline = @import("interfaces").AnimationTimeline;
const Element = @import("interfaces").Element;
const AnimationEffect = @import("interfaces").AnimationEffect;
const PointerTimelineOptions = @import("dictionaries").PointerTimelineOptions;
const PointerAxis = @import("enums").PointerAxis;
const CSSNumberish = @import("typedefs").CSSNumberish;
const Animation = @import("interfaces").Animation;

pub const PointerTimeline = struct {
    pub const Meta = struct {
        pub const name = "PointerTimeline";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AnimationTimeline;
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
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
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
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            source: ?*runtime.Instance = null,
            axis: PointerAxis = undefined,
            _internal: ?*PointerTimelineImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_axis = &get_axis,
        .get_source = &get_source,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PointerTimelineImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PointerTimelineImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, options: webidl.Opt(PointerTimelineOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PointerTimelineImpl.call_constructor(allocator, ctx, options);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try PointerTimelineImpl.get_source(instance);
    }

    pub fn get_axis(instance: *runtime.Instance) anyerror!PointerAxis {
        return try PointerTimelineImpl.get_axis(instance);
    }

};
