//! Generated from: netinfo.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorNetworkInformationImpl = @import("impls").NavigatorNetworkInformation;
const NetworkInformation = @import("interfaces").NetworkInformation;

pub const NavigatorNetworkInformation = struct {
    pub const Meta = struct {
        pub const name = "NavigatorNetworkInformation";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            connection: NetworkInformation = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigatorNetworkInformation, .{
        .deinit_fn = &deinit_wrapper,

        .get_connection = &get_connection,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        NavigatorNetworkInformationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorNetworkInformationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_connection(instance: *runtime.Instance) anyerror!NetworkInformation {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_connection) |cached| {
            return cached;
        }
        const value = try NavigatorNetworkInformationImpl.get_connection(instance);
        state.cached_connection = value;
        return value;
    }

};
