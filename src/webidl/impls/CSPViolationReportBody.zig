//! Implementation for CSPViolationReportBody interface
//!
//! CSP 3 §5.2 "violation report body" (csp_violations.zig writes its members).
//! One of the report body interfaces of specs/supplementary/
//! reporting-interfaces.idl (the user's ruling of 2026-11-05): its members are
//! read from the native report record it was made from
//! (dom.reporting.makeBody, dom.reporting.BodyImpl).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const reporting = @import("dom").reporting;
const CSPViolationReportBody = interfaces.CSPViolationReportBody;

pub const State = CSPViolationReportBody.State;

const Body = reporting.BodyImpl(State);
pub const construction_args = Body.construction_args;
pub const InternalState = reporting.BodyInternal;
pub const initOwn = Body.initOwn;
pub const deinitOwn = Body.deinitOwn;

/// Getter for documentURL
pub fn get_documentURL(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try instance.ctx.allocator.dupe(u8, (try Body.fields(instance)).string("documentURL") orelse "");
}

/// Getter for referrer
pub fn get_referrer(instance: *runtime.Instance) anyerror!?runtime.USVString {
    return if ((try Body.fields(instance)).string("referrer")) |value| try instance.ctx.allocator.dupe(u8, value) else null;
}

/// Getter for blockedURL
pub fn get_blockedURL(instance: *runtime.Instance) anyerror!?runtime.USVString {
    return if ((try Body.fields(instance)).string("blockedURL")) |value| try instance.ctx.allocator.dupe(u8, value) else null;
}

/// Getter for effectiveDirective
pub fn get_effectiveDirective(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try Body.fields(instance)).string("effectiveDirective") orelse "");
}

/// Getter for originalPolicy
pub fn get_originalPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try Body.fields(instance)).string("originalPolicy") orelse "");
}

/// Getter for sourceFile
pub fn get_sourceFile(instance: *runtime.Instance) anyerror!?runtime.USVString {
    return if ((try Body.fields(instance)).string("sourceFile")) |value| try instance.ctx.allocator.dupe(u8, value) else null;
}

/// Getter for sample
pub fn get_sample(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return if ((try Body.fields(instance)).string("sample")) |value| runtime.DOMString.initInterned(value) else null;
}

/// Getter for disposition
pub fn get_disposition(instance: *runtime.Instance) anyerror!enums.SecurityPolicyViolationEventDisposition {
    return (try Body.fields(instance)).enumeration(enums.SecurityPolicyViolationEventDisposition, "disposition");
}

/// Getter for statusCode
pub fn get_statusCode(instance: *runtime.Instance) anyerror!u16 {
    return std.math.cast(u16, (try Body.fields(instance)).unsigned("statusCode") orelse 0) orelse 0;
}

/// Getter for lineNumber
pub fn get_lineNumber(instance: *runtime.Instance) anyerror!?u32 {
    return (try Body.fields(instance)).unsigned("lineNumber");
}

/// Getter for columnNumber
pub fn get_columnNumber(instance: *runtime.Instance) anyerror!?u32 {
    return (try Body.fields(instance)).unsigned("columnNumber");
}

/// Operation: toJSON ([Default]: every attribute, ReportBody's none)
pub fn call_toJSON(instance: *runtime.Instance) anyerror!CSPViolationReportBody.CSPViolationReportBodyToJSON {
    const fields = try Body.fields(instance);
    return .{
        .documentURL = fields.string("documentURL") orelse "",
        .referrer = fields.string("referrer"),
        .blockedURL = fields.string("blockedURL"),
        .effectiveDirective = runtime.DOMString.initInterned(fields.string("effectiveDirective") orelse ""),
        .originalPolicy = runtime.DOMString.initInterned(fields.string("originalPolicy") orelse ""),
        .sourceFile = fields.string("sourceFile"),
        .sample = if (fields.string("sample")) |value| runtime.DOMString.initInterned(value) else null,
        .disposition = fields.enumeration(enums.SecurityPolicyViolationEventDisposition, "disposition"),
        .statusCode = std.math.cast(u16, fields.unsigned("statusCode") orelse 0) orelse 0,
        .lineNumber = fields.unsigned("lineNumber"),
        .columnNumber = fields.unsigned("columnNumber"),
    };
}
