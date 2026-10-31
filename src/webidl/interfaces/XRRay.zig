//! Generated from: webxr-hit-test.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRRayImpl = @import("impls").XRRay;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMPointInit = @import("dictionaries").DOMPointInit;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const XRRayDirectionInit = @import("dictionaries").XRRayDirectionInit;
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;

pub const XRRay = struct {
    pub const Meta = struct {
        pub const name = "XRRay";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "origin", "get_origin", null },
            .{ "direction", "get_direction", null },
            .{ "matrix", "get_matrix", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "origin", "get_origin", null },
            .{ "direction", "get_direction", null },
            .{ "matrix", "get_matrix", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            origin: *runtime.Instance = undefined,
            direction: *runtime.Instance = undefined,
            matrix: runtime.Float32Array = undefined,
            cached_origin: ?*runtime.Instance = null,
            cached_direction: ?*runtime.Instance = null,
            cached_matrix: ?runtime.JSValue = null,
            _internal: ?*XRRayImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_direction = &get_direction,
        .get_matrix = &get_matrix,
        .get_origin = &get_origin,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("XRRay has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(XRRayImpl, "init") and @hasDecl(XRRayImpl, "initOwn")) @compileError("XRRayImpl defines both init and initOwn");
        if (comptime @hasDecl(XRRayImpl, "init")) return XRRayImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(XRRayImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try XRRayImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRRayImpl, "init")) return false;
        if (comptime @hasDecl(XRRayImpl, "construction_args")) {
            inline for (XRRayImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRRayImpl, "deinit") and @hasDecl(XRRayImpl, "deinitOwn")) @compileError("XRRayImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(XRRayImpl, "deinit")) return XRRayImpl.deinit(instance);
        if (comptime @hasDecl(XRRayImpl, "deinitOwn")) XRRayImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRRay")) {
            if (comptime @hasDecl(impls.XRRay, "installHooks")) impls.XRRay.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor(origin, direction)
        DOMPointInit_XRRayDirectionInit: struct {
            origin: webidl.Opt(DOMPointInit),
            direction: webidl.Opt(XRRayDirectionInit),
        },
        /// constructor(transform)
        XRRigidTransform: *runtime.Instance,
    };

    /// WebIDL overload set of the constructor: one entry per variant of
    /// ConstructorArgs, in its order, for the overload resolution algorithm
    /// (webidl.overload_resolution) the binding runs to pick the variant.
    pub const constructor_overloads = &[_]webidl.overload_resolution.Overload{
        .{ .function = "DOMPointInit_XRRayDirectionInit", .args = &.{ .{ .kinds = &.{.dictionary}, .optionality = .optional }, .{ .kinds = &.{.dictionary}, .optionality = .optional } } },
        .{ .function = "XRRigidTransform", .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "XRRigidTransform")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").XRRigidTransform.State) } else .other)} }} },
    };

    /// WebIDL constructor (overloaded)
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try XRRayImpl.call_constructor(ctx, args);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "XRRigidTransform", 0, "XRRigidTransform" },
    };

    /// Extended attributes: [SameObject]
    pub fn get_origin(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_origin) |cached| {
            return cached;
        }
        const value = try XRRayImpl.get_origin(instance);
        state.own.cached_origin = value;
        @import("dom").same_object_cache.made(instance, value, "origin");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_direction(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_direction) |cached| {
            return cached;
        }
        const value = try XRRayImpl.get_direction(instance);
        state.own.cached_direction = value;
        @import("dom").same_object_cache.made(instance, value, "direction");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_matrix(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try XRRayImpl.get_matrix(instance);
    }
};
