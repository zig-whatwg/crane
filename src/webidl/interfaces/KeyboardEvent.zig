//! Generated from: uievents.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const KeyboardEventImpl = @import("impls").KeyboardEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const UIEvent = @import("interfaces").UIEvent;
const Window = @import("interfaces").Window;
const UIEventInit = @import("dictionaries").UIEventInit;
const EventTarget = @import("interfaces").EventTarget;
const InputDeviceCapabilities = @import("interfaces").InputDeviceCapabilities;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;
const KeyboardEventInit = @import("dictionaries").KeyboardEventInit;

pub const KeyboardEvent = struct {
    pub const Meta = struct {
        pub const name = "KeyboardEvent";
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
            .{ "key", "get_key", null },
            .{ "code", "get_code", null },
            .{ "location", "get_location", null },
            .{ "ctrlKey", "get_ctrlKey", null },
            .{ "shiftKey", "get_shiftKey", null },
            .{ "altKey", "get_altKey", null },
            .{ "metaKey", "get_metaKey", null },
            .{ "repeat", "get_repeat", null },
            .{ "isComposing", "get_isComposing", null },
            .{ "charCode", "get_charCode", null },
            .{ "keyCode", "get_keyCode", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getModifierState", "call_getModifierState", 1 },
            .{ "initKeyboardEvent", "call_initKeyboardEvent", 1 },
        };

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "DOM_KEY_LOCATION_STANDARD", "get_DOM_KEY_LOCATION_STANDARD" },
            .{ "DOM_KEY_LOCATION_LEFT", "get_DOM_KEY_LOCATION_LEFT" },
            .{ "DOM_KEY_LOCATION_RIGHT", "get_DOM_KEY_LOCATION_RIGHT" },
            .{ "DOM_KEY_LOCATION_NUMPAD", "get_DOM_KEY_LOCATION_NUMPAD" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getModifierState",
            "initKeyboardEvent",
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
            .{ "key", "get_key", null },
            .{ "code", "get_code", null },
            .{ "location", "get_location", null },
            .{ "ctrlKey", "get_ctrlKey", null },
            .{ "shiftKey", "get_shiftKey", null },
            .{ "altKey", "get_altKey", null },
            .{ "metaKey", "get_metaKey", null },
            .{ "repeat", "get_repeat", null },
            .{ "isComposing", "get_isComposing", null },
            .{ "charCode", "get_charCode", null },
            .{ "keyCode", "get_keyCode", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            key: runtime.DOMString = undefined,
            code: runtime.DOMString = undefined,
            location: u32 = undefined,
            ctrlKey: bool = undefined,
            shiftKey: bool = undefined,
            altKey: bool = undefined,
            metaKey: bool = undefined,
            repeat: bool = undefined,
            isComposing: bool = undefined,
            charCode: u32 = undefined,
            keyCode: u32 = undefined,
            _internal: ?*KeyboardEventImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned long DOM_KEY_LOCATION_STANDARD = 0;
    pub fn get_DOM_KEY_LOCATION_STANDARD() u32 {
        return 0;
    }

    /// WebIDL constant: const unsigned long DOM_KEY_LOCATION_LEFT = 1;
    pub fn get_DOM_KEY_LOCATION_LEFT() u32 {
        return 1;
    }

    /// WebIDL constant: const unsigned long DOM_KEY_LOCATION_RIGHT = 2;
    pub fn get_DOM_KEY_LOCATION_RIGHT() u32 {
        return 2;
    }

    /// WebIDL constant: const unsigned long DOM_KEY_LOCATION_NUMPAD = 3;
    pub fn get_DOM_KEY_LOCATION_NUMPAD() u32 {
        return 3;
    }

    const delegates = .{
        .get_DOM_KEY_LOCATION_LEFT = &get_DOM_KEY_LOCATION_LEFT,
        .get_DOM_KEY_LOCATION_NUMPAD = &get_DOM_KEY_LOCATION_NUMPAD,
        .get_DOM_KEY_LOCATION_RIGHT = &get_DOM_KEY_LOCATION_RIGHT,
        .get_DOM_KEY_LOCATION_STANDARD = &get_DOM_KEY_LOCATION_STANDARD,
        .get_altKey = &get_altKey,
        .get_charCode = &get_charCode,
        .get_code = &get_code,
        .get_ctrlKey = &get_ctrlKey,
        .get_isComposing = &get_isComposing,
        .get_key = &get_key,
        .get_keyCode = &get_keyCode,
        .get_location = &get_location,
        .get_metaKey = &get_metaKey,
        .get_repeat = &get_repeat,
        .get_shiftKey = &get_shiftKey,

        .call_getModifierState = &call_getModifierState,
        .call_initKeyboardEvent = &call_initKeyboardEvent,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("KeyboardEvent has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(KeyboardEventImpl, "init") and @hasDecl(KeyboardEventImpl, "initOwn")) @compileError("KeyboardEventImpl defines both init and initOwn");
        if (comptime @hasDecl(KeyboardEventImpl, "init")) return KeyboardEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(KeyboardEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try KeyboardEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(KeyboardEventImpl, "init")) return false;
        if (comptime @hasDecl(KeyboardEventImpl, "construction_args")) {
            inline for (KeyboardEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(KeyboardEventImpl, "deinit") and @hasDecl(KeyboardEventImpl, "deinitOwn")) @compileError("KeyboardEventImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(KeyboardEventImpl, "deinit")) return KeyboardEventImpl.deinit(instance);
        if (comptime @hasDecl(KeyboardEventImpl, "deinitOwn")) KeyboardEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "KeyboardEvent")) {
            if (comptime @hasDecl(impls.KeyboardEvent, "installHooks")) impls.KeyboardEvent.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(KeyboardEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try KeyboardEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_key(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try KeyboardEventImpl.get_key(instance);
    }

    pub fn get_code(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try KeyboardEventImpl.get_code(instance);
    }

    pub fn get_location(instance: *runtime.Instance) anyerror!u32 {
        return try KeyboardEventImpl.get_location(instance);
    }

    pub fn get_ctrlKey(instance: *runtime.Instance) anyerror!bool {
        return try KeyboardEventImpl.get_ctrlKey(instance);
    }

    pub fn get_shiftKey(instance: *runtime.Instance) anyerror!bool {
        return try KeyboardEventImpl.get_shiftKey(instance);
    }

    pub fn get_altKey(instance: *runtime.Instance) anyerror!bool {
        return try KeyboardEventImpl.get_altKey(instance);
    }

    pub fn get_metaKey(instance: *runtime.Instance) anyerror!bool {
        return try KeyboardEventImpl.get_metaKey(instance);
    }

    pub fn get_repeat(instance: *runtime.Instance) anyerror!bool {
        return try KeyboardEventImpl.get_repeat(instance);
    }

    pub fn get_isComposing(instance: *runtime.Instance) anyerror!bool {
        return try KeyboardEventImpl.get_isComposing(instance);
    }

    pub fn get_charCode(instance: *runtime.Instance) anyerror!u32 {
        return try KeyboardEventImpl.get_charCode(instance);
    }

    pub fn get_keyCode(instance: *runtime.Instance) anyerror!u32 {
        return try KeyboardEventImpl.get_keyCode(instance);
    }

    pub fn call_getModifierState(instance: *runtime.Instance, keyArg: runtime.DOMString) anyerror!bool {
        return try KeyboardEventImpl.call_getModifierState(instance, keyArg);
    }

    pub fn call_initKeyboardEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, bubblesArg: webidl.Opt(bool), cancelableArg: webidl.Opt(bool), viewArg: webidl.Opt(?*runtime.Instance), keyArg: webidl.Opt(runtime.DOMString), locationArg: webidl.Opt(u32), ctrlKey: webidl.Opt(bool), altKey: webidl.Opt(bool), shiftKey: webidl.Opt(bool), metaKey: webidl.Opt(bool)) anyerror!void {
        return try KeyboardEventImpl.call_initKeyboardEvent(instance, typeArg, bubblesArg, cancelableArg, viewArg, keyArg, locationArg, ctrlKey, altKey, shiftKey, metaKey);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_initKeyboardEvent", 3, "Window" },
    };
};
