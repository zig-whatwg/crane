//! Generated from: webxr.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRWebGLLayerImpl = @import("impls").XRWebGLLayer;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRLayer = @import("interfaces").XRLayer;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const XRView = @import("interfaces").XRView;
const XRSession = @import("interfaces").XRSession;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const XRViewport = @import("interfaces").XRViewport;
const WebGLFramebuffer = @import("interfaces").WebGLFramebuffer;
const XRWebGLLayerInit = @import("dictionaries").XRWebGLLayerInit;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const XRWebGLRenderingContext = @import("typedefs").XRWebGLRenderingContext;
const DOMString = @import("typedefs").DOMString;

pub const XRWebGLLayer = struct {
    pub const Meta = struct {
        pub const name = "XRWebGLLayer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = XRLayer.State;
        pub const ParentInterface = XRLayer;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "antialias", "get_antialias", null },
            .{ "ignoreDepthValues", "get_ignoreDepthValues", null },
            .{ "fixedFoveation", "get_fixedFoveation", "set_fixedFoveation" },
            .{ "framebuffer", "get_framebuffer", null },
            .{ "framebufferWidth", "get_framebufferWidth", null },
            .{ "framebufferHeight", "get_framebufferHeight", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getViewport", "call_getViewport", 1 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "getNativeFramebufferScaleFactor", "call_static_getNativeFramebufferScaleFactor", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getViewport",
            "getNativeFramebufferScaleFactor",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "antialias", "get_antialias", null },
            .{ "ignoreDepthValues", "get_ignoreDepthValues", null },
            .{ "fixedFoveation", "get_fixedFoveation", "set_fixedFoveation" },
            .{ "framebuffer", "get_framebuffer", null },
            .{ "framebufferWidth", "get_framebufferWidth", null },
            .{ "framebufferHeight", "get_framebufferHeight", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            antialias: bool = undefined,
            ignoreDepthValues: bool = undefined,
            fixedFoveation: ?f32 = null,
            framebuffer: ?*runtime.Instance = null,
            framebufferWidth: u32 = undefined,
            framebufferHeight: u32 = undefined,
            cached_framebuffer: ?*runtime.Instance = null,
            _internal: ?*XRWebGLLayerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_antialias = &get_antialias,
        .get_fixedFoveation = &get_fixedFoveation,
        .get_framebuffer = &get_framebuffer,
        .get_framebufferHeight = &get_framebufferHeight,
        .get_framebufferWidth = &get_framebufferWidth,
        .get_ignoreDepthValues = &get_ignoreDepthValues,

        .set_fixedFoveation = &set_fixedFoveation,

        .call_getViewport = &call_getViewport,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XRWebGLLayer has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XRWebGLLayerImpl, "init") and @hasDecl(XRWebGLLayerImpl, "initOwn")) @compileError("XRWebGLLayerImpl defines both init and initOwn");
        if (comptime @hasDecl(XRWebGLLayerImpl, "init")) return XRWebGLLayerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(XRWebGLLayerImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try XRWebGLLayerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRWebGLLayerImpl, "init")) return false;
        if (comptime @hasDecl(XRWebGLLayerImpl, "construction_args")) {
            inline for (XRWebGLLayerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRWebGLLayerImpl, "deinit") and @hasDecl(XRWebGLLayerImpl, "deinitOwn")) @compileError("XRWebGLLayerImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(XRWebGLLayerImpl, "deinit")) return XRWebGLLayerImpl.deinit(instance);
        if (comptime @hasDecl(XRWebGLLayerImpl, "deinitOwn")) XRWebGLLayerImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRWebGLLayer")) {
            if (comptime @hasDecl(impls.XRWebGLLayer, "installHooks")) impls.XRWebGLLayer.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, session: *runtime.Instance, context: XRWebGLRenderingContext, layerInit: webidl.Opt(XRWebGLLayerInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XRWebGLLayerImpl.call_constructor(ctx, session, context, layerInit);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "XRSession" },
    };

    pub fn get_antialias(instance: *runtime.Instance) anyerror!bool {
        return try XRWebGLLayerImpl.get_antialias(instance);
    }

    pub fn get_ignoreDepthValues(instance: *runtime.Instance) anyerror!bool {
        return try XRWebGLLayerImpl.get_ignoreDepthValues(instance);
    }

    pub fn get_fixedFoveation(instance: *runtime.Instance) anyerror!?f32 {
        return try XRWebGLLayerImpl.get_fixedFoveation(instance);
    }

    pub fn set_fixedFoveation(instance: *runtime.Instance, value: ?f32) anyerror!void {
        try XRWebGLLayerImpl.set_fixedFoveation(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_framebuffer(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_framebuffer) |cached| {
            return cached;
        }
        const value = try XRWebGLLayerImpl.get_framebuffer(instance);
        state.own.cached_framebuffer = value;
        if (value) |child| @import("dom").same_object_cache.made(instance, child, "framebuffer");
        return value;
    }

    pub fn get_framebufferWidth(instance: *runtime.Instance) anyerror!u32 {
        return try XRWebGLLayerImpl.get_framebufferWidth(instance);
    }

    pub fn get_framebufferHeight(instance: *runtime.Instance) anyerror!u32 {
        return try XRWebGLLayerImpl.get_framebufferHeight(instance);
    }

    pub fn call_getViewport(instance: *runtime.Instance, view: *runtime.Instance) anyerror!?*runtime.Instance {
        return try XRWebGLLayerImpl.call_getViewport(instance, view);
    }

    pub fn call_static_getNativeFramebufferScaleFactor(instance: *runtime.Instance, session: *runtime.Instance) anyerror!f64 {
        return try XRWebGLLayerImpl.call_static_getNativeFramebufferScaleFactor(instance, session);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_fixedFoveation", 0b1 },
    };

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_getViewport", 0, "XRView" },
        .{ "call_static_getNativeFramebufferScaleFactor", 0, "XRSession" },
    };
};
