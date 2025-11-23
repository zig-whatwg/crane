//! Generated from: SVG.idl
//! Generated at: 2025-11-23T16:59:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ShadowAnimationImpl = @import("impls").ShadowAnimation;
const Animation = @import("interfaces").Animation;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const AnimationPlayState = @import("enums").AnimationPlayState;
const TimelineRangeOffset = @import("dictionaries").TimelineRangeOffset;
const CSSKeywordValue = @import("interfaces").CSSKeywordValue;
const AnimationTrigger = @import("interfaces").AnimationTrigger;
const AnimationTimeline = @import("interfaces").AnimationTimeline;
const Event = @import("interfaces").Event;
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const Observable = @import("interfaces").Observable;
const AnimationEffect = @import("interfaces").AnimationEffect;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AnimationReplaceState = @import("enums").AnimationReplaceState;
const EventListener = @import("interfaces").EventListener;
const CSSNumberish = @import("typedefs").CSSNumberish;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const ShadowAnimation = struct {
    pub const Meta = struct {
        pub const name = "ShadowAnimation";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Animation;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Constructor" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "sourceAnimation", "get_sourceAnimation", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "cancel",
            "finish",
            "play",
            "pause",
            "updatePlaybackRate",
            "reverse",
            "persist",
            "commitStyles",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sourceAnimation", "get_sourceAnimation", null },
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
            sourceAnimation: Animation = undefined,
            cached_sourceAnimation: ?Animation = null,
            _internal: ?*ShadowAnimationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_sourceAnimation = &get_sourceAnimation,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ShadowAnimationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ShadowAnimationImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_sourceAnimation(instance: *runtime.Instance) anyerror!Animation {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_sourceAnimation) |cached| {
            return cached;
        }
        const value = try ShadowAnimationImpl.get_sourceAnimation(instance);
        state.own.cached_sourceAnimation = value;
        return value;
    }

};
