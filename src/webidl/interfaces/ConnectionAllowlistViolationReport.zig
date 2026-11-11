//! Generated from: reporting-interfaces.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ConnectionAllowlistViolationReportImpl = @import("impls").ConnectionAllowlistViolationReport;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ReportBody = @import("interfaces").ReportBody;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;
const ConnectionAllowlistDisposition = @import("enums").ConnectionAllowlistDisposition;

pub const ConnectionAllowlistViolationReport = struct {
    pub const Meta = struct {
        pub const name = "ConnectionAllowlistViolationReport";
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
            .{ "url", "get_url", null },
            .{ "connection", "get_connection", null },
            .{ "allowlist", "get_allowlist", null },
            .{ "disposition", "get_disposition", null },
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
            .{ "url", "get_url", null },
            .{ "connection", "get_connection", null },
            .{ "allowlist", "get_allowlist", null },
            .{ "disposition", "get_disposition", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*ConnectionAllowlistViolationReportImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for ConnectionAllowlistViolationReport
    /// Generated from [Default] toJSON extended attribute
    pub const ConnectionAllowlistViolationReportToJSON = struct {
        url: runtime.USVString,
        connection: runtime.USVString,
        allowlist: runtime.JSValue,
        disposition: ConnectionAllowlistDisposition,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_allowlist = &get_allowlist,
        .get_connection = &get_connection,
        .get_disposition = &get_disposition,
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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("ConnectionAllowlistViolationReport has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(ConnectionAllowlistViolationReportImpl, "init") and @hasDecl(ConnectionAllowlistViolationReportImpl, "initOwn")) @compileError("ConnectionAllowlistViolationReportImpl defines both init and initOwn");
        if (comptime @hasDecl(ConnectionAllowlistViolationReportImpl, "init")) return ConnectionAllowlistViolationReportImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(ConnectionAllowlistViolationReportImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try ConnectionAllowlistViolationReportImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ConnectionAllowlistViolationReportImpl, "init")) return false;
        if (comptime @hasDecl(ConnectionAllowlistViolationReportImpl, "construction_args")) {
            inline for (ConnectionAllowlistViolationReportImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ConnectionAllowlistViolationReportImpl, "deinit") and @hasDecl(ConnectionAllowlistViolationReportImpl, "deinitOwn")) @compileError("ConnectionAllowlistViolationReportImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ConnectionAllowlistViolationReportImpl, "deinit")) return ConnectionAllowlistViolationReportImpl.deinit(instance);
        if (comptime @hasDecl(ConnectionAllowlistViolationReportImpl, "deinitOwn")) ConnectionAllowlistViolationReportImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ConnectionAllowlistViolationReport")) {
            if (comptime @hasDecl(impls.ConnectionAllowlistViolationReport, "installHooks")) impls.ConnectionAllowlistViolationReport.installHooks();
        }
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ConnectionAllowlistViolationReportImpl.get_url(instance);
    }

    pub fn get_connection(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ConnectionAllowlistViolationReportImpl.get_connection(instance);
    }

    pub fn get_allowlist(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ConnectionAllowlistViolationReportImpl.get_allowlist(instance);
    }

    pub fn get_disposition(instance: *runtime.Instance) anyerror!ConnectionAllowlistDisposition {
        return try ConnectionAllowlistViolationReportImpl.get_disposition(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!ConnectionAllowlistViolationReportToJSON {
        return try ConnectionAllowlistViolationReportImpl.call_toJSON(instance);
    }
};
