//! Generated from: reporting-interfaces.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CrashReportBodyImpl = @import("impls").CrashReportBody;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ReportBody = @import("interfaces").ReportBody;
const DocumentVisibilityState = @import("enums").DocumentVisibilityState;
const DOMString = @import("typedefs").DOMString;

pub const CrashReportBody = struct {
    pub const Meta = struct {
        pub const name = "CrashReportBody";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ReportBody.State;
        pub const ParentInterface = ReportBody;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "LegacyNoInterfaceObject" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "reason", "get_reason", null },
            .{ "stack", "get_stack", null },
            .{ "is_top_level", "get_is_top_level", null },
            .{ "visibility_state", "get_visibility_state", null },
            .{ "crash_report_api", "get_crash_report_api", null },
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
            .{ "reason", "get_reason", null },
            .{ "stack", "get_stack", null },
            .{ "is_top_level", "get_is_top_level", null },
            .{ "visibility_state", "get_visibility_state", null },
            .{ "crash_report_api", "get_crash_report_api", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*CrashReportBodyImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for CrashReportBody
    /// Generated from [Default] toJSON extended attribute
    pub const CrashReportBodyToJSON = struct {
        reason: runtime.DOMString,
        stack: runtime.DOMString,
        is_top_level: bool,
        visibility_state: DocumentVisibilityState,
        crash_report_api: runtime.JSValue,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_crash_report_api = &get_crash_report_api,
        .get_is_top_level = &get_is_top_level,
        .get_reason = &get_reason,
        .get_stack = &get_stack,
        .get_visibility_state = &get_visibility_state,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("CrashReportBody has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(CrashReportBodyImpl, "init") and @hasDecl(CrashReportBodyImpl, "initOwn")) @compileError("CrashReportBodyImpl defines both init and initOwn");
        if (comptime @hasDecl(CrashReportBodyImpl, "init")) return CrashReportBodyImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CrashReportBodyImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CrashReportBodyImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CrashReportBodyImpl, "init")) return false;
        if (comptime @hasDecl(CrashReportBodyImpl, "construction_args")) {
            inline for (CrashReportBodyImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CrashReportBodyImpl, "deinit") and @hasDecl(CrashReportBodyImpl, "deinitOwn")) @compileError("CrashReportBodyImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CrashReportBodyImpl, "deinit")) return CrashReportBodyImpl.deinit(instance);
        if (comptime @hasDecl(CrashReportBodyImpl, "deinitOwn")) CrashReportBodyImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CrashReportBody")) {
            if (comptime @hasDecl(impls.CrashReportBody, "installHooks")) impls.CrashReportBody.installHooks();
        }
    }

    pub fn get_reason(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try CrashReportBodyImpl.get_reason(instance);
    }

    pub fn get_stack(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try CrashReportBodyImpl.get_stack(instance);
    }

    pub fn get_is_top_level(instance: *runtime.Instance) anyerror!bool {
        return try CrashReportBodyImpl.get_is_top_level(instance);
    }

    pub fn get_visibility_state(instance: *runtime.Instance) anyerror!DocumentVisibilityState {
        return try CrashReportBodyImpl.get_visibility_state(instance);
    }

    pub fn get_crash_report_api(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try CrashReportBodyImpl.get_crash_report_api(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!CrashReportBodyToJSON {
        return try CrashReportBodyImpl.call_toJSON(instance);
    }
};
