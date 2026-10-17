//! Generated from: scheduling-apis.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TaskSignalImpl = @import("impls").TaskSignal;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AbortSignal = @import("interfaces").AbortSignal;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Observable = @import("interfaces").Observable;
const TaskPriority = @import("enums").TaskPriority;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const EventListener = @import("interfaces").EventListener;
const TaskSignalAnyInit = @import("dictionaries").TaskSignalAnyInit;
const EventHandler = @import("typedefs").EventHandler;

pub const TaskSignal = struct {
    pub const Meta = struct {
        pub const name = "TaskSignal";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = AbortSignal.State;
        pub const ParentInterface = AbortSignal;
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
            .{ "priority", "get_priority", null },
            .{ "onprioritychange", "get_onprioritychange", "set_onprioritychange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "any", "call_static_any", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "any",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "abort",
            "timeout",
            "throwIfAborted",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "priority", "get_priority", null },
            .{ "onprioritychange", "get_onprioritychange", "set_onprioritychange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            priority: enums.TaskPriority = undefined,
            onprioritychange: typedefs.EventHandler = undefined,
            _internal: ?*TaskSignalImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onprioritychange = &get_onprioritychange,
        .get_priority = &get_priority,

        .set_onprioritychange = &set_onprioritychange,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("TaskSignal has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(TaskSignalImpl, "init") and @hasDecl(TaskSignalImpl, "initOwn")) @compileError("TaskSignalImpl defines both init and initOwn");
        if (comptime @hasDecl(TaskSignalImpl, "init")) return TaskSignalImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(TaskSignalImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try TaskSignalImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(TaskSignalImpl, "init")) return false;
        if (comptime @hasDecl(TaskSignalImpl, "construction_args")) {
            inline for (TaskSignalImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(TaskSignalImpl, "deinit") and @hasDecl(TaskSignalImpl, "deinitOwn")) @compileError("TaskSignalImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(TaskSignalImpl, "deinit")) return TaskSignalImpl.deinit(instance);
        if (comptime @hasDecl(TaskSignalImpl, "deinitOwn")) TaskSignalImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "TaskSignal")) {
            if (comptime @hasDecl(impls.TaskSignal, "installHooks")) impls.TaskSignal.installHooks();
        }
    }

    pub fn get_priority(instance: *runtime.Instance) anyerror!TaskPriority {
        return try TaskSignalImpl.get_priority(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onprioritychange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(TaskSignalImpl, "get_onprioritychange")) return try TaskSignalImpl.get_onprioritychange(instance);
        return event_handlers.value(EventHandler, instance, "onprioritychange");
    }

    pub fn set_onprioritychange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(TaskSignalImpl, "set_onprioritychange")) return try TaskSignalImpl.set_onprioritychange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onprioritychange", value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_any(instance: *runtime.Instance, signals: runtime.JSValue, init_data: webidl.Opt(TaskSignalAnyInit)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try TaskSignalImpl.call_static_any(instance, signals, init_data);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_static_any", 0, "AbortSignal" },
    };
};
