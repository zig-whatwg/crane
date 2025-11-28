//! Generated from: service-workers.idl
//! Generated at: 2025-11-28T22:33:18Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CacheStorageImpl = @import("impls").CacheStorage;
const mixins = @import("mixins");
const Cache = @import("interfaces").Cache;
const MultiCacheQueryOptions = @import("dictionaries").MultiCacheQueryOptions;
const RequestInfo = @import("typedefs").RequestInfo;
const DOMString = @import("typedefs").DOMString;

pub const CacheStorage = struct {
    pub const Meta = struct {
        pub const name = "CacheStorage";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "match", "call_match", 1 },
            .{ "has", "call_has", 1 },
            .{ "open", "call_open", 1 },
            .{ "delete", "call_delete", 1 },
            .{ "keys", "call_keys", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "match",
            "has",
            "open",
            "delete",
            "keys",
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
        struct {
            _internal: ?*CacheStorageImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_delete = &call_delete,
        .call_has = &call_has,
        .call_keys = &call_keys,
        .call_match = &call_match,
        .call_open = &call_open,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CacheStorageImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CacheStorageImpl.deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_delete(instance: *runtime.Instance, cacheName: DOMString) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try CacheStorageImpl.call_delete(instance, cacheName);
    }

    /// Extended attributes: [NewObject]
    pub fn call_keys(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try CacheStorageImpl.call_keys(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_has(instance: *runtime.Instance, cacheName: DOMString) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try CacheStorageImpl.call_has(instance, cacheName);
    }

    /// Extended attributes: [NewObject]
    pub fn call_open(instance: *runtime.Instance, cacheName: DOMString) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try CacheStorageImpl.call_open(instance, cacheName);
    }

    /// Extended attributes: [NewObject]
    pub fn call_match(instance: *runtime.Instance, request: RequestInfo, options: webidl.Opt(MultiCacheQueryOptions)) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try CacheStorageImpl.call_match(instance, request, options);
    }

};
