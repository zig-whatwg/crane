//! Generated from: window-controls-overlay.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WindowControlsOverlayImpl = @import("impls").WindowControlsOverlay;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMRect = @import("interfaces").DOMRect;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const WindowControlsOverlay = struct {
    pub const Meta = struct {
        pub const name = "WindowControlsOverlay";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "visible", "get_visible", null },
            .{ "ongeometrychange", "get_ongeometrychange", "set_ongeometrychange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getTitlebarAreaRect", "call_getTitlebarAreaRect", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getTitlebarAreaRect",
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
            .{ "visible", "get_visible", null },
            .{ "ongeometrychange", "get_ongeometrychange", "set_ongeometrychange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            visible: bool = undefined,
            ongeometrychange: typedefs.EventHandler = undefined,
            _internal: ?*WindowControlsOverlayImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_ongeometrychange = &get_ongeometrychange,
        .get_visible = &get_visible,

        .set_ongeometrychange = &set_ongeometrychange,

        .call_getTitlebarAreaRect = &call_getTitlebarAreaRect,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("WindowControlsOverlay has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(WindowControlsOverlayImpl, "init") and @hasDecl(WindowControlsOverlayImpl, "initOwn")) @compileError("WindowControlsOverlayImpl defines both init and initOwn");
        if (comptime @hasDecl(WindowControlsOverlayImpl, "init")) return WindowControlsOverlayImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(WindowControlsOverlayImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try WindowControlsOverlayImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(WindowControlsOverlayImpl, "init")) return false;
        if (comptime @hasDecl(WindowControlsOverlayImpl, "construction_args")) {
            inline for (WindowControlsOverlayImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(WindowControlsOverlayImpl, "deinit") and @hasDecl(WindowControlsOverlayImpl, "deinitOwn")) @compileError("WindowControlsOverlayImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(WindowControlsOverlayImpl, "deinit")) return WindowControlsOverlayImpl.deinit(instance);
        if (comptime @hasDecl(WindowControlsOverlayImpl, "deinitOwn")) WindowControlsOverlayImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "WindowControlsOverlay")) {
            if (comptime @hasDecl(impls.WindowControlsOverlay, "installHooks")) impls.WindowControlsOverlay.installHooks();
        }
    }

    pub fn get_visible(instance: *runtime.Instance) anyerror!bool {
        return try WindowControlsOverlayImpl.get_visible(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_ongeometrychange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(WindowControlsOverlayImpl, "get_ongeometrychange")) return try WindowControlsOverlayImpl.get_ongeometrychange(instance);
        return event_handlers.value(EventHandler, instance, "ongeometrychange");
    }

    pub fn set_ongeometrychange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(WindowControlsOverlayImpl, "set_ongeometrychange")) return try WindowControlsOverlayImpl.set_ongeometrychange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ongeometrychange", value);
    }

    pub fn call_getTitlebarAreaRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowControlsOverlayImpl.call_getTitlebarAreaRect(instance);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_ongeometrychange"};
};
