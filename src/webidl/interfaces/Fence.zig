//! Generated from: fenced-frame.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FenceImpl = @import("impls").Fence;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const FenceEvent = @import("dictionaries").FenceEvent;
const FencedFrameConfig = @import("interfaces").FencedFrameConfig;
const ReportEventType = @import("typedefs").ReportEventType;
const Event = @import("interfaces").Event;

pub const Fence = struct {
    pub const Meta = struct {
        pub const name = "Fence";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "reportEvent", "call_reportEvent", 0 },
            .{ "setReportEventDataForAutomaticBeacons", "call_setReportEventDataForAutomaticBeacons", 0 },
            .{ "getNestedConfigs", "call_getNestedConfigs", 0 },
            .{ "disableUntrustedNetwork", "call_disableUntrustedNetwork", 0 },
            .{ "notifyEvent", "call_notifyEvent", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "reportEvent",
            "setReportEventDataForAutomaticBeacons",
            "getNestedConfigs",
            "disableUntrustedNetwork",
            "notifyEvent",
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
            _internal: ?*FenceImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_disableUntrustedNetwork = &call_disableUntrustedNetwork,
        .call_getNestedConfigs = &call_getNestedConfigs,
        .call_notifyEvent = &call_notifyEvent,
        .call_reportEvent = &call_reportEvent,
        .call_setReportEventDataForAutomaticBeacons = &call_setReportEventDataForAutomaticBeacons,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("Fence has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(FenceImpl, "init") and @hasDecl(FenceImpl, "initOwn")) @compileError("FenceImpl defines both init and initOwn");
        if (comptime @hasDecl(FenceImpl, "init")) return FenceImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(FenceImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try FenceImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(FenceImpl, "init")) return false;
        if (comptime @hasDecl(FenceImpl, "construction_args")) {
            inline for (FenceImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(FenceImpl, "deinit") and @hasDecl(FenceImpl, "deinitOwn")) @compileError("FenceImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(FenceImpl, "deinit")) return FenceImpl.deinit(instance);
        if (comptime @hasDecl(FenceImpl, "deinitOwn")) FenceImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Fence")) {
            if (comptime @hasDecl(impls.Fence, "installHooks")) impls.Fence.installHooks();
        }
    }

    pub fn call_reportEvent(instance: *runtime.Instance, event: webidl.Opt(ReportEventType)) anyerror!void {
        return try FenceImpl.call_reportEvent(instance, event);
    }

    pub fn call_notifyEvent(instance: *runtime.Instance, event: *runtime.Instance) anyerror!void {
        return try FenceImpl.call_notifyEvent(instance, event);
    }

    pub fn call_getNestedConfigs(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try FenceImpl.call_getNestedConfigs(instance);
    }

    pub fn call_setReportEventDataForAutomaticBeacons(instance: *runtime.Instance, event: webidl.Opt(FenceEvent)) anyerror!void {
        return try FenceImpl.call_setReportEventDataForAutomaticBeacons(instance, event);
    }

    pub fn call_disableUntrustedNetwork(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try FenceImpl.call_disableUntrustedNetwork(instance);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_notifyEvent", 0, "Event" },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_disableUntrustedNetwork",
    };
};
