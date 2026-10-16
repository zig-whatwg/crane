//! Generated from: gamepad.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GamepadImpl = @import("impls").Gamepad;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GamepadHapticActuator = @import("interfaces").GamepadHapticActuator;
const GamepadPose = @import("interfaces").GamepadPose;
const GamepadButton = @import("interfaces").GamepadButton;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const GamepadMappingType = @import("enums").GamepadMappingType;
const GamepadHand = @import("enums").GamepadHand;
const DOMString = @import("typedefs").DOMString;
const GamepadTouch = @import("dictionaries").GamepadTouch;

pub const Gamepad = struct {
    pub const Meta = struct {
        pub const name = "Gamepad";
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
            .{ "id", "get_id", null },
            .{ "index", "get_index", null },
            .{ "connected", "get_connected", null },
            .{ "timestamp", "get_timestamp", null },
            .{ "mapping", "get_mapping", null },
            .{ "axes", "get_axes", null },
            .{ "buttons", "get_buttons", null },
            .{ "touches", "get_touches", null },
            .{ "vibrationActuator", "get_vibrationActuator", null },
            .{ "hand", "get_hand", null },
            .{ "hapticActuators", "get_hapticActuators", null },
            .{ "pose", "get_pose", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "id", "get_id", null },
            .{ "index", "get_index", null },
            .{ "connected", "get_connected", null },
            .{ "timestamp", "get_timestamp", null },
            .{ "mapping", "get_mapping", null },
            .{ "axes", "get_axes", null },
            .{ "buttons", "get_buttons", null },
            .{ "touches", "get_touches", null },
            .{ "vibrationActuator", "get_vibrationActuator", null },
            .{ "hand", "get_hand", null },
            .{ "hapticActuators", "get_hapticActuators", null },
            .{ "pose", "get_pose", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            id: typedefs.DOMString = undefined,
            index: i32 = undefined,
            connected: bool = undefined,
            timestamp: typedefs.DOMHighResTimeStamp = undefined,
            mapping: enums.GamepadMappingType = undefined,
            axes: runtime.JSValue = undefined,
            buttons: runtime.JSValue = undefined,
            touches: runtime.JSValue = undefined,
            vibrationActuator: *runtime.Instance = undefined,
            hand: enums.GamepadHand = undefined,
            hapticActuators: runtime.JSValue = undefined,
            pose: ?*runtime.Instance = null,
            cached_vibrationActuator: ?*runtime.Instance = null,
            _internal: ?*GamepadImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_axes = &get_axes,
        .get_buttons = &get_buttons,
        .get_connected = &get_connected,
        .get_hand = &get_hand,
        .get_hapticActuators = &get_hapticActuators,
        .get_id = &get_id,
        .get_index = &get_index,
        .get_mapping = &get_mapping,
        .get_pose = &get_pose,
        .get_timestamp = &get_timestamp,
        .get_touches = &get_touches,
        .get_vibrationActuator = &get_vibrationActuator,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Gamepad has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(GamepadImpl, "init") and @hasDecl(GamepadImpl, "initOwn")) @compileError("GamepadImpl defines both init and initOwn");
        if (comptime @hasDecl(GamepadImpl, "init")) return GamepadImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GamepadImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GamepadImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GamepadImpl, "init")) return false;
        if (comptime @hasDecl(GamepadImpl, "construction_args")) {
            inline for (GamepadImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(GamepadImpl, "deinit") and @hasDecl(GamepadImpl, "deinitOwn")) @compileError("GamepadImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(GamepadImpl, "deinit")) return GamepadImpl.deinit(instance);
        if (comptime @hasDecl(GamepadImpl, "deinitOwn")) GamepadImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Gamepad")) {
            if (comptime @hasDecl(impls.Gamepad, "installHooks")) impls.Gamepad.installHooks();
        }
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try GamepadImpl.get_id(instance);
    }

    pub fn get_index(instance: *runtime.Instance) anyerror!i32 {
        return try GamepadImpl.get_index(instance);
    }

    pub fn get_connected(instance: *runtime.Instance) anyerror!bool {
        return try GamepadImpl.get_connected(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try GamepadImpl.get_timestamp(instance);
    }

    pub fn get_mapping(instance: *runtime.Instance) anyerror!GamepadMappingType {
        return try GamepadImpl.get_mapping(instance);
    }

    pub fn get_axes(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try GamepadImpl.get_axes(instance);
    }

    pub fn get_buttons(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try GamepadImpl.get_buttons(instance);
    }

    pub fn get_touches(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try GamepadImpl.get_touches(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_vibrationActuator(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_vibrationActuator) |cached| {
            return cached;
        }
        const value = try GamepadImpl.get_vibrationActuator(instance);
        state.own.cached_vibrationActuator = value;
        @import("dom").same_object_cache.made(instance, value, "vibrationActuator");
        return value;
    }

    pub fn get_hand(instance: *runtime.Instance) anyerror!GamepadHand {
        return try GamepadImpl.get_hand(instance);
    }

    pub fn get_hapticActuators(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try GamepadImpl.get_hapticActuators(instance);
    }

    pub fn get_pose(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try GamepadImpl.get_pose(instance);
    }
};
