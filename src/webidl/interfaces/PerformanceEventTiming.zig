//! Generated from: event-timing.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PerformanceEventTimingImpl = @import("impls").PerformanceEventTiming;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const Node = @import("interfaces").Node;
const DOMString = @import("typedefs").DOMString;

pub const PerformanceEventTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceEventTiming";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = PerformanceEntry.State;
        pub const ParentInterface = PerformanceEntry;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "processingStart", "get_processingStart", null },
            .{ "processingEnd", "get_processingEnd", null },
            .{ "cancelable", "get_cancelable", null },
            .{ "target", "get_target", null },
            .{ "targetSelector", "get_targetSelector", null },
            .{ "interactionId", "get_interactionId", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "processingStart", "get_processingStart", null },
            .{ "processingEnd", "get_processingEnd", null },
            .{ "cancelable", "get_cancelable", null },
            .{ "target", "get_target", null },
            .{ "targetSelector", "get_targetSelector", null },
            .{ "interactionId", "get_interactionId", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            processingStart: typedefs.DOMHighResTimeStamp = undefined,
            processingEnd: typedefs.DOMHighResTimeStamp = undefined,
            cancelable: bool = undefined,
            target: ?*runtime.Instance = null,
            targetSelector: runtime.DOMString = undefined,
            interactionId: u64 = undefined,
            _internal: ?*PerformanceEventTimingImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for PerformanceEventTiming
    /// Generated from [Default] toJSON extended attribute
    pub const PerformanceEventTimingToJSON = struct {
        id: u64,
        name: runtime.DOMString,
        entryType: runtime.DOMString,
        startTime: DOMHighResTimeStamp,
        duration: DOMHighResTimeStamp,
        navigationId: u64,
        processingStart: DOMHighResTimeStamp,
        processingEnd: DOMHighResTimeStamp,
        cancelable: bool,
        target: ?*runtime.Instance,
        targetSelector: runtime.DOMString,
        interactionId: u64,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_cancelable = &get_cancelable,
        .get_interactionId = &get_interactionId,
        .get_processingEnd = &get_processingEnd,
        .get_processingStart = &get_processingStart,
        .get_target = &get_target,
        .get_targetSelector = &get_targetSelector,

        .call_toJSON = &call_toJSON,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("PerformanceEventTiming has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(PerformanceEventTimingImpl, "init") and @hasDecl(PerformanceEventTimingImpl, "initOwn")) @compileError("PerformanceEventTimingImpl defines both init and initOwn");
        if (comptime @hasDecl(PerformanceEventTimingImpl, "init")) return PerformanceEventTimingImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(PerformanceEventTimingImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try PerformanceEventTimingImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PerformanceEventTimingImpl, "init")) return false;
        if (comptime @hasDecl(PerformanceEventTimingImpl, "construction_args")) {
            inline for (PerformanceEventTimingImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PerformanceEventTimingImpl, "deinit") and @hasDecl(PerformanceEventTimingImpl, "deinitOwn")) @compileError("PerformanceEventTimingImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PerformanceEventTimingImpl, "deinit")) return PerformanceEventTimingImpl.deinit(instance);
        if (comptime @hasDecl(PerformanceEventTimingImpl, "deinitOwn")) PerformanceEventTimingImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PerformanceEventTiming")) {
            if (comptime @hasDecl(impls.PerformanceEventTiming, "installHooks")) impls.PerformanceEventTiming.installHooks();
        }
    }

    pub fn get_processingStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceEventTimingImpl.get_processingStart(instance);
    }

    pub fn get_processingEnd(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceEventTimingImpl.get_processingEnd(instance);
    }

    pub fn get_cancelable(instance: *runtime.Instance) anyerror!bool {
        return try PerformanceEventTimingImpl.get_cancelable(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try PerformanceEventTimingImpl.get_target(instance);
    }

    pub fn get_targetSelector(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try PerformanceEventTimingImpl.get_targetSelector(instance);
    }

    pub fn get_interactionId(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceEventTimingImpl.get_interactionId(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PerformanceEventTimingToJSON {
        return try PerformanceEventTimingImpl.call_toJSON(instance);
    }
};
