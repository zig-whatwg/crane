//! Generated from: keyboard-lock.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const KeyboardImpl = @import("impls").Keyboard;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const KeyboardLayoutMap = @import("interfaces").KeyboardLayoutMap;
const EventHandler = @import("typedefs").EventHandler;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const Keyboard = struct {
    pub const Meta = struct {
        pub const name = "Keyboard";
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
            .{ "onlayoutchange", "get_onlayoutchange", "set_onlayoutchange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "lock", "call_lock", 0 },
            .{ "unlock", "call_unlock", 0 },
            .{ "getLayoutMap", "call_getLayoutMap", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "lock",
            "unlock",
            "getLayoutMap",
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
            .{ "onlayoutchange", "get_onlayoutchange", "set_onlayoutchange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onlayoutchange: typedefs.EventHandler = undefined,
            _internal: ?*KeyboardImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onlayoutchange = &get_onlayoutchange,

        .set_onlayoutchange = &set_onlayoutchange,

        .call_getLayoutMap = &call_getLayoutMap,
        .call_lock = &call_lock,
        .call_unlock = &call_unlock,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Keyboard has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(KeyboardImpl, "init") and @hasDecl(KeyboardImpl, "initOwn")) @compileError("KeyboardImpl defines both init and initOwn");
        if (comptime @hasDecl(KeyboardImpl, "init")) return KeyboardImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(KeyboardImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try KeyboardImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(KeyboardImpl, "init")) return false;
        if (comptime @hasDecl(KeyboardImpl, "construction_args")) {
            inline for (KeyboardImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(KeyboardImpl, "deinit") and @hasDecl(KeyboardImpl, "deinitOwn")) @compileError("KeyboardImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(KeyboardImpl, "deinit")) return KeyboardImpl.deinit(instance);
        if (comptime @hasDecl(KeyboardImpl, "deinitOwn")) KeyboardImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Keyboard")) {
            if (comptime @hasDecl(impls.Keyboard, "installHooks")) impls.Keyboard.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onlayoutchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(KeyboardImpl, "get_onlayoutchange")) return try KeyboardImpl.get_onlayoutchange(instance);
        return event_handlers.value(EventHandler, instance, "onlayoutchange");
    }

    pub fn set_onlayoutchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(KeyboardImpl, "set_onlayoutchange")) return try KeyboardImpl.set_onlayoutchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onlayoutchange", value);
    }

    pub fn call_unlock(instance: *runtime.Instance) anyerror!void {
        return try KeyboardImpl.call_unlock(instance);
    }

    pub fn call_getLayoutMap(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try KeyboardImpl.call_getLayoutMap(instance);
    }

    pub fn call_lock(instance: *runtime.Instance, keyCodes: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try KeyboardImpl.call_lock(instance, keyCodes);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_onlayoutchange"};

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_getLayoutMap",
        "call_lock",
    };
};
