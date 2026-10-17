//! Generated from: webxrlayers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRCubeLayerImpl = @import("impls").XRCubeLayer;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRCompositionLayer = @import("interfaces").XRCompositionLayer;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const XRLayerQuality = @import("enums").XRLayerQuality;
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const XRSpace = @import("interfaces").XRSpace;
const EventListener = @import("interfaces").EventListener;
const XRLayerLayout = @import("enums").XRLayerLayout;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const XRCubeLayer = struct {
    pub const Meta = struct {
        pub const name = "XRCubeLayer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = XRCompositionLayer.State;
        pub const ParentInterface = XRCompositionLayer;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "space", "get_space", "set_space" },
            .{ "orientation", "get_orientation", "set_orientation" },
            .{ "onredraw", "get_onredraw", "set_onredraw" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "destroy",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "space", "get_space", "set_space" },
            .{ "orientation", "get_orientation", "set_orientation" },
            .{ "onredraw", "get_onredraw", "set_onredraw" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            space: *runtime.Instance = undefined,
            orientation: *runtime.Instance = undefined,
            onredraw: typedefs.EventHandler = undefined,
            _internal: ?*XRCubeLayerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onredraw = &get_onredraw,
        .get_orientation = &get_orientation,
        .get_space = &get_space,

        .set_onredraw = &set_onredraw,
        .set_orientation = &set_orientation,
        .set_space = &set_space,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XRCubeLayer has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XRCubeLayerImpl, "init") and @hasDecl(XRCubeLayerImpl, "initOwn")) @compileError("XRCubeLayerImpl defines both init and initOwn");
        if (comptime @hasDecl(XRCubeLayerImpl, "init")) return XRCubeLayerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(XRCubeLayerImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try XRCubeLayerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRCubeLayerImpl, "init")) return false;
        if (comptime @hasDecl(XRCubeLayerImpl, "construction_args")) {
            inline for (XRCubeLayerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRCubeLayerImpl, "deinit") and @hasDecl(XRCubeLayerImpl, "deinitOwn")) @compileError("XRCubeLayerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(XRCubeLayerImpl, "deinit")) return XRCubeLayerImpl.deinit(instance);
        if (comptime @hasDecl(XRCubeLayerImpl, "deinitOwn")) XRCubeLayerImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRCubeLayer")) {
            if (comptime @hasDecl(impls.XRCubeLayer, "installHooks")) impls.XRCubeLayer.installHooks();
        }
    }

    pub fn get_space(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XRCubeLayerImpl.get_space(instance);
    }

    pub fn set_space(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try XRCubeLayerImpl.set_space(instance, value);
    }

    pub fn get_orientation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XRCubeLayerImpl.get_orientation(instance);
    }

    pub fn set_orientation(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try XRCubeLayerImpl.set_orientation(instance, value);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onredraw(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(XRCubeLayerImpl, "get_onredraw")) return try XRCubeLayerImpl.get_onredraw(instance);
        return event_handlers.value(EventHandler, instance, "onredraw");
    }

    pub fn set_onredraw(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(XRCubeLayerImpl, "set_onredraw")) return try XRCubeLayerImpl.set_onredraw(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onredraw", value);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "set_space", 0, "XRSpace" },
        .{ "set_orientation", 0, "DOMPointReadOnly" },
    };
};
