//! Generated from: html.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CloseWatcherImpl = @import("impls").CloseWatcher;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const CloseWatcherOptions = @import("dictionaries").CloseWatcherOptions;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const CloseWatcher = struct {
    pub const Meta = struct {
        pub const name = "CloseWatcher";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "oncancel", "get_oncancel", "set_oncancel" },
            .{ "onclose", "get_onclose", "set_onclose" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "requestClose", "call_requestClose", 0 },
            .{ "close", "call_close", 0 },
            .{ "destroy", "call_destroy", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestClose",
            "close",
            "destroy",
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
            .{ "oncancel", "get_oncancel", "set_oncancel" },
            .{ "onclose", "get_onclose", "set_onclose" },
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
            oncancel: EventHandler = undefined,
            onclose: EventHandler = undefined,
            _internal: ?*CloseWatcherImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_oncancel = &get_oncancel,
        .get_onclose = &get_onclose,

        .set_oncancel = &set_oncancel,
        .set_onclose = &set_onclose,

        .call_close = &call_close,
        .call_destroy = &call_destroy,
        .call_requestClose = &call_requestClose,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CloseWatcherImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CloseWatcherImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, options: CloseWatcherOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CloseWatcherImpl.call_constructor(allocator, ctx, options);
    }

    pub fn get_oncancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try CloseWatcherImpl.get_oncancel(instance);
    }

    pub fn set_oncancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try CloseWatcherImpl.set_oncancel(instance, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try CloseWatcherImpl.get_onclose(instance);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try CloseWatcherImpl.set_onclose(instance, value);
    }

    pub fn call_requestClose(instance: *runtime.Instance) anyerror!void {
        return try CloseWatcherImpl.call_requestClose(instance);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try CloseWatcherImpl.call_destroy(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try CloseWatcherImpl.call_close(instance);
    }

};
