//! Generated from: fetch.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RequestImpl = @import("impls").Request;
const Body = @import("interfaces").Body;
const RequestCredentials = @import("enums").RequestCredentials;
const Promise<Blob> = @import("interfaces").Promise<Blob>;
const RequestMode = @import("enums").RequestMode;
const RequestInfo = @import("typedefs").RequestInfo;
const Promise<FormData> = @import("interfaces").Promise<FormData>;
const ReferrerPolicy = @import("enums").ReferrerPolicy;
const RequestInit = @import("dictionaries").RequestInit;
const RequestRedirect = @import("enums").RequestRedirect;
const RequestDuplex = @import("enums").RequestDuplex;
const IPAddressSpace = @import("enums").IPAddressSpace;
const RequestCache = @import("enums").RequestCache;
const Promise<any> = @import("interfaces").Promise<any>;
const Promise<ArrayBuffer> = @import("interfaces").Promise<ArrayBuffer>;
const ReadableStream = @import("interfaces").ReadableStream;
const AbortSignal = @import("interfaces").AbortSignal;
const Promise<USVString> = @import("interfaces").Promise<USVString>;
const Promise<Uint8Array> = @import("interfaces").Promise<Uint8Array>;
const Headers = @import("interfaces").Headers;
const RequestDestination = @import("enums").RequestDestination;

pub const Request = struct {
    pub const Meta = struct {
        pub const name = "Request";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            Body,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            method: runtime.ByteString = undefined,
            url: runtime.USVString = undefined,
            headers: Headers = undefined,
            destination: RequestDestination = undefined,
            referrer: runtime.USVString = undefined,
            referrerPolicy: ReferrerPolicy = undefined,
            mode: RequestMode = undefined,
            credentials: RequestCredentials = undefined,
            cache: RequestCache = undefined,
            redirect: RequestRedirect = undefined,
            integrity: runtime.DOMString = undefined,
            keepalive: bool = undefined,
            isReloadNavigation: bool = undefined,
            isHistoryNavigation: bool = undefined,
            signal: AbortSignal = undefined,
            duplex: RequestDuplex = undefined,
            targetAddressSpace: IPAddressSpace = undefined,
            body: ?ReadableStream = null,
            bodyUsed: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Request, .{
        .deinit_fn = &deinit_wrapper,

        .get_body = &get_body,
        .get_bodyUsed = &get_bodyUsed,
        .get_cache = &get_cache,
        .get_credentials = &get_credentials,
        .get_destination = &get_destination,
        .get_duplex = &get_duplex,
        .get_headers = &get_headers,
        .get_integrity = &get_integrity,
        .get_isHistoryNavigation = &get_isHistoryNavigation,
        .get_isReloadNavigation = &get_isReloadNavigation,
        .get_keepalive = &get_keepalive,
        .get_method = &get_method,
        .get_mode = &get_mode,
        .get_redirect = &get_redirect,
        .get_referrer = &get_referrer,
        .get_referrerPolicy = &get_referrerPolicy,
        .get_signal = &get_signal,
        .get_targetAddressSpace = &get_targetAddressSpace,
        .get_url = &get_url,

        .call_arrayBuffer = &call_arrayBuffer,
        .call_blob = &call_blob,
        .call_bytes = &call_bytes,
        .call_clone = &call_clone,
        .call_formData = &call_formData,
        .call_json = &call_json,
        .call_text = &call_text,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        RequestImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RequestImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, input: RequestInfo, init: RequestInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try RequestImpl.constructor(instance, input, init);
        
        return instance;
    }

    pub fn get_method(instance: *runtime.Instance) anyerror!runtime.ByteString {
        return try RequestImpl.get_method(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RequestImpl.get_url(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_headers(instance: *runtime.Instance) anyerror!Headers {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_headers) |cached| {
            return cached;
        }
        const value = try RequestImpl.get_headers(instance);
        state.cached_headers = value;
        return value;
    }

    pub fn get_destination(instance: *runtime.Instance) anyerror!RequestDestination {
        return try RequestImpl.get_destination(instance);
    }

    pub fn get_referrer(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RequestImpl.get_referrer(instance);
    }

    pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!ReferrerPolicy {
        return try RequestImpl.get_referrerPolicy(instance);
    }

    pub fn get_mode(instance: *runtime.Instance) anyerror!RequestMode {
        return try RequestImpl.get_mode(instance);
    }

    pub fn get_credentials(instance: *runtime.Instance) anyerror!RequestCredentials {
        return try RequestImpl.get_credentials(instance);
    }

    pub fn get_cache(instance: *runtime.Instance) anyerror!RequestCache {
        return try RequestImpl.get_cache(instance);
    }

    pub fn get_redirect(instance: *runtime.Instance) anyerror!RequestRedirect {
        return try RequestImpl.get_redirect(instance);
    }

    pub fn get_integrity(instance: *runtime.Instance) anyerror!DOMString {
        return try RequestImpl.get_integrity(instance);
    }

    pub fn get_keepalive(instance: *runtime.Instance) anyerror!bool {
        return try RequestImpl.get_keepalive(instance);
    }

    pub fn get_isReloadNavigation(instance: *runtime.Instance) anyerror!bool {
        return try RequestImpl.get_isReloadNavigation(instance);
    }

    pub fn get_isHistoryNavigation(instance: *runtime.Instance) anyerror!bool {
        return try RequestImpl.get_isHistoryNavigation(instance);
    }

    pub fn get_signal(instance: *runtime.Instance) anyerror!AbortSignal {
        return try RequestImpl.get_signal(instance);
    }

    pub fn get_duplex(instance: *runtime.Instance) anyerror!RequestDuplex {
        return try RequestImpl.get_duplex(instance);
    }

    pub fn get_targetAddressSpace(instance: *runtime.Instance) anyerror!IPAddressSpace {
        return try RequestImpl.get_targetAddressSpace(instance);
    }

    pub fn get_body(instance: *runtime.Instance) anyerror!anyopaque {
        return try RequestImpl.get_body(instance);
    }

    pub fn get_bodyUsed(instance: *runtime.Instance) anyerror!bool {
        return try RequestImpl.get_bodyUsed(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_clone(instance: *runtime.Instance) anyerror!Request {
        // [NewObject] - Caller owns the returned object
        return try RequestImpl.call_clone(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_blob(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try RequestImpl.call_blob(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try RequestImpl.call_arrayBuffer(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_formData(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try RequestImpl.call_formData(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_text(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try RequestImpl.call_text(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_json(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try RequestImpl.call_json(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_bytes(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try RequestImpl.call_bytes(instance);
    }

};
