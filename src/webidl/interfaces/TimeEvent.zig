//! Generated from: svg-animations.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TimeEventImpl = @import("impls").TimeEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("interfaces").Event;
const Window = @import("interfaces").Window;
const EventTarget = @import("interfaces").EventTarget;
const WindowProxy = @import("typedefs").WindowProxy;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const TimeEvent = struct {
    pub const Meta = struct {
        pub const name = "TimeEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "view", "get_view", null },
            .{ "detail", "get_detail", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "initTimeEvent", "call_initTimeEvent", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "initTimeEvent",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "view", "get_view", null },
            .{ "detail", "get_detail", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            view: ?typedefs.WindowProxy = null,
            detail: i32 = undefined,
            _internal: ?*TimeEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_detail = &get_detail,
        .get_view = &get_view,

        .call_initTimeEvent = &call_initTimeEvent,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("TimeEvent has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(TimeEventImpl, "init") and @hasDecl(TimeEventImpl, "initOwn")) @compileError("TimeEventImpl defines both init and initOwn");
        if (comptime @hasDecl(TimeEventImpl, "init")) return TimeEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(TimeEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try TimeEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(TimeEventImpl, "init")) return false;
        if (comptime @hasDecl(TimeEventImpl, "construction_args")) {
            inline for (TimeEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(TimeEventImpl, "deinit") and @hasDecl(TimeEventImpl, "deinitOwn")) @compileError("TimeEventImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(TimeEventImpl, "deinit")) return TimeEventImpl.deinit(instance);
        if (comptime @hasDecl(TimeEventImpl, "deinitOwn")) TimeEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "TimeEvent")) {
            if (comptime @hasDecl(impls.TimeEvent, "installHooks")) impls.TimeEvent.installHooks();
        }
    }

    pub fn get_view(instance: *runtime.Instance) anyerror!?WindowProxy {
        return try TimeEventImpl.get_view(instance);
    }

    pub fn get_detail(instance: *runtime.Instance) anyerror!i32 {
        return try TimeEventImpl.get_detail(instance);
    }

    pub fn call_initTimeEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, viewArg: webidl.Opt(?*runtime.Instance), detailArg: webidl.Opt(i32)) anyerror!void {
        return try TimeEventImpl.call_initTimeEvent(instance, typeArg, viewArg, detailArg);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_initTimeEvent", 1, "Window" },
    };
};
