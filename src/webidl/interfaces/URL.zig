//! Generated from: url.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const URLImpl = @import("impls").URL;
const mixins = @import("mixins");
const URLSearchParams = @import("interfaces").URLSearchParams;
const Blob = @import("interfaces").Blob;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;
const MediaSource = @import("interfaces").MediaSource;

pub const URL = struct {
    pub const Meta = struct {
        pub const name = "URL";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker", "SharedWorker" } } },
            .{ .name = "LegacyWindowAlias", .value = .{ .identifier = "webkitURL" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
            .SharedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "href", "get_href", "set_href" },
            .{ "origin", "get_origin", null },
            .{ "protocol", "get_protocol", "set_protocol" },
            .{ "username", "get_username", "set_username" },
            .{ "password", "get_password", "set_password" },
            .{ "host", "get_host", "set_host" },
            .{ "hostname", "get_hostname", "set_hostname" },
            .{ "port", "get_port", "set_port" },
            .{ "pathname", "get_pathname", "set_pathname" },
            .{ "search", "get_search", "set_search" },
            .{ "searchParams", "get_searchParams", null },
            .{ "hash", "get_hash", "set_hash" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
            .{ "toString", "get_href", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "parse", "call_static_parse", 1 },
            .{ "canParse", "call_static_canParse", 1 },
            .{ "createObjectURL", "call_static_createObjectURL", 1 },
            .{ "revokeObjectURL", "call_static_revokeObjectURL", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "parse",
            "canParse",
            "toJSON",
            "createObjectURL",
            "revokeObjectURL",
            "toString",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "href", "get_href", "set_href" },
            .{ "origin", "get_origin", null },
            .{ "protocol", "get_protocol", "set_protocol" },
            .{ "username", "get_username", "set_username" },
            .{ "password", "get_password", "set_password" },
            .{ "host", "get_host", "set_host" },
            .{ "hostname", "get_hostname", "set_hostname" },
            .{ "port", "get_port", "set_port" },
            .{ "pathname", "get_pathname", "set_pathname" },
            .{ "search", "get_search", "set_search" },
            .{ "searchParams", "get_searchParams", null },
            .{ "hash", "get_hash", "set_hash" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            href: runtime.USVString = undefined,
            origin: runtime.USVString = undefined,
            protocol: runtime.USVString = undefined,
            username: runtime.USVString = undefined,
            password: runtime.USVString = undefined,
            host: runtime.USVString = undefined,
            hostname: runtime.USVString = undefined,
            port: runtime.USVString = undefined,
            pathname: runtime.USVString = undefined,
            search: runtime.USVString = undefined,
            searchParams: *runtime.Instance = undefined,
            hash: runtime.USVString = undefined,
            cached_searchParams: ?*runtime.Instance = null,
            _internal: ?*URLImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_hash = &get_hash,
        .get_host = &get_host,
        .get_hostname = &get_hostname,
        .get_href = &get_href,
        .get_origin = &get_origin,
        .get_password = &get_password,
        .get_pathname = &get_pathname,
        .get_port = &get_port,
        .get_protocol = &get_protocol,
        .get_search = &get_search,
        .get_searchParams = &get_searchParams,
        .get_username = &get_username,

        .set_hash = &set_hash,
        .set_host = &set_host,
        .set_hostname = &set_hostname,
        .set_href = &set_href,
        .set_password = &set_password,
        .set_pathname = &set_pathname,
        .set_port = &set_port,
        .set_protocol = &set_protocol,
        .set_search = &set_search,
        .set_username = &set_username,

        .call_toJSON = &call_toJSON,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return URLImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return URLImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        URLImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, url: runtime.USVString, base: webidl.Opt(runtime.USVString)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try URLImpl.call_constructor(ctx, url, base);
    }

    /// Extended attributes: [Stringifier]
    pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_href(instance);
    }

    /// Extended attributes: [Stringifier]
    pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_href(instance, value);
    }

    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_origin(instance);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_protocol(instance);
    }

    pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_protocol(instance, value);
    }

    pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_username(instance);
    }

    pub fn set_username(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_username(instance, value);
    }

    pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_password(instance);
    }

    pub fn set_password(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_password(instance, value);
    }

    pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_host(instance);
    }

    pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_host(instance, value);
    }

    pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_hostname(instance);
    }

    pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_hostname(instance, value);
    }

    pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_port(instance);
    }

    pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_port(instance, value);
    }

    pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_pathname(instance);
    }

    pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_pathname(instance, value);
    }

    pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_search(instance);
    }

    pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_search(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_searchParams(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_searchParams) |cached| {
            return cached;
        }
        const value = try URLImpl.get_searchParams(instance);
        state.own.cached_searchParams = value;
        return value;
    }

    pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_hash(instance);
    }

    pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_hash(instance, value);
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.call_toJSON(instance);
    }

    pub fn call_static_canParse(instance: *runtime.Instance, url: runtime.USVString, base: webidl.Opt(runtime.USVString)) anyerror!bool {
        
        return try URLImpl.call_static_canParse(instance, url, base);
    }

    pub fn call_static_createObjectURL(instance: *runtime.Instance, obj: runtime.JSValue) anyerror!DOMString {
        
        return try URLImpl.call_static_createObjectURL(instance, obj);
    }

    pub fn call_static_parse(instance: *runtime.Instance, url: runtime.USVString, base: webidl.Opt(runtime.USVString)) anyerror!?*runtime.Instance {
        
        return try URLImpl.call_static_parse(instance, url, base);
    }

    pub fn call_static_revokeObjectURL(instance: *runtime.Instance, url: DOMString) anyerror!void {
        
        return try URLImpl.call_static_revokeObjectURL(instance, url);
    }

};
