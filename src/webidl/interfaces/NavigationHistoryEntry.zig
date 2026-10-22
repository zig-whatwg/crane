//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigationHistoryEntryImpl = @import("impls").NavigationHistoryEntry;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const NavigationHistoryEntry = struct {
    pub const Meta = struct {
        pub const name = "NavigationHistoryEntry";
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
            .{ "url", "get_url", null },
            .{ "key", "get_key", null },
            .{ "id", "get_id", null },
            .{ "index", "get_index", null },
            .{ "sameDocument", "get_sameDocument", null },
            .{ "ondispose", "get_ondispose", "set_ondispose" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getState", "call_getState", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getState",
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
            .{ "url", "get_url", null },
            .{ "key", "get_key", null },
            .{ "id", "get_id", null },
            .{ "index", "get_index", null },
            .{ "sameDocument", "get_sameDocument", null },
            .{ "ondispose", "get_ondispose", "set_ondispose" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            url: ?runtime.USVString = null,
            key: runtime.DOMString = undefined,
            id: runtime.DOMString = undefined,
            index: i64 = undefined,
            sameDocument: bool = undefined,
            ondispose: typedefs.EventHandler = undefined,
            _internal: ?*NavigationHistoryEntryImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_id = &get_id,
        .get_index = &get_index,
        .get_key = &get_key,
        .get_ondispose = &get_ondispose,
        .get_sameDocument = &get_sameDocument,
        .get_url = &get_url,

        .set_ondispose = &set_ondispose,

        .call_getState = &call_getState,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("NavigationHistoryEntry has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(NavigationHistoryEntryImpl, "init") and @hasDecl(NavigationHistoryEntryImpl, "initOwn")) @compileError("NavigationHistoryEntryImpl defines both init and initOwn");
        if (comptime @hasDecl(NavigationHistoryEntryImpl, "init")) return NavigationHistoryEntryImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(NavigationHistoryEntryImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try NavigationHistoryEntryImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(NavigationHistoryEntryImpl, "init")) return false;
        if (comptime @hasDecl(NavigationHistoryEntryImpl, "construction_args")) {
            inline for (NavigationHistoryEntryImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(NavigationHistoryEntryImpl, "deinit") and @hasDecl(NavigationHistoryEntryImpl, "deinitOwn")) @compileError("NavigationHistoryEntryImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(NavigationHistoryEntryImpl, "deinit")) return NavigationHistoryEntryImpl.deinit(instance);
        if (comptime @hasDecl(NavigationHistoryEntryImpl, "deinitOwn")) NavigationHistoryEntryImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "NavigationHistoryEntry")) {
            if (comptime @hasDecl(impls.NavigationHistoryEntry, "installHooks")) impls.NavigationHistoryEntry.installHooks();
        }
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!?runtime.USVString {
        return try NavigationHistoryEntryImpl.get_url(instance);
    }

    pub fn get_key(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try NavigationHistoryEntryImpl.get_key(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try NavigationHistoryEntryImpl.get_id(instance);
    }

    pub fn get_index(instance: *runtime.Instance) anyerror!i64 {
        return try NavigationHistoryEntryImpl.get_index(instance);
    }

    pub fn get_sameDocument(instance: *runtime.Instance) anyerror!bool {
        return try NavigationHistoryEntryImpl.get_sameDocument(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_ondispose(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(NavigationHistoryEntryImpl, "get_ondispose")) return try NavigationHistoryEntryImpl.get_ondispose(instance);
        return event_handlers.value(EventHandler, instance, "ondispose");
    }

    pub fn set_ondispose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(NavigationHistoryEntryImpl, "set_ondispose")) return try NavigationHistoryEntryImpl.set_ondispose(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondispose", value);
    }

    pub fn call_getState(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NavigationHistoryEntryImpl.call_getState(instance);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_ondispose"};
};
