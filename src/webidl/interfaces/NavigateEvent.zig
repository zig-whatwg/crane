//! Generated from: html.idl
//! Generated at: 2025-11-23T16:59:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigateEventImpl = @import("impls").NavigateEvent;
const Event = @import("interfaces").Event;
const NavigationType = @import("enums").NavigationType;
const NavigationDestination = @import("interfaces").NavigationDestination;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const Element = @import("interfaces").Element;
const AbortSignal = @import("interfaces").AbortSignal;
const NavigateEventInit = @import("dictionaries").NavigateEventInit;
const NavigationInterceptOptions = @import("dictionaries").NavigationInterceptOptions;
const EventTarget = @import("interfaces").EventTarget;
const EventInit = @import("dictionaries").EventInit;
const FormData = @import("interfaces").FormData;
const DOMString = @import("typedefs").DOMString;

pub const NavigateEvent = struct {
    pub const Meta = struct {
        pub const name = "NavigateEvent";
        pub const is_mixin = false;
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
            .{ "navigationType", "get_navigationType", null },
            .{ "destination", "get_destination", null },
            .{ "canIntercept", "get_canIntercept", null },
            .{ "userInitiated", "get_userInitiated", null },
            .{ "hashChange", "get_hashChange", null },
            .{ "signal", "get_signal", null },
            .{ "formData", "get_formData", null },
            .{ "downloadRequest", "get_downloadRequest", null },
            .{ "info", "get_info", null },
            .{ "hasUAVisualTransition", "get_hasUAVisualTransition", null },
            .{ "sourceElement", "get_sourceElement", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "intercept", "call_intercept", 0 },
            .{ "scroll", "call_scroll", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "intercept",
            "scroll",
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
            .{ "navigationType", "get_navigationType", null },
            .{ "destination", "get_destination", null },
            .{ "canIntercept", "get_canIntercept", null },
            .{ "userInitiated", "get_userInitiated", null },
            .{ "hashChange", "get_hashChange", null },
            .{ "signal", "get_signal", null },
            .{ "formData", "get_formData", null },
            .{ "downloadRequest", "get_downloadRequest", null },
            .{ "info", "get_info", null },
            .{ "hasUAVisualTransition", "get_hasUAVisualTransition", null },
            .{ "sourceElement", "get_sourceElement", null },
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
            navigationType: NavigationType = undefined,
            destination: NavigationDestination = undefined,
            canIntercept: bool = undefined,
            userInitiated: bool = undefined,
            hashChange: bool = undefined,
            signal: AbortSignal = undefined,
            formData: ?FormData = null,
            downloadRequest: ?runtime.DOMString = null,
            info: *const anyopaque = undefined,
            hasUAVisualTransition: bool = undefined,
            sourceElement: ?Element = null,
            _internal: ?*NavigateEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_canIntercept = &get_canIntercept,
        .get_destination = &get_destination,
        .get_downloadRequest = &get_downloadRequest,
        .get_formData = &get_formData,
        .get_hasUAVisualTransition = &get_hasUAVisualTransition,
        .get_hashChange = &get_hashChange,
        .get_info = &get_info,
        .get_navigationType = &get_navigationType,
        .get_signal = &get_signal,
        .get_sourceElement = &get_sourceElement,
        .get_userInitiated = &get_userInitiated,

        .call_intercept = &call_intercept,
        .call_scroll = &call_scroll,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigateEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigateEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: NavigateEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try NavigateEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_navigationType(instance: *runtime.Instance) anyerror!NavigationType {
        return try NavigateEventImpl.get_navigationType(instance);
    }

    pub fn get_destination(instance: *runtime.Instance) anyerror!NavigationDestination {
        return try NavigateEventImpl.get_destination(instance);
    }

    pub fn get_canIntercept(instance: *runtime.Instance) anyerror!bool {
        return try NavigateEventImpl.get_canIntercept(instance);
    }

    pub fn get_userInitiated(instance: *runtime.Instance) anyerror!bool {
        return try NavigateEventImpl.get_userInitiated(instance);
    }

    pub fn get_hashChange(instance: *runtime.Instance) anyerror!bool {
        return try NavigateEventImpl.get_hashChange(instance);
    }

    pub fn get_signal(instance: *runtime.Instance) anyerror!AbortSignal {
        return try NavigateEventImpl.get_signal(instance);
    }

    pub fn get_formData(instance: *runtime.Instance) anyerror!FormData {
        return try NavigateEventImpl.get_formData(instance);
    }

    pub fn get_downloadRequest(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigateEventImpl.get_downloadRequest(instance);
    }

    pub fn get_info(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigateEventImpl.get_info(instance);
    }

    pub fn get_hasUAVisualTransition(instance: *runtime.Instance) anyerror!bool {
        return try NavigateEventImpl.get_hasUAVisualTransition(instance);
    }

    pub fn get_sourceElement(instance: *runtime.Instance) anyerror!Element {
        return try NavigateEventImpl.get_sourceElement(instance);
    }

    pub fn call_scroll(instance: *runtime.Instance) anyerror!void {
        return try NavigateEventImpl.call_scroll(instance);
    }

    pub fn call_intercept(instance: *runtime.Instance, options: NavigationInterceptOptions) anyerror!void {
        
        return try NavigateEventImpl.call_intercept(instance, options);
    }

};
