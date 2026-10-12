//! Generated from: permissions-policy.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PermissionsPolicyViolationReportBodyImpl = @import("impls").PermissionsPolicyViolationReportBody;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ReportBody = @import("dictionaries").ReportBody;
const DOMString = @import("typedefs").DOMString;

pub const PermissionsPolicyViolationReportBody = struct {
    pub const Meta = struct {
        pub const name = "PermissionsPolicyViolationReportBody";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ReportBody;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "featureId", "get_featureId", null },
            .{ "sourceFile", "get_sourceFile", null },
            .{ "lineNumber", "get_lineNumber", null },
            .{ "columnNumber", "get_columnNumber", null },
            .{ "disposition", "get_disposition", null },
            .{ "allowAttribute", "get_allowAttribute", null },
            .{ "srcAttribute", "get_srcAttribute", null },
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
            .{ "featureId", "get_featureId", null },
            .{ "sourceFile", "get_sourceFile", null },
            .{ "lineNumber", "get_lineNumber", null },
            .{ "columnNumber", "get_columnNumber", null },
            .{ "disposition", "get_disposition", null },
            .{ "allowAttribute", "get_allowAttribute", null },
            .{ "srcAttribute", "get_srcAttribute", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            featureId: typedefs.DOMString = undefined,
            sourceFile: ?typedefs.DOMString = null,
            lineNumber: ?i32 = null,
            columnNumber: ?i32 = null,
            disposition: typedefs.DOMString = undefined,
            allowAttribute: ?typedefs.DOMString = null,
            srcAttribute: ?typedefs.DOMString = null,
            _internal: ?*PermissionsPolicyViolationReportBodyImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for PermissionsPolicyViolationReportBody
    /// Generated from [Default] toJSON extended attribute
    pub const PermissionsPolicyViolationReportBodyToJSON = struct {
        featureId: runtime.DOMString,
        sourceFile: ?runtime.DOMString,
        lineNumber: ?i32,
        columnNumber: ?i32,
        disposition: runtime.DOMString,
        allowAttribute: ?runtime.DOMString,
        srcAttribute: ?runtime.DOMString,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_allowAttribute = &get_allowAttribute,
        .get_columnNumber = &get_columnNumber,
        .get_disposition = &get_disposition,
        .get_featureId = &get_featureId,
        .get_lineNumber = &get_lineNumber,
        .get_sourceFile = &get_sourceFile,
        .get_srcAttribute = &get_srcAttribute,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("PermissionsPolicyViolationReportBody has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(PermissionsPolicyViolationReportBodyImpl, "init") and @hasDecl(PermissionsPolicyViolationReportBodyImpl, "initOwn")) @compileError("PermissionsPolicyViolationReportBodyImpl defines both init and initOwn");
        if (comptime @hasDecl(PermissionsPolicyViolationReportBodyImpl, "init")) return PermissionsPolicyViolationReportBodyImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(PermissionsPolicyViolationReportBodyImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try PermissionsPolicyViolationReportBodyImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PermissionsPolicyViolationReportBodyImpl, "init")) return false;
        if (comptime @hasDecl(PermissionsPolicyViolationReportBodyImpl, "construction_args")) {
            inline for (PermissionsPolicyViolationReportBodyImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PermissionsPolicyViolationReportBodyImpl, "deinit") and @hasDecl(PermissionsPolicyViolationReportBodyImpl, "deinitOwn")) @compileError("PermissionsPolicyViolationReportBodyImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PermissionsPolicyViolationReportBodyImpl, "deinit")) return PermissionsPolicyViolationReportBodyImpl.deinit(instance);
        if (comptime @hasDecl(PermissionsPolicyViolationReportBodyImpl, "deinitOwn")) PermissionsPolicyViolationReportBodyImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PermissionsPolicyViolationReportBody")) {
            if (comptime @hasDecl(impls.PermissionsPolicyViolationReportBody, "installHooks")) impls.PermissionsPolicyViolationReportBody.installHooks();
        }
    }

    pub fn get_featureId(instance: *runtime.Instance) anyerror!DOMString {
        return try PermissionsPolicyViolationReportBodyImpl.get_featureId(instance);
    }

    pub fn get_sourceFile(instance: *runtime.Instance) anyerror!?DOMString {
        return try PermissionsPolicyViolationReportBodyImpl.get_sourceFile(instance);
    }

    pub fn get_lineNumber(instance: *runtime.Instance) anyerror!?i32 {
        return try PermissionsPolicyViolationReportBodyImpl.get_lineNumber(instance);
    }

    pub fn get_columnNumber(instance: *runtime.Instance) anyerror!?i32 {
        return try PermissionsPolicyViolationReportBodyImpl.get_columnNumber(instance);
    }

    pub fn get_disposition(instance: *runtime.Instance) anyerror!DOMString {
        return try PermissionsPolicyViolationReportBodyImpl.get_disposition(instance);
    }

    pub fn get_allowAttribute(instance: *runtime.Instance) anyerror!?DOMString {
        return try PermissionsPolicyViolationReportBodyImpl.get_allowAttribute(instance);
    }

    pub fn get_srcAttribute(instance: *runtime.Instance) anyerror!?DOMString {
        return try PermissionsPolicyViolationReportBodyImpl.get_srcAttribute(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PermissionsPolicyViolationReportBodyToJSON {
        return try PermissionsPolicyViolationReportBodyImpl.call_toJSON(instance);
    }
};
