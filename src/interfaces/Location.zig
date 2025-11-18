//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LocationImpl = @import("../impls/Location.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        LocationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        LocationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_href(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return LocationImpl.get_href(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        LocationImpl.set_href(state, value);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_origin(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return LocationImpl.get_origin(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_protocol(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return LocationImpl.get_protocol(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        LocationImpl.set_protocol(state, value);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_host(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return LocationImpl.get_host(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        LocationImpl.set_host(state, value);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_hostname(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return LocationImpl.get_hostname(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        LocationImpl.set_hostname(state, value);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_port(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return LocationImpl.get_port(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        LocationImpl.set_port(state, value);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_pathname(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return LocationImpl.get_pathname(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        LocationImpl.set_pathname(state, value);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_search(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return LocationImpl.get_search(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        LocationImpl.set_search(state, value);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_hash(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return LocationImpl.get_hash(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        LocationImpl.set_hash(state, value);
    }

    /// Extended attributes: [LegacyUnforgeable], [SameObject]
    pub fn get_ancestorOrigins(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_ancestorOrigins) |cached| {
            return cached;
        }
        const value = LocationImpl.get_ancestorOrigins(state);
        state.cached_ancestorOrigins = value;
        return value;
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn call_reload(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LocationImpl.call_reload(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn call_replace(instance: *runtime.Instance, url: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return LocationImpl.call_replace(state, url);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn call_assign(instance: *runtime.Instance, url: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return LocationImpl.call_assign(state, url);
    }

};
