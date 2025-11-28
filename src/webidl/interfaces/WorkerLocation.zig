//! Generated from: html.idl
//! Generated at: 2025-11-28T18:57:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WorkerLocationImpl = @import("impls").WorkerLocation;
const mixins = @import("mixins");
const USVString = @import("interfaces").USVString;

pub const WorkerLocation = struct {
    pub const Meta = struct {
        pub const name = "WorkerLocation";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Worker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Worker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "href", "get_href", null },
            .{ "origin", "get_origin", null },
            .{ "protocol", "get_protocol", null },
            .{ "host", "get_host", null },
            .{ "hostname", "get_hostname", null },
            .{ "port", "get_port", null },
            .{ "pathname", "get_pathname", null },
            .{ "search", "get_search", null },
            .{ "hash", "get_hash", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "href", "get_href", null },
            .{ "origin", "get_origin", null },
            .{ "protocol", "get_protocol", null },
            .{ "host", "get_host", null },
            .{ "hostname", "get_hostname", null },
            .{ "port", "get_port", null },
            .{ "pathname", "get_pathname", null },
            .{ "search", "get_search", null },
            .{ "hash", "get_hash", null },
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
            _internal: ?*WorkerLocationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_hash = &get_hash,
        .get_host = &get_host,
        .get_hostname = &get_hostname,
        .get_href = &get_href,
        .get_origin = &get_origin,
        .get_pathname = &get_pathname,
        .get_port = &get_port,
        .get_protocol = &get_protocol,
        .get_search = &get_search,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WorkerLocationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WorkerLocationImpl.deinit(instance);
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
