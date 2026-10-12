//! Generated from: IndexedDB.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IDBOpenDBRequestImpl = @import("impls").IDBOpenDBRequest;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const IDBRequest = @import("interfaces").IDBRequest;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const IDBRequestReadyState = @import("enums").IDBRequestReadyState;
const IDBIndex = @import("interfaces").IDBIndex;
const IDBTransaction = @import("interfaces").IDBTransaction;
const IDBObjectStore = @import("interfaces").IDBObjectStore;
const IDBCursor = @import("interfaces").IDBCursor;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMException = @import("interfaces").DOMException;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const IDBOpenDBRequest = struct {
    pub const Meta = struct {
        pub const name = "IDBOpenDBRequest";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = IDBRequest.State;
        pub const ParentInterface = IDBRequest;
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
            .{ "onblocked", "get_onblocked", "set_onblocked" },
            .{ "onupgradeneeded", "get_onupgradeneeded", "set_onupgradeneeded" },
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
            .{ "onblocked", "get_onblocked", "set_onblocked" },
            .{ "onupgradeneeded", "get_onupgradeneeded", "set_onupgradeneeded" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onblocked: typedefs.EventHandler = undefined,
            onupgradeneeded: typedefs.EventHandler = undefined,
            _internal: ?*IDBOpenDBRequestImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onblocked = &get_onblocked,
        .get_onupgradeneeded = &get_onupgradeneeded,

        .set_onblocked = &set_onblocked,
        .set_onupgradeneeded = &set_onupgradeneeded,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("IDBOpenDBRequest has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(IDBOpenDBRequestImpl, "init") and @hasDecl(IDBOpenDBRequestImpl, "initOwn")) @compileError("IDBOpenDBRequestImpl defines both init and initOwn");
        if (comptime @hasDecl(IDBOpenDBRequestImpl, "init")) return IDBOpenDBRequestImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(IDBOpenDBRequestImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try IDBOpenDBRequestImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(IDBOpenDBRequestImpl, "init")) return false;
        if (comptime @hasDecl(IDBOpenDBRequestImpl, "construction_args")) {
            inline for (IDBOpenDBRequestImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(IDBOpenDBRequestImpl, "deinit") and @hasDecl(IDBOpenDBRequestImpl, "deinitOwn")) @compileError("IDBOpenDBRequestImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(IDBOpenDBRequestImpl, "deinit")) return IDBOpenDBRequestImpl.deinit(instance);
        if (comptime @hasDecl(IDBOpenDBRequestImpl, "deinitOwn")) IDBOpenDBRequestImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "IDBOpenDBRequest")) {
            if (comptime @hasDecl(impls.IDBOpenDBRequest, "installHooks")) impls.IDBOpenDBRequest.installHooks();
        }
    }

    pub fn get_onblocked(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBOpenDBRequestImpl.get_onblocked(instance);
    }

    pub fn set_onblocked(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBOpenDBRequestImpl.set_onblocked(instance, value);
    }

    pub fn get_onupgradeneeded(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBOpenDBRequestImpl.get_onupgradeneeded(instance);
    }

    pub fn set_onupgradeneeded(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBOpenDBRequestImpl.set_onupgradeneeded(instance, value);
    }
};
