//! Generated from: IndexedDB.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IDBFactoryImpl = @import("impls").IDBFactory;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const IDBOpenDBRequest = @import("interfaces").IDBOpenDBRequest;
const DOMString = @import("typedefs").DOMString;

pub const IDBFactory = struct {
    pub const Meta = struct {
        pub const name = "IDBFactory";
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
            .{ "open", "call_open", 1 },
            .{ "deleteDatabase", "call_deleteDatabase", 1 },
            .{ "databases", "call_databases", 0 },
            .{ "cmp", "call_cmp", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "open",
            "deleteDatabase",
            "databases",
            "cmp",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*IDBFactoryImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_cmp = &call_cmp,
        .call_databases = &call_databases,
        .call_deleteDatabase = &call_deleteDatabase,
        .call_open = &call_open,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("IDBFactory has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(IDBFactoryImpl, "init") and @hasDecl(IDBFactoryImpl, "initOwn")) @compileError("IDBFactoryImpl defines both init and initOwn");
        if (comptime @hasDecl(IDBFactoryImpl, "init")) return IDBFactoryImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(IDBFactoryImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try IDBFactoryImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(IDBFactoryImpl, "init")) return false;
        if (comptime @hasDecl(IDBFactoryImpl, "construction_args")) {
            inline for (IDBFactoryImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(IDBFactoryImpl, "deinit") and @hasDecl(IDBFactoryImpl, "deinitOwn")) @compileError("IDBFactoryImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(IDBFactoryImpl, "deinit")) return IDBFactoryImpl.deinit(instance);
        if (comptime @hasDecl(IDBFactoryImpl, "deinitOwn")) IDBFactoryImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "IDBFactory")) {
            if (comptime @hasDecl(impls.IDBFactory, "installHooks")) impls.IDBFactory.installHooks();
        }
    }

    /// Extended attributes: [NewObject]
    pub fn call_deleteDatabase(instance: *runtime.Instance, name: runtime.DOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try IDBFactoryImpl.call_deleteDatabase(instance, name);
    }

    pub fn call_databases(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IDBFactoryImpl.call_databases(instance);
    }

    pub fn call_cmp(instance: *runtime.Instance, first: runtime.JSValue, second: runtime.JSValue) anyerror!i16 {
        return try IDBFactoryImpl.call_cmp(instance, first, second);
    }

    /// Extended attributes: [NewObject]
    pub fn call_open(instance: *runtime.Instance, name: runtime.DOMString, version: webidl.Opt(u64)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try IDBFactoryImpl.call_open(instance, name, version);
    }

    /// WebIDL [EnforceRange]: the integer arguments and attribute values
    /// whose conversion takes that branch of ConvertToInt (bit i = argument i;
    /// an attribute setter's value is bit 0).
    pub const enforce_range = .{
        .{ "call_open", 0b10 },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_databases",
    };
};
