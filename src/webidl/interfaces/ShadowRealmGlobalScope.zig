//! Generated from: ShadowRealmGlobalScope.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ShadowRealmGlobalScopeImpl = @import("impls").ShadowRealmGlobalScope;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ByteString = @import("typedefs").ByteString;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const ShadowRealmGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "ShadowRealmGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier = "ShadowRealm" } },
            .{ .name = "Exposed", .value = .{ .identifier = "ShadowRealm" } },
            .{ .name = "LegacyNoInterfaceObject" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ShadowRealm = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "self", "get_self", "set_self" },
            .{ "name", "get_name", null },
            .{ "origin", "get_origin", null },
            .{ "isSecureContext", "get_isSecureContext", null },
            .{ "crossOriginIsolated", "get_crossOriginIsolated", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "btoa", "call_btoa", 1 },
            .{ "atob", "call_atob", 1 },
            .{ "structuredClone", "call_structuredClone", 1 },
            .{ "queueMicrotask", "call_queueMicrotask", 1 },
            .{ "reportError", "call_reportError", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "btoa",
            "atob",
            "structuredClone",
            "queueMicrotask",
            "reportError",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "self", "get_self", "set_self" },
            .{ "name", "get_name", null },
            .{ "origin", "get_origin", null },
            .{ "isSecureContext", "get_isSecureContext", null },
            .{ "crossOriginIsolated", "get_crossOriginIsolated", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            self: *runtime.Instance = undefined,
            name: runtime.DOMString = undefined,
            origin: runtime.USVString = undefined,
            isSecureContext: bool = undefined,
            crossOriginIsolated: bool = undefined,
            _internal: ?*ShadowRealmGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_crossOriginIsolated = &get_crossOriginIsolated,
        .get_isSecureContext = &get_isSecureContext,
        .get_name = &get_name,
        .get_origin = &get_origin,
        .get_self = &get_self,

        .set_self = &set_self,

        .call_atob = &call_atob,
        .call_btoa = &call_btoa,
        .call_queueMicrotask = &call_queueMicrotask,
        .call_reportError = &call_reportError,
        .call_structuredClone = &call_structuredClone,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ShadowRealmGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ShadowRealmGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ShadowRealmGlobalScopeImpl.deinit(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_self(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ShadowRealmGlobalScopeImpl.get_self(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_self(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "self", value);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ShadowRealmGlobalScopeImpl.get_name(instance);
    }

    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ShadowRealmGlobalScopeImpl.get_origin(instance);
    }

    pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
        return try ShadowRealmGlobalScopeImpl.get_isSecureContext(instance);
    }

    pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
        return try ShadowRealmGlobalScopeImpl.get_crossOriginIsolated(instance);
    }

    pub fn call_queueMicrotask(instance: *runtime.Instance, callback: runtime.JSValue) anyerror!void {
        
        return try ShadowRealmGlobalScopeImpl.call_queueMicrotask(instance, callback);
    }

    pub fn call_structuredClone(instance: *runtime.Instance, value: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        
        return try ShadowRealmGlobalScopeImpl.call_structuredClone(instance, value, options);
    }

    pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.ByteString {
        
        return try ShadowRealmGlobalScopeImpl.call_atob(instance, data);
    }

    pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.DOMString {
        
        return try ShadowRealmGlobalScopeImpl.call_btoa(instance, data);
    }

    pub fn call_reportError(instance: *runtime.Instance, e: runtime.JSValue) anyerror!void {
        
        return try ShadowRealmGlobalScopeImpl.call_reportError(instance, e);
    }

};
