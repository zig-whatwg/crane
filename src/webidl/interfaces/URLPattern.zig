//! Generated from: urlpattern.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const URLPatternImpl = @import("impls").URLPattern;
const mixins = @import("mixins");
const URLPatternOptions = @import("dictionaries").URLPatternOptions;
const USVString = @import("interfaces").USVString;
const URLPatternResult = @import("dictionaries").URLPatternResult;
const URLPatternInput = @import("typedefs").URLPatternInput;

pub const URLPattern = struct {
    pub const Meta = struct {
        pub const name = "URLPattern";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "protocol", "get_protocol", null },
            .{ "username", "get_username", null },
            .{ "password", "get_password", null },
            .{ "hostname", "get_hostname", null },
            .{ "port", "get_port", null },
            .{ "pathname", "get_pathname", null },
            .{ "search", "get_search", null },
            .{ "hash", "get_hash", null },
            .{ "hasRegExpGroups", "get_hasRegExpGroups", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "test", "call_test", 0 },
            .{ "exec", "call_exec", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "test",
            "exec",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "protocol", "get_protocol", null },
            .{ "username", "get_username", null },
            .{ "password", "get_password", null },
            .{ "hostname", "get_hostname", null },
            .{ "port", "get_port", null },
            .{ "pathname", "get_pathname", null },
            .{ "search", "get_search", null },
            .{ "hash", "get_hash", null },
            .{ "hasRegExpGroups", "get_hasRegExpGroups", null },
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
            protocol: runtime.USVString = undefined,
            username: runtime.USVString = undefined,
            password: runtime.USVString = undefined,
            hostname: runtime.USVString = undefined,
            port: runtime.USVString = undefined,
            pathname: runtime.USVString = undefined,
            search: runtime.USVString = undefined,
            hash: runtime.USVString = undefined,
            hasRegExpGroups: bool = undefined,
            _internal: ?*URLPatternImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_hasRegExpGroups = &get_hasRegExpGroups,
        .get_hash = &get_hash,
        .get_hostname = &get_hostname,
        .get_password = &get_password,
        .get_pathname = &get_pathname,
        .get_port = &get_port,
        .get_protocol = &get_protocol,
        .get_search = &get_search,
        .get_username = &get_username,

        .call_exec = &call_exec,
        .call_test = &call_test,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return URLPatternImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return URLPatternImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        URLPatternImpl.deinit(instance);
    }

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor(input, baseURL, options)
        URLPatternInput_USVString_URLPatternOptions: struct {
            input: URLPatternInput,
            baseURL: runtime.USVString,
            options: webidl.Opt(URLPatternOptions),
        },
        /// constructor(input, options)
        URLPatternInput_URLPatternOptions: struct {
            input: webidl.Opt(URLPatternInput),
            options: webidl.Opt(URLPatternOptions),
        },
    };

    /// WebIDL constructor (overloaded)
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try URLPatternImpl.call_constructor(ctx, args);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLPatternImpl.get_protocol(instance);
    }

    pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLPatternImpl.get_username(instance);
    }

    pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLPatternImpl.get_password(instance);
    }

    pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLPatternImpl.get_hostname(instance);
    }

    pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLPatternImpl.get_port(instance);
    }

    pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLPatternImpl.get_pathname(instance);
    }

    pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLPatternImpl.get_search(instance);
    }

    pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLPatternImpl.get_hash(instance);
    }

    pub fn get_hasRegExpGroups(instance: *runtime.Instance) anyerror!bool {
        return try URLPatternImpl.get_hasRegExpGroups(instance);
    }

    pub fn call_test(instance: *runtime.Instance, input: webidl.Opt(URLPatternInput), baseURL: webidl.Opt(runtime.USVString)) anyerror!bool {
        
        return try URLPatternImpl.call_test(instance, input, baseURL);
    }

    pub fn call_exec(instance: *runtime.Instance, input: webidl.Opt(URLPatternInput), baseURL: webidl.Opt(runtime.USVString)) anyerror!?URLPatternResult {
        
        return try URLPatternImpl.call_exec(instance, input, baseURL);
    }

};
