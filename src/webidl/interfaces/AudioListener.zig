//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioListenerImpl = @import("impls").AudioListener;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AudioParam = @import("interfaces").AudioParam;

pub const AudioListener = struct {
    pub const Meta = struct {
        pub const name = "AudioListener";
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
            .{ "positionX", "get_positionX", null },
            .{ "positionY", "get_positionY", null },
            .{ "positionZ", "get_positionZ", null },
            .{ "forwardX", "get_forwardX", null },
            .{ "forwardY", "get_forwardY", null },
            .{ "forwardZ", "get_forwardZ", null },
            .{ "upX", "get_upX", null },
            .{ "upY", "get_upY", null },
            .{ "upZ", "get_upZ", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setPosition", "call_setPosition", 3 },
            .{ "setOrientation", "call_setOrientation", 6 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setPosition",
            "setOrientation",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "positionX", "get_positionX", null },
            .{ "positionY", "get_positionY", null },
            .{ "positionZ", "get_positionZ", null },
            .{ "forwardX", "get_forwardX", null },
            .{ "forwardY", "get_forwardY", null },
            .{ "forwardZ", "get_forwardZ", null },
            .{ "upX", "get_upX", null },
            .{ "upY", "get_upY", null },
            .{ "upZ", "get_upZ", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            positionX: *runtime.Instance = undefined,
            positionY: *runtime.Instance = undefined,
            positionZ: *runtime.Instance = undefined,
            forwardX: *runtime.Instance = undefined,
            forwardY: *runtime.Instance = undefined,
            forwardZ: *runtime.Instance = undefined,
            upX: *runtime.Instance = undefined,
            upY: *runtime.Instance = undefined,
            upZ: *runtime.Instance = undefined,
            _internal: ?*AudioListenerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_forwardX = &get_forwardX,
        .get_forwardY = &get_forwardY,
        .get_forwardZ = &get_forwardZ,
        .get_positionX = &get_positionX,
        .get_positionY = &get_positionY,
        .get_positionZ = &get_positionZ,
        .get_upX = &get_upX,
        .get_upY = &get_upY,
        .get_upZ = &get_upZ,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("AudioListener has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(AudioListenerImpl, "init") and @hasDecl(AudioListenerImpl, "initOwn")) @compileError("AudioListenerImpl defines both init and initOwn");
        if (comptime @hasDecl(AudioListenerImpl, "init")) return AudioListenerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(AudioListenerImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try AudioListenerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AudioListenerImpl, "init")) return false;
        if (comptime @hasDecl(AudioListenerImpl, "construction_args")) {
            inline for (AudioListenerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AudioListenerImpl, "deinit") and @hasDecl(AudioListenerImpl, "deinitOwn")) @compileError("AudioListenerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AudioListenerImpl, "deinit")) return AudioListenerImpl.deinit(instance);
        if (comptime @hasDecl(AudioListenerImpl, "deinitOwn")) AudioListenerImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AudioListener")) {
            if (comptime @hasDecl(impls.AudioListener, "installHooks")) impls.AudioListener.installHooks();
        }
    }

    pub fn get_positionX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_positionX(instance);
    }

    pub fn get_positionY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_positionY(instance);
    }

    pub fn get_positionZ(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_positionZ(instance);
    }

    pub fn get_forwardX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_forwardX(instance);
    }

    pub fn get_forwardY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_forwardY(instance);
    }

    pub fn get_forwardZ(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_forwardZ(instance);
    }

    pub fn get_upX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_upX(instance);
    }

    pub fn get_upY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_upY(instance);
    }

    pub fn get_upZ(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioListenerImpl.get_upZ(instance);
    }

    pub fn call_setOrientation(instance: *runtime.Instance, x: f32, y: f32, z: f32, xUp: f32, yUp: f32, zUp: f32) anyerror!void {
        return try AudioListenerImpl.call_setOrientation(instance, x, y, z, xUp, yUp, zUp);
    }

    pub fn call_setPosition(instance: *runtime.Instance, x: f32, y: f32, z: f32) anyerror!void {
        return try AudioListenerImpl.call_setPosition(instance, x, y, z);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "call_setOrientation", 0b111111 },
        .{ "call_setPosition", 0b111 },
    };
};
