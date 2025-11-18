//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LocationImpl = @import("impls").Location;
const DOMStringList = @import("interfaces").DOMStringList;

pub const Location = struct {
    pub const Meta = struct {
        pub const name = "Location";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Properties that cannot be shadowed or deleted (configurable: false)
        pub const legacy_unforgeable_properties = .{
            "href",
            "origin",
            "protocol",
            "host",
            "hostname",
            "port",
            "pathname",
            "search",
            "hash",
            "ancestorOrigins",
        };
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
            ancestorOrigins: DOMStringList = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Location, .{
        .deinit_fn = &deinit_wrapper,

        .get_ancestorOrigins = &get_ancestorOrigins,
        .get_hash = &get_hash,
        .get_host = &get_host,
        .get_hostname = &get_hostname,
        .get_href = &get_href,
        .get_origin = &get_origin,
        .get_pathname = &get_pathname,
        .get_port = &get_port,
        .get_protocol = &get_protocol,
        .get_search = &get_search,

        .set_hash = &set_hash,
        .set_host = &set_host,
        .set_hostname = &set_hostname,
        .set_href = &set_href,
        .set_pathname = &set_pathname,
        .set_port = &set_port,
        .set_protocol = &set_protocol,
        .set_search = &set_search,

        .call_assign = &call_assign,
        .call_reload = &call_reload,
        .call_replace = &call_replace,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        LocationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LocationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try LocationImpl.get_href(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try LocationImpl.set_href(instance, value);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try LocationImpl.get_origin(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try LocationImpl.get_protocol(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try LocationImpl.set_protocol(instance, value);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try LocationImpl.get_host(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try LocationImpl.set_host(instance, value);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try LocationImpl.get_hostname(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try LocationImpl.set_hostname(instance, value);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try LocationImpl.get_port(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try LocationImpl.set_port(instance, value);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try LocationImpl.get_pathname(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try LocationImpl.set_pathname(instance, value);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try LocationImpl.get_search(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try LocationImpl.set_search(instance, value);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try LocationImpl.get_hash(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try LocationImpl.set_hash(instance, value);
    }

    /// Extended attributes: [LegacyUnforgeable], [SameObject]
    pub fn get_ancestorOrigins(instance: *runtime.Instance) anyerror!DOMStringList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_ancestorOrigins) |cached| {
            return cached;
        }
        const value = try LocationImpl.get_ancestorOrigins(instance);
        state.cached_ancestorOrigins = value;
        return value;
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn call_reload(instance: *runtime.Instance) anyerror!void {
        return try LocationImpl.call_reload(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn call_replace(instance: *runtime.Instance, url: runtime.USVString) anyerror!void {
        
        return try LocationImpl.call_replace(instance, url);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn call_assign(instance: *runtime.Instance, url: runtime.USVString) anyerror!void {
        
        return try LocationImpl.call_assign(instance, url);
    }

};
