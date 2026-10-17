//! Generated from: container-timing.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PerformanceContainerTimingImpl = @import("impls").PerformanceContainerTiming;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const PaintTimingMixin = @import("mixins").PaintTimingMixin;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const HTMLElement = @import("interfaces").HTMLElement;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMString = @import("typedefs").DOMString;

pub const PerformanceContainerTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceContainerTiming";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = PerformanceEntry.State;
        pub const ParentInterface = PerformanceEntry;
        pub const MixinTypes = &.{
            PaintTimingMixin,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "identifier", "get_identifier", null },
            .{ "intersectionRect", "get_intersectionRect", null },
            .{ "size", "get_size", null },
            .{ "firstRenderTime", "get_firstRenderTime", null },
            .{ "lastPaintedElement", "get_lastPaintedElement", null },
            .{ "rootElement", "get_rootElement", null },
            .{ "paintTime", "get_paintTime", null },
            .{ "presentationTime", "get_presentationTime", null },
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
            .{ "identifier", "get_identifier", null },
            .{ "intersectionRect", "get_intersectionRect", null },
            .{ "size", "get_size", null },
            .{ "firstRenderTime", "get_firstRenderTime", null },
            .{ "lastPaintedElement", "get_lastPaintedElement", null },
            .{ "rootElement", "get_rootElement", null },
            .{ "paintTime", "get_paintTime", null },
            .{ "presentationTime", "get_presentationTime", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            identifier: runtime.DOMString = undefined,
            intersectionRect: *runtime.Instance = undefined,
            size: u64 = undefined,
            firstRenderTime: typedefs.DOMHighResTimeStamp = undefined,
            lastPaintedElement: ?*runtime.Instance = null,
            rootElement: ?*runtime.Instance = null,
            paintTime: typedefs.DOMHighResTimeStamp = undefined,
            presentationTime: ?typedefs.DOMHighResTimeStamp = null,
            _internal: ?*PerformanceContainerTimingImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for PerformanceContainerTiming
    /// Generated from [Default] toJSON extended attribute
    pub const PerformanceContainerTimingToJSON = struct {
        id: u64,
        name: runtime.DOMString,
        entryType: runtime.DOMString,
        startTime: DOMHighResTimeStamp,
        duration: DOMHighResTimeStamp,
        navigationId: u64,
        identifier: runtime.DOMString,
        intersectionRect: *runtime.Instance,
        size: u64,
        firstRenderTime: DOMHighResTimeStamp,
        lastPaintedElement: ?*runtime.Instance,
        rootElement: ?*runtime.Instance,
        paintTime: DOMHighResTimeStamp,
        presentationTime: ?DOMHighResTimeStamp,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_firstRenderTime = &get_firstRenderTime,
        .get_identifier = &get_identifier,
        .get_intersectionRect = &get_intersectionRect,
        .get_lastPaintedElement = &get_lastPaintedElement,
        .get_paintTime = &get_paintTime,
        .get_presentationTime = &get_presentationTime,
        .get_rootElement = &get_rootElement,
        .get_size = &get_size,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("PerformanceContainerTiming has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(PerformanceContainerTimingImpl, "init") and @hasDecl(PerformanceContainerTimingImpl, "initOwn")) @compileError("PerformanceContainerTimingImpl defines both init and initOwn");
        if (comptime @hasDecl(PerformanceContainerTimingImpl, "init")) return PerformanceContainerTimingImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(PerformanceContainerTimingImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try PerformanceContainerTimingImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PerformanceContainerTimingImpl, "init")) return false;
        if (comptime @hasDecl(PerformanceContainerTimingImpl, "construction_args")) {
            inline for (PerformanceContainerTimingImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PerformanceContainerTimingImpl, "deinit") and @hasDecl(PerformanceContainerTimingImpl, "deinitOwn")) @compileError("PerformanceContainerTimingImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PerformanceContainerTimingImpl, "deinit")) return PerformanceContainerTimingImpl.deinit(instance);
        if (comptime @hasDecl(PerformanceContainerTimingImpl, "deinitOwn")) PerformanceContainerTimingImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PerformanceContainerTiming")) {
            if (comptime @hasDecl(impls.PerformanceContainerTiming, "installHooks")) impls.PerformanceContainerTiming.installHooks();
        }
    }

    pub fn get_identifier(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try PerformanceContainerTimingImpl.get_identifier(instance);
    }

    pub fn get_intersectionRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PerformanceContainerTimingImpl.get_intersectionRect(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceContainerTimingImpl.get_size(instance);
    }

    pub fn get_firstRenderTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceContainerTimingImpl.get_firstRenderTime(instance);
    }

    pub fn get_lastPaintedElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try PerformanceContainerTimingImpl.get_lastPaintedElement(instance);
    }

    pub fn get_rootElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try PerformanceContainerTimingImpl.get_rootElement(instance);
    }

    pub fn get_paintTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceContainerTimingImpl.get_paintTime(instance);
    }

    pub fn get_presentationTime(instance: *runtime.Instance) anyerror!?DOMHighResTimeStamp {
        return try PerformanceContainerTimingImpl.get_presentationTime(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PerformanceContainerTimingToJSON {
        return try PerformanceContainerTimingImpl.call_toJSON(instance);
    }
};
