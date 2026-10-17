//! Generated from: uievents.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const UIEventImpl = @import("impls").UIEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("interfaces").Event;
const UIEventInit = @import("dictionaries").UIEventInit;
const Window = @import("interfaces").Window;
const EventTarget = @import("interfaces").EventTarget;
const InputDeviceCapabilities = @import("interfaces").InputDeviceCapabilities;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const UIEvent = struct {
    pub const Meta = struct {
        pub const name = "UIEvent";
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
            .{ "sourceCapabilities", "get_sourceCapabilities", null },
            .{ "which", "get_which", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "initUIEvent", "call_initUIEvent", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "initUIEvent",
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
            .{ "sourceCapabilities", "get_sourceCapabilities", null },
            .{ "which", "get_which", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            view: ?*runtime.Instance = null,
            detail: i32 = undefined,
            sourceCapabilities: ?*runtime.Instance = null,
            which: u32 = undefined,
            _internal: ?*UIEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_detail = &get_detail,
        .get_sourceCapabilities = &get_sourceCapabilities,
        .get_view = &get_view,
        .get_which = &get_which,

        .call_initUIEvent = &call_initUIEvent,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("UIEvent has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(UIEventImpl, "init") and @hasDecl(UIEventImpl, "initOwn")) @compileError("UIEventImpl defines both init and initOwn");
        if (comptime @hasDecl(UIEventImpl, "init")) return UIEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(UIEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try UIEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(UIEventImpl, "init")) return false;
        if (comptime @hasDecl(UIEventImpl, "construction_args")) {
            inline for (UIEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(UIEventImpl, "deinit") and @hasDecl(UIEventImpl, "deinitOwn")) @compileError("UIEventImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(UIEventImpl, "deinit")) return UIEventImpl.deinit(instance);
        if (comptime @hasDecl(UIEventImpl, "deinitOwn")) UIEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "UIEvent")) {
            if (comptime @hasDecl(impls.UIEvent, "installHooks")) impls.UIEvent.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(UIEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try UIEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_view(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try UIEventImpl.get_view(instance);
    }

    pub fn get_detail(instance: *runtime.Instance) anyerror!i32 {
        return try UIEventImpl.get_detail(instance);
    }

    pub fn get_sourceCapabilities(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try UIEventImpl.get_sourceCapabilities(instance);
    }

    pub fn get_which(instance: *runtime.Instance) anyerror!u32 {
        return try UIEventImpl.get_which(instance);
    }

    pub fn call_initUIEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, bubblesArg: webidl.Opt(bool), cancelableArg: webidl.Opt(bool), viewArg: webidl.Opt(?*runtime.Instance), detailArg: webidl.Opt(i32)) anyerror!void {
        return try UIEventImpl.call_initUIEvent(instance, typeArg, bubblesArg, cancelableArg, viewArg, detailArg);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_initUIEvent", 3, "Window" },
    };
};
