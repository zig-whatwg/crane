//! Generated from: IndexedDB.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IDBCursorImpl = @import("impls").IDBCursor;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const IDBRequest = @import("interfaces").IDBRequest;
const IDBIndex = @import("interfaces").IDBIndex;
const IDBCursorDirection = @import("enums").IDBCursorDirection;
const IDBObjectStore = @import("interfaces").IDBObjectStore;

pub const IDBCursor = struct {
    pub const Meta = struct {
        pub const name = "IDBCursor";
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
            .{ "source", "get_source", null },
            .{ "direction", "get_direction", null },
            .{ "key", "get_key", null },
            .{ "primaryKey", "get_primaryKey", null },
            .{ "request", "get_request", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "advance", "call_advance", 1 },
            .{ "continue", "call_continue", 0 },
            .{ "continuePrimaryKey", "call_continuePrimaryKey", 2 },
            .{ "update", "call_update", 1 },
            .{ "delete", "call_delete", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "advance",
            "continue",
            "continuePrimaryKey",
            "update",
            "delete",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "source", "get_source", null },
            .{ "direction", "get_direction", null },
            .{ "key", "get_key", null },
            .{ "primaryKey", "get_primaryKey", null },
            .{ "request", "get_request", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            source: union(enum) {
                IDBObjectStore: IDBObjectStore,
                IDBIndex: IDBIndex,
            } = undefined,
            direction: enums.IDBCursorDirection = undefined,
            key: runtime.JSValue = undefined,
            primaryKey: runtime.JSValue = undefined,
            request: *runtime.Instance = undefined,
            cached_request: ?*runtime.Instance = null,
            _internal: ?*IDBCursorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_direction = &get_direction,
        .get_key = &get_key,
        .get_primaryKey = &get_primaryKey,
        .get_request = &get_request,
        .get_source = &get_source,

        .call_advance = &call_advance,
        .call_continue = &call_continue,
        .call_continuePrimaryKey = &call_continuePrimaryKey,
        .call_delete = &call_delete,
        .call_update = &call_update,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("IDBCursor has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(IDBCursorImpl, "init") and @hasDecl(IDBCursorImpl, "initOwn")) @compileError("IDBCursorImpl defines both init and initOwn");
        if (comptime @hasDecl(IDBCursorImpl, "init")) return IDBCursorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(IDBCursorImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try IDBCursorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(IDBCursorImpl, "init")) return false;
        if (comptime @hasDecl(IDBCursorImpl, "construction_args")) {
            inline for (IDBCursorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(IDBCursorImpl, "deinit") and @hasDecl(IDBCursorImpl, "deinitOwn")) @compileError("IDBCursorImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(IDBCursorImpl, "deinit")) return IDBCursorImpl.deinit(instance);
        if (comptime @hasDecl(IDBCursorImpl, "deinitOwn")) IDBCursorImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "IDBCursor")) {
            if (comptime @hasDecl(impls.IDBCursor, "installHooks")) impls.IDBCursor.installHooks();
        }
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IDBCursorImpl.get_source(instance);
    }

    pub fn get_direction(instance: *runtime.Instance) anyerror!IDBCursorDirection {
        return try IDBCursorImpl.get_direction(instance);
    }

    pub fn get_key(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IDBCursorImpl.get_key(instance);
    }

    pub fn get_primaryKey(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IDBCursorImpl.get_primaryKey(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_request(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_request) |cached| {
            return cached;
        }
        const value = try IDBCursorImpl.get_request(instance);
        state.own.cached_request = value;
        return value;
    }

    pub fn call_advance(instance: *runtime.Instance, count: u32) anyerror!void {
        return try IDBCursorImpl.call_advance(instance, count);
    }

    pub fn call_continue(instance: *runtime.Instance, key: webidl.Opt(runtime.JSValue)) anyerror!void {
        return try IDBCursorImpl.call_continue(instance, key);
    }

    /// Extended attributes: [NewObject]
    pub fn call_delete(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try IDBCursorImpl.call_delete(instance);
    }

    pub fn call_continuePrimaryKey(instance: *runtime.Instance, key: runtime.JSValue, primaryKey: runtime.JSValue) anyerror!void {
        return try IDBCursorImpl.call_continuePrimaryKey(instance, key, primaryKey);
    }

    /// Extended attributes: [NewObject]
    pub fn call_update(instance: *runtime.Instance, value: runtime.JSValue) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try IDBCursorImpl.call_update(instance, value);
    }

    /// WebIDL [EnforceRange]: the integer arguments and attribute values
    /// whose conversion takes that branch of ConvertToInt (bit i = argument i;
    /// an attribute setter's value is bit 0).
    pub const enforce_range = .{
        .{ "call_advance", 0b1 },
    };
};
