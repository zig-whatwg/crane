//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WorkerLocationImpl = @import("../impls/WorkerLocation.zig");

pub const WorkerLocation = struct {
    pub const Meta = struct {
        pub const name = "WorkerLocation";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Worker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Worker = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            href: runtime.USVString = undefined,
            origin: runtime.USVString = undefined,
            protocol: runtime.USVString = undefined,
            host: runtime.USVString = undefined,
            hostname: runtime.USVString = undefined,
            port: runtime.USVString = undefined,
            pathname: runtime.USVString = undefined,
            search: runtime.USVString = undefined,
            hash: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WorkerLocation, .{
        .deinit_fn = &deinit_wrapper,

        .get_hash = &get_hash,
        .get_host = &get_host,
        .get_hostname = &get_hostname,
        .get_href = &get_href,
        .get_origin = &get_origin,
        .get_pathname = &get_pathname,
        .get_port = &get_port,
        .get_protocol = &get_protocol,
        .get_search = &get_search,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        WorkerLocationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WorkerLocationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_href(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return WorkerLocationImpl.get_href(state);
    }

    pub fn get_origin(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return WorkerLocationImpl.get_origin(state);
    }

    pub fn get_protocol(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return WorkerLocationImpl.get_protocol(state);
    }

    pub fn get_host(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return WorkerLocationImpl.get_host(state);
    }

    pub fn get_hostname(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return WorkerLocationImpl.get_hostname(state);
    }

    pub fn get_port(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return WorkerLocationImpl.get_port(state);
    }

    pub fn get_pathname(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return WorkerLocationImpl.get_pathname(state);
    }

    pub fn get_search(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return WorkerLocationImpl.get_search(state);
    }

    pub fn get_hash(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return WorkerLocationImpl.get_hash(state);
    }

};
