//! Generated from: web-animations.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AnimationTimelineImpl = @import("impls").AnimationTimeline;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AnimationEffect = @import("AnimationEffect.zig").AnimationEffect;
const CSSNumberish = @import("typedefs").CSSNumberish;
const Animation = @import("Animation.zig").Animation;

pub const AnimationTimeline = struct {
    pub const Meta = struct {
        pub const name = "AnimationTimeline";
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
            .{ "currentTime", "get_currentTime", null },
            .{ "duration", "get_duration", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "play", "call_play", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "play",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "currentTime", "get_currentTime", null },
            .{ "duration", "get_duration", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            currentTime: ?f64 = null,
            duration: ?typedefs.CSSNumberish = null,
            _internal: ?*AnimationTimelineImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_currentTime = &get_currentTime,
        .get_duration = &get_duration,

        .call_play = &call_play,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AnimationTimelineImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return AnimationTimelineImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AnimationTimelineImpl.deinit(instance);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!?f64 {
        return try AnimationTimelineImpl.get_currentTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!?CSSNumberish {
        return try AnimationTimelineImpl.get_duration(instance);
    }

    pub fn call_play(instance: *runtime.Instance, effect: webidl.Opt(?*runtime.Instance)) anyerror!*runtime.Instance {
        
        return try AnimationTimelineImpl.call_play(instance, effect);
    }

};
