//! Generated from: direct-sockets.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const UDPSocketImpl = @import("impls").UDPSocket;
const UDPSocketOptions = @import("dictionaries").UDPSocketOptions;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const Promise<UDPSocketOpenInfo> = @import("interfaces").Promise<UDPSocketOpenInfo>;

pub const UDPSocket = struct {
    pub const Meta = struct {
        pub const name = "UDPSocket";
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
            opened: Promise<UDPSocketOpenInfo> = undefined,
            closed: Promise<undefined> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(UDPSocket, .{
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
        
        // Initialize the instance (Impl receives full instance)
        UDPSocketImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        UDPSocketImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: UDPSocketOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try UDPSocketImpl.constructor(instance, options);
        
        return instance;
    }

    pub fn get_opened(instance: *runtime.Instance) anyerror!anyopaque {
        return try UDPSocketImpl.get_opened(instance);
    }

    pub fn get_closed(instance: *runtime.Instance) anyerror!anyopaque {
        return try UDPSocketImpl.get_closed(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!anyopaque {
        return try UDPSocketImpl.call_close(instance);
    }

};
