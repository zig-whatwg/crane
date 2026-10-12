//! Generated from: virtual-keyboard.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const VirtualKeyboardImpl = @import("impls").VirtualKeyboard;
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

pub const VirtualKeyboard = struct {
    pub const Meta = struct {
        pub const name = "VirtualKeyboard";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "boundingRect", "get_boundingRect", null },
            .{ "overlaysContent", "get_overlaysContent", "set_overlaysContent" },
            .{ "ongeometrychange", "get_ongeometrychange", "set_ongeometrychange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "show", "call_show", 0 },
            .{ "hide", "call_hide", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "show",
            "hide",
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
            .{ "boundingRect", "get_boundingRect", null },
            .{ "overlaysContent", "get_overlaysContent", "set_overlaysContent" },
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
            boundingRect: *runtime.Instance = undefined,
            overlaysContent: bool = undefined,
            ongeometrychange: typedefs.EventHandler = undefined,
            _internal: ?*VirtualKeyboardImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_boundingRect = &get_boundingRect,
        .get_ongeometrychange = &get_ongeometrychange,
        .get_overlaysContent = &get_overlaysContent,

        .set_ongeometrychange = &set_ongeometrychange,
        .set_overlaysContent = &set_overlaysContent,

        .call_hide = &call_hide,
        .call_show = &call_show,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("VirtualKeyboard has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(VirtualKeyboardImpl, "init") and @hasDecl(VirtualKeyboardImpl, "initOwn")) @compileError("VirtualKeyboardImpl defines both init and initOwn");
        if (comptime @hasDecl(VirtualKeyboardImpl, "init")) return VirtualKeyboardImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(VirtualKeyboardImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try VirtualKeyboardImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(VirtualKeyboardImpl, "init")) return false;
        if (comptime @hasDecl(VirtualKeyboardImpl, "construction_args")) {
            inline for (VirtualKeyboardImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(VirtualKeyboardImpl, "deinit") and @hasDecl(VirtualKeyboardImpl, "deinitOwn")) @compileError("VirtualKeyboardImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(VirtualKeyboardImpl, "deinit")) return VirtualKeyboardImpl.deinit(instance);
        if (comptime @hasDecl(VirtualKeyboardImpl, "deinitOwn")) VirtualKeyboardImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "VirtualKeyboard")) {
            if (comptime @hasDecl(impls.VirtualKeyboard, "installHooks")) impls.VirtualKeyboard.installHooks();
        }
    }

    pub fn get_boundingRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try VirtualKeyboardImpl.get_boundingRect(instance);
    }

    pub fn get_overlaysContent(instance: *runtime.Instance) anyerror!bool {
        return try VirtualKeyboardImpl.get_overlaysContent(instance);
    }

    pub fn set_overlaysContent(instance: *runtime.Instance, value: bool) anyerror!void {
        try VirtualKeyboardImpl.set_overlaysContent(instance, value);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_ongeometrychange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(VirtualKeyboardImpl, "get_ongeometrychange")) return try VirtualKeyboardImpl.get_ongeometrychange(instance);
        return event_handlers.value(EventHandler, instance, "ongeometrychange");
    }

    pub fn set_ongeometrychange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(VirtualKeyboardImpl, "set_ongeometrychange")) return try VirtualKeyboardImpl.set_ongeometrychange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ongeometrychange", value);
    }

    pub fn call_show(instance: *runtime.Instance) anyerror!void {
        return try VirtualKeyboardImpl.call_show(instance);
    }

    pub fn call_hide(instance: *runtime.Instance) anyerror!void {
        return try VirtualKeyboardImpl.call_hide(instance);
    }
};
