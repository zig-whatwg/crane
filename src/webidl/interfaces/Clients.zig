//! Generated from: service-workers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ClientsImpl = @import("impls").Clients;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const WindowClient = @import("interfaces").WindowClient;
const ClientQueryOptions = @import("dictionaries").ClientQueryOptions;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const Clients = struct {
    pub const Meta = struct {
        pub const name = "Clients";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "get", "call_get", 1 },
            .{ "matchAll", "call_matchAll", 0 },
            .{ "openWindow", "call_openWindow", 1 },
            .{ "claim", "call_claim", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "get",
            "matchAll",
            "openWindow",
            "claim",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*ClientsImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_claim = &call_claim,
        .call_get = &call_get,
        .call_matchAll = &call_matchAll,
        .call_openWindow = &call_openWindow,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Clients has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ClientsImpl, "init") and @hasDecl(ClientsImpl, "initOwn")) @compileError("ClientsImpl defines both init and initOwn");
        if (comptime @hasDecl(ClientsImpl, "init")) return ClientsImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ClientsImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ClientsImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ClientsImpl, "init")) return false;
        if (comptime @hasDecl(ClientsImpl, "construction_args")) {
            inline for (ClientsImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(ClientsImpl, "deinit") and @hasDecl(ClientsImpl, "deinitOwn")) @compileError("ClientsImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ClientsImpl, "deinit")) return ClientsImpl.deinit(instance);
        if (comptime @hasDecl(ClientsImpl, "deinitOwn")) ClientsImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Clients")) {
            if (comptime @hasDecl(impls.Clients, "installHooks")) impls.Clients.installHooks();
        }
    }

    /// Extended attributes: [NewObject]
    pub fn call_claim(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try ClientsImpl.call_claim(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_matchAll(instance: *runtime.Instance, options: webidl.Opt(ClientQueryOptions)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try ClientsImpl.call_matchAll(instance, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_get(instance: *runtime.Instance, id: runtime.DOMString) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try ClientsImpl.call_get(instance, id);
    }

    /// Extended attributes: [NewObject]
    pub fn call_openWindow(instance: *runtime.Instance, url: runtime.USVString) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try ClientsImpl.call_openWindow(instance, url);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_claim",
        "call_matchAll",
        "call_get",
        "call_openWindow",
    };
};
