//! Generated from: url.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const URLSearchParamsImpl = @import("impls").URLSearchParams;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const URLSearchParams = struct {
    pub const Meta = struct {
        pub const name = "URLSearchParams";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "size", "get_size", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "append", "call_append", 2 },
            .{ "delete", "call_delete", 1 },
            .{ "get", "call_get", 1 },
            .{ "getAll", "call_getAll", 1 },
            .{ "has", "call_has", 1 },
            .{ "set", "call_set", 2 },
            .{ "sort", "call_sort", 0 },
            .{ "toString", "serialize", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "append",
            "delete",
            "get",
            "getAll",
            "has",
            "set",
            "sort",
            "toString",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "size", "get_size", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;

        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "runtime.USVString",
            .key_type = "runtime.USVString",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            size: u32 = undefined,
            _internal: ?*URLSearchParamsImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_size = &get_size,

        .call_append = &call_append,
        .call_delete = &call_delete,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_has = &call_has,
        .call_set = &call_set,
        .call_sort = &call_sort,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("URLSearchParams has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(URLSearchParamsImpl, "init") and @hasDecl(URLSearchParamsImpl, "initOwn")) @compileError("URLSearchParamsImpl defines both init and initOwn");
        if (comptime @hasDecl(URLSearchParamsImpl, "init")) return URLSearchParamsImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(URLSearchParamsImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try URLSearchParamsImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(URLSearchParamsImpl, "init")) return false;
        if (comptime @hasDecl(URLSearchParamsImpl, "construction_args")) {
            inline for (URLSearchParamsImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(URLSearchParamsImpl, "deinit") and @hasDecl(URLSearchParamsImpl, "deinitOwn")) @compileError("URLSearchParamsImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(URLSearchParamsImpl, "deinit")) return URLSearchParamsImpl.deinit(instance);
        if (comptime @hasDecl(URLSearchParamsImpl, "deinitOwn")) URLSearchParamsImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "URLSearchParams")) {
            if (comptime @hasDecl(impls.URLSearchParams, "installHooks")) impls.URLSearchParams.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, init_data: webidl.Opt(runtime.JSValue)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try URLSearchParamsImpl.call_constructor(ctx, init_data);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try URLSearchParamsImpl.get_size(instance);
    }

    pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString, value: webidl.Opt(runtime.USVString)) anyerror!void {
        return try URLSearchParamsImpl.call_delete(instance, name, value);
    }

    pub fn call_get(instance: *runtime.Instance, name: runtime.USVString) anyerror!?runtime.USVString {
        return try URLSearchParamsImpl.call_get(instance, name);
    }

    pub fn call_stringifier(instance: *runtime.Instance) anyerror!DOMString {
        return try URLSearchParamsImpl.call_stringifier(instance);
    }

    pub fn call_has(instance: *runtime.Instance, name: runtime.USVString, value: webidl.Opt(runtime.USVString)) anyerror!bool {
        return try URLSearchParamsImpl.call_has(instance, name, value);
    }

    pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) anyerror!runtime.JSValue {
        return try URLSearchParamsImpl.call_getAll(instance, name);
    }

    pub fn call_set(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
        return try URLSearchParamsImpl.call_set(instance, name, value);
    }

    pub fn call_sort(instance: *runtime.Instance) anyerror!void {
        return try URLSearchParamsImpl.call_sort(instance);
    }

    pub fn call_append(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
        return try URLSearchParamsImpl.call_append(instance, name, value);
    }

    /// Stringifier delegate - toString() implementation
    /// Per WebIDL spec: https://webidl.spec.whatwg.org/#es-stringifier
    pub fn serialize(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLSearchParamsImpl.serialize(instance);
    }

    /// Get entries for pair iterable support (used by V8 for iteration)
    /// Returns slice of entries with .name and .value fields
    pub fn getEntriesForIterable(instance: *runtime.Instance) ?[]const URLSearchParamsImpl.IterableEntry {
        return URLSearchParamsImpl.getEntriesInternal(instance);
    }
};
