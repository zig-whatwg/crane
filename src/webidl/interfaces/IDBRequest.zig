//! Generated from: IndexedDB.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IDBRequestImpl = @import("impls").IDBRequest;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const IDBRequestReadyState = @import("enums").IDBRequestReadyState;
const IDBIndex = @import("interfaces").IDBIndex;
const IDBTransaction = @import("interfaces").IDBTransaction;
const Observable = @import("interfaces").Observable;
const IDBCursor = @import("interfaces").IDBCursor;
const Event = @import("interfaces").Event;
const IDBObjectStore = @import("interfaces").IDBObjectStore;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMException = @import("interfaces").DOMException;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const IDBRequest = struct {
    pub const Meta = struct {
        pub const name = "IDBRequest";
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
            .{ "result", "get_result", null },
            .{ "error", "get_error", null },
            .{ "source", "get_source", null },
            .{ "transaction", "get_transaction", null },
            .{ "readyState", "get_readyState", null },
            .{ "onsuccess", "get_onsuccess", "set_onsuccess" },
            .{ "onerror", "get_onerror", "set_onerror" },
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
            .{ "result", "get_result", null },
            .{ "error", "get_error", null },
            .{ "source", "get_source", null },
            .{ "transaction", "get_transaction", null },
            .{ "readyState", "get_readyState", null },
            .{ "onsuccess", "get_onsuccess", "set_onsuccess" },
            .{ "onerror", "get_onerror", "set_onerror" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            result: runtime.JSValue = undefined,
            @"error": ?*runtime.Instance = null,
            source: ?union(enum) {
                IDBObjectStore: IDBObjectStore,
                IDBIndex: IDBIndex,
                IDBCursor: IDBCursor,
            } = null,
            transaction: ?*runtime.Instance = null,
            readyState: enums.IDBRequestReadyState = undefined,
            onsuccess: typedefs.EventHandler = undefined,
            onerror: typedefs.EventHandler = undefined,
            _internal: ?*IDBRequestImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_error = &get_error,
        .get_onerror = &get_onerror,
        .get_onsuccess = &get_onsuccess,
        .get_readyState = &get_readyState,
        .get_result = &get_result,
        .get_source = &get_source,
        .get_transaction = &get_transaction,

        .set_onerror = &set_onerror,
        .set_onsuccess = &set_onsuccess,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("IDBRequest has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(IDBRequestImpl, "init") and @hasDecl(IDBRequestImpl, "initOwn")) @compileError("IDBRequestImpl defines both init and initOwn");
        if (comptime @hasDecl(IDBRequestImpl, "init")) return IDBRequestImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(IDBRequestImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try IDBRequestImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(IDBRequestImpl, "init")) return false;
        if (comptime @hasDecl(IDBRequestImpl, "construction_args")) {
            inline for (IDBRequestImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(IDBRequestImpl, "deinit") and @hasDecl(IDBRequestImpl, "deinitOwn")) @compileError("IDBRequestImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(IDBRequestImpl, "deinit")) return IDBRequestImpl.deinit(instance);
        if (comptime @hasDecl(IDBRequestImpl, "deinitOwn")) IDBRequestImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "IDBRequest")) {
            if (comptime @hasDecl(impls.IDBRequest, "installHooks")) impls.IDBRequest.installHooks();
        }
    }

    pub fn get_result(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IDBRequestImpl.get_result(instance);
    }

    pub fn get_error(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try IDBRequestImpl.get_error(instance);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try IDBRequestImpl.get_source(instance);
    }

    pub fn get_transaction(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try IDBRequestImpl.get_transaction(instance);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyerror!IDBRequestReadyState {
        return try IDBRequestImpl.get_readyState(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onsuccess(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(IDBRequestImpl, "get_onsuccess")) return try IDBRequestImpl.get_onsuccess(instance);
        return event_handlers.value(EventHandler, instance, "onsuccess");
    }

    pub fn set_onsuccess(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(IDBRequestImpl, "set_onsuccess")) return try IDBRequestImpl.set_onsuccess(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onsuccess", value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(IDBRequestImpl, "get_onerror")) return try IDBRequestImpl.get_onerror(instance);
        return event_handlers.value(EventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(IDBRequestImpl, "set_onerror")) return try IDBRequestImpl.set_onerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onerror", value);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onsuccess", "set_onerror" };
};
