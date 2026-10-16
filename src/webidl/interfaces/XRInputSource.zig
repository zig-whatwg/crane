//! Generated from: webxr.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRInputSourceImpl = @import("impls").XRInputSource;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRHandedness = @import("enums").XRHandedness;
const Gamepad = @import("interfaces").Gamepad;
const XRSpace = @import("interfaces").XRSpace;
const XRHand = @import("interfaces").XRHand;
const XRTargetRayMode = @import("enums").XRTargetRayMode;
const DOMString = @import("typedefs").DOMString;

pub const XRInputSource = struct {
    pub const Meta = struct {
        pub const name = "XRInputSource";
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
            .{ "handedness", "get_handedness", null },
            .{ "targetRayMode", "get_targetRayMode", null },
            .{ "targetRaySpace", "get_targetRaySpace", null },
            .{ "gripSpace", "get_gripSpace", null },
            .{ "profiles", "get_profiles", null },
            .{ "skipRendering", "get_skipRendering", null },
            .{ "gamepad", "get_gamepad", null },
            .{ "hand", "get_hand", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "handedness", "get_handedness", null },
            .{ "targetRayMode", "get_targetRayMode", null },
            .{ "targetRaySpace", "get_targetRaySpace", null },
            .{ "gripSpace", "get_gripSpace", null },
            .{ "profiles", "get_profiles", null },
            .{ "skipRendering", "get_skipRendering", null },
            .{ "gamepad", "get_gamepad", null },
            .{ "hand", "get_hand", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            handedness: enums.XRHandedness = undefined,
            targetRayMode: enums.XRTargetRayMode = undefined,
            targetRaySpace: *runtime.Instance = undefined,
            gripSpace: ?*runtime.Instance = null,
            profiles: runtime.JSValue = undefined,
            skipRendering: bool = undefined,
            gamepad: ?*runtime.Instance = null,
            hand: ?*runtime.Instance = null,
            cached_targetRaySpace: ?*runtime.Instance = null,
            cached_gripSpace: ?*runtime.Instance = null,
            cached_profiles: ?runtime.JSValue = null,
            cached_gamepad: ?*runtime.Instance = null,
            cached_hand: ?*runtime.Instance = null,
            _internal: ?*XRInputSourceImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_gamepad = &get_gamepad,
        .get_gripSpace = &get_gripSpace,
        .get_hand = &get_hand,
        .get_handedness = &get_handedness,
        .get_profiles = &get_profiles,
        .get_skipRendering = &get_skipRendering,
        .get_targetRayMode = &get_targetRayMode,
        .get_targetRaySpace = &get_targetRaySpace,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XRInputSource has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XRInputSourceImpl, "init") and @hasDecl(XRInputSourceImpl, "initOwn")) @compileError("XRInputSourceImpl defines both init and initOwn");
        if (comptime @hasDecl(XRInputSourceImpl, "init")) return XRInputSourceImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(XRInputSourceImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try XRInputSourceImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRInputSourceImpl, "init")) return false;
        if (comptime @hasDecl(XRInputSourceImpl, "construction_args")) {
            inline for (XRInputSourceImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRInputSourceImpl, "deinit") and @hasDecl(XRInputSourceImpl, "deinitOwn")) @compileError("XRInputSourceImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(XRInputSourceImpl, "deinit")) return XRInputSourceImpl.deinit(instance);
        if (comptime @hasDecl(XRInputSourceImpl, "deinitOwn")) XRInputSourceImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRInputSource")) {
            if (comptime @hasDecl(impls.XRInputSource, "installHooks")) impls.XRInputSource.installHooks();
        }
    }

    pub fn get_handedness(instance: *runtime.Instance) anyerror!XRHandedness {
        return try XRInputSourceImpl.get_handedness(instance);
    }

    pub fn get_targetRayMode(instance: *runtime.Instance) anyerror!XRTargetRayMode {
        return try XRInputSourceImpl.get_targetRayMode(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_targetRaySpace(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_targetRaySpace) |cached| {
            return cached;
        }
        const value = try XRInputSourceImpl.get_targetRaySpace(instance);
        state.own.cached_targetRaySpace = value;
        @import("dom").same_object_cache.made(instance, value, "targetRaySpace");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_gripSpace(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_gripSpace) |cached| {
            return cached;
        }
        const value = try XRInputSourceImpl.get_gripSpace(instance);
        state.own.cached_gripSpace = value;
        if (value) |child| @import("dom").same_object_cache.made(instance, child, "gripSpace");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_profiles(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try XRInputSourceImpl.get_profiles(instance);
    }

    pub fn get_skipRendering(instance: *runtime.Instance) anyerror!bool {
        return try XRInputSourceImpl.get_skipRendering(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_gamepad(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_gamepad) |cached| {
            return cached;
        }
        const value = try XRInputSourceImpl.get_gamepad(instance);
        state.own.cached_gamepad = value;
        if (value) |child| @import("dom").same_object_cache.made(instance, child, "gamepad");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_hand(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_hand) |cached| {
            return cached;
        }
        const value = try XRInputSourceImpl.get_hand(instance);
        state.own.cached_hand = value;
        if (value) |child| @import("dom").same_object_cache.made(instance, child, "hand");
        return value;
    }
};
