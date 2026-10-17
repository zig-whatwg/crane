//! Generated from: service-workers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WindowClientImpl = @import("impls").WindowClient;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Client = @import("interfaces").Client;
const ClientType = @import("enums").ClientType;
const FrameType = @import("enums").FrameType;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const ClientLifecycleState = @import("enums").ClientLifecycleState;
const DocumentVisibilityState = @import("enums").DocumentVisibilityState;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const WindowClient = struct {
    pub const Meta = struct {
        pub const name = "WindowClient";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Client.State;
        pub const ParentInterface = Client;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "visibilityState", "get_visibilityState", null },
            .{ "focused", "get_focused", null },
            .{ "ancestorOrigins", "get_ancestorOrigins", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "focus", "call_focus", 0 },
            .{ "navigate", "call_navigate", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "focus",
            "navigate",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "postMessage",
            "postMessage",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "visibilityState", "get_visibilityState", null },
            .{ "focused", "get_focused", null },
            .{ "ancestorOrigins", "get_ancestorOrigins", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            visibilityState: enums.DocumentVisibilityState = undefined,
            focused: bool = undefined,
            ancestorOrigins: runtime.JSValue = undefined,
            cached_ancestorOrigins: ?runtime.JSValue = null,
            _internal: ?*WindowClientImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_ancestorOrigins = &get_ancestorOrigins,
        .get_focused = &get_focused,
        .get_visibilityState = &get_visibilityState,

        .call_focus = &call_focus,
        .call_navigate = &call_navigate,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("WindowClient has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(WindowClientImpl, "init") and @hasDecl(WindowClientImpl, "initOwn")) @compileError("WindowClientImpl defines both init and initOwn");
        if (comptime @hasDecl(WindowClientImpl, "init")) return WindowClientImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(WindowClientImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try WindowClientImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(WindowClientImpl, "init")) return false;
        if (comptime @hasDecl(WindowClientImpl, "construction_args")) {
            inline for (WindowClientImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(WindowClientImpl, "deinit") and @hasDecl(WindowClientImpl, "deinitOwn")) @compileError("WindowClientImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(WindowClientImpl, "deinit")) return WindowClientImpl.deinit(instance);
        if (comptime @hasDecl(WindowClientImpl, "deinitOwn")) WindowClientImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "WindowClient")) {
            if (comptime @hasDecl(impls.WindowClient, "installHooks")) impls.WindowClient.installHooks();
        }
    }

    pub fn get_visibilityState(instance: *runtime.Instance) anyerror!DocumentVisibilityState {
        return try WindowClientImpl.get_visibilityState(instance);
    }

    pub fn get_focused(instance: *runtime.Instance) anyerror!bool {
        return try WindowClientImpl.get_focused(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_ancestorOrigins(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try WindowClientImpl.get_ancestorOrigins(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_navigate(instance: *runtime.Instance, url: runtime.USVString) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try WindowClientImpl.call_navigate(instance, url);
    }

    /// Extended attributes: [NewObject]
    pub fn call_focus(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try WindowClientImpl.call_focus(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_navigate",
        "call_focus",
    };
};
