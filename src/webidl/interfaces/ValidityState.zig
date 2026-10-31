//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ValidityStateImpl = @import("impls").ValidityState;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const ValidityState = struct {
    pub const Meta = struct {
        pub const name = "ValidityState";
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
            .{ "valueMissing", "get_valueMissing", null },
            .{ "typeMismatch", "get_typeMismatch", null },
            .{ "patternMismatch", "get_patternMismatch", null },
            .{ "tooLong", "get_tooLong", null },
            .{ "tooShort", "get_tooShort", null },
            .{ "rangeUnderflow", "get_rangeUnderflow", null },
            .{ "rangeOverflow", "get_rangeOverflow", null },
            .{ "stepMismatch", "get_stepMismatch", null },
            .{ "badInput", "get_badInput", null },
            .{ "customError", "get_customError", null },
            .{ "valid", "get_valid", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "valueMissing", "get_valueMissing", null },
            .{ "typeMismatch", "get_typeMismatch", null },
            .{ "patternMismatch", "get_patternMismatch", null },
            .{ "tooLong", "get_tooLong", null },
            .{ "tooShort", "get_tooShort", null },
            .{ "rangeUnderflow", "get_rangeUnderflow", null },
            .{ "rangeOverflow", "get_rangeOverflow", null },
            .{ "stepMismatch", "get_stepMismatch", null },
            .{ "badInput", "get_badInput", null },
            .{ "customError", "get_customError", null },
            .{ "valid", "get_valid", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            valueMissing: bool = undefined,
            typeMismatch: bool = undefined,
            patternMismatch: bool = undefined,
            tooLong: bool = undefined,
            tooShort: bool = undefined,
            rangeUnderflow: bool = undefined,
            rangeOverflow: bool = undefined,
            stepMismatch: bool = undefined,
            badInput: bool = undefined,
            customError: bool = undefined,
            valid: bool = undefined,
            _internal: ?*ValidityStateImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_badInput = &get_badInput,
        .get_customError = &get_customError,
        .get_patternMismatch = &get_patternMismatch,
        .get_rangeOverflow = &get_rangeOverflow,
        .get_rangeUnderflow = &get_rangeUnderflow,
        .get_stepMismatch = &get_stepMismatch,
        .get_tooLong = &get_tooLong,
        .get_tooShort = &get_tooShort,
        .get_typeMismatch = &get_typeMismatch,
        .get_valid = &get_valid,
        .get_valueMissing = &get_valueMissing,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("ValidityState has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(ValidityStateImpl, "init") and @hasDecl(ValidityStateImpl, "initOwn")) @compileError("ValidityStateImpl defines both init and initOwn");
        if (comptime @hasDecl(ValidityStateImpl, "init")) return ValidityStateImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ValidityStateImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ValidityStateImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ValidityStateImpl, "init")) return false;
        if (comptime @hasDecl(ValidityStateImpl, "construction_args")) {
            inline for (ValidityStateImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ValidityStateImpl, "deinit") and @hasDecl(ValidityStateImpl, "deinitOwn")) @compileError("ValidityStateImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ValidityStateImpl, "deinit")) return ValidityStateImpl.deinit(instance);
        if (comptime @hasDecl(ValidityStateImpl, "deinitOwn")) ValidityStateImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ValidityState")) {
            if (comptime @hasDecl(impls.ValidityState, "installHooks")) impls.ValidityState.installHooks();
        }
    }

    pub fn get_valueMissing(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_valueMissing(instance);
    }

    pub fn get_typeMismatch(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_typeMismatch(instance);
    }

    pub fn get_patternMismatch(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_patternMismatch(instance);
    }

    pub fn get_tooLong(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_tooLong(instance);
    }

    pub fn get_tooShort(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_tooShort(instance);
    }

    pub fn get_rangeUnderflow(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_rangeUnderflow(instance);
    }

    pub fn get_rangeOverflow(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_rangeOverflow(instance);
    }

    pub fn get_stepMismatch(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_stepMismatch(instance);
    }

    pub fn get_badInput(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_badInput(instance);
    }

    pub fn get_customError(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_customError(instance);
    }

    pub fn get_valid(instance: *runtime.Instance) anyerror!bool {
        return try ValidityStateImpl.get_valid(instance);
    }
};
