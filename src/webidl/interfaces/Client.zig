//! Generated from: service-workers.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ClientImpl = @import("impls").Client;
const ClientLifecycleState = @import("enums").ClientLifecycleState;
const FrameType = @import("enums").FrameType;
const ClientType = @import("enums").ClientType;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;

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
            type: ClientType = undefined,
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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ClientImpl.init(instance);
        
        return instance;
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

    /// Arguments for postMessage (WebIDL overloading)
    pub const PostMessageArgs = union(enum) {
        /// postMessage(message, transfer)
        any_sequence: struct {
            message: anyopaque,
            transfer: anyopaque,
        },
        /// postMessage(message, options)
        any_StructuredSerializeOptions: struct {
            message: anyopaque,
            options: StructuredSerializeOptions,
        },
    };

    pub fn call_postMessage(instance: *runtime.Instance, args: PostMessageArgs) anyerror!void {
        switch (args) {
            .any_sequence => |a| return try ClientImpl.any_sequence(instance, a.message, a.transfer),
            .any_StructuredSerializeOptions => |a| return try ClientImpl.any_StructuredSerializeOptions(instance, a.message, a.options),
        }
    }

};
