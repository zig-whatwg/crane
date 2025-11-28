//! Generated from: css-animations.idl
//! Generated at: 2025-11-28T19:11:18Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AnimationEventImpl = @import("impls").AnimationEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const AnimationEventInit = @import("dictionaries").AnimationEventInit;
const CSSOMString = @import("typedefs").CSSOMString;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const AnimationEvent = struct {
    pub const Meta = struct {
        pub const name = "AnimationEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "animationName", "get_animationName", null },
            .{ "elapsedTime", "get_elapsedTime", null },
            .{ "pseudoElement", "get_pseudoElement", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "animationName", "get_animationName", null },
            .{ "elapsedTime", "get_elapsedTime", null },
            .{ "pseudoElement", "get_pseudoElement", null },
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
            animationName: CSSOMString = undefined,
            elapsedTime: f64 = undefined,
            pseudoElement: CSSOMString = undefined,
            _internal: ?*AnimationEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_animationName = &get_animationName,
        .get_elapsedTime = &get_elapsedTime,
        .get_pseudoElement = &get_pseudoElement,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AnimationEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AnimationEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": CSSOMString, animationEventInitDict: webidl.Opt(AnimationEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AnimationEventImpl.call_constructor(allocator, ctx, @"type", animationEventInitDict);
    }

    pub fn get_animationName(instance: *runtime.Instance) anyerror!CSSOMString {
        return try AnimationEventImpl.get_animationName(instance);
    }

    pub fn get_elapsedTime(instance: *runtime.Instance) anyerror!f64 {
        return try AnimationEventImpl.get_elapsedTime(instance);
    }

    pub fn get_pseudoElement(instance: *runtime.Instance) anyerror!CSSOMString {
        return try AnimationEventImpl.get_pseudoElement(instance);
    }

};
