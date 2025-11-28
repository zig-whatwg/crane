//! Generated from: permissions-policy.idl
//! Generated at: 2025-11-28T18:57:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PermissionsPolicyViolationReportBodyImpl = @import("impls").PermissionsPolicyViolationReportBody;
const mixins = @import("mixins");
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
        pub const inherited_methods = .{
        };
        
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
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            featureId: runtime.DOMString = undefined,
            sourceFile: ?runtime.DOMString = null,
            lineNumber: ?i32 = null,
            columnNumber: ?i32 = null,
            disposition: runtime.DOMString = undefined,
            allowAttribute: ?runtime.DOMString = null,
            srcAttribute: ?runtime.DOMString = null,
            _internal: ?*PermissionsPolicyViolationReportBodyImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_allowAttribute = &get_allowAttribute,
        .get_columnNumber = &get_columnNumber,
        .get_disposition = &get_disposition,
        .get_featureId = &get_featureId,
        .get_lineNumber = &get_lineNumber,
        .get_sourceFile = &get_sourceFile,
        .get_srcAttribute = &get_srcAttribute,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PermissionsPolicyViolationReportBodyImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PermissionsPolicyViolationReportBodyImpl.deinit(instance);
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
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PermissionsPolicyViolationReportBodyImpl.call_toJSON(instance);
    }

};
