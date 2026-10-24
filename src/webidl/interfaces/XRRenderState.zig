//! Generated from: webxr.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRRenderStateImpl = @import("impls").XRRenderState;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRWebGLLayer = @import("interfaces").XRWebGLLayer;
const XRLayer = @import("interfaces").XRLayer;

pub const XRRenderState = struct {
    pub const Meta = struct {
        pub const name = "XRRenderState";
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
            .{ "depthNear", "get_depthNear", null },
            .{ "depthFar", "get_depthFar", null },
            .{ "passthroughFullyObscured", "get_passthroughFullyObscured", null },
            .{ "inlineVerticalFieldOfView", "get_inlineVerticalFieldOfView", null },
            .{ "baseLayer", "get_baseLayer", null },
            .{ "layers", "get_layers", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "depthNear", "get_depthNear", null },
            .{ "depthFar", "get_depthFar", null },
            .{ "passthroughFullyObscured", "get_passthroughFullyObscured", null },
            .{ "inlineVerticalFieldOfView", "get_inlineVerticalFieldOfView", null },
            .{ "baseLayer", "get_baseLayer", null },
            .{ "layers", "get_layers", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// [SecureContext] members - their own, their partial interface's or
        /// their mixin's: hidden in a realm that is not a secure context
        /// (WebIDL 3.3.13).
        pub const secure_context_members = .{
            "layers",
        };
        /// Member-level [Exposed] overrides; unlisted members inherit the interface.
        pub const exposed_members = .{
            .{ "layers", .{"Window"} },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            depthNear: f64 = undefined,
            depthFar: f64 = undefined,
            passthroughFullyObscured: ?bool = null,
            inlineVerticalFieldOfView: ?f64 = null,
            baseLayer: ?*runtime.Instance = null,
            layers: runtime.JSValue = undefined,
            _internal: ?*XRRenderStateImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_baseLayer = &get_baseLayer,
        .get_depthFar = &get_depthFar,
        .get_depthNear = &get_depthNear,
        .get_inlineVerticalFieldOfView = &get_inlineVerticalFieldOfView,
        .get_layers = &get_layers,
        .get_passthroughFullyObscured = &get_passthroughFullyObscured,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XRRenderState has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XRRenderStateImpl, "init") and @hasDecl(XRRenderStateImpl, "initOwn")) @compileError("XRRenderStateImpl defines both init and initOwn");
        if (comptime @hasDecl(XRRenderStateImpl, "init")) return XRRenderStateImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(XRRenderStateImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try XRRenderStateImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRRenderStateImpl, "init")) return false;
        if (comptime @hasDecl(XRRenderStateImpl, "construction_args")) {
            inline for (XRRenderStateImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRRenderStateImpl, "deinit") and @hasDecl(XRRenderStateImpl, "deinitOwn")) @compileError("XRRenderStateImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(XRRenderStateImpl, "deinit")) return XRRenderStateImpl.deinit(instance);
        if (comptime @hasDecl(XRRenderStateImpl, "deinitOwn")) XRRenderStateImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRRenderState")) {
            if (comptime @hasDecl(impls.XRRenderState, "installHooks")) impls.XRRenderState.installHooks();
        }
    }

    pub fn get_depthNear(instance: *runtime.Instance) anyerror!f64 {
        return try XRRenderStateImpl.get_depthNear(instance);
    }

    pub fn get_depthFar(instance: *runtime.Instance) anyerror!f64 {
        return try XRRenderStateImpl.get_depthFar(instance);
    }

    pub fn get_passthroughFullyObscured(instance: *runtime.Instance) anyerror!?bool {
        return try XRRenderStateImpl.get_passthroughFullyObscured(instance);
    }

    pub fn get_inlineVerticalFieldOfView(instance: *runtime.Instance) anyerror!?f64 {
        return try XRRenderStateImpl.get_inlineVerticalFieldOfView(instance);
    }

    pub fn get_baseLayer(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try XRRenderStateImpl.get_baseLayer(instance);
    }

    /// Extended attributes: [SecureContext], [Exposed=Window]
    pub fn get_layers(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try XRRenderStateImpl.get_layers(instance);
    }
};
