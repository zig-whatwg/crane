//! Generated from: direct-sockets.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TCPSocketImpl = @import("impls").TCPSocket;
const TCPSocketOptions = @import("dictionaries").TCPSocketOptions;
const TCPSocketOpenInfo = @import("dictionaries").TCPSocketOpenInfo;
const DOMString = @import("typedefs").DOMString;

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
            opened: runtime.Promise(TCPSocketOpenInfo) = undefined,
            closed: runtime.Promise(undefined) = undefined,
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
        return TCPSocketImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TCPSocketImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, remoteAddress: DOMString, remotePort: u16, options: TCPSocketOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try TCPSocketImpl.constructor(instance, remoteAddress, remotePort, options);
        
        return instance;
    }

    pub fn get_opened(instance: *runtime.Instance) anyerror!anyopaque {
        return try TCPSocketImpl.get_opened(instance);
    }

    pub fn get_closed(instance: *runtime.Instance) anyerror!anyopaque {
        return try TCPSocketImpl.get_closed(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!anyopaque {
        return try TCPSocketImpl.call_close(instance);
    }

};
