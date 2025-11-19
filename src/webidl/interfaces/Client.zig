//! Generated from: service-workers.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ClientImpl = @import("impls").Client;
const FrameType = @import("enums").FrameType;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const ClientLifecycleState = @import("enums").ClientLifecycleState;
const ClientType = @import("enums").ClientType;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const Client = struct {
    pub const Meta = struct {
        pub const name = "Client";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            url: runtime.USVString = undefined,
            frameType: FrameType = undefined,
            id: runtime.DOMString = undefined,
            @"type": ClientType = undefined,
            lifecycleState: ClientLifecycleState = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Client, .{
        .deinit_fn = &deinit_wrapper,

        .get_frameType = &get_frameType,
        .get_id = &get_id,
        .get_lifecycleState = &get_lifecycleState,
        .get_type = &get_type,
        .get_url = &get_url,

        .call_postMessage = &call_postMessage,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return ClientImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ClientImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ClientImpl.get_url(instance);
    }

    pub fn get_frameType(instance: *runtime.Instance) anyerror!FrameType {
        return try ClientImpl.get_frameType(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try ClientImpl.get_id(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!ClientType {
        return try ClientImpl.get_type(instance);
    }

    pub fn get_lifecycleState(instance: *runtime.Instance) anyerror!ClientLifecycleState {
        return try ClientImpl.get_lifecycleState(instance);
    }

    pub fn call_postMessage(instance: *runtime.Instance, message: anyopaque, transfer: anyopaque) anyerror!void {
        
        return try ClientImpl.call_postMessage(instance, message, transfer);
    }

};
