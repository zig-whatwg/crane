//! Generated from: longtasks.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TaskAttributionTimingImpl = @import("impls").TaskAttributionTiming;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMString = @import("typedefs").DOMString;

pub const TaskAttributionTiming = struct {
    pub const Meta = struct {
        pub const name = "TaskAttributionTiming";
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
            .{ "startTime", "get_startTime", null },
            .{ "duration", "get_duration", null },
            .{ "name", "get_name", null },
            .{ "entryType", "get_entryType", null },
            .{ "containerType", "get_containerType", null },
            .{ "containerSrc", "get_containerSrc", null },
            .{ "containerId", "get_containerId", null },
            .{ "containerName", "get_containerName", null },
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
            .{ "startTime", "get_startTime", null },
            .{ "duration", "get_duration", null },
            .{ "name", "get_name", null },
            .{ "entryType", "get_entryType", null },
            .{ "containerType", "get_containerType", null },
            .{ "containerSrc", "get_containerSrc", null },
            .{ "containerId", "get_containerId", null },
            .{ "containerName", "get_containerName", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            startTime: typedefs.DOMHighResTimeStamp = undefined,
            duration: typedefs.DOMHighResTimeStamp = undefined,
            name: runtime.DOMString = undefined,
            entryType: runtime.DOMString = undefined,
            containerType: runtime.DOMString = undefined,
            containerSrc: runtime.DOMString = undefined,
            containerId: runtime.DOMString = undefined,
            containerName: runtime.DOMString = undefined,
            _internal: ?*TaskAttributionTimingImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for TaskAttributionTiming
    /// Generated from [Default] toJSON extended attribute
    pub const TaskAttributionTimingToJSON = struct {
        id: u64,
        name: runtime.DOMString,
        entryType: runtime.DOMString,
        startTime: DOMHighResTimeStamp,
        duration: DOMHighResTimeStamp,
        navigationId: u64,
        containerType: runtime.DOMString,
        containerSrc: runtime.DOMString,
        containerId: runtime.DOMString,
        containerName: runtime.DOMString,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_containerId = &get_containerId,
        .get_containerName = &get_containerName,
        .get_containerSrc = &get_containerSrc,
        .get_containerType = &get_containerType,
        .get_duration = &get_duration,
        .get_entryType = &get_entryType,
        .get_name = &get_name,
        .get_startTime = &get_startTime,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("TaskAttributionTiming has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(TaskAttributionTimingImpl, "init") and @hasDecl(TaskAttributionTimingImpl, "initOwn")) @compileError("TaskAttributionTimingImpl defines both init and initOwn");
        if (comptime @hasDecl(TaskAttributionTimingImpl, "init")) return TaskAttributionTimingImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(TaskAttributionTimingImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try TaskAttributionTimingImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(TaskAttributionTimingImpl, "init")) return false;
        if (comptime @hasDecl(TaskAttributionTimingImpl, "construction_args")) {
            inline for (TaskAttributionTimingImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(TaskAttributionTimingImpl, "deinit") and @hasDecl(TaskAttributionTimingImpl, "deinitOwn")) @compileError("TaskAttributionTimingImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(TaskAttributionTimingImpl, "deinit")) return TaskAttributionTimingImpl.deinit(instance);
        if (comptime @hasDecl(TaskAttributionTimingImpl, "deinitOwn")) TaskAttributionTimingImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "TaskAttributionTiming")) {
            if (comptime @hasDecl(impls.TaskAttributionTiming, "installHooks")) impls.TaskAttributionTiming.installHooks();
        }
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try TaskAttributionTimingImpl.get_startTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try TaskAttributionTimingImpl.get_duration(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try TaskAttributionTimingImpl.get_name(instance);
    }

    pub fn get_entryType(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try TaskAttributionTimingImpl.get_entryType(instance);
    }

    pub fn get_containerType(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try TaskAttributionTimingImpl.get_containerType(instance);
    }

    pub fn get_containerSrc(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try TaskAttributionTimingImpl.get_containerSrc(instance);
    }

    pub fn get_containerId(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try TaskAttributionTimingImpl.get_containerId(instance);
    }

    pub fn get_containerName(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try TaskAttributionTimingImpl.get_containerName(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!TaskAttributionTimingToJSON {
        return try TaskAttributionTimingImpl.call_toJSON(instance);
    }
};
