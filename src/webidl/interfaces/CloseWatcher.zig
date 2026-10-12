//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CloseWatcherImpl = @import("impls").CloseWatcher;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const CloseWatcherOptions = @import("dictionaries").CloseWatcherOptions;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const CloseWatcher = struct {
    pub const Meta = struct {
        pub const name = "CloseWatcher";
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
            .{ "oncancel", "get_oncancel", "set_oncancel" },
            .{ "onclose", "get_onclose", "set_onclose" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "requestClose", "call_requestClose", 0 },
            .{ "close", "call_close", 0 },
            .{ "destroy", "call_destroy", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestClose",
            "close",
            "destroy",
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
            .{ "oncancel", "get_oncancel", "set_oncancel" },
            .{ "onclose", "get_onclose", "set_onclose" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            oncancel: typedefs.EventHandler = undefined,
            onclose: typedefs.EventHandler = undefined,
            _internal: ?*CloseWatcherImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_oncancel = &get_oncancel,
        .get_onclose = &get_onclose,

        .set_oncancel = &set_oncancel,
        .set_onclose = &set_onclose,

        .call_close = &call_close,
        .call_destroy = &call_destroy,
        .call_requestClose = &call_requestClose,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("CloseWatcher has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(CloseWatcherImpl, "init") and @hasDecl(CloseWatcherImpl, "initOwn")) @compileError("CloseWatcherImpl defines both init and initOwn");
        if (comptime @hasDecl(CloseWatcherImpl, "init")) return CloseWatcherImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CloseWatcherImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CloseWatcherImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CloseWatcherImpl, "init")) return false;
        if (comptime @hasDecl(CloseWatcherImpl, "construction_args")) {
            inline for (CloseWatcherImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CloseWatcherImpl, "deinit") and @hasDecl(CloseWatcherImpl, "deinitOwn")) @compileError("CloseWatcherImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CloseWatcherImpl, "deinit")) return CloseWatcherImpl.deinit(instance);
        if (comptime @hasDecl(CloseWatcherImpl, "deinitOwn")) CloseWatcherImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CloseWatcher")) {
            if (comptime @hasDecl(impls.CloseWatcher, "installHooks")) impls.CloseWatcher.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, options: webidl.Opt(CloseWatcherOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CloseWatcherImpl.call_constructor(ctx, options);
    }

    pub fn get_oncancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try CloseWatcherImpl.get_oncancel(instance);
    }

    pub fn set_oncancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try CloseWatcherImpl.set_oncancel(instance, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try CloseWatcherImpl.get_onclose(instance);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try CloseWatcherImpl.set_onclose(instance, value);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try CloseWatcherImpl.call_close(instance);
    }

    pub fn call_requestClose(instance: *runtime.Instance) anyerror!void {
        return try CloseWatcherImpl.call_requestClose(instance);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try CloseWatcherImpl.call_destroy(instance);
    }
};
