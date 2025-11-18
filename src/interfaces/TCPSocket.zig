//! Generated from: direct-sockets.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TCPSocketImpl = @import("../impls/TCPSocket.zig");

pub const TCPSocket = struct {
    pub const Meta = struct {
        pub const name = "TCPSocket";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "SecureContext" },
            .{ .name = "IsolatedContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            opened: Promise<TCPSocketOpenInfo> = undefined,
            closed: Promise<undefined> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TCPSocket, .{
        .deinit_fn = &deinit_wrapper,

        .get_closed = &get_closed,
        .get_opened = &get_opened,

        .call_close = &call_close,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        TCPSocketImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TCPSocketImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, remoteAddress: runtime.DOMString, remotePort: u16, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try TCPSocketImpl.constructor(state, remoteAddress, remotePort, options);
        
        return instance;
    }

    pub fn get_opened(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TCPSocketImpl.get_opened(state);
    }

    pub fn get_closed(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TCPSocketImpl.get_closed(state);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TCPSocketImpl.call_close(state);
    }

};
