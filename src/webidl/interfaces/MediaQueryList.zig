//! Generated from: cssom-view.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaQueryListImpl = @import("impls").MediaQueryList;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const CSSOMString = @import("typedefs").CSSOMString;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const MediaQueryList = struct {
    pub const Meta = struct {
        pub const name = "MediaQueryList";
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
            .{ "media", "get_media", null },
            .{ "matches", "get_matches", null },
            .{ "onchange", "get_onchange", "set_onchange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "addListener", "call_addListener", 1 },
            .{ "removeListener", "call_removeListener", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "addListener",
            "removeListener",
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
            .{ "media", "get_media", null },
            .{ "matches", "get_matches", null },
            .{ "onchange", "get_onchange", "set_onchange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            media: typedefs.CSSOMString = undefined,
            matches: bool = undefined,
            onchange: typedefs.EventHandler = undefined,
            _internal: ?*MediaQueryListImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_matches = &get_matches,
        .get_media = &get_media,
        .get_onchange = &get_onchange,

        .set_onchange = &set_onchange,

        .call_addListener = &call_addListener,
        .call_removeListener = &call_removeListener,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("MediaQueryList has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(MediaQueryListImpl, "init") and @hasDecl(MediaQueryListImpl, "initOwn")) @compileError("MediaQueryListImpl defines both init and initOwn");
        if (comptime @hasDecl(MediaQueryListImpl, "init")) return MediaQueryListImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(MediaQueryListImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try MediaQueryListImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MediaQueryListImpl, "init")) return false;
        if (comptime @hasDecl(MediaQueryListImpl, "construction_args")) {
            inline for (MediaQueryListImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MediaQueryListImpl, "deinit") and @hasDecl(MediaQueryListImpl, "deinitOwn")) @compileError("MediaQueryListImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MediaQueryListImpl, "deinit")) return MediaQueryListImpl.deinit(instance);
        if (comptime @hasDecl(MediaQueryListImpl, "deinitOwn")) MediaQueryListImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MediaQueryList")) {
            if (comptime @hasDecl(impls.MediaQueryList, "installHooks")) impls.MediaQueryList.installHooks();
        }
    }

    pub fn get_media(instance: *runtime.Instance) anyerror!CSSOMString {
        return try MediaQueryListImpl.get_media(instance);
    }

    pub fn get_matches(instance: *runtime.Instance) anyerror!bool {
        return try MediaQueryListImpl.get_matches(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MediaQueryListImpl, "get_onchange")) return try MediaQueryListImpl.get_onchange(instance);
        return event_handlers.value(EventHandler, instance, "onchange");
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MediaQueryListImpl, "set_onchange")) return try MediaQueryListImpl.set_onchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onchange", value);
    }

    pub fn call_addListener(instance: *runtime.Instance, callback: ??*runtime.CallbackWrapper) anyerror!void {
        return try MediaQueryListImpl.call_addListener(instance, callback);
    }

    pub fn call_removeListener(instance: *runtime.Instance, callback: ??*runtime.CallbackWrapper) anyerror!void {
        return try MediaQueryListImpl.call_removeListener(instance, callback);
    }
};
