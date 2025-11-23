//! Generated from: webrtc.idl
//! Generated at: 2025-11-23T14:26:30Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCErrorImpl = @import("impls").RTCError;
const DOMException = @import("interfaces").DOMException;
const RTCErrorInit = @import("dictionaries").RTCErrorInit;
const DOMString = @import("typedefs").DOMString;
const RTCErrorDetailType = @import("enums").RTCErrorDetailType;

pub const RTCError = struct {
    pub const Meta = struct {
        pub const name = "RTCError";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DOMException;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "errorDetail", "get_errorDetail", null },
            .{ "sdpLineNumber", "get_sdpLineNumber", null },
            .{ "sctpCauseCode", "get_sctpCauseCode", null },
            .{ "receivedAlert", "get_receivedAlert", null },
            .{ "sentAlert", "get_sentAlert", null },
            .{ "httpRequestStatusCode", "get_httpRequestStatusCode", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "errorDetail", "get_errorDetail", null },
            .{ "sdpLineNumber", "get_sdpLineNumber", null },
            .{ "sctpCauseCode", "get_sctpCauseCode", null },
            .{ "receivedAlert", "get_receivedAlert", null },
            .{ "sentAlert", "get_sentAlert", null },
            .{ "httpRequestStatusCode", "get_httpRequestStatusCode", null },
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
            errorDetail: RTCErrorDetailType = undefined,
            sdpLineNumber: ?i32 = null,
            sctpCauseCode: ?i32 = null,
            receivedAlert: ?u32 = null,
            sentAlert: ?u32 = null,
            httpRequestStatusCode: ?i32 = null,
            _internal: ?*RTCErrorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_errorDetail = &get_errorDetail,
        .get_httpRequestStatusCode = &get_httpRequestStatusCode,
        .get_receivedAlert = &get_receivedAlert,
        .get_sctpCauseCode = &get_sctpCauseCode,
        .get_sdpLineNumber = &get_sdpLineNumber,
        .get_sentAlert = &get_sentAlert,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCErrorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCErrorImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: RTCErrorInit, message: DOMString) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RTCErrorImpl.call_constructor(allocator, ctx, init_data, message);
    }

    pub fn get_errorDetail(instance: *runtime.Instance) anyerror!RTCErrorDetailType {
        return try RTCErrorImpl.get_errorDetail(instance);
    }

    pub fn get_sdpLineNumber(instance: *runtime.Instance) anyerror!i32 {
        return try RTCErrorImpl.get_sdpLineNumber(instance);
    }

    pub fn get_sctpCauseCode(instance: *runtime.Instance) anyerror!i32 {
        return try RTCErrorImpl.get_sctpCauseCode(instance);
    }

    pub fn get_receivedAlert(instance: *runtime.Instance) anyerror!u32 {
        return try RTCErrorImpl.get_receivedAlert(instance);
    }

    pub fn get_sentAlert(instance: *runtime.Instance) anyerror!u32 {
        return try RTCErrorImpl.get_sentAlert(instance);
    }

    pub fn get_httpRequestStatusCode(instance: *runtime.Instance) anyerror!i32 {
        return try RTCErrorImpl.get_httpRequestStatusCode(instance);
    }

};
