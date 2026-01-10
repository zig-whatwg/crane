//! Generated from: css-transitions.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TransitionEventImpl = @import("impls").TransitionEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("Event.zig").Event;
const TransitionEventInit = @import("dictionaries").TransitionEventInit;
const CSSOMString = @import("typedefs").CSSOMString;
const EventTarget = @import("EventTarget.zig").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const TransitionEvent = struct {
    pub const Meta = struct {
        pub const name = "TransitionEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "propertyName", "get_propertyName", null },
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
            .{ "propertyName", "get_propertyName", null },
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
            propertyName: typedefs.CSSOMString = undefined,
            elapsedTime: f64 = undefined,
            pseudoElement: typedefs.CSSOMString = undefined,
            _internal: ?*TransitionEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_elapsedTime = &get_elapsedTime,
        .get_propertyName = &get_propertyName,
        .get_pseudoElement = &get_pseudoElement,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TransitionEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return TransitionEventImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TransitionEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": CSSOMString, transitionEventInitDict: webidl.Opt(TransitionEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TransitionEventImpl.call_constructor(ctx, @"type", transitionEventInitDict);
    }

    pub fn get_propertyName(instance: *runtime.Instance) anyerror!CSSOMString {
        return try TransitionEventImpl.get_propertyName(instance);
    }

    pub fn get_elapsedTime(instance: *runtime.Instance) anyerror!f64 {
        return try TransitionEventImpl.get_elapsedTime(instance);
    }

    pub fn get_pseudoElement(instance: *runtime.Instance) anyerror!CSSOMString {
        return try TransitionEventImpl.get_pseudoElement(instance);
    }

};
