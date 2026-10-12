//! Generated from: webxr-lighting-estimation.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRLightProbeImpl = @import("impls").XRLightProbe;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const XRSpace = @import("interfaces").XRSpace;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const XRLightProbe = struct {
    pub const Meta = struct {
        pub const name = "XRLightProbe";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "probeSpace", "get_probeSpace", null },
            .{ "onreflectionchange", "get_onreflectionchange", "set_onreflectionchange" },
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
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "probeSpace", "get_probeSpace", null },
            .{ "onreflectionchange", "get_onreflectionchange", "set_onreflectionchange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            probeSpace: *runtime.Instance = undefined,
            onreflectionchange: typedefs.EventHandler = undefined,
            _internal: ?*XRLightProbeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onreflectionchange = &get_onreflectionchange,
        .get_probeSpace = &get_probeSpace,

        .set_onreflectionchange = &set_onreflectionchange,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XRLightProbe has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XRLightProbeImpl, "init") and @hasDecl(XRLightProbeImpl, "initOwn")) @compileError("XRLightProbeImpl defines both init and initOwn");
        if (comptime @hasDecl(XRLightProbeImpl, "init")) return XRLightProbeImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(XRLightProbeImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try XRLightProbeImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRLightProbeImpl, "init")) return false;
        if (comptime @hasDecl(XRLightProbeImpl, "construction_args")) {
            inline for (XRLightProbeImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRLightProbeImpl, "deinit") and @hasDecl(XRLightProbeImpl, "deinitOwn")) @compileError("XRLightProbeImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(XRLightProbeImpl, "deinit")) return XRLightProbeImpl.deinit(instance);
        if (comptime @hasDecl(XRLightProbeImpl, "deinitOwn")) XRLightProbeImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRLightProbe")) {
            if (comptime @hasDecl(impls.XRLightProbe, "installHooks")) impls.XRLightProbe.installHooks();
        }
    }

    pub fn get_probeSpace(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XRLightProbeImpl.get_probeSpace(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onreflectionchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(XRLightProbeImpl, "get_onreflectionchange")) return try XRLightProbeImpl.get_onreflectionchange(instance);
        return event_handlers.value(EventHandler, instance, "onreflectionchange");
    }

    pub fn set_onreflectionchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(XRLightProbeImpl, "set_onreflectionchange")) return try XRLightProbeImpl.set_onreflectionchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onreflectionchange", value);
    }
};
