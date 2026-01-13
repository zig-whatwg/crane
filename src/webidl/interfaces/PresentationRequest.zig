//! Generated from: presentation-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PresentationRequestImpl = @import("impls").PresentationRequest;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("EventTarget.zig").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const PresentationAvailability = @import("PresentationAvailability.zig").PresentationAvailability;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("Event.zig").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const PresentationConnection = @import("PresentationConnection.zig").PresentationConnection;
const USVString = @import("typedefs").USVString;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("Observable.zig").Observable;

pub const PresentationRequest = struct {
    pub const Meta = struct {
        pub const name = "PresentationRequest";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onconnectionavailable", "get_onconnectionavailable", "set_onconnectionavailable" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "start", "call_start", 0 },
            .{ "reconnect", "call_reconnect", 1 },
            .{ "getAvailability", "call_getAvailability", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "start",
            "reconnect",
            "getAvailability",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onconnectionavailable", "get_onconnectionavailable", "set_onconnectionavailable" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onconnectionavailable: typedefs.EventHandler = undefined,
            _internal: ?*PresentationRequestImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onconnectionavailable = &get_onconnectionavailable,

        .set_onconnectionavailable = &set_onconnectionavailable,

        .call_getAvailability = &call_getAvailability,
        .call_reconnect = &call_reconnect,
        .call_start = &call_start,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PresentationRequestImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PresentationRequestImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PresentationRequestImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, url: runtime.USVString) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PresentationRequestImpl.call_constructor(ctx, url);
    }

    pub fn get_onconnectionavailable(instance: *runtime.Instance) anyerror!EventHandler {
        return try PresentationRequestImpl.get_onconnectionavailable(instance);
    }

    pub fn set_onconnectionavailable(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PresentationRequestImpl.set_onconnectionavailable(instance, value);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PresentationRequestImpl.call_start(instance);
    }

    pub fn call_getAvailability(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PresentationRequestImpl.call_getAvailability(instance);
    }

    pub fn call_reconnect(instance: *runtime.Instance, presentationId: runtime.USVString) anyerror!runtime.JSValue {
        
        return try PresentationRequestImpl.call_reconnect(instance, presentationId);
    }

};
