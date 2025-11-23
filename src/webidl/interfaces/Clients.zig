//! Generated from: service-workers.idl
//! Generated at: 2025-11-23T16:59:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ClientsImpl = @import("impls").Clients;
const WindowClient = @import("interfaces").WindowClient;
const ClientQueryOptions = @import("dictionaries").ClientQueryOptions;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const Clients = struct {
    pub const Meta = struct {
        pub const name = "Clients";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "get", "call_get", 1 },
            .{ "matchAll", "call_matchAll", 0 },
            .{ "openWindow", "call_openWindow", 1 },
            .{ "claim", "call_claim", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "get",
            "matchAll",
            "openWindow",
            "claim",
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

        .call_claim = &call_claim,
        .call_get = &call_get,
        .call_matchAll = &call_matchAll,
        .call_openWindow = &call_openWindow,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ClientsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ClientsImpl.deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_get(instance: *runtime.Instance, id: DOMString) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try ClientsImpl.call_get(instance, id);
    }

    /// Extended attributes: [NewObject]
    pub fn call_matchAll(instance: *runtime.Instance, options: ClientQueryOptions) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try ClientsImpl.call_matchAll(instance, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_openWindow(instance: *runtime.Instance, url: runtime.USVString) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try ClientsImpl.call_openWindow(instance, url);
    }

    /// Extended attributes: [NewObject]
    pub fn call_claim(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try ClientsImpl.call_claim(instance);
    }

};
