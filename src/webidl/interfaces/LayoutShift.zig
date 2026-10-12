//! Generated from: layout-instability.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const LayoutShiftImpl = @import("impls").LayoutShift;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const LayoutShiftAttribution = @import("interfaces").LayoutShiftAttribution;
const DOMString = @import("typedefs").DOMString;

pub const LayoutShift = struct {
    pub const Meta = struct {
        pub const name = "LayoutShift";
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
            .{ "value", "get_value", null },
            .{ "hadRecentInput", "get_hadRecentInput", null },
            .{ "lastInputTime", "get_lastInputTime", null },
            .{ "sources", "get_sources", null },
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
            .{ "value", "get_value", null },
            .{ "hadRecentInput", "get_hadRecentInput", null },
            .{ "lastInputTime", "get_lastInputTime", null },
            .{ "sources", "get_sources", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            value: f64 = undefined,
            hadRecentInput: bool = undefined,
            lastInputTime: typedefs.DOMHighResTimeStamp = undefined,
            sources: runtime.JSValue = undefined,
            _internal: ?*LayoutShiftImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for LayoutShift
    /// Generated from [Default] toJSON extended attribute
    pub const LayoutShiftToJSON = struct {
        id: u64,
        name: runtime.DOMString,
        entryType: runtime.DOMString,
        startTime: DOMHighResTimeStamp,
        duration: DOMHighResTimeStamp,
        navigationId: u64,
        value: f64,
        hadRecentInput: bool,
        lastInputTime: DOMHighResTimeStamp,
        sources: runtime.JSValue,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_hadRecentInput = &get_hadRecentInput,
        .get_lastInputTime = &get_lastInputTime,
        .get_sources = &get_sources,
        .get_value = &get_value,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("LayoutShift has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(LayoutShiftImpl, "init") and @hasDecl(LayoutShiftImpl, "initOwn")) @compileError("LayoutShiftImpl defines both init and initOwn");
        if (comptime @hasDecl(LayoutShiftImpl, "init")) return LayoutShiftImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(LayoutShiftImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try LayoutShiftImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(LayoutShiftImpl, "init")) return false;
        if (comptime @hasDecl(LayoutShiftImpl, "construction_args")) {
            inline for (LayoutShiftImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(LayoutShiftImpl, "deinit") and @hasDecl(LayoutShiftImpl, "deinitOwn")) @compileError("LayoutShiftImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(LayoutShiftImpl, "deinit")) return LayoutShiftImpl.deinit(instance);
        if (comptime @hasDecl(LayoutShiftImpl, "deinitOwn")) LayoutShiftImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "LayoutShift")) {
            if (comptime @hasDecl(impls.LayoutShift, "installHooks")) impls.LayoutShift.installHooks();
        }
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutShiftImpl.get_value(instance);
    }

    pub fn get_hadRecentInput(instance: *runtime.Instance) anyerror!bool {
        return try LayoutShiftImpl.get_hadRecentInput(instance);
    }

    pub fn get_lastInputTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LayoutShiftImpl.get_lastInputTime(instance);
    }

    pub fn get_sources(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try LayoutShiftImpl.get_sources(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!LayoutShiftToJSON {
        return try LayoutShiftImpl.call_toJSON(instance);
    }
};
