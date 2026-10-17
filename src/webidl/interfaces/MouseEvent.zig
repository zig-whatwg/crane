//! Generated from: pointerevents.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MouseEventImpl = @import("impls").MouseEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const UIEvent = @import("interfaces").UIEvent;
const Window = @import("interfaces").Window;
const UIEventInit = @import("dictionaries").UIEventInit;
const EventTarget = @import("interfaces").EventTarget;
const InputDeviceCapabilities = @import("interfaces").InputDeviceCapabilities;
const MouseEventInit = @import("dictionaries").MouseEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const MouseEvent = struct {
    pub const Meta = struct {
        pub const name = "MouseEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = UIEvent.State;
        pub const ParentInterface = UIEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "screenX", "get_screenX", null },
            .{ "screenY", "get_screenY", null },
            .{ "clientX", "get_clientX", null },
            .{ "clientY", "get_clientY", null },
            .{ "layerX", "get_layerX", null },
            .{ "layerY", "get_layerY", null },
            .{ "ctrlKey", "get_ctrlKey", null },
            .{ "shiftKey", "get_shiftKey", null },
            .{ "altKey", "get_altKey", null },
            .{ "metaKey", "get_metaKey", null },
            .{ "button", "get_button", null },
            .{ "buttons", "get_buttons", null },
            .{ "relatedTarget", "get_relatedTarget", null },
            .{ "pageX", "get_pageX", null },
            .{ "pageY", "get_pageY", null },
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "offsetX", "get_offsetX", null },
            .{ "offsetY", "get_offsetY", null },
            .{ "movementX", "get_movementX", null },
            .{ "movementY", "get_movementY", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getModifierState", "call_getModifierState", 1 },
            .{ "initMouseEvent", "call_initMouseEvent", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getModifierState",
            "initMouseEvent",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
            "initUIEvent",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "screenX", "get_screenX", null },
            .{ "screenY", "get_screenY", null },
            .{ "clientX", "get_clientX", null },
            .{ "clientY", "get_clientY", null },
            .{ "layerX", "get_layerX", null },
            .{ "layerY", "get_layerY", null },
            .{ "ctrlKey", "get_ctrlKey", null },
            .{ "shiftKey", "get_shiftKey", null },
            .{ "altKey", "get_altKey", null },
            .{ "metaKey", "get_metaKey", null },
            .{ "button", "get_button", null },
            .{ "buttons", "get_buttons", null },
            .{ "relatedTarget", "get_relatedTarget", null },
            .{ "pageX", "get_pageX", null },
            .{ "pageY", "get_pageY", null },
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "offsetX", "get_offsetX", null },
            .{ "offsetY", "get_offsetY", null },
            .{ "movementX", "get_movementX", null },
            .{ "movementY", "get_movementY", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            screenX: i32 = undefined,
            screenY: i32 = undefined,
            clientX: i32 = undefined,
            clientY: i32 = undefined,
            layerX: i32 = undefined,
            layerY: i32 = undefined,
            ctrlKey: bool = undefined,
            shiftKey: bool = undefined,
            altKey: bool = undefined,
            metaKey: bool = undefined,
            button: i16 = undefined,
            buttons: u16 = undefined,
            relatedTarget: ?*runtime.Instance = null,
            pageX: f64 = undefined,
            pageY: f64 = undefined,
            x: f64 = undefined,
            y: f64 = undefined,
            offsetX: f64 = undefined,
            offsetY: f64 = undefined,
            movementX: f64 = undefined,
            movementY: f64 = undefined,
            _internal: ?*MouseEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_altKey = &get_altKey,
        .get_button = &get_button,
        .get_buttons = &get_buttons,
        .get_clientX = &get_clientX,
        .get_clientY = &get_clientY,
        .get_ctrlKey = &get_ctrlKey,
        .get_layerX = &get_layerX,
        .get_layerY = &get_layerY,
        .get_metaKey = &get_metaKey,
        .get_movementX = &get_movementX,
        .get_movementY = &get_movementY,
        .get_offsetX = &get_offsetX,
        .get_offsetY = &get_offsetY,
        .get_pageX = &get_pageX,
        .get_pageY = &get_pageY,
        .get_relatedTarget = &get_relatedTarget,
        .get_screenX = &get_screenX,
        .get_screenY = &get_screenY,
        .get_shiftKey = &get_shiftKey,
        .get_x = &get_x,
        .get_y = &get_y,

        .call_getModifierState = &call_getModifierState,
        .call_initMouseEvent = &call_initMouseEvent,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("MouseEvent has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(MouseEventImpl, "init") and @hasDecl(MouseEventImpl, "initOwn")) @compileError("MouseEventImpl defines both init and initOwn");
        if (comptime @hasDecl(MouseEventImpl, "init")) return MouseEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(MouseEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try MouseEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MouseEventImpl, "init")) return false;
        if (comptime @hasDecl(MouseEventImpl, "construction_args")) {
            inline for (MouseEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MouseEventImpl, "deinit") and @hasDecl(MouseEventImpl, "deinitOwn")) @compileError("MouseEventImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MouseEventImpl, "deinit")) return MouseEventImpl.deinit(instance);
        if (comptime @hasDecl(MouseEventImpl, "deinitOwn")) MouseEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MouseEvent")) {
            if (comptime @hasDecl(impls.MouseEvent, "installHooks")) impls.MouseEvent.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(MouseEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MouseEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_screenX(instance: *runtime.Instance) anyerror!i32 {
        return try MouseEventImpl.get_screenX(instance);
    }

    pub fn get_screenY(instance: *runtime.Instance) anyerror!i32 {
        return try MouseEventImpl.get_screenY(instance);
    }

    pub fn get_clientX(instance: *runtime.Instance) anyerror!i32 {
        return try MouseEventImpl.get_clientX(instance);
    }

    pub fn get_clientY(instance: *runtime.Instance) anyerror!i32 {
        return try MouseEventImpl.get_clientY(instance);
    }

    pub fn get_layerX(instance: *runtime.Instance) anyerror!i32 {
        return try MouseEventImpl.get_layerX(instance);
    }

    pub fn get_layerY(instance: *runtime.Instance) anyerror!i32 {
        return try MouseEventImpl.get_layerY(instance);
    }

    pub fn get_ctrlKey(instance: *runtime.Instance) anyerror!bool {
        return try MouseEventImpl.get_ctrlKey(instance);
    }

    pub fn get_shiftKey(instance: *runtime.Instance) anyerror!bool {
        return try MouseEventImpl.get_shiftKey(instance);
    }

    pub fn get_altKey(instance: *runtime.Instance) anyerror!bool {
        return try MouseEventImpl.get_altKey(instance);
    }

    pub fn get_metaKey(instance: *runtime.Instance) anyerror!bool {
        return try MouseEventImpl.get_metaKey(instance);
    }

    pub fn get_button(instance: *runtime.Instance) anyerror!i16 {
        return try MouseEventImpl.get_button(instance);
    }

    pub fn get_buttons(instance: *runtime.Instance) anyerror!u16 {
        return try MouseEventImpl.get_buttons(instance);
    }

    pub fn get_relatedTarget(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try MouseEventImpl.get_relatedTarget(instance);
    }

    pub fn get_pageX(instance: *runtime.Instance) anyerror!f64 {
        return try MouseEventImpl.get_pageX(instance);
    }

    pub fn get_pageY(instance: *runtime.Instance) anyerror!f64 {
        return try MouseEventImpl.get_pageY(instance);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
        return try MouseEventImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
        return try MouseEventImpl.get_y(instance);
    }

    pub fn get_offsetX(instance: *runtime.Instance) anyerror!f64 {
        return try MouseEventImpl.get_offsetX(instance);
    }

    pub fn get_offsetY(instance: *runtime.Instance) anyerror!f64 {
        return try MouseEventImpl.get_offsetY(instance);
    }

    pub fn get_movementX(instance: *runtime.Instance) anyerror!f64 {
        return try MouseEventImpl.get_movementX(instance);
    }

    pub fn get_movementY(instance: *runtime.Instance) anyerror!f64 {
        return try MouseEventImpl.get_movementY(instance);
    }

    pub fn call_getModifierState(instance: *runtime.Instance, keyArg: runtime.DOMString) anyerror!bool {
        return try MouseEventImpl.call_getModifierState(instance, keyArg);
    }

    pub fn call_initMouseEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, bubblesArg: webidl.Opt(bool), cancelableArg: webidl.Opt(bool), viewArg: webidl.Opt(?*runtime.Instance), detailArg: webidl.Opt(i32), screenXArg: webidl.Opt(i32), screenYArg: webidl.Opt(i32), clientXArg: webidl.Opt(i32), clientYArg: webidl.Opt(i32), ctrlKeyArg: webidl.Opt(bool), altKeyArg: webidl.Opt(bool), shiftKeyArg: webidl.Opt(bool), metaKeyArg: webidl.Opt(bool), buttonArg: webidl.Opt(i16), relatedTargetArg: webidl.Opt(?*runtime.Instance)) anyerror!void {
        return try MouseEventImpl.call_initMouseEvent(instance, typeArg, bubblesArg, cancelableArg, viewArg, detailArg, screenXArg, screenYArg, clientXArg, clientYArg, ctrlKeyArg, altKeyArg, shiftKeyArg, metaKeyArg, buttonArg, relatedTargetArg);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_initMouseEvent", 3, "Window" },
        .{ "call_initMouseEvent", 14, "EventTarget" },
    };
};
