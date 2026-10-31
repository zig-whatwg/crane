//! Generated from: gamepad-extensions.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GamepadPoseImpl = @import("impls").GamepadPose;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const GamepadPose = struct {
    pub const Meta = struct {
        pub const name = "GamepadPose";
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
            .{ "hasOrientation", "get_hasOrientation", null },
            .{ "hasPosition", "get_hasPosition", null },
            .{ "position", "get_position", null },
            .{ "linearVelocity", "get_linearVelocity", null },
            .{ "linearAcceleration", "get_linearAcceleration", null },
            .{ "orientation", "get_orientation", null },
            .{ "angularVelocity", "get_angularVelocity", null },
            .{ "angularAcceleration", "get_angularAcceleration", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "hasOrientation", "get_hasOrientation", null },
            .{ "hasPosition", "get_hasPosition", null },
            .{ "position", "get_position", null },
            .{ "linearVelocity", "get_linearVelocity", null },
            .{ "linearAcceleration", "get_linearAcceleration", null },
            .{ "orientation", "get_orientation", null },
            .{ "angularVelocity", "get_angularVelocity", null },
            .{ "angularAcceleration", "get_angularAcceleration", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            hasOrientation: bool = undefined,
            hasPosition: bool = undefined,
            position: ?runtime.Float32Array = null,
            linearVelocity: ?runtime.Float32Array = null,
            linearAcceleration: ?runtime.Float32Array = null,
            orientation: ?runtime.Float32Array = null,
            angularVelocity: ?runtime.Float32Array = null,
            angularAcceleration: ?runtime.Float32Array = null,
            _internal: ?*GamepadPoseImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_angularAcceleration = &get_angularAcceleration,
        .get_angularVelocity = &get_angularVelocity,
        .get_hasOrientation = &get_hasOrientation,
        .get_hasPosition = &get_hasPosition,
        .get_linearAcceleration = &get_linearAcceleration,
        .get_linearVelocity = &get_linearVelocity,
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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("GamepadPose has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(GamepadPoseImpl, "init") and @hasDecl(GamepadPoseImpl, "initOwn")) @compileError("GamepadPoseImpl defines both init and initOwn");
        if (comptime @hasDecl(GamepadPoseImpl, "init")) return GamepadPoseImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GamepadPoseImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GamepadPoseImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GamepadPoseImpl, "init")) return false;
        if (comptime @hasDecl(GamepadPoseImpl, "construction_args")) {
            inline for (GamepadPoseImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(GamepadPoseImpl, "deinit") and @hasDecl(GamepadPoseImpl, "deinitOwn")) @compileError("GamepadPoseImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(GamepadPoseImpl, "deinit")) return GamepadPoseImpl.deinit(instance);
        if (comptime @hasDecl(GamepadPoseImpl, "deinitOwn")) GamepadPoseImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GamepadPose")) {
            if (comptime @hasDecl(impls.GamepadPose, "installHooks")) impls.GamepadPose.installHooks();
        }
    }

    pub fn get_hasOrientation(instance: *runtime.Instance) anyerror!bool {
        return try GamepadPoseImpl.get_hasOrientation(instance);
    }

    pub fn get_hasPosition(instance: *runtime.Instance) anyerror!bool {
        return try GamepadPoseImpl.get_hasPosition(instance);
    }

    pub fn get_position(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try GamepadPoseImpl.get_position(instance);
    }

    pub fn get_linearVelocity(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try GamepadPoseImpl.get_linearVelocity(instance);
    }

    pub fn get_linearAcceleration(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try GamepadPoseImpl.get_linearAcceleration(instance);
    }

    pub fn get_orientation(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try GamepadPoseImpl.get_orientation(instance);
    }

    pub fn get_angularVelocity(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try GamepadPoseImpl.get_angularVelocity(instance);
    }

    pub fn get_angularAcceleration(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try GamepadPoseImpl.get_angularAcceleration(instance);
    }
};
