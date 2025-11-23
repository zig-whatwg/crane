//! Generated from: html.idl
//! Generated at: 2025-11-23T19:47:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorContentUtilsImpl = @import("impls").NavigatorContentUtils;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const NavigatorContentUtils = struct {
    pub const Meta = struct {
        pub const name = "NavigatorContentUtils";
        pub const is_mixin = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "registerProtocolHandler", "call_registerProtocolHandler", 2 },
            .{ "unregisterProtocolHandler", "call_unregisterProtocolHandler", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "registerProtocolHandler",
            "unregisterProtocolHandler",
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
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_registerProtocolHandler = &call_registerProtocolHandler,
        .call_unregisterProtocolHandler = &call_unregisterProtocolHandler,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigatorContentUtilsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorContentUtilsImpl.deinit(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_unregisterProtocolHandler(instance: *runtime.Instance, scheme: DOMString, url: runtime.USVString) anyerror!void {
        
        return try NavigatorContentUtilsImpl.call_unregisterProtocolHandler(instance, scheme, url);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_registerProtocolHandler(instance: *runtime.Instance, scheme: DOMString, url: runtime.USVString) anyerror!void {
        
        return try NavigatorContentUtilsImpl.call_registerProtocolHandler(instance, scheme, url);
    }

};
