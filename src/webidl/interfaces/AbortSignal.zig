//! Generated from: dom.idl
//! Generated at: 2025-12-07T19:33:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const AbortSignalImpl = @import("impls").AbortSignal;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const AbortSignal = struct {
    pub const Meta = struct {
        pub const name = "AbortSignal";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "aborted", "get_aborted", null },
            .{ "reason", "get_reason", null },
            .{ "onabort", "get_onabort", "set_onabort" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "throwIfAborted", "call_throwIfAborted", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "abort", "call_abort", 0 },
            .{ "timeout", "call_timeout", 1 },
            .{ "_any", "call__any", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "abort",
            "timeout",
            "_any",
            "throwIfAborted",
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
            .{ "aborted", "get_aborted", null },
            .{ "reason", "get_reason", null },
            .{ "onabort", "get_onabort", "set_onabort" },
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
            aborted: bool = undefined,
            reason: v8.JSValue = undefined,
            onabort: EventHandler = undefined,
            _internal: ?*AbortSignalImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_aborted = &get_aborted,
        .get_onabort = &get_onabort,
        .get_reason = &get_reason,

        .set_onabort = &set_onabort,

        .call_throwIfAborted = &call_throwIfAborted,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AbortSignalImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AbortSignalImpl.deinit(instance);
    }

    pub fn get_aborted(instance: *runtime.Instance) anyerror!bool {
        return try AbortSignalImpl.get_aborted(instance);
    }

    pub fn get_reason(instance: *runtime.Instance) anyerror!v8.JSValue {
        return try AbortSignalImpl.get_reason(instance);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        return try AbortSignalImpl.get_onabort(instance);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AbortSignalImpl.set_onabort(instance, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call__any(instance: *runtime.Instance, signals: *const anyopaque) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try AbortSignalImpl.call__any(instance, signals);
    }

    /// Extended attributes: [NewObject]
    pub fn call_abort(instance: *runtime.Instance, reason: webidl.Opt(v8.JSValue)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try AbortSignalImpl.call_abort(instance, reason);
    }

    /// Extended attributes: [Exposed=(Window,Worker)], [NewObject]
    pub fn call_timeout(instance: *runtime.Instance, milliseconds: u64) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on milliseconds
        if (!runtime.isInRange(u64, milliseconds)) return error.TypeError;
        
        return try AbortSignalImpl.call_timeout(instance, milliseconds);
    }

    pub fn call_throwIfAborted(instance: *runtime.Instance) anyerror!void {
        return try AbortSignalImpl.call_throwIfAborted(instance);
    }

};
