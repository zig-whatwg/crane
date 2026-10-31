//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PannerNodeImpl = @import("impls").PannerNode;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AudioNode = @import("interfaces").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DistanceModelType = @import("enums").DistanceModelType;
const ChannelCountMode = @import("enums").ChannelCountMode;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AudioParam = @import("interfaces").AudioParam;
const PanningModelType = @import("enums").PanningModelType;
const PannerOptions = @import("dictionaries").PannerOptions;
const EventListener = @import("interfaces").EventListener;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const DOMString = @import("typedefs").DOMString;

pub const PannerNode = struct {
    pub const Meta = struct {
        pub const name = "PannerNode";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = AudioNode.State;
        pub const ParentInterface = AudioNode;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "panningModel", "get_panningModel", "set_panningModel" },
            .{ "positionX", "get_positionX", null },
            .{ "positionY", "get_positionY", null },
            .{ "positionZ", "get_positionZ", null },
            .{ "orientationX", "get_orientationX", null },
            .{ "orientationY", "get_orientationY", null },
            .{ "orientationZ", "get_orientationZ", null },
            .{ "distanceModel", "get_distanceModel", "set_distanceModel" },
            .{ "refDistance", "get_refDistance", "set_refDistance" },
            .{ "maxDistance", "get_maxDistance", "set_maxDistance" },
            .{ "rolloffFactor", "get_rolloffFactor", "set_rolloffFactor" },
            .{ "coneInnerAngle", "get_coneInnerAngle", "set_coneInnerAngle" },
            .{ "coneOuterAngle", "get_coneOuterAngle", "set_coneOuterAngle" },
            .{ "coneOuterGain", "get_coneOuterGain", "set_coneOuterGain" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setPosition", "call_setPosition", 3 },
            .{ "setOrientation", "call_setOrientation", 3 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setPosition",
            "setOrientation",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "connect",
            "connect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "panningModel", "get_panningModel", "set_panningModel" },
            .{ "positionX", "get_positionX", null },
            .{ "positionY", "get_positionY", null },
            .{ "positionZ", "get_positionZ", null },
            .{ "orientationX", "get_orientationX", null },
            .{ "orientationY", "get_orientationY", null },
            .{ "orientationZ", "get_orientationZ", null },
            .{ "distanceModel", "get_distanceModel", "set_distanceModel" },
            .{ "refDistance", "get_refDistance", "set_refDistance" },
            .{ "maxDistance", "get_maxDistance", "set_maxDistance" },
            .{ "rolloffFactor", "get_rolloffFactor", "set_rolloffFactor" },
            .{ "coneInnerAngle", "get_coneInnerAngle", "set_coneInnerAngle" },
            .{ "coneOuterAngle", "get_coneOuterAngle", "set_coneOuterAngle" },
            .{ "coneOuterGain", "get_coneOuterGain", "set_coneOuterGain" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            panningModel: enums.PanningModelType = undefined,
            positionX: *runtime.Instance = undefined,
            positionY: *runtime.Instance = undefined,
            positionZ: *runtime.Instance = undefined,
            orientationX: *runtime.Instance = undefined,
            orientationY: *runtime.Instance = undefined,
            orientationZ: *runtime.Instance = undefined,
            distanceModel: enums.DistanceModelType = undefined,
            refDistance: f64 = undefined,
            maxDistance: f64 = undefined,
            rolloffFactor: f64 = undefined,
            coneInnerAngle: f64 = undefined,
            coneOuterAngle: f64 = undefined,
            coneOuterGain: f64 = undefined,
            _internal: ?*PannerNodeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_coneInnerAngle = &get_coneInnerAngle,
        .get_coneOuterAngle = &get_coneOuterAngle,
        .get_coneOuterGain = &get_coneOuterGain,
        .get_distanceModel = &get_distanceModel,
        .get_maxDistance = &get_maxDistance,
        .get_orientationX = &get_orientationX,
        .get_orientationY = &get_orientationY,
        .get_orientationZ = &get_orientationZ,
        .get_panningModel = &get_panningModel,
        .get_positionX = &get_positionX,
        .get_positionY = &get_positionY,
        .get_positionZ = &get_positionZ,
        .get_refDistance = &get_refDistance,
        .get_rolloffFactor = &get_rolloffFactor,

        .set_coneInnerAngle = &set_coneInnerAngle,
        .set_coneOuterAngle = &set_coneOuterAngle,
        .set_coneOuterGain = &set_coneOuterGain,
        .set_distanceModel = &set_distanceModel,
        .set_maxDistance = &set_maxDistance,
        .set_panningModel = &set_panningModel,
        .set_refDistance = &set_refDistance,
        .set_rolloffFactor = &set_rolloffFactor,

        .call_setOrientation = &call_setOrientation,
        .call_setPosition = &call_setPosition,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("PannerNode has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(PannerNodeImpl, "init") and @hasDecl(PannerNodeImpl, "initOwn")) @compileError("PannerNodeImpl defines both init and initOwn");
        if (comptime @hasDecl(PannerNodeImpl, "init")) return PannerNodeImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(PannerNodeImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try PannerNodeImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PannerNodeImpl, "init")) return false;
        if (comptime @hasDecl(PannerNodeImpl, "construction_args")) {
            inline for (PannerNodeImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PannerNodeImpl, "deinit") and @hasDecl(PannerNodeImpl, "deinitOwn")) @compileError("PannerNodeImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PannerNodeImpl, "deinit")) return PannerNodeImpl.deinit(instance);
        if (comptime @hasDecl(PannerNodeImpl, "deinitOwn")) PannerNodeImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PannerNode")) {
            if (comptime @hasDecl(impls.PannerNode, "installHooks")) impls.PannerNode.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, context: *runtime.Instance, options: webidl.Opt(PannerOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PannerNodeImpl.call_constructor(ctx, context, options);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "BaseAudioContext" },
    };

    pub fn get_panningModel(instance: *runtime.Instance) anyerror!PanningModelType {
        return try PannerNodeImpl.get_panningModel(instance);
    }

    pub fn set_panningModel(instance: *runtime.Instance, value: PanningModelType) anyerror!void {
        try PannerNodeImpl.set_panningModel(instance, value);
    }

    pub fn get_positionX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PannerNodeImpl.get_positionX(instance);
    }

    pub fn get_positionY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PannerNodeImpl.get_positionY(instance);
    }

    pub fn get_positionZ(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PannerNodeImpl.get_positionZ(instance);
    }

    pub fn get_orientationX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PannerNodeImpl.get_orientationX(instance);
    }

    pub fn get_orientationY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PannerNodeImpl.get_orientationY(instance);
    }

    pub fn get_orientationZ(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PannerNodeImpl.get_orientationZ(instance);
    }

    pub fn get_distanceModel(instance: *runtime.Instance) anyerror!DistanceModelType {
        return try PannerNodeImpl.get_distanceModel(instance);
    }

    pub fn set_distanceModel(instance: *runtime.Instance, value: DistanceModelType) anyerror!void {
        try PannerNodeImpl.set_distanceModel(instance, value);
    }

    pub fn get_refDistance(instance: *runtime.Instance) anyerror!f64 {
        return try PannerNodeImpl.get_refDistance(instance);
    }

    pub fn set_refDistance(instance: *runtime.Instance, value: f64) anyerror!void {
        try PannerNodeImpl.set_refDistance(instance, value);
    }

    pub fn get_maxDistance(instance: *runtime.Instance) anyerror!f64 {
        return try PannerNodeImpl.get_maxDistance(instance);
    }

    pub fn set_maxDistance(instance: *runtime.Instance, value: f64) anyerror!void {
        try PannerNodeImpl.set_maxDistance(instance, value);
    }

    pub fn get_rolloffFactor(instance: *runtime.Instance) anyerror!f64 {
        return try PannerNodeImpl.get_rolloffFactor(instance);
    }

    pub fn set_rolloffFactor(instance: *runtime.Instance, value: f64) anyerror!void {
        try PannerNodeImpl.set_rolloffFactor(instance, value);
    }

    pub fn get_coneInnerAngle(instance: *runtime.Instance) anyerror!f64 {
        return try PannerNodeImpl.get_coneInnerAngle(instance);
    }

    pub fn set_coneInnerAngle(instance: *runtime.Instance, value: f64) anyerror!void {
        try PannerNodeImpl.set_coneInnerAngle(instance, value);
    }

    pub fn get_coneOuterAngle(instance: *runtime.Instance) anyerror!f64 {
        return try PannerNodeImpl.get_coneOuterAngle(instance);
    }

    pub fn set_coneOuterAngle(instance: *runtime.Instance, value: f64) anyerror!void {
        try PannerNodeImpl.set_coneOuterAngle(instance, value);
    }

    pub fn get_coneOuterGain(instance: *runtime.Instance) anyerror!f64 {
        return try PannerNodeImpl.get_coneOuterGain(instance);
    }

    pub fn set_coneOuterGain(instance: *runtime.Instance, value: f64) anyerror!void {
        try PannerNodeImpl.set_coneOuterGain(instance, value);
    }

    pub fn call_setOrientation(instance: *runtime.Instance, x: f32, y: f32, z: f32) anyerror!void {
        return try PannerNodeImpl.call_setOrientation(instance, x, y, z);
    }

    pub fn call_setPosition(instance: *runtime.Instance, x: f32, y: f32, z: f32) anyerror!void {
        return try PannerNodeImpl.call_setPosition(instance, x, y, z);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_refDistance", 0b1 },
        .{ "set_maxDistance", 0b1 },
        .{ "set_rolloffFactor", 0b1 },
        .{ "set_coneInnerAngle", 0b1 },
        .{ "set_coneOuterAngle", 0b1 },
        .{ "set_coneOuterGain", 0b1 },
        .{ "call_setOrientation", 0b111 },
        .{ "call_setPosition", 0b111 },
    };
};
