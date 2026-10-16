//! Generated from: cookiestore.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CookieStoreImpl = @import("impls").CookieStore;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const CookieStoreGetOptions = @import("dictionaries").CookieStoreGetOptions;
const CookieStoreDeleteOptions = @import("dictionaries").CookieStoreDeleteOptions;
const USVString = @import("typedefs").USVString;
const CookieListItem = @import("dictionaries").CookieListItem;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const CookieList = @import("typedefs").CookieList;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const CookieInit = @import("dictionaries").CookieInit;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const CookieStore = struct {
    pub const Meta = struct {
        pub const name = "CookieStore";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "ServiceWorker", "Window" } } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .ServiceWorker = true,
            .Window = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onchange", "get_onchange", "set_onchange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "get", "call_get", 0 },
            .{ "getAll", "call_getAll", 0 },
            .{ "set", "call_set", 1 },
            .{ "delete", "call_delete", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "get",
            "getAll",
            "set",
            "delete",
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
            onchange: typedefs.EventHandler = undefined,
            _internal: ?*CookieStoreImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onchange = &get_onchange,

        .set_onchange = &set_onchange,

        .call_delete = &call_delete,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_set = &call_set,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("CookieStore has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(CookieStoreImpl, "init") and @hasDecl(CookieStoreImpl, "initOwn")) @compileError("CookieStoreImpl defines both init and initOwn");
        if (comptime @hasDecl(CookieStoreImpl, "init")) return CookieStoreImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CookieStoreImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CookieStoreImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CookieStoreImpl, "init")) return false;
        if (comptime @hasDecl(CookieStoreImpl, "construction_args")) {
            inline for (CookieStoreImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CookieStoreImpl, "deinit") and @hasDecl(CookieStoreImpl, "deinitOwn")) @compileError("CookieStoreImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CookieStoreImpl, "deinit")) return CookieStoreImpl.deinit(instance);
        if (comptime @hasDecl(CookieStoreImpl, "deinitOwn")) CookieStoreImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CookieStore")) {
            if (comptime @hasDecl(impls.CookieStore, "installHooks")) impls.CookieStore.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    /// Extended attributes: [Exposed=Window]
    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(CookieStoreImpl, "get_onchange")) return try CookieStoreImpl.get_onchange(instance);
        return event_handlers.value(EventHandler, instance, "onchange");
    }

    /// Extended attributes: [Exposed=Window]
    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(CookieStoreImpl, "set_onchange")) return try CookieStoreImpl.set_onchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onchange", value);
    }

    pub fn call_set(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!runtime.JSValue {
        return try CookieStoreImpl.call_set(instance, name, value);
    }

    pub fn call_get(instance: *runtime.Instance, name: runtime.USVString) anyerror!runtime.JSValue {
        return try CookieStoreImpl.call_get(instance, name);
    }

    pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) anyerror!runtime.JSValue {
        return try CookieStoreImpl.call_getAll(instance, name);
    }

    pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString) anyerror!runtime.JSValue {
        return try CookieStoreImpl.call_delete(instance, name);
    }

    pub fn call_set__1(instance: *runtime.Instance, options: CookieInit) anyerror!runtime.JSValue {
        if (comptime @hasDecl(CookieStoreImpl, "call_set__1")) {
            return try CookieStoreImpl.call_set__1(instance, options);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_get__1(instance: *runtime.Instance, options: webidl.Opt(CookieStoreGetOptions)) anyerror!runtime.JSValue {
        if (comptime @hasDecl(CookieStoreImpl, "call_get__1")) {
            return try CookieStoreImpl.call_get__1(instance, options);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_getAll__1(instance: *runtime.Instance, options: webidl.Opt(CookieStoreGetOptions)) anyerror!runtime.JSValue {
        if (comptime @hasDecl(CookieStoreImpl, "call_getAll__1")) {
            return try CookieStoreImpl.call_getAll__1(instance, options);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_delete__1(instance: *runtime.Instance, options: CookieStoreDeleteOptions) anyerror!runtime.JSValue {
        if (comptime @hasDecl(CookieStoreImpl, "call_delete__1")) {
            return try CookieStoreImpl.call_delete__1(instance, options);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "set", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_set", .args = &.{ .{ .kinds = &.{.string} }, .{ .kinds = &.{.string} } } },
            .{ .function = "call_set__1", .implemented = @hasDecl(CookieStoreImpl, "call_set__1"), .args = &.{.{ .kinds = &.{.dictionary} }} },
        } },
        .{ "get", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_get", .args = &.{.{ .kinds = &.{.string} }} },
            .{ .function = "call_get__1", .implemented = @hasDecl(CookieStoreImpl, "call_get__1"), .args = &.{.{ .kinds = &.{.dictionary}, .optionality = .optional }} },
        } },
        .{ "getAll", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_getAll", .args = &.{.{ .kinds = &.{.string} }} },
            .{ .function = "call_getAll__1", .implemented = @hasDecl(CookieStoreImpl, "call_getAll__1"), .args = &.{.{ .kinds = &.{.dictionary}, .optionality = .optional }} },
        } },
        .{ "delete", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_delete", .args = &.{.{ .kinds = &.{.string} }} },
            .{ .function = "call_delete__1", .implemented = @hasDecl(CookieStoreImpl, "call_delete__1"), .args = &.{.{ .kinds = &.{.dictionary} }} },
        } },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_set",
        "call_set__1",
        "call_get",
        "call_get__1",
        "call_getAll",
        "call_getAll__1",
        "call_delete",
        "call_delete__1",
    };
};
