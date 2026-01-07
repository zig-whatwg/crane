//! Generated from: fetch.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ResponseImpl = @import("impls").Response;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Body = @import("mixins").Body;
const ByteString = @import("typedefs").ByteString;
const Blob = @import("interfaces").Blob;
const ResponseType = @import("enums").ResponseType;
const USVString = @import("typedefs").USVString;
const ReadableStream = @import("interfaces").ReadableStream;
const BodyInit = @import("typedefs").BodyInit;
const ResponseInit = @import("dictionaries").ResponseInit;
const FormData = @import("interfaces").FormData;
const Headers = @import("interfaces").Headers;

pub const Response = struct {
    pub const Meta = struct {
        pub const name = "Response";
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
            .{ "type", "get_type", null },
            .{ "url", "get_url", null },
            .{ "redirected", "get_redirected", null },
            .{ "status", "get_status", null },
            .{ "ok", "get_ok", null },
            .{ "statusText", "get_statusText", null },
            .{ "headers", "get_headers", null },
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "error", "call_static_error", 0 },
            .{ "redirect", "call_static_redirect", 1 },
            .{ "json", "call_static_json", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "error",
            "redirect",
            "json",
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
            .{ "type", "get_type", null },
            .{ "url", "get_url", null },
            .{ "redirected", "get_redirected", null },
            .{ "status", "get_status", null },
            .{ "ok", "get_ok", null },
            .{ "statusText", "get_statusText", null },
            .{ "headers", "get_headers", null },
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
            @"type": enums.ResponseType = undefined,
            url: runtime.USVString = undefined,
            redirected: bool = undefined,
            status: u16 = undefined,
            ok: bool = undefined,
            statusText: runtime.ByteString = undefined,
            headers: *runtime.Instance = undefined,
            body: ?*runtime.Instance = null,
            bodyUsed: bool = undefined,
            cached_headers: ?*runtime.Instance = null,
            _internal: ?*ResponseImpl.InternalState = null,
        },
    );

    const delegates = .{

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
        .call_formData = &call_formData,
        .call_json = &call_json,
        .call_text = &call_text,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ResponseImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ResponseImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ResponseImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, body: webidl.Opt(?BodyInit), init_data: webidl.Opt(ResponseInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ResponseImpl.call_constructor(ctx, body, init_data);
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
    pub fn get_headers(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_headers) |cached| {
            return cached;
        }
        const value = try ResponseImpl.get_headers(instance);
        state.own.cached_headers = value;
        return value;
    }

    pub fn get_body(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ResponseImpl.get_body(instance);
    }

    pub fn get_bodyUsed(instance: *runtime.Instance) anyerror!bool {
        return try ResponseImpl.get_bodyUsed(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try ResponseImpl.call_arrayBuffer(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_json(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try ResponseImpl.call_json(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_text(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try ResponseImpl.call_text(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_json(instance: *runtime.Instance, data: runtime.JSValue, init_data: webidl.Opt(ResponseInit)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try ResponseImpl.call_static_json(instance, data, init_data);
    }

    /// Extended attributes: [NewObject]
    pub fn call_blob(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try ResponseImpl.call_blob(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_error(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try ResponseImpl.call_static_error(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_redirect(instance: *runtime.Instance, url: runtime.USVString, status: webidl.Opt(u16)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try ResponseImpl.call_static_redirect(instance, url, status);
    }

    /// Extended attributes: [NewObject]
    pub fn call_bytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try ResponseImpl.call_bytes(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_formData(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try ResponseImpl.call_formData(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try ResponseImpl.call_clone(instance);
    }

};
