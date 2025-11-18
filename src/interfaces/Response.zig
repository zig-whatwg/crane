//! Generated from: fetch.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ResponseImpl = @import("../impls/Response.zig");
const Body = @import("Body.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        ResponseImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ResponseImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, body: anyopaque, init: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try ResponseImpl.constructor(state, body, init);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ResponseImpl.get_type(state);
    }

    pub fn get_url(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return ResponseImpl.get_url(state);
    }

    pub fn get_redirected(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ResponseImpl.get_redirected(state);
    }

    pub fn get_status(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return ResponseImpl.get_status(state);
    }

    pub fn get_ok(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ResponseImpl.get_ok(state);
    }

    pub fn get_statusText(instance: *runtime.Instance) runtime.ByteString {
        const state = instance.getState(State);
        return ResponseImpl.get_statusText(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_headers(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_headers) |cached| {
            return cached;
        }
        const value = ResponseImpl.get_headers(state);
        state.cached_headers = value;
        return value;
    }

    pub fn get_body(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ResponseImpl.get_body(state);
    }

    pub fn get_bodyUsed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ResponseImpl.get_bodyUsed(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_error(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return ResponseImpl.call_error(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_clone(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return ResponseImpl.call_clone(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_blob(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return ResponseImpl.call_blob(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_arrayBuffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return ResponseImpl.call_arrayBuffer(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_formData(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return ResponseImpl.call_formData(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_text(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return ResponseImpl.call_text(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_redirect(instance: *runtime.Instance, url: runtime.USVString, status: u16) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return ResponseImpl.call_redirect(state, url, status);
    }

    /// Arguments for json (WebIDL overloading)
    pub const JsonArgs = union(enum) {
        /// json(data, init)
        any_ResponseInit: struct {
            data: anyopaque,
            init: anyopaque,
        },
        /// json()
        no_params: void,
    };

    pub fn call_json(instance: *runtime.Instance, args: JsonArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .any_ResponseInit => |a| return ResponseImpl.any_ResponseInit(state, a.data, a.init),
            .no_params => return ResponseImpl.no_params(state),
        }
    }

    /// Extended attributes: [NewObject]
    pub fn call_bytes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return ResponseImpl.call_bytes(state);
    }

};
