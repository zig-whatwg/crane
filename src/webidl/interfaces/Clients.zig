//! Generated from: service-workers.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ClientsImpl = @import("impls").Clients;
const WindowClient = @import("interfaces").WindowClient;
const ClientQueryOptions = @import("dictionaries").ClientQueryOptions;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

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
        return ClientsImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ClientsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_get(instance: *runtime.Instance, id: DOMString) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try ClientsImpl.call_get(instance, id);
    }

    /// Extended attributes: [NewObject]
    pub fn call_matchAll(instance: *runtime.Instance, options: ClientQueryOptions) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try ClientsImpl.call_matchAll(instance, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_openWindow(instance: *runtime.Instance, url: runtime.USVString) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try ClientsImpl.call_openWindow(instance, url);
    }

    /// Extended attributes: [NewObject]
    pub fn call_claim(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try ClientsImpl.call_claim(instance);
    }

};
