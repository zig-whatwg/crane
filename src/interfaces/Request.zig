//! Generated from: fetch.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RequestImpl = @import("../impls/Request.zig");
const Body = @import("Body.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        RequestImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RequestImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, input: anyopaque, init: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try RequestImpl.constructor(state, input, init);
        
        return instance;
    }

    pub fn get_method(instance: *runtime.Instance) runtime.ByteString {
        const state = instance.getState(State);
        return RequestImpl.get_method(state);
    }

    pub fn get_url(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return RequestImpl.get_url(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_headers(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_headers) |cached| {
            return cached;
        }
        const value = RequestImpl.get_headers(state);
        state.cached_headers = value;
        return value;
    }

    pub fn get_destination(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RequestImpl.get_destination(state);
    }

    pub fn get_referrer(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return RequestImpl.get_referrer(state);
    }

    pub fn get_referrerPolicy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RequestImpl.get_referrerPolicy(state);
    }

    pub fn get_mode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RequestImpl.get_mode(state);
    }

    pub fn get_credentials(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RequestImpl.get_credentials(state);
    }

    pub fn get_cache(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RequestImpl.get_cache(state);
    }

    pub fn get_redirect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RequestImpl.get_redirect(state);
    }

    pub fn get_integrity(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return RequestImpl.get_integrity(state);
    }

    pub fn get_keepalive(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return RequestImpl.get_keepalive(state);
    }

    pub fn get_isReloadNavigation(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return RequestImpl.get_isReloadNavigation(state);
    }

    pub fn get_isHistoryNavigation(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return RequestImpl.get_isHistoryNavigation(state);
    }

    pub fn get_signal(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RequestImpl.get_signal(state);
    }

    pub fn get_duplex(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RequestImpl.get_duplex(state);
    }

    pub fn get_targetAddressSpace(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RequestImpl.get_targetAddressSpace(state);
    }

    pub fn get_body(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RequestImpl.get_body(state);
    }

    pub fn get_bodyUsed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return RequestImpl.get_bodyUsed(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_clone(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return RequestImpl.call_clone(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_blob(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return RequestImpl.call_blob(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_arrayBuffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return RequestImpl.call_arrayBuffer(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_formData(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return RequestImpl.call_formData(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_text(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return RequestImpl.call_text(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_json(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return RequestImpl.call_json(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_bytes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return RequestImpl.call_bytes(state);
    }

};
