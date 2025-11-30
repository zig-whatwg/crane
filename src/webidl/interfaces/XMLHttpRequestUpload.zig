//! Generated from: xhr.idl
//! Generated at: 2025-11-29T11:15:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XMLHttpRequestUploadImpl = @import("impls").XMLHttpRequestUpload;
const mixins = @import("mixins");
const XMLHttpRequestEventTarget = @import("interfaces").XMLHttpRequestEventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const XMLHttpRequestUpload = struct {
    pub const Meta = struct {
        pub const name = "XMLHttpRequestUpload";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = XMLHttpRequestEventTarget.State;
        pub const ParentInterface = XMLHttpRequestEventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker", "SharedWorker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
            .SharedWorker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        /// NOTE: These are inherited from XMLHttpRequestEventTarget but need to be on own prototype
        /// to use correct state type. See XMLHttpRequestUpload impl for details.
        pub const properties = .{
            .{ "onloadstart", "get_onloadstart", "set_onloadstart" },
            .{ "onprogress", "get_onprogress", "set_onprogress" },
            .{ "onabort", "get_onabort", "set_onabort" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onload", "get_onload", "set_onload" },
            .{ "ontimeout", "get_ontimeout", "set_ontimeout" },
            .{ "onloadend", "get_onloadend", "set_onloadend" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onloadstart", "get_onloadstart", "set_onloadstart" },
            .{ "onprogress", "get_onprogress", "set_onprogress" },
            .{ "onabort", "get_onabort", "set_onabort" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onload", "get_onload", "set_onload" },
            .{ "ontimeout", "get_ontimeout", "set_ontimeout" },
            .{ "onloadend", "get_onloadend", "set_onloadend" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*XMLHttpRequestUploadImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onloadstart = &get_onloadstart,
        .get_onprogress = &get_onprogress,
        .get_onabort = &get_onabort,
        .get_onerror = &get_onerror,
        .get_onload = &get_onload,
        .get_ontimeout = &get_ontimeout,
        .get_onloadend = &get_onloadend,

        .set_onloadstart = &set_onloadstart,
        .set_onprogress = &set_onprogress,
        .set_onabort = &set_onabort,
        .set_onerror = &set_onerror,
        .set_onload = &set_onload,
        .set_ontimeout = &set_ontimeout,
        .set_onloadend = &set_onloadend,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XMLHttpRequestUploadImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XMLHttpRequestUploadImpl.deinit(instance);
    }

    // Event handler property accessors (inherited from XMLHttpRequestEventTarget)
    pub fn get_onloadstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestUploadImpl.get_onloadstart(instance);
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestUploadImpl.set_onloadstart(instance, value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestUploadImpl.get_onprogress(instance);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestUploadImpl.set_onprogress(instance, value);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestUploadImpl.get_onabort(instance);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestUploadImpl.set_onabort(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestUploadImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestUploadImpl.set_onerror(instance, value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestUploadImpl.get_onload(instance);
    }

    pub fn set_onload(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestUploadImpl.set_onload(instance, value);
    }

    pub fn get_ontimeout(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestUploadImpl.get_ontimeout(instance);
    }

    pub fn set_ontimeout(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestUploadImpl.set_ontimeout(instance, value);
    }

    pub fn get_onloadend(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestUploadImpl.get_onloadend(instance);
    }

    pub fn set_onloadend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestUploadImpl.set_onloadend(instance, value);
    }
};
