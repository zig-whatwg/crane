//! Generated from: IndexedDB.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IDBKeyRangeImpl = @import("impls").IDBKeyRange;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const IDBKeyRange = struct {
    pub const Meta = struct {
        pub const name = "IDBKeyRange";
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
            .{ "lower", "get_lower", null },
            .{ "upper", "get_upper", null },
            .{ "lowerOpen", "get_lowerOpen", null },
            .{ "upperOpen", "get_upperOpen", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "includes", "call_includes", 1 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "only", "call_static_only", 1 },
            .{ "lowerBound", "call_static_lowerBound", 1 },
            .{ "upperBound", "call_static_upperBound", 1 },
            .{ "bound", "call_static_bound", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "only",
            "lowerBound",
            "upperBound",
            "bound",
            "includes",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "lower", "get_lower", null },
            .{ "upper", "get_upper", null },
            .{ "lowerOpen", "get_lowerOpen", null },
            .{ "upperOpen", "get_upperOpen", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            lower: runtime.JSValue = undefined,
            upper: runtime.JSValue = undefined,
            lowerOpen: bool = undefined,
            upperOpen: bool = undefined,
            _internal: ?*IDBKeyRangeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_lower = &get_lower,
        .get_lowerOpen = &get_lowerOpen,
        .get_upper = &get_upper,
        .get_upperOpen = &get_upperOpen,

        .call_includes = &call_includes,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("IDBKeyRange has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(IDBKeyRangeImpl, "init") and @hasDecl(IDBKeyRangeImpl, "initOwn")) @compileError("IDBKeyRangeImpl defines both init and initOwn");
        if (comptime @hasDecl(IDBKeyRangeImpl, "init")) return IDBKeyRangeImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(IDBKeyRangeImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try IDBKeyRangeImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(IDBKeyRangeImpl, "init")) return false;
        if (comptime @hasDecl(IDBKeyRangeImpl, "construction_args")) {
            inline for (IDBKeyRangeImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(IDBKeyRangeImpl, "deinit") and @hasDecl(IDBKeyRangeImpl, "deinitOwn")) @compileError("IDBKeyRangeImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(IDBKeyRangeImpl, "deinit")) return IDBKeyRangeImpl.deinit(instance);
        if (comptime @hasDecl(IDBKeyRangeImpl, "deinitOwn")) IDBKeyRangeImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "IDBKeyRange")) {
            if (comptime @hasDecl(impls.IDBKeyRange, "installHooks")) impls.IDBKeyRange.installHooks();
        }
    }

    pub fn get_lower(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IDBKeyRangeImpl.get_lower(instance);
    }

    pub fn get_upper(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IDBKeyRangeImpl.get_upper(instance);
    }

    pub fn get_lowerOpen(instance: *runtime.Instance) anyerror!bool {
        return try IDBKeyRangeImpl.get_lowerOpen(instance);
    }

    pub fn get_upperOpen(instance: *runtime.Instance) anyerror!bool {
        return try IDBKeyRangeImpl.get_upperOpen(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_only(instance: *runtime.Instance, value: runtime.JSValue) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try IDBKeyRangeImpl.call_static_only(instance, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_lowerBound(instance: *runtime.Instance, lower: runtime.JSValue, open: webidl.Opt(bool)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try IDBKeyRangeImpl.call_static_lowerBound(instance, lower, open);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_upperBound(instance: *runtime.Instance, upper: runtime.JSValue, open: webidl.Opt(bool)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try IDBKeyRangeImpl.call_static_upperBound(instance, upper, open);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_bound(instance: *runtime.Instance, lower: runtime.JSValue, upper: runtime.JSValue, lowerOpen: webidl.Opt(bool), upperOpen: webidl.Opt(bool)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try IDBKeyRangeImpl.call_static_bound(instance, lower, upper, lowerOpen, upperOpen);
    }

    pub fn call_includes(instance: *runtime.Instance, key: runtime.JSValue) anyerror!bool {
        return try IDBKeyRangeImpl.call_includes(instance, key);
    }
};
