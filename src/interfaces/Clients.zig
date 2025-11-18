//! Generated from: service-workers.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ClientsImpl = @import("../impls/Clients.zig");

pub const Clients = struct {
    pub const Meta = struct {
        pub const name = "Clients";
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Clients, .{
        .deinit_fn = &deinit_wrapper,

        .call_claim = &call_claim,
        .call_get = &call_get,
        .call_matchAll = &call_matchAll,
        .call_openWindow = &call_openWindow,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ClientsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ClientsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_get(instance: *runtime.Instance, id: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return ClientsImpl.call_get(state, id);
    }

    /// Extended attributes: [NewObject]
    pub fn call_matchAll(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return ClientsImpl.call_matchAll(state, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_openWindow(instance: *runtime.Instance, url: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return ClientsImpl.call_openWindow(state, url);
    }

    /// Extended attributes: [NewObject]
    pub fn call_claim(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return ClientsImpl.call_claim(state);
    }

};
