//! Generated from: reporting-interfaces.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CoopAccessViolationReportBodyImpl = @import("impls").CoopAccessViolationReportBody;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ReportBody = @import("interfaces").ReportBody;
const DOMString = @import("typedefs").DOMString;

pub const CoopAccessViolationReportBody = struct {
    pub const Meta = struct {
        pub const name = "CoopAccessViolationReportBody";
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
            .{ "sourceFile", "get_sourceFile", null },
            .{ "lineNumber", "get_lineNumber", null },
            .{ "columnNumber", "get_columnNumber", null },
            .{ "type", "get_type", null },
            .{ "property", "get_property", null },
            .{ "openeeURL", "get_openeeURL", null },
            .{ "openerURL", "get_openerURL", null },
            .{ "otherDocumentURL", "get_otherDocumentURL", null },
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
            .{ "sourceFile", "get_sourceFile", null },
            .{ "lineNumber", "get_lineNumber", null },
            .{ "columnNumber", "get_columnNumber", null },
            .{ "type", "get_type", null },
            .{ "property", "get_property", null },
            .{ "openeeURL", "get_openeeURL", null },
            .{ "openerURL", "get_openerURL", null },
            .{ "otherDocumentURL", "get_otherDocumentURL", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*CoopAccessViolationReportBodyImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_columnNumber = &get_columnNumber,
        .get_lineNumber = &get_lineNumber,
        .get_openeeURL = &get_openeeURL,
        .get_openerURL = &get_openerURL,
        .get_otherDocumentURL = &get_otherDocumentURL,
        .get_property = &get_property,
        .get_sourceFile = &get_sourceFile,
        .get_type = &get_type,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("CoopAccessViolationReportBody has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(CoopAccessViolationReportBodyImpl, "init") and @hasDecl(CoopAccessViolationReportBodyImpl, "initOwn")) @compileError("CoopAccessViolationReportBodyImpl defines both init and initOwn");
        if (comptime @hasDecl(CoopAccessViolationReportBodyImpl, "init")) return CoopAccessViolationReportBodyImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CoopAccessViolationReportBodyImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CoopAccessViolationReportBodyImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CoopAccessViolationReportBodyImpl, "init")) return false;
        if (comptime @hasDecl(CoopAccessViolationReportBodyImpl, "construction_args")) {
            inline for (CoopAccessViolationReportBodyImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CoopAccessViolationReportBodyImpl, "deinit") and @hasDecl(CoopAccessViolationReportBodyImpl, "deinitOwn")) @compileError("CoopAccessViolationReportBodyImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CoopAccessViolationReportBodyImpl, "deinit")) return CoopAccessViolationReportBodyImpl.deinit(instance);
        if (comptime @hasDecl(CoopAccessViolationReportBodyImpl, "deinitOwn")) CoopAccessViolationReportBodyImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CoopAccessViolationReportBody")) {
            if (comptime @hasDecl(impls.CoopAccessViolationReportBody, "installHooks")) impls.CoopAccessViolationReportBody.installHooks();
        }
    }

    pub fn get_sourceFile(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try CoopAccessViolationReportBodyImpl.get_sourceFile(instance);
    }

    pub fn get_lineNumber(instance: *runtime.Instance) anyerror!?u32 {
        return try CoopAccessViolationReportBodyImpl.get_lineNumber(instance);
    }

    pub fn get_columnNumber(instance: *runtime.Instance) anyerror!?u32 {
        return try CoopAccessViolationReportBodyImpl.get_columnNumber(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try CoopAccessViolationReportBodyImpl.get_type(instance);
    }

    pub fn get_property(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try CoopAccessViolationReportBodyImpl.get_property(instance);
    }

    pub fn get_openeeURL(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try CoopAccessViolationReportBodyImpl.get_openeeURL(instance);
    }

    pub fn get_openerURL(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try CoopAccessViolationReportBodyImpl.get_openerURL(instance);
    }

    pub fn get_otherDocumentURL(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try CoopAccessViolationReportBodyImpl.get_otherDocumentURL(instance);
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try CoopAccessViolationReportBodyImpl.call_toJSON(instance);
    }
};
