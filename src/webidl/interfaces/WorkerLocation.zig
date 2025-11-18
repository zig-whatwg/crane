//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WorkerLocationImpl = @import("impls").WorkerLocation;

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
        
        // Initialize the instance (Impl receives full instance)
        WorkerLocationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WorkerLocationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try WorkerLocationImpl.get_href(instance);
    }

    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try WorkerLocationImpl.get_origin(instance);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try WorkerLocationImpl.get_protocol(instance);
    }

    pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try WorkerLocationImpl.get_host(instance);
    }

    pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try WorkerLocationImpl.get_hostname(instance);
    }

    pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try WorkerLocationImpl.get_port(instance);
    }

    pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try WorkerLocationImpl.get_pathname(instance);
    }

    pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try WorkerLocationImpl.get_search(instance);
    }

    pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try WorkerLocationImpl.get_hash(instance);
    }

};
