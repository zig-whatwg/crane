//! Generated from: IndexedDB.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IDBRecordImpl = @import("impls").IDBRecord;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const IDBRecord = struct {
    pub const Meta = struct {
        pub const name = "IDBRecord";
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
            .{ "key", "get_key", null },
            .{ "primaryKey", "get_primaryKey", null },
            .{ "value", "get_value", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "key", "get_key", null },
            .{ "primaryKey", "get_primaryKey", null },
            .{ "value", "get_value", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            key: runtime.JSValue = undefined,
            primaryKey: runtime.JSValue = undefined,
            value: runtime.JSValue = undefined,
            _internal: ?*IDBRecordImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_key = &get_key,
        .get_primaryKey = &get_primaryKey,
        .get_value = &get_value,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("IDBRecord has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(IDBRecordImpl, "init") and @hasDecl(IDBRecordImpl, "initOwn")) @compileError("IDBRecordImpl defines both init and initOwn");
        if (comptime @hasDecl(IDBRecordImpl, "init")) return IDBRecordImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(IDBRecordImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try IDBRecordImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(IDBRecordImpl, "init")) return false;
        if (comptime @hasDecl(IDBRecordImpl, "construction_args")) {
            inline for (IDBRecordImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(IDBRecordImpl, "deinit") and @hasDecl(IDBRecordImpl, "deinitOwn")) @compileError("IDBRecordImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(IDBRecordImpl, "deinit")) return IDBRecordImpl.deinit(instance);
        if (comptime @hasDecl(IDBRecordImpl, "deinitOwn")) IDBRecordImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "IDBRecord")) {
            if (comptime @hasDecl(impls.IDBRecord, "installHooks")) impls.IDBRecord.installHooks();
        }
    }

    pub fn get_key(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IDBRecordImpl.get_key(instance);
    }

    pub fn get_primaryKey(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IDBRecordImpl.get_primaryKey(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IDBRecordImpl.get_value(instance);
    }
};
