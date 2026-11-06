//! Implementation for PermissionsPolicyViolationReportBody interface
//!
//! Permissions Policy's report body (policy_containers.zig writes its members).
//! One of the report body interfaces of specs/supplementary/
//! reporting-interfaces.idl (the user's ruling of 2026-11-05): its members are
//! read from the native report record it was made from
//! (dom.reporting.makeBody, dom.reporting.BodyImpl).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const reporting = @import("dom").reporting;
const PermissionsPolicyViolationReportBody = interfaces.PermissionsPolicyViolationReportBody;

pub const State = PermissionsPolicyViolationReportBody.State;

const Body = reporting.BodyImpl(State);
pub const construction_args = Body.construction_args;
pub const InternalState = reporting.BodyInternal;
pub const initOwn = Body.initOwn;
pub const deinitOwn = Body.deinitOwn;

/// Getter for featureId
pub fn get_featureId(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try Body.fields(instance)).string("featureId") orelse "");
}

/// Getter for sourceFile
pub fn get_sourceFile(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return if ((try Body.fields(instance)).string("sourceFile")) |value| runtime.DOMString.initInterned(value) else null;
}

/// Getter for lineNumber
pub fn get_lineNumber(instance: *runtime.Instance) anyerror!?i32 {
    return (try Body.fields(instance)).signed("lineNumber");
}

/// Getter for columnNumber
pub fn get_columnNumber(instance: *runtime.Instance) anyerror!?i32 {
    return (try Body.fields(instance)).signed("columnNumber");
}

/// Getter for disposition
pub fn get_disposition(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try Body.fields(instance)).string("disposition") orelse "");
}

/// Getter for allowAttribute
pub fn get_allowAttribute(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return if ((try Body.fields(instance)).string("allowAttribute")) |value| runtime.DOMString.initInterned(value) else null;
}

/// Getter for srcAttribute
pub fn get_srcAttribute(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return if ((try Body.fields(instance)).string("srcAttribute")) |value| runtime.DOMString.initInterned(value) else null;
}

/// Operation: toJSON ([Default]: every attribute, ReportBody's none)
pub fn call_toJSON(instance: *runtime.Instance) anyerror!PermissionsPolicyViolationReportBody.PermissionsPolicyViolationReportBodyToJSON {
    const fields = try Body.fields(instance);
    return .{
        .featureId = runtime.DOMString.initInterned(fields.string("featureId") orelse ""),
        .sourceFile = if (fields.string("sourceFile")) |value| runtime.DOMString.initInterned(value) else null,
        .lineNumber = fields.signed("lineNumber"),
        .columnNumber = fields.signed("columnNumber"),
        .disposition = runtime.DOMString.initInterned(fields.string("disposition") orelse ""),
        .allowAttribute = if (fields.string("allowAttribute")) |value| runtime.DOMString.initInterned(value) else null,
        .srcAttribute = if (fields.string("srcAttribute")) |value| runtime.DOMString.initInterned(value) else null,
    };
}
