//! Generated from: webxr.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRRigidTransformImpl = @import("impls").XRRigidTransform;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMPointInit = @import("dictionaries").DOMPointInit;
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;

pub const XRRigidTransform = struct {
    pub const Meta = struct {
        pub const name = "XRRigidTransform";
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
            .{ "position", "get_position", null },
            .{ "orientation", "get_orientation", null },
            .{ "matrix", "get_matrix", null },
            .{ "inverse", "get_inverse", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "position", "get_position", null },
            .{ "orientation", "get_orientation", null },
            .{ "matrix", "get_matrix", null },
            .{ "inverse", "get_inverse", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            position: *runtime.Instance = undefined,
            orientation: *runtime.Instance = undefined,
            matrix: runtime.Float32Array = undefined,
            inverse: *runtime.Instance = undefined,
            cached_position: ?*runtime.Instance = null,
            cached_orientation: ?*runtime.Instance = null,
            cached_inverse: ?*runtime.Instance = null,
            _internal: ?*XRRigidTransformImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_inverse = &get_inverse,
        .get_matrix = &get_matrix,
        .get_orientation = &get_orientation,
        .get_position = &get_position,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XRRigidTransform has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XRRigidTransformImpl, "init") and @hasDecl(XRRigidTransformImpl, "initOwn")) @compileError("XRRigidTransformImpl defines both init and initOwn");
        if (comptime @hasDecl(XRRigidTransformImpl, "init")) return XRRigidTransformImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(XRRigidTransformImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try XRRigidTransformImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRRigidTransformImpl, "init")) return false;
        if (comptime @hasDecl(XRRigidTransformImpl, "construction_args")) {
            inline for (XRRigidTransformImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRRigidTransformImpl, "deinit") and @hasDecl(XRRigidTransformImpl, "deinitOwn")) @compileError("XRRigidTransformImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(XRRigidTransformImpl, "deinit")) return XRRigidTransformImpl.deinit(instance);
        if (comptime @hasDecl(XRRigidTransformImpl, "deinitOwn")) XRRigidTransformImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRRigidTransform")) {
            if (comptime @hasDecl(impls.XRRigidTransform, "installHooks")) impls.XRRigidTransform.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, position: webidl.Opt(DOMPointInit), orientation: webidl.Opt(DOMPointInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XRRigidTransformImpl.call_constructor(ctx, position, orientation);
    }

    /// Extended attributes: [SameObject]
    pub fn get_position(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_position) |cached| {
            return cached;
        }
        const value = try XRRigidTransformImpl.get_position(instance);
        state.own.cached_position = value;
        @import("dom").same_object_cache.made(instance, value, "position");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_orientation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_orientation) |cached| {
            return cached;
        }
        const value = try XRRigidTransformImpl.get_orientation(instance);
        state.own.cached_orientation = value;
        @import("dom").same_object_cache.made(instance, value, "orientation");
        return value;
    }

    pub fn get_matrix(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try XRRigidTransformImpl.get_matrix(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_inverse(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_inverse) |cached| {
            return cached;
        }
        const value = try XRRigidTransformImpl.get_inverse(instance);
        state.own.cached_inverse = value;
        @import("dom").same_object_cache.made(instance, value, "inverse");
        return value;
    }
};
