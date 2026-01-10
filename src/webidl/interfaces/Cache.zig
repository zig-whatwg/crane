//! Generated from: service-workers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CacheImpl = @import("impls").Cache;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CacheQueryOptions = @import("dictionaries").CacheQueryOptions;
const RequestInfo = @import("typedefs").RequestInfo;
const Response = @import("Response.zig").Response;

pub const Cache = struct {
    pub const Meta = struct {
        pub const name = "Cache";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
            .{ "matchAll", "call_matchAll", 0 },
            .{ "add", "call_add", 1 },
            .{ "addAll", "call_addAll", 1 },
            .{ "put", "call_put", 2 },
            .{ "delete", "call_delete", 1 },
            .{ "keys", "call_keys", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "match",
            "matchAll",
            "add",
            "addAll",
            "put",
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
            _internal: ?*CacheImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_add = &call_add,
        .call_addAll = &call_addAll,
        .call_delete = &call_delete,
        .call_keys = &call_keys,
        .call_match = &call_match,
        .call_matchAll = &call_matchAll,
        .call_put = &call_put,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CacheImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CacheImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CacheImpl.deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_match(instance: *runtime.Instance, request: RequestInfo, options: webidl.Opt(CacheQueryOptions)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        
        return try CacheImpl.call_match(instance, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_delete(instance: *runtime.Instance, request: RequestInfo, options: webidl.Opt(CacheQueryOptions)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        
        return try CacheImpl.call_delete(instance, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_matchAll(instance: *runtime.Instance, request: webidl.Opt(RequestInfo), options: webidl.Opt(CacheQueryOptions)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        
        return try CacheImpl.call_matchAll(instance, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_addAll(instance: *runtime.Instance, requests: runtime.JSValue) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        
        return try CacheImpl.call_addAll(instance, requests);
    }

    /// Extended attributes: [NewObject]
    pub fn call_put(instance: *runtime.Instance, request: RequestInfo, response: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        
        return try CacheImpl.call_put(instance, request, response);
    }

    /// Extended attributes: [NewObject]
    pub fn call_keys(instance: *runtime.Instance, request: webidl.Opt(RequestInfo), options: webidl.Opt(CacheQueryOptions)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        
        return try CacheImpl.call_keys(instance, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_add(instance: *runtime.Instance, request: RequestInfo) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        
        return try CacheImpl.call_add(instance, request);
    }

};
