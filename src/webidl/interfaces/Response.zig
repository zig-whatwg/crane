//! Generated from: fetch.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ResponseImpl = @import("impls").Response;
const Body = @import("interfaces").Body;
const Promise<Blob> = @import("interfaces").Promise<Blob>;
const Promise<FormData> = @import("interfaces").Promise<FormData>;
const ResponseType = @import("enums").ResponseType;
const Promise<any> = @import("interfaces").Promise<any>;
const Promise<ArrayBuffer> = @import("interfaces").Promise<ArrayBuffer>;
const ReadableStream = @import("interfaces").ReadableStream;
const BodyInit = @import("typedefs").BodyInit;
const ResponseInit = @import("dictionaries").ResponseInit;
const Promise<Uint8Array> = @import("interfaces").Promise<Uint8Array>;
const Headers = @import("interfaces").Headers;
const Promise<USVString> = @import("interfaces").Promise<USVString>;

pub const Response = struct {
    pub const Meta = struct {
        pub const name = "Response";
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
            type: ResponseType = undefined,
            url: runtime.USVString = undefined,
            redirected: bool = undefined,
            status: u16 = undefined,
            ok: bool = undefined,
            statusText: runtime.ByteString = undefined,
            headers: Headers = undefined,
            body: ?ReadableStream = null,
            bodyUsed: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Response, .{
        .deinit_fn = &deinit_wrapper,

        .get_body = &get_body,
        .get_bodyUsed = &get_bodyUsed,
        .get_headers = &get_headers,
        .get_ok = &get_ok,
        .get_redirected = &get_redirected,
        .get_status = &get_status,
        .get_statusText = &get_statusText,
        .get_type = &get_type,
        .get_url = &get_url,

        .call_arrayBuffer = &call_arrayBuffer,
        .call_blob = &call_blob,
        .call_bytes = &call_bytes,
        .call_clone = &call_clone,
        .call_error = &call_error,
        .call_formData = &call_formData,
        .call_json = &call_json,
        .call_redirect = &call_redirect,
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
        ResponseImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ResponseImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, body: anyopaque, init: ResponseInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ResponseImpl.constructor(instance, body, init);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!ResponseType {
        return try ResponseImpl.get_type(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ResponseImpl.get_url(instance);
    }

    pub fn get_redirected(instance: *runtime.Instance) anyerror!bool {
        return try ResponseImpl.get_redirected(instance);
    }

    pub fn get_status(instance: *runtime.Instance) anyerror!u16 {
        return try ResponseImpl.get_status(instance);
    }

    pub fn get_ok(instance: *runtime.Instance) anyerror!bool {
        return try ResponseImpl.get_ok(instance);
    }

    pub fn get_statusText(instance: *runtime.Instance) anyerror!runtime.ByteString {
        return try ResponseImpl.get_statusText(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_headers(instance: *runtime.Instance) anyerror!Headers {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_headers) |cached| {
            return cached;
        }
        const value = try ResponseImpl.get_headers(instance);
        state.cached_headers = value;
        return value;
    }

    pub fn get_body(instance: *runtime.Instance) anyerror!anyopaque {
        return try ResponseImpl.get_body(instance);
    }

    pub fn get_bodyUsed(instance: *runtime.Instance) anyerror!bool {
        return try ResponseImpl.get_bodyUsed(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_error(instance: *runtime.Instance) anyerror!Response {
        // [NewObject] - Caller owns the returned object
        return try ResponseImpl.call_error(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_clone(instance: *runtime.Instance) anyerror!Response {
        // [NewObject] - Caller owns the returned object
        return try ResponseImpl.call_clone(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_blob(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try ResponseImpl.call_blob(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try ResponseImpl.call_arrayBuffer(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_formData(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try ResponseImpl.call_formData(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_text(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try ResponseImpl.call_text(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_redirect(instance: *runtime.Instance, url: runtime.USVString, status: u16) anyerror!Response {
        // [NewObject] - Caller owns the returned object
        
        return try ResponseImpl.call_redirect(instance, url, status);
    }

    /// Arguments for json (WebIDL overloading)
    pub const JsonArgs = union(enum) {
        /// json(data, init)
        any_ResponseInit: struct {
            data: anyopaque,
            init: ResponseInit,
        },
        /// json()
        no_params: void,
    };

    pub fn call_json(instance: *runtime.Instance, args: JsonArgs) anyerror!Response {
        switch (args) {
            .any_ResponseInit => |a| return try ResponseImpl.any_ResponseInit(instance, a.data, a.init),
            .no_params => return try ResponseImpl.no_params(instance),
        }
    }

    /// Extended attributes: [NewObject]
    pub fn call_bytes(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try ResponseImpl.call_bytes(instance);
    }

};
