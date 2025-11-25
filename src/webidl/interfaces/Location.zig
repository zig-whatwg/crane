//! Generated from: html.idl
//! Generated at: 2025-11-25T19:42:24Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LocationImpl = @import("impls").Location;
const DOMStringList = @import("interfaces").DOMStringList;
const USVString = @import("interfaces").USVString;

pub const Location = struct {
    pub const Meta = struct {
        pub const name = "Location";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "href", "get_href", "set_href" },
            .{ "origin", "get_origin", null },
            .{ "protocol", "get_protocol", "set_protocol" },
            .{ "host", "get_host", "set_host" },
            .{ "hostname", "get_hostname", "set_hostname" },
            .{ "port", "get_port", "set_port" },
            .{ "pathname", "get_pathname", "set_pathname" },
            .{ "search", "get_search", "set_search" },
            .{ "hash", "get_hash", "set_hash" },
            .{ "ancestorOrigins", "get_ancestorOrigins", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "assign", "call_assign", 1 },
            .{ "replace", "call_replace", 1 },
            .{ "reload", "call_reload", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "assign",
            "replace",
            "reload",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "href", "get_href", "set_href" },
            .{ "origin", "get_origin", null },
            .{ "protocol", "get_protocol", "set_protocol" },
            .{ "host", "get_host", "set_host" },
            .{ "hostname", "get_hostname", "set_hostname" },
            .{ "port", "get_port", "set_port" },
            .{ "pathname", "get_pathname", "set_pathname" },
            .{ "search", "get_search", "set_search" },
            .{ "hash", "get_hash", "set_hash" },
            .{ "ancestorOrigins", "get_ancestorOrigins", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
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
            ancestorOrigins: *runtime.Instance = undefined,
            cached_ancestorOrigins: ?*runtime.Instance = null,
            _internal: ?*LocationImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return LocationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LocationImpl.deinit(instance);
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
    pub fn get_ancestorOrigins(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_ancestorOrigins) |cached| {
            return cached;
        }
        const value = try LocationImpl.get_ancestorOrigins(instance);
        state.own.cached_ancestorOrigins = value;
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
