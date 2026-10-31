//! Generated from: css-font-loading.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FontFaceSetImpl = @import("impls").FontFaceSet;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const CSSOMString = @import("typedefs").CSSOMString;
const FontFace = @import("interfaces").FontFace;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const FontFaceSetLoadStatus = @import("enums").FontFaceSetLoadStatus;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const FontFaceSet = struct {
    pub const Meta = struct {
        pub const name = "FontFaceSet";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onloading", "get_onloading", "set_onloading" },
            .{ "onloadingdone", "get_onloadingdone", "set_onloadingdone" },
            .{ "onloadingerror", "get_onloadingerror", "set_onloadingerror" },
            .{ "ready", "get_ready", null },
            .{ "status", "get_status", null },
            .{ "size", "get_size", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "add", "call_add", 1 },
            .{ "delete", "call_delete", 1 },
            .{ "clear", "call_clear", 0 },
            .{ "load", "call_load", 1 },
            .{ "check", "call_check", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "add",
            "delete",
            "clear",
            "load",
            "check",
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
            .{ "onloading", "get_onloading", "set_onloading" },
            .{ "onloadingdone", "get_onloadingdone", "set_onloadingdone" },
            .{ "onloadingerror", "get_onloadingerror", "set_onloadingerror" },
            .{ "ready", "get_ready", null },
            .{ "status", "get_status", null },
            .{ "size", "get_size", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onloading: typedefs.EventHandler = undefined,
            onloadingdone: typedefs.EventHandler = undefined,
            onloadingerror: typedefs.EventHandler = undefined,
            ready: runtime.JSValue = undefined,
            status: enums.FontFaceSetLoadStatus = undefined,
            size: u32 = undefined,
            _internal: ?*FontFaceSetImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    const delegates = .{
        .get_onloading = &get_onloading,
        .get_onloadingdone = &get_onloadingdone,
        .get_onloadingerror = &get_onloadingerror,
        .get_ready = &get_ready,
        .get_size = &get_size,
        .get_status = &get_status,

        .set_onloading = &set_onloading,
        .set_onloadingdone = &set_onloadingdone,
        .set_onloadingerror = &set_onloadingerror,

        .call_add = &call_add,
        .call_check = &call_check,
        .call_clear = &call_clear,
        .call_delete = &call_delete,
        .call_load = &call_load,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("FontFaceSet has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(FontFaceSetImpl, "init") and @hasDecl(FontFaceSetImpl, "initOwn")) @compileError("FontFaceSetImpl defines both init and initOwn");
        if (comptime @hasDecl(FontFaceSetImpl, "init")) return FontFaceSetImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(FontFaceSetImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try FontFaceSetImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(FontFaceSetImpl, "init")) return false;
        if (comptime @hasDecl(FontFaceSetImpl, "construction_args")) {
            inline for (FontFaceSetImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(FontFaceSetImpl, "deinit") and @hasDecl(FontFaceSetImpl, "deinitOwn")) @compileError("FontFaceSetImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(FontFaceSetImpl, "deinit")) return FontFaceSetImpl.deinit(instance);
        if (comptime @hasDecl(FontFaceSetImpl, "deinitOwn")) FontFaceSetImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "FontFaceSet")) {
            if (comptime @hasDecl(impls.FontFaceSet, "installHooks")) impls.FontFaceSet.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onloading(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(FontFaceSetImpl, "get_onloading")) return try FontFaceSetImpl.get_onloading(instance);
        return event_handlers.value(EventHandler, instance, "onloading");
    }

    pub fn set_onloading(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(FontFaceSetImpl, "set_onloading")) return try FontFaceSetImpl.set_onloading(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onloading", value);
    }

    pub fn get_onloadingdone(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(FontFaceSetImpl, "get_onloadingdone")) return try FontFaceSetImpl.get_onloadingdone(instance);
        return event_handlers.value(EventHandler, instance, "onloadingdone");
    }

    pub fn set_onloadingdone(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(FontFaceSetImpl, "set_onloadingdone")) return try FontFaceSetImpl.set_onloadingdone(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onloadingdone", value);
    }

    pub fn get_onloadingerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(FontFaceSetImpl, "get_onloadingerror")) return try FontFaceSetImpl.get_onloadingerror(instance);
        return event_handlers.value(EventHandler, instance, "onloadingerror");
    }

    pub fn set_onloadingerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(FontFaceSetImpl, "set_onloadingerror")) return try FontFaceSetImpl.set_onloadingerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onloadingerror", value);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try FontFaceSetImpl.get_ready(instance);
    }

    pub fn get_status(instance: *runtime.Instance) anyerror!FontFaceSetLoadStatus {
        return try FontFaceSetImpl.get_status(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try FontFaceSetImpl.get_size(instance);
    }

    pub fn call_delete(instance: *runtime.Instance, font: *runtime.Instance) anyerror!bool {
        return try FontFaceSetImpl.call_delete(instance, font);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try FontFaceSetImpl.call_clear(instance);
    }

    pub fn call_check(instance: *runtime.Instance, font: CSSOMString, text: webidl.Opt(CSSOMString)) anyerror!bool {
        return try FontFaceSetImpl.call_check(instance, font, text);
    }

    pub fn call_load(instance: *runtime.Instance, font: CSSOMString, text: webidl.Opt(CSSOMString)) anyerror!runtime.JSValue {
        return try FontFaceSetImpl.call_load(instance, font, text);
    }

    pub fn call_add(instance: *runtime.Instance, font: *runtime.Instance) anyerror!*runtime.Instance {
        return try FontFaceSetImpl.call_add(instance, font);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onloading", "set_onloadingdone", "set_onloadingerror" };

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_delete", 0, "FontFace" },
        .{ "call_add", 0, "FontFace" },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_load",
    };
};
