//! Generated from: webidl.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const QuotaExceededErrorImpl = @import("impls").QuotaExceededError;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMException = @import("interfaces").DOMException;
const QuotaExceededErrorOptions = @import("dictionaries").QuotaExceededErrorOptions;
const DOMString = @import("typedefs").DOMString;

pub const QuotaExceededError = struct {
    pub const Meta = struct {
        pub const name = "QuotaExceededError";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = DOMException.State;
        pub const ParentInterface = DOMException;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
            .{ .name = "Serializable" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "quota", "get_quota", null },
            .{ "requested", "get_requested", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "quota", "get_quota", null },
            .{ "requested", "get_requested", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            quota: ?f64 = null,
            requested: ?f64 = null,
            _internal: ?*QuotaExceededErrorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_quota = &get_quota,
        .get_requested = &get_requested,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("QuotaExceededError has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(QuotaExceededErrorImpl, "init") and @hasDecl(QuotaExceededErrorImpl, "initOwn")) @compileError("QuotaExceededErrorImpl defines both init and initOwn");
        if (comptime @hasDecl(QuotaExceededErrorImpl, "init")) return QuotaExceededErrorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(QuotaExceededErrorImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try QuotaExceededErrorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(QuotaExceededErrorImpl, "init")) return false;
        if (comptime @hasDecl(QuotaExceededErrorImpl, "construction_args")) {
            inline for (QuotaExceededErrorImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(QuotaExceededErrorImpl, "deinit") and @hasDecl(QuotaExceededErrorImpl, "deinitOwn")) @compileError("QuotaExceededErrorImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(QuotaExceededErrorImpl, "deinit")) return QuotaExceededErrorImpl.deinit(instance);
        if (comptime @hasDecl(QuotaExceededErrorImpl, "deinitOwn")) QuotaExceededErrorImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "QuotaExceededError")) {
            if (comptime @hasDecl(impls.QuotaExceededError, "installHooks")) impls.QuotaExceededError.installHooks();
        }
    }

    // HTML 2.7.1 serializable objects: QuotaExceededError is [Serializable].

    /// QuotaExceededError's serialization steps, given `value` and `serialized`: its impl's.
    pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) anyerror!void {
        return @import("impls").QuotaExceededError.serializationSteps(value, serialized);
    }

    /// QuotaExceededError's deserialization steps, given `serialized`, `value` and
    /// `target_realm`: its impl's.
    pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) anyerror!void {
        return @import("impls").QuotaExceededError.deserializationSteps(serialized, value, target_realm);
    }

    /// HTML StructuredDeserialize steps 22.3 and 24.4: a new instance of
    /// QuotaExceededError, created in `target_realm`, set up by its deserialization steps.
    /// Unwrapped: the engine wraps it in `target_realm`.
    fn deserializeNew(serialized: *runtime.DeserializationRecord, target_realm: runtime.Context) anyerror!*runtime.Instance {
        const value = try init(target_realm.allocator, target_realm);
        const generation = runtime.SlabAllocator.generationOf(value);
        errdefer value.releaseIfUnwrapped(generation);
        try deserializationSteps(serialized, value, target_realm);
        return value;
    }

    /// QuotaExceededError's serialization and deserialization steps, as an engine finds
    /// them by interface identifier; null while its impl defines none.
    pub const serializable_steps: ?runtime.SerializableSteps = if (has_serializable_steps) .{
        .serialize = &serializationSteps,
        .deserialize = &deserializeNew,
    } else null;

    const has_serializable_steps = blk: {
        const impls = @import("impls");
        if (!@hasDecl(impls, "QuotaExceededError")) break :blk false;
        break :blk @hasDecl(impls.QuotaExceededError, "serializationSteps") and @hasDecl(impls.QuotaExceededError, "deserializationSteps");
    };

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, message: webidl.Opt(runtime.DOMString), options: webidl.Opt(QuotaExceededErrorOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try QuotaExceededErrorImpl.call_constructor(ctx, message, options);
    }

    pub fn get_quota(instance: *runtime.Instance) anyerror!?f64 {
        return try QuotaExceededErrorImpl.get_quota(instance);
    }

    pub fn get_requested(instance: *runtime.Instance) anyerror!?f64 {
        return try QuotaExceededErrorImpl.get_requested(instance);
    }
};
