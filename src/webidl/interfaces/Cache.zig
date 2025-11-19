//! Generated from: service-workers.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CacheImpl = @import("impls").Cache;
const CacheQueryOptions = @import("dictionaries").CacheQueryOptions;
const RequestInfo = @import("typedefs").RequestInfo;
const Response = @import("interfaces").Response;

pub const Cache = struct {
    pub const Meta = struct {
        pub const name = "Cache";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Cache, .{
        .deinit_fn = &deinit_wrapper,

        .call_add = &call_add,
        .call_addAll = &call_addAll,
        .call_delete = &call_delete,
        .call_keys = &call_keys,
        .call_match = &call_match,
        .call_matchAll = &call_matchAll,
        .call_put = &call_put,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return CacheImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CacheImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_delete(instance: *runtime.Instance, request: RequestInfo, options: CacheQueryOptions) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try CacheImpl.call_delete(instance, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_match(instance: *runtime.Instance, request: RequestInfo, options: CacheQueryOptions) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try CacheImpl.call_match(instance, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_keys(instance: *runtime.Instance, request: RequestInfo, options: CacheQueryOptions) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try CacheImpl.call_keys(instance, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_matchAll(instance: *runtime.Instance, request: RequestInfo, options: CacheQueryOptions) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try CacheImpl.call_matchAll(instance, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_add(instance: *runtime.Instance, request: RequestInfo) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try CacheImpl.call_add(instance, request);
    }

    /// Extended attributes: [NewObject]
    pub fn call_addAll(instance: *runtime.Instance, requests: anyopaque) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try CacheImpl.call_addAll(instance, requests);
    }

    /// Extended attributes: [NewObject]
    pub fn call_put(instance: *runtime.Instance, request: RequestInfo, response: Response) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try CacheImpl.call_put(instance, request, response);
    }

};
