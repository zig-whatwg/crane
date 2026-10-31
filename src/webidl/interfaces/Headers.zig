//! Generated from: fetch.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HeadersImpl = @import("impls").Headers;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ByteString = @import("typedefs").ByteString;
const HeadersInit = @import("typedefs").HeadersInit;

pub const Headers = struct {
    pub const Meta = struct {
        pub const name = "Headers";
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
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "append", "call_append", 2 },
            .{ "delete", "call_delete", 1 },
            .{ "get", "call_get", 1 },
            .{ "getSetCookie", "call_getSetCookie", 0 },
            .{ "has", "call_has", 1 },
            .{ "set", "call_set", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "append",
            "delete",
            "get",
            "getSetCookie",
            "has",
            "set",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;

        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "runtime.ByteString",
            .key_type = "runtime.ByteString",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*HeadersImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_append = &call_append,
        .call_delete = &call_delete,
        .call_get = &call_get,
        .call_getSetCookie = &call_getSetCookie,
        .call_has = &call_has,
        .call_set = &call_set,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("Headers has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(HeadersImpl, "init") and @hasDecl(HeadersImpl, "initOwn")) @compileError("HeadersImpl defines both init and initOwn");
        if (comptime @hasDecl(HeadersImpl, "init")) return HeadersImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(HeadersImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try HeadersImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(HeadersImpl, "init")) return false;
        if (comptime @hasDecl(HeadersImpl, "construction_args")) {
            inline for (HeadersImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(HeadersImpl, "deinit") and @hasDecl(HeadersImpl, "deinitOwn")) @compileError("HeadersImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(HeadersImpl, "deinit")) return HeadersImpl.deinit(instance);
        if (comptime @hasDecl(HeadersImpl, "deinitOwn")) HeadersImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Headers")) {
            if (comptime @hasDecl(impls.Headers, "installHooks")) impls.Headers.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, init_data: webidl.Opt(HeadersInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HeadersImpl.call_constructor(ctx, init_data);
    }

    pub fn call_delete(instance: *runtime.Instance, name: runtime.ByteString) anyerror!void {
        return try HeadersImpl.call_delete(instance, name);
    }

    pub fn call_get(instance: *runtime.Instance, name: runtime.ByteString) anyerror!?runtime.ByteString {
        return try HeadersImpl.call_get(instance, name);
    }

    pub fn call_getSetCookie(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try HeadersImpl.call_getSetCookie(instance);
    }

    pub fn call_has(instance: *runtime.Instance, name: runtime.ByteString) anyerror!bool {
        return try HeadersImpl.call_has(instance, name);
    }

    pub fn call_set(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) anyerror!void {
        return try HeadersImpl.call_set(instance, name, value);
    }

    pub fn call_append(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) anyerror!void {
        return try HeadersImpl.call_append(instance, name, value);
    }

    /// WebIDL ByteString values: a code unit above 0xFF throws a TypeError
    /// for (bit i = argument i; an attribute setter's value is bit 0).
    pub const byte_string_arguments = .{
        .{ "call_delete", 0b1 },
        .{ "call_get", 0b1 },
        .{ "call_has", 0b1 },
        .{ "call_set", 0b11 },
        .{ "call_append", 0b11 },
    };

    /// WebIDL ByteString results: each byte becomes the code unit of its value.
    pub const byte_string_returns = .{
        "call_get",
    };

    /// Get entries for pair iterable support (used by V8 for iteration)
    /// Returns slice of entries with .name and .value fields
    pub fn getEntriesForIterable(instance: *runtime.Instance) ?[]const HeadersImpl.IterableEntry {
        return HeadersImpl.getEntriesInternal(instance);
    }
};
