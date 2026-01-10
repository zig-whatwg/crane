//! Generated from: fetch.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RequestImpl = @import("impls").Request;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Body = @import("mixins").Body;
const RequestDestination = @import("enums").RequestDestination;
const RequestCredentials = @import("enums").RequestCredentials;
const ByteString = @import("typedefs").ByteString;
const RequestMode = @import("enums").RequestMode;
const RequestInfo = @import("typedefs").RequestInfo;
const Blob = @import("Blob.zig").Blob;
const ReferrerPolicy = @import("enums").ReferrerPolicy;
const RequestInit = @import("dictionaries").RequestInit;
const RequestRedirect = @import("enums").RequestRedirect;
const USVString = @import("typedefs").USVString;
const RequestDuplex = @import("enums").RequestDuplex;
const RequestCache = @import("enums").RequestCache;
const IPAddressSpace = @import("enums").IPAddressSpace;
const ReadableStream = @import("ReadableStream.zig").ReadableStream;
const AbortSignal = @import("AbortSignal.zig").AbortSignal;
const FormData = @import("FormData.zig").FormData;
const DOMString = @import("typedefs").DOMString;
const Headers = @import("Headers.zig").Headers;

pub const Request = struct {
    pub const Meta = struct {
        pub const name = "Request";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
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
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "method", "get_method", null },
            .{ "url", "get_url", null },
            .{ "headers", "get_headers", null },
            .{ "destination", "get_destination", null },
            .{ "referrer", "get_referrer", null },
            .{ "referrerPolicy", "get_referrerPolicy", null },
            .{ "mode", "get_mode", null },
            .{ "credentials", "get_credentials", null },
            .{ "cache", "get_cache", null },
            .{ "redirect", "get_redirect", null },
            .{ "integrity", "get_integrity", null },
            .{ "keepalive", "get_keepalive", null },
            .{ "isReloadNavigation", "get_isReloadNavigation", null },
            .{ "isHistoryNavigation", "get_isHistoryNavigation", null },
            .{ "signal", "get_signal", null },
            .{ "duplex", "get_duplex", null },
            .{ "targetAddressSpace", "get_targetAddressSpace", null },
            .{ "body", "get_body", null },
            .{ "bodyUsed", "get_bodyUsed", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "clone", "call_clone", 0 },
            .{ "arrayBuffer", "call_arrayBuffer", 0 },
            .{ "blob", "call_blob", 0 },
            .{ "bytes", "call_bytes", 0 },
            .{ "formData", "call_formData", 0 },
            .{ "json", "call_json", 0 },
            .{ "text", "call_text", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "clone",
            "arrayBuffer",
            "blob",
            "bytes",
            "formData",
            "json",
            "text",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "method", "get_method", null },
            .{ "url", "get_url", null },
            .{ "headers", "get_headers", null },
            .{ "destination", "get_destination", null },
            .{ "referrer", "get_referrer", null },
            .{ "referrerPolicy", "get_referrerPolicy", null },
            .{ "mode", "get_mode", null },
            .{ "credentials", "get_credentials", null },
            .{ "cache", "get_cache", null },
            .{ "redirect", "get_redirect", null },
            .{ "integrity", "get_integrity", null },
            .{ "keepalive", "get_keepalive", null },
            .{ "isReloadNavigation", "get_isReloadNavigation", null },
            .{ "isHistoryNavigation", "get_isHistoryNavigation", null },
            .{ "signal", "get_signal", null },
            .{ "duplex", "get_duplex", null },
            .{ "targetAddressSpace", "get_targetAddressSpace", null },
            .{ "body", "get_body", null },
            .{ "bodyUsed", "get_bodyUsed", null },
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
            method: runtime.ByteString = undefined,
            url: runtime.USVString = undefined,
            headers: *runtime.Instance = undefined,
            destination: enums.RequestDestination = undefined,
            referrer: runtime.USVString = undefined,
            referrerPolicy: enums.ReferrerPolicy = undefined,
            mode: enums.RequestMode = undefined,
            credentials: enums.RequestCredentials = undefined,
            cache: enums.RequestCache = undefined,
            redirect: enums.RequestRedirect = undefined,
            integrity: typedefs.DOMString = undefined,
            keepalive: bool = undefined,
            isReloadNavigation: bool = undefined,
            isHistoryNavigation: bool = undefined,
            signal: *runtime.Instance = undefined,
            duplex: enums.RequestDuplex = undefined,
            targetAddressSpace: enums.IPAddressSpace = undefined,
            body: ?*runtime.Instance = null,
            bodyUsed: bool = undefined,
            cached_headers: ?*runtime.Instance = null,
            _internal: ?*RequestImpl.InternalState = null,
        },
    );

    const delegates = .{

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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RequestImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return RequestImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RequestImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, input: RequestInfo, init_data: webidl.Opt(RequestInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RequestImpl.call_constructor(ctx, input, init_data);
    }

    pub fn get_method(instance: *runtime.Instance) anyerror!runtime.ByteString {
        return try RequestImpl.get_method(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RequestImpl.get_url(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_headers(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_headers) |cached| {
            return cached;
        }
        const value = try RequestImpl.get_headers(instance);
        state.own.cached_headers = value;
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

    pub fn get_signal(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RequestImpl.get_signal(instance);
    }

    pub fn get_duplex(instance: *runtime.Instance) anyerror!RequestDuplex {
        return try RequestImpl.get_duplex(instance);
    }

    pub fn get_targetAddressSpace(instance: *runtime.Instance) anyerror!IPAddressSpace {
        return try RequestImpl.get_targetAddressSpace(instance);
    }

    pub fn get_body(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try RequestImpl.get_body(instance);
    }

    pub fn get_bodyUsed(instance: *runtime.Instance) anyerror!bool {
        return try RequestImpl.get_bodyUsed(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try RequestImpl.call_arrayBuffer(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_json(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try RequestImpl.call_json(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_text(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try RequestImpl.call_text(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_blob(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try RequestImpl.call_blob(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_bytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try RequestImpl.call_bytes(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_formData(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try RequestImpl.call_formData(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try RequestImpl.call_clone(instance);
    }

};
