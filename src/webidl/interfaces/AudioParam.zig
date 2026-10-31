//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioParamImpl = @import("impls").AudioParam;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AutomationRate = @import("enums").AutomationRate;

pub const AudioParam = struct {
    pub const Meta = struct {
        pub const name = "AudioParam";
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
            .{ "value", "get_value", "set_value" },
            .{ "automationRate", "get_automationRate", "set_automationRate" },
            .{ "defaultValue", "get_defaultValue", null },
            .{ "minValue", "get_minValue", null },
            .{ "maxValue", "get_maxValue", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setValueAtTime", "call_setValueAtTime", 2 },
            .{ "linearRampToValueAtTime", "call_linearRampToValueAtTime", 2 },
            .{ "exponentialRampToValueAtTime", "call_exponentialRampToValueAtTime", 2 },
            .{ "setTargetAtTime", "call_setTargetAtTime", 3 },
            .{ "setValueCurveAtTime", "call_setValueCurveAtTime", 3 },
            .{ "cancelScheduledValues", "call_cancelScheduledValues", 1 },
            .{ "cancelAndHoldAtTime", "call_cancelAndHoldAtTime", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setValueAtTime",
            "linearRampToValueAtTime",
            "exponentialRampToValueAtTime",
            "setTargetAtTime",
            "setValueCurveAtTime",
            "cancelScheduledValues",
            "cancelAndHoldAtTime",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "value", "get_value", "set_value" },
            .{ "automationRate", "get_automationRate", "set_automationRate" },
            .{ "defaultValue", "get_defaultValue", null },
            .{ "minValue", "get_minValue", null },
            .{ "maxValue", "get_maxValue", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            value: f32 = undefined,
            automationRate: enums.AutomationRate = undefined,
            defaultValue: f32 = undefined,
            minValue: f32 = undefined,
            maxValue: f32 = undefined,
            _internal: ?*AudioParamImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_automationRate = &get_automationRate,
        .get_defaultValue = &get_defaultValue,
        .get_maxValue = &get_maxValue,
        .get_minValue = &get_minValue,
        .get_value = &get_value,

        .set_automationRate = &set_automationRate,
        .set_value = &set_value,

        .call_cancelAndHoldAtTime = &call_cancelAndHoldAtTime,
        .call_cancelScheduledValues = &call_cancelScheduledValues,
        .call_exponentialRampToValueAtTime = &call_exponentialRampToValueAtTime,
        .call_linearRampToValueAtTime = &call_linearRampToValueAtTime,
        .call_setTargetAtTime = &call_setTargetAtTime,
        .call_setValueAtTime = &call_setValueAtTime,
        .call_setValueCurveAtTime = &call_setValueCurveAtTime,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("AudioParam has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(AudioParamImpl, "init") and @hasDecl(AudioParamImpl, "initOwn")) @compileError("AudioParamImpl defines both init and initOwn");
        if (comptime @hasDecl(AudioParamImpl, "init")) return AudioParamImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(AudioParamImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try AudioParamImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AudioParamImpl, "init")) return false;
        if (comptime @hasDecl(AudioParamImpl, "construction_args")) {
            inline for (AudioParamImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AudioParamImpl, "deinit") and @hasDecl(AudioParamImpl, "deinitOwn")) @compileError("AudioParamImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AudioParamImpl, "deinit")) return AudioParamImpl.deinit(instance);
        if (comptime @hasDecl(AudioParamImpl, "deinitOwn")) AudioParamImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AudioParam")) {
            if (comptime @hasDecl(impls.AudioParam, "installHooks")) impls.AudioParam.installHooks();
        }
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!f32 {
        return try AudioParamImpl.get_value(instance);
    }

    pub fn set_value(instance: *runtime.Instance, value: f32) anyerror!void {
        try AudioParamImpl.set_value(instance, value);
    }

    pub fn get_automationRate(instance: *runtime.Instance) anyerror!AutomationRate {
        return try AudioParamImpl.get_automationRate(instance);
    }

    pub fn set_automationRate(instance: *runtime.Instance, value: AutomationRate) anyerror!void {
        try AudioParamImpl.set_automationRate(instance, value);
    }

    pub fn get_defaultValue(instance: *runtime.Instance) anyerror!f32 {
        return try AudioParamImpl.get_defaultValue(instance);
    }

    pub fn get_minValue(instance: *runtime.Instance) anyerror!f32 {
        return try AudioParamImpl.get_minValue(instance);
    }

    pub fn get_maxValue(instance: *runtime.Instance) anyerror!f32 {
        return try AudioParamImpl.get_maxValue(instance);
    }

    pub fn call_setValueAtTime(instance: *runtime.Instance, value: f32, startTime: f64) anyerror!*runtime.Instance {
        return try AudioParamImpl.call_setValueAtTime(instance, value, startTime);
    }

    pub fn call_setTargetAtTime(instance: *runtime.Instance, target: f32, startTime: f64, timeConstant: f32) anyerror!*runtime.Instance {
        return try AudioParamImpl.call_setTargetAtTime(instance, target, startTime, timeConstant);
    }

    pub fn call_cancelScheduledValues(instance: *runtime.Instance, cancelTime: f64) anyerror!*runtime.Instance {
        return try AudioParamImpl.call_cancelScheduledValues(instance, cancelTime);
    }

    pub fn call_exponentialRampToValueAtTime(instance: *runtime.Instance, value: f32, endTime: f64) anyerror!*runtime.Instance {
        return try AudioParamImpl.call_exponentialRampToValueAtTime(instance, value, endTime);
    }

    pub fn call_cancelAndHoldAtTime(instance: *runtime.Instance, cancelTime: f64) anyerror!*runtime.Instance {
        return try AudioParamImpl.call_cancelAndHoldAtTime(instance, cancelTime);
    }

    pub fn call_linearRampToValueAtTime(instance: *runtime.Instance, value: f32, endTime: f64) anyerror!*runtime.Instance {
        return try AudioParamImpl.call_linearRampToValueAtTime(instance, value, endTime);
    }

    pub fn call_setValueCurveAtTime(instance: *runtime.Instance, values: runtime.JSValue, startTime: f64, duration: f64) anyerror!*runtime.Instance {
        return try AudioParamImpl.call_setValueCurveAtTime(instance, values, startTime, duration);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_value", 0b1 },
        .{ "call_setValueAtTime", 0b11 },
        .{ "call_setTargetAtTime", 0b111 },
        .{ "call_cancelScheduledValues", 0b1 },
        .{ "call_exponentialRampToValueAtTime", 0b11 },
        .{ "call_cancelAndHoldAtTime", 0b1 },
        .{ "call_linearRampToValueAtTime", 0b11 },
        .{ "call_setValueCurveAtTime", 0b111 },
    };
};
