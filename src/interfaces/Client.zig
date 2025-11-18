//! Generated from: service-workers.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ClientImpl = @import("../impls/Client.zig");

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
        .call_postMessage = &call_postMessage,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ClientImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ClientImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_url(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return ClientImpl.get_url(state);
    }

    pub fn get_frameType(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ClientImpl.get_frameType(state);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return ClientImpl.get_id(state);
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ClientImpl.get_type(state);
    }

    pub fn get_lifecycleState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ClientImpl.get_lifecycleState(state);
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
            options: anyopaque,
        },
    };

    pub fn call_postMessage(instance: *runtime.Instance, args: PostMessageArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .any_sequence => |a| return ClientImpl.any_sequence(state, a.message, a.transfer),
            .any_StructuredSerializeOptions => |a| return ClientImpl.any_StructuredSerializeOptions(state, a.message, a.options),
        }
    }

};
