//! Generated from: csp-next.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ScriptingPolicyReportBodyImpl = @import("impls").ScriptingPolicyReportBody;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ReportBody = @import("dictionaries").ReportBody;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const ScriptingPolicyReportBody = struct {
    pub const Meta = struct {
        pub const name = "ScriptingPolicyReportBody";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ReportBody;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "violationType", "get_violationType", null },
            .{ "violationURL", "get_violationURL", null },
            .{ "violationSample", "get_violationSample", null },
            .{ "lineno", "get_lineno", null },
            .{ "colno", "get_colno", null },
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
            .{ "violationType", "get_violationType", null },
            .{ "violationURL", "get_violationURL", null },
            .{ "violationSample", "get_violationSample", null },
            .{ "lineno", "get_lineno", null },
            .{ "colno", "get_colno", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            violationType: typedefs.DOMString = undefined,
            violationURL: ?runtime.USVString = null,
            violationSample: ?runtime.USVString = null,
            lineno: u32 = undefined,
            colno: u32 = undefined,
            _internal: ?*ScriptingPolicyReportBodyImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for ScriptingPolicyReportBody
    /// Generated from [Default] toJSON extended attribute
    pub const ScriptingPolicyReportBodyToJSON = struct {
        violationType: runtime.DOMString,
        violationURL: ?runtime.USVString,
        violationSample: ?runtime.USVString,
        lineno: u32,
        colno: u32,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_colno = &get_colno,
        .get_lineno = &get_lineno,
        .get_violationSample = &get_violationSample,
        .get_violationType = &get_violationType,
        .get_violationURL = &get_violationURL,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("ScriptingPolicyReportBody has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ScriptingPolicyReportBodyImpl, "init") and @hasDecl(ScriptingPolicyReportBodyImpl, "initOwn")) @compileError("ScriptingPolicyReportBodyImpl defines both init and initOwn");
        if (comptime @hasDecl(ScriptingPolicyReportBodyImpl, "init")) return ScriptingPolicyReportBodyImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ScriptingPolicyReportBodyImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ScriptingPolicyReportBodyImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ScriptingPolicyReportBodyImpl, "init")) return false;
        if (comptime @hasDecl(ScriptingPolicyReportBodyImpl, "construction_args")) {
            inline for (ScriptingPolicyReportBodyImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ScriptingPolicyReportBodyImpl, "deinit") and @hasDecl(ScriptingPolicyReportBodyImpl, "deinitOwn")) @compileError("ScriptingPolicyReportBodyImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ScriptingPolicyReportBodyImpl, "deinit")) return ScriptingPolicyReportBodyImpl.deinit(instance);
        if (comptime @hasDecl(ScriptingPolicyReportBodyImpl, "deinitOwn")) ScriptingPolicyReportBodyImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ScriptingPolicyReportBody")) {
            if (comptime @hasDecl(impls.ScriptingPolicyReportBody, "installHooks")) impls.ScriptingPolicyReportBody.installHooks();
        }
    }

    pub fn get_violationType(instance: *runtime.Instance) anyerror!DOMString {
        return try ScriptingPolicyReportBodyImpl.get_violationType(instance);
    }

    pub fn get_violationURL(instance: *runtime.Instance) anyerror!?runtime.USVString {
        return try ScriptingPolicyReportBodyImpl.get_violationURL(instance);
    }

    pub fn get_violationSample(instance: *runtime.Instance) anyerror!?runtime.USVString {
        return try ScriptingPolicyReportBodyImpl.get_violationSample(instance);
    }

    pub fn get_lineno(instance: *runtime.Instance) anyerror!u32 {
        return try ScriptingPolicyReportBodyImpl.get_lineno(instance);
    }

    pub fn get_colno(instance: *runtime.Instance) anyerror!u32 {
        return try ScriptingPolicyReportBodyImpl.get_colno(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!ScriptingPolicyReportBodyToJSON {
        return try ScriptingPolicyReportBodyImpl.call_toJSON(instance);
    }
};
