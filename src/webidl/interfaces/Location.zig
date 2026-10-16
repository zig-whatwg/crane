//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const LocationImpl = @import("impls").Location;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMStringList = @import("interfaces").DOMStringList;
const USVString = @import("typedefs").USVString;

pub const Location = struct {
    pub const Meta = struct {
        pub const name = "Location";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
            .{ "toString", "get_href", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "assign",
            "replace",
            "reload",
            "toString",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

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
        pub const lazy_properties = .{};

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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("Location has no construction argument '" ++ field.name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(LocationImpl, "init") and @hasDecl(LocationImpl, "initOwn")) @compileError("LocationImpl defines both init and initOwn");
        if (comptime @hasDecl(LocationImpl, "init")) return LocationImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(LocationImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try LocationImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(LocationImpl, "init")) return false;
        if (comptime @hasDecl(LocationImpl, "construction_args")) {
            inline for (LocationImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(LocationImpl, "deinit") and @hasDecl(LocationImpl, "deinitOwn")) @compileError("LocationImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(LocationImpl, "deinit")) return LocationImpl.deinit(instance);
        if (comptime @hasDecl(LocationImpl, "deinitOwn")) LocationImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Location")) {
            if (comptime @hasDecl(impls.Location, "installHooks")) impls.Location.installHooks();
        }
    }

    /// Extended attributes: [LegacyUnforgeable], [Stringifier]
    pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try LocationImpl.get_href(instance);
    }

    /// Extended attributes: [LegacyUnforgeable], [Stringifier]
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
        @import("dom").same_object_cache.made(instance, value, "ancestorOrigins");
        return value;
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn call_replace(instance: *runtime.Instance, url: runtime.USVString) anyerror!void {
        return try LocationImpl.call_replace(instance, url);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn call_assign(instance: *runtime.Instance, url: runtime.USVString) anyerror!void {
        return try LocationImpl.call_assign(instance, url);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn call_reload(instance: *runtime.Instance) anyerror!void {
        return try LocationImpl.call_reload(instance);
    }
};
