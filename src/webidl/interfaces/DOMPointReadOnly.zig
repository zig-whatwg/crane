//! Generated from: geometry.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DOMPointReadOnlyImpl = @import("impls").DOMPointReadOnly;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMPoint = @import("interfaces").DOMPoint;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const DOMMatrixInit = @import("dictionaries").DOMMatrixInit;

pub const DOMPointReadOnly = struct {
    pub const Meta = struct {
        pub const name = "DOMPointReadOnly";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "z", "get_z", null },
            .{ "w", "get_w", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "matrixTransform", "call_matrixTransform", 0 },
            .{ "toJSON", "call_toJSON", 0 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "fromPoint", "call_static_fromPoint", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "fromPoint",
            "matrixTransform",
            "toJSON",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "z", "get_z", null },
            .{ "w", "get_w", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            x: f64 = undefined,
            y: f64 = undefined,
            z: f64 = undefined,
            w: f64 = undefined,
            _internal: ?*DOMPointReadOnlyImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for DOMPointReadOnly
    /// Generated from [Default] toJSON extended attribute
    pub const DOMPointReadOnlyToJSON = struct {
        x: f64,
        y: f64,
        z: f64,
        w: f64,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_w = &get_w,
        .get_x = &get_x,
        .get_y = &get_y,
        .get_z = &get_z,

        .call_matrixTransform = &call_matrixTransform,
        .call_toJSON = &call_toJSON,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("DOMPointReadOnly has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(DOMPointReadOnlyImpl, "init") and @hasDecl(DOMPointReadOnlyImpl, "initOwn")) @compileError("DOMPointReadOnlyImpl defines both init and initOwn");
        if (comptime @hasDecl(DOMPointReadOnlyImpl, "init")) return DOMPointReadOnlyImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(DOMPointReadOnlyImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try DOMPointReadOnlyImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(DOMPointReadOnlyImpl, "init")) return false;
        if (comptime @hasDecl(DOMPointReadOnlyImpl, "construction_args")) {
            inline for (DOMPointReadOnlyImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(DOMPointReadOnlyImpl, "deinit") and @hasDecl(DOMPointReadOnlyImpl, "deinitOwn")) @compileError("DOMPointReadOnlyImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(DOMPointReadOnlyImpl, "deinit")) return DOMPointReadOnlyImpl.deinit(instance);
        if (comptime @hasDecl(DOMPointReadOnlyImpl, "deinitOwn")) DOMPointReadOnlyImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "DOMPointReadOnly")) {
            if (comptime @hasDecl(impls.DOMPointReadOnly, "installHooks")) impls.DOMPointReadOnly.installHooks();
        }
    }

    // HTML 2.7.1 serializable objects: DOMPointReadOnly is [Serializable].

    /// DOMPointReadOnly's serialization steps, given `value` and `serialized`: its impl's.
    pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) anyerror!void {
        return @import("impls").DOMPointReadOnly.serializationSteps(value, serialized);
    }

    /// DOMPointReadOnly's deserialization steps, given `serialized`, `value` and
    /// `target_realm`: its impl's.
    pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) anyerror!void {
        return @import("impls").DOMPointReadOnly.deserializationSteps(serialized, value, target_realm);
    }

    /// HTML StructuredDeserialize steps 22.3 and 24.4: a new instance of
    /// DOMPointReadOnly, created in `target_realm`, set up by its deserialization steps.
    /// Unwrapped: the engine wraps it in `target_realm`.
    fn deserializeNew(serialized: *runtime.DeserializationRecord, target_realm: runtime.Context) anyerror!*runtime.Instance {
        const value = try init(target_realm.allocator, target_realm);
        const generation = runtime.SlabAllocator.generationOf(value);
        errdefer value.releaseIfUnwrapped(generation);
        try deserializationSteps(serialized, value, target_realm);
        return value;
    }

    /// DOMPointReadOnly's serialization and deserialization steps, as an engine finds
    /// them by interface identifier; null while its impl defines none.
    pub const serializable_steps: ?runtime.SerializableSteps = if (has_serializable_steps) .{
        .serialize = &serializationSteps,
        .deserialize = &deserializeNew,
    } else null;

    const has_serializable_steps = blk: {
        const impls = @import("impls");
        if (!@hasDecl(impls, "DOMPointReadOnly")) break :blk false;
        break :blk @hasDecl(impls.DOMPointReadOnly, "serializationSteps") and @hasDecl(impls.DOMPointReadOnly, "deserializationSteps");
    };

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, x: webidl.Opt(f64), y: webidl.Opt(f64), z: webidl.Opt(f64), w: webidl.Opt(f64)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DOMPointReadOnlyImpl.call_constructor(ctx, x, y, z, w);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointReadOnlyImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointReadOnlyImpl.get_y(instance);
    }

    pub fn get_z(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointReadOnlyImpl.get_z(instance);
    }

    pub fn get_w(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointReadOnlyImpl.get_w(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_fromPoint(instance: *runtime.Instance, other: webidl.Opt(DOMPointInit)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try DOMPointReadOnlyImpl.call_static_fromPoint(instance, other);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!DOMPointReadOnlyToJSON {
        return try DOMPointReadOnlyImpl.call_toJSON(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_matrixTransform(instance: *runtime.Instance, matrix: webidl.Opt(DOMMatrixInit)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try DOMPointReadOnlyImpl.call_matrixTransform(instance, matrix);
    }
};
