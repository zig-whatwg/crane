//! Generated from: reporting-interfaces.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ReportImpl = @import("impls").Report;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ReportBody = @import("interfaces").ReportBody;
const DOMString = @import("typedefs").DOMString;

pub const Report = struct {
    pub const Meta = struct {
        pub const name = "Report";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", null },
            .{ "url", "get_url", null },
            .{ "body", "get_body", null },
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
            .{ "type", "get_type", null },
            .{ "url", "get_url", null },
            .{ "body", "get_body", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*ReportImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for Report
    /// Generated from [Default] toJSON extended attribute
    pub const ReportToJSON = struct {
        type: runtime.DOMString,
        url: runtime.DOMString,
        body: ?*runtime.Instance,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_body = &get_body,
        .get_type = &get_type,
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
            if (comptime !takesConstructionArg(field_name)) @compileError("Report has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(ReportImpl, "init") and @hasDecl(ReportImpl, "initOwn")) @compileError("ReportImpl defines both init and initOwn");
        if (comptime @hasDecl(ReportImpl, "init")) return ReportImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ReportImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ReportImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ReportImpl, "init")) return false;
        if (comptime @hasDecl(ReportImpl, "construction_args")) {
            inline for (ReportImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ReportImpl, "deinit") and @hasDecl(ReportImpl, "deinitOwn")) @compileError("ReportImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ReportImpl, "deinit")) return ReportImpl.deinit(instance);
        if (comptime @hasDecl(ReportImpl, "deinitOwn")) ReportImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Report")) {
            if (comptime @hasDecl(impls.Report, "installHooks")) impls.Report.installHooks();
        }
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ReportImpl.get_type(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ReportImpl.get_url(instance);
    }

    pub fn get_body(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ReportImpl.get_body(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!ReportToJSON {
        return try ReportImpl.call_toJSON(instance);
    }
};
