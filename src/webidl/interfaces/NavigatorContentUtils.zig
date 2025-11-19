//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorContentUtilsImpl = @import("impls").NavigatorContentUtils;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const NavigatorContentUtils = struct {
    pub const Meta = struct {
        pub const name = "NavigatorContentUtils";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigatorContentUtils, .{
        .deinit_fn = &deinit_wrapper,

        .call_registerProtocolHandler = &call_registerProtocolHandler,
        .call_unregisterProtocolHandler = &call_unregisterProtocolHandler,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return NavigatorContentUtilsImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorContentUtilsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_unregisterProtocolHandler(instance: *runtime.Instance, scheme: DOMString, url: runtime.USVString) anyerror!void {
        
        return try NavigatorContentUtilsImpl.call_unregisterProtocolHandler(instance, scheme, url);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_registerProtocolHandler(instance: *runtime.Instance, scheme: DOMString, url: runtime.USVString) anyerror!void {
        
        return try NavigatorContentUtilsImpl.call_registerProtocolHandler(instance, scheme, url);
    }

};
