//! Generated from: css-animation-worklet.idl
//! Generated at: 2025-11-29T05:01:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WorkletAnimationImpl = @import("impls").WorkletAnimation;
const mixins = @import("mixins");
const Animation = @import("interfaces").Animation;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const AnimationPlayState = @import("enums").AnimationPlayState;
const TimelineRangeOffset = @import("dictionaries").TimelineRangeOffset;
const CSSKeywordValue = @import("interfaces").CSSKeywordValue;
const AnimationTrigger = @import("interfaces").AnimationTrigger;
const AnimationTimeline = @import("interfaces").AnimationTimeline;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const AnimationEffect = @import("interfaces").AnimationEffect;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const sequence = @import("interfaces").sequence;
const AnimationReplaceState = @import("enums").AnimationReplaceState;
const EventListener = @import("interfaces").EventListener;
const CSSNumberish = @import("typedefs").CSSNumberish;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const WorkletAnimation = struct {
    pub const Meta = struct {
        pub const name = "WorkletAnimation";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Animation.State;
        pub const ParentInterface = Animation;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "animatorName", "get_animatorName", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "animatorName", "get_animatorName", null },
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
            animatorName: runtime.DOMString = undefined,
            _internal: ?*WorkletAnimationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_animatorName = &get_animatorName,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WorkletAnimationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WorkletAnimationImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, animatorName: DOMString, effects: webidl.Opt(?*const anyopaque), timeline: webidl.Opt(?*runtime.Instance), options: webidl.Opt(*const anyopaque)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try WorkletAnimationImpl.call_constructor(allocator, ctx, animatorName, effects, timeline, options);
    }

    pub fn get_animatorName(instance: *runtime.Instance) anyerror!DOMString {
        return try WorkletAnimationImpl.get_animatorName(instance);
    }

};
