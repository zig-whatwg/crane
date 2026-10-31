//! Generated from: pointerevents.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WheelEventImpl = @import("impls").WheelEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MouseEvent = @import("interfaces").MouseEvent;
const UIEventInit = @import("dictionaries").UIEventInit;
const Window = @import("interfaces").Window;
const EventTarget = @import("interfaces").EventTarget;
const WheelEventInit = @import("dictionaries").WheelEventInit;
const InputDeviceCapabilities = @import("interfaces").InputDeviceCapabilities;
const MouseEventInit = @import("dictionaries").MouseEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const WheelEvent = struct {
    pub const Meta = struct {
        pub const name = "WheelEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = MouseEvent.State;
        pub const ParentInterface = MouseEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "deltaX", "get_deltaX", null },
            .{ "deltaY", "get_deltaY", null },
            .{ "deltaZ", "get_deltaZ", null },
            .{ "deltaMode", "get_deltaMode", null },
            .{ "momentum", "get_momentum", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "DOM_DELTA_PIXEL", "get_DOM_DELTA_PIXEL" },
            .{ "DOM_DELTA_LINE", "get_DOM_DELTA_LINE" },
            .{ "DOM_DELTA_PAGE", "get_DOM_DELTA_PAGE" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
            "initUIEvent",
            "getModifierState",
            "initMouseEvent",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "deltaX", "get_deltaX", null },
            .{ "deltaY", "get_deltaY", null },
            .{ "deltaZ", "get_deltaZ", null },
            .{ "deltaMode", "get_deltaMode", null },
            .{ "momentum", "get_momentum", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            deltaX: f64 = undefined,
            deltaY: f64 = undefined,
            deltaZ: f64 = undefined,
            deltaMode: u32 = undefined,
            momentum: bool = undefined,
            _internal: ?*WheelEventImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned long DOM_DELTA_PIXEL = 0;
    pub fn get_DOM_DELTA_PIXEL() u32 {
        return 0;
    }

    /// WebIDL constant: const unsigned long DOM_DELTA_LINE = 1;
    pub fn get_DOM_DELTA_LINE() u32 {
        return 1;
    }

    /// WebIDL constant: const unsigned long DOM_DELTA_PAGE = 2;
    pub fn get_DOM_DELTA_PAGE() u32 {
        return 2;
    }

    const delegates = .{
        .get_DOM_DELTA_LINE = &get_DOM_DELTA_LINE,
        .get_DOM_DELTA_PAGE = &get_DOM_DELTA_PAGE,
        .get_DOM_DELTA_PIXEL = &get_DOM_DELTA_PIXEL,
        .get_deltaMode = &get_deltaMode,
        .get_deltaX = &get_deltaX,
        .get_deltaY = &get_deltaY,
        .get_deltaZ = &get_deltaZ,
        .get_momentum = &get_momentum,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("WheelEvent has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(WheelEventImpl, "init") and @hasDecl(WheelEventImpl, "initOwn")) @compileError("WheelEventImpl defines both init and initOwn");
        if (comptime @hasDecl(WheelEventImpl, "init")) return WheelEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(WheelEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try WheelEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(WheelEventImpl, "init")) return false;
        if (comptime @hasDecl(WheelEventImpl, "construction_args")) {
            inline for (WheelEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(WheelEventImpl, "deinit") and @hasDecl(WheelEventImpl, "deinitOwn")) @compileError("WheelEventImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(WheelEventImpl, "deinit")) return WheelEventImpl.deinit(instance);
        if (comptime @hasDecl(WheelEventImpl, "deinitOwn")) WheelEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "WheelEvent")) {
            if (comptime @hasDecl(impls.WheelEvent, "installHooks")) impls.WheelEvent.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(WheelEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try WheelEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_deltaX(instance: *runtime.Instance) anyerror!f64 {
        return try WheelEventImpl.get_deltaX(instance);
    }

    pub fn get_deltaY(instance: *runtime.Instance) anyerror!f64 {
        return try WheelEventImpl.get_deltaY(instance);
    }

    pub fn get_deltaZ(instance: *runtime.Instance) anyerror!f64 {
        return try WheelEventImpl.get_deltaZ(instance);
    }

    pub fn get_deltaMode(instance: *runtime.Instance) anyerror!u32 {
        return try WheelEventImpl.get_deltaMode(instance);
    }

    pub fn get_momentum(instance: *runtime.Instance) anyerror!bool {
        return try WheelEventImpl.get_momentum(instance);
    }
};
