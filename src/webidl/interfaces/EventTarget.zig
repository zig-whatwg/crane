//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const EventTargetImpl = @import("impls").EventTarget;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const EventTarget = struct {
    pub const Meta = struct {
        pub const name = "EventTarget";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "addEventListener", "call_addEventListener", 2 },
            .{ "removeEventListener", "call_removeEventListener", 2 },
            .{ "dispatchEvent", "call_dispatchEvent", 1 },
            .{ "when", "call_when", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*EventTargetImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return EventTargetImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return EventTargetImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EventTargetImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try EventTargetImpl.call_constructor(ctx);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: *runtime.Instance) anyerror!bool {
        
        return try EventTargetImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: ??*runtime.CallbackWrapper, options: webidl.Opt(runtime.JSValue)) anyerror!void {
        
        return try EventTargetImpl.call_removeEventListener(instance, @"type", callback, options);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: webidl.Opt(ObservableEventListenerOptions)) anyerror!*runtime.Instance {
        
        return try EventTargetImpl.call_when(instance, @"type", options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: ??*runtime.CallbackWrapper, options: webidl.Opt(runtime.JSValue)) anyerror!void {
        
        return try EventTargetImpl.call_addEventListener(instance, @"type", callback, options);
    }

};
