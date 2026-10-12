//! Generated from: largest-contentful-paint.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const LargestContentfulPaintImpl = @import("impls").LargestContentfulPaint;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const PaintTimingMixin = @import("mixins").PaintTimingMixin;
const Element = @import("interfaces").Element;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMString = @import("typedefs").DOMString;

pub const LargestContentfulPaint = struct {
    pub const Meta = struct {
        pub const name = "LargestContentfulPaint";
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
            .{ "loadTime", "get_loadTime", null },
            .{ "renderTime", "get_renderTime", null },
            .{ "size", "get_size", null },
            .{ "id", "get_id", null },
            .{ "url", "get_url", null },
            .{ "element", "get_element", null },
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
            .{ "loadTime", "get_loadTime", null },
            .{ "renderTime", "get_renderTime", null },
            .{ "size", "get_size", null },
            .{ "id", "get_id", null },
            .{ "url", "get_url", null },
            .{ "element", "get_element", null },
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
            loadTime: typedefs.DOMHighResTimeStamp = undefined,
            renderTime: typedefs.DOMHighResTimeStamp = undefined,
            size: u32 = undefined,
            id: typedefs.DOMString = undefined,
            url: typedefs.DOMString = undefined,
            element: ?*runtime.Instance = null,
            paintTime: typedefs.DOMHighResTimeStamp = undefined,
            presentationTime: ?typedefs.DOMHighResTimeStamp = null,
            _internal: ?*LargestContentfulPaintImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for LargestContentfulPaint
    /// Generated from [Default] toJSON extended attribute
    pub const LargestContentfulPaintToJSON = struct {
        id: runtime.DOMString,
        name: runtime.DOMString,
        entryType: runtime.DOMString,
        startTime: DOMHighResTimeStamp,
        duration: DOMHighResTimeStamp,
        navigationId: u64,
        loadTime: DOMHighResTimeStamp,
        renderTime: DOMHighResTimeStamp,
        size: u32,
        url: runtime.DOMString,
        element: ?*runtime.Instance,
        paintTime: DOMHighResTimeStamp,
        presentationTime: ?DOMHighResTimeStamp,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_element = &get_element,
        .get_id = &get_id,
        .get_loadTime = &get_loadTime,
        .get_paintTime = &get_paintTime,
        .get_presentationTime = &get_presentationTime,
        .get_renderTime = &get_renderTime,
        .get_size = &get_size,
        .get_url = &get_url,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("LargestContentfulPaint has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(LargestContentfulPaintImpl, "init") and @hasDecl(LargestContentfulPaintImpl, "initOwn")) @compileError("LargestContentfulPaintImpl defines both init and initOwn");
        if (comptime @hasDecl(LargestContentfulPaintImpl, "init")) return LargestContentfulPaintImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(LargestContentfulPaintImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try LargestContentfulPaintImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(LargestContentfulPaintImpl, "init")) return false;
        if (comptime @hasDecl(LargestContentfulPaintImpl, "construction_args")) {
            inline for (LargestContentfulPaintImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(LargestContentfulPaintImpl, "deinit") and @hasDecl(LargestContentfulPaintImpl, "deinitOwn")) @compileError("LargestContentfulPaintImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(LargestContentfulPaintImpl, "deinit")) return LargestContentfulPaintImpl.deinit(instance);
        if (comptime @hasDecl(LargestContentfulPaintImpl, "deinitOwn")) LargestContentfulPaintImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "LargestContentfulPaint")) {
            if (comptime @hasDecl(impls.LargestContentfulPaint, "installHooks")) impls.LargestContentfulPaint.installHooks();
        }
    }

    pub fn get_loadTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LargestContentfulPaintImpl.get_loadTime(instance);
    }

    pub fn get_renderTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LargestContentfulPaintImpl.get_renderTime(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try LargestContentfulPaintImpl.get_size(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try LargestContentfulPaintImpl.get_id(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!DOMString {
        return try LargestContentfulPaintImpl.get_url(instance);
    }

    pub fn get_element(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try LargestContentfulPaintImpl.get_element(instance);
    }

    pub fn get_paintTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LargestContentfulPaintImpl.get_paintTime(instance);
    }

    pub fn get_presentationTime(instance: *runtime.Instance) anyerror!?DOMHighResTimeStamp {
        return try LargestContentfulPaintImpl.get_presentationTime(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!LargestContentfulPaintToJSON {
        return try LargestContentfulPaintImpl.call_toJSON(instance);
    }
};
