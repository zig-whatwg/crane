//! Generated from: wasm-js-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TableImpl = @import("impls").Table;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AddressValue = @import("typedefs").AddressValue;
const TableDescriptor = @import("dictionaries").TableDescriptor;

pub const Table = struct {
    pub const Meta = struct {
        pub const name = "Table";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "LegacyNamespace", .value = .{ .identifier = "WebAssembly" } },
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "grow", "call_grow", 1 },
            .{ "get", "call_get", 1 },
            .{ "set", "call_set", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "grow",
            "get",
            "set",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: typedefs.AddressValue = undefined,
            _internal: ?*TableImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,

        .call_get = &call_get,
        .call_grow = &call_grow,
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
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("Table has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(TableImpl, "init") and @hasDecl(TableImpl, "initOwn")) @compileError("TableImpl defines both init and initOwn");
        if (comptime @hasDecl(TableImpl, "init")) return TableImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(TableImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try TableImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(TableImpl, "init")) return false;
        if (comptime @hasDecl(TableImpl, "construction_args")) {
            inline for (TableImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(TableImpl, "deinit") and @hasDecl(TableImpl, "deinitOwn")) @compileError("TableImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(TableImpl, "deinit")) return TableImpl.deinit(instance);
        if (comptime @hasDecl(TableImpl, "deinitOwn")) TableImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Table")) {
            if (comptime @hasDecl(impls.Table, "installHooks")) impls.Table.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, descriptor: TableDescriptor, value: webidl.Opt(runtime.JSValue)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TableImpl.call_constructor(ctx, descriptor, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!AddressValue {
        return try TableImpl.get_length(instance);
    }

    pub fn call_set(instance: *runtime.Instance, index: AddressValue, value: webidl.Opt(runtime.JSValue)) anyerror!void {
        return try TableImpl.call_set(instance, index, value);
    }

    pub fn call_get(instance: *runtime.Instance, index: AddressValue) anyerror!runtime.JSValue {
        return try TableImpl.call_get(instance, index);
    }

    pub fn call_grow(instance: *runtime.Instance, delta: AddressValue, value: webidl.Opt(runtime.JSValue)) anyerror!AddressValue {
        return try TableImpl.call_grow(instance, delta, value);
    }
};
