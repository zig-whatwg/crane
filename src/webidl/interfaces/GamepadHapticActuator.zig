//! Generated from: gamepad.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GamepadHapticActuatorImpl = @import("impls").GamepadHapticActuator;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GamepadHapticEffectType = @import("enums").GamepadHapticEffectType;
const GamepadHapticsResult = @import("enums").GamepadHapticsResult;
const GamepadEffectParameters = @import("dictionaries").GamepadEffectParameters;

pub const GamepadHapticActuator = struct {
    pub const Meta = struct {
        pub const name = "GamepadHapticActuator";
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
            .{ "effects", "get_effects", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "playEffect", "call_playEffect", 1 },
            .{ "reset", "call_reset", 0 },
            .{ "pulse", "call_pulse", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "playEffect",
            "reset",
            "pulse",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "effects", "get_effects", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            effects: runtime.JSValue = undefined,
            cached_effects: ?runtime.JSValue = null,
            _internal: ?*GamepadHapticActuatorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_effects = &get_effects,

        .call_playEffect = &call_playEffect,
        .call_pulse = &call_pulse,
        .call_reset = &call_reset,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("GamepadHapticActuator has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(GamepadHapticActuatorImpl, "init") and @hasDecl(GamepadHapticActuatorImpl, "initOwn")) @compileError("GamepadHapticActuatorImpl defines both init and initOwn");
        if (comptime @hasDecl(GamepadHapticActuatorImpl, "init")) return GamepadHapticActuatorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GamepadHapticActuatorImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GamepadHapticActuatorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GamepadHapticActuatorImpl, "init")) return false;
        if (comptime @hasDecl(GamepadHapticActuatorImpl, "construction_args")) {
            inline for (GamepadHapticActuatorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(GamepadHapticActuatorImpl, "deinit") and @hasDecl(GamepadHapticActuatorImpl, "deinitOwn")) @compileError("GamepadHapticActuatorImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(GamepadHapticActuatorImpl, "deinit")) return GamepadHapticActuatorImpl.deinit(instance);
        if (comptime @hasDecl(GamepadHapticActuatorImpl, "deinitOwn")) GamepadHapticActuatorImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GamepadHapticActuator")) {
            if (comptime @hasDecl(impls.GamepadHapticActuator, "installHooks")) impls.GamepadHapticActuator.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_effects(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try GamepadHapticActuatorImpl.get_effects(instance);
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try GamepadHapticActuatorImpl.call_reset(instance);
    }

    pub fn call_playEffect(instance: *runtime.Instance, @"type": GamepadHapticEffectType, params: webidl.Opt(GamepadEffectParameters)) anyerror!runtime.JSValue {
        return try GamepadHapticActuatorImpl.call_playEffect(instance, @"type", params);
    }

    pub fn call_pulse(instance: *runtime.Instance, value: f64, duration: f64) anyerror!runtime.JSValue {
        return try GamepadHapticActuatorImpl.call_pulse(instance, value, duration);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "call_pulse", 0b11 },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_reset",
        "call_playEffect",
        "call_pulse",
    };
};
