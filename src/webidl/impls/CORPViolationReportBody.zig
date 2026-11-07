//! Implementation for CORPViolationReportBody interface
//!
//! HTML 7.1.4 COEP's "corp" violation report body, WebKit's CORPViolationReportBody (coep_reporting.zig and HTMLIFrameElement.zig write its members).
//! One of the report body interfaces of specs/supplementary/
//! reporting-interfaces.idl (the user's ruling of 2026-11-05): its members are
//! read from the native report record it was made from
//! (dom.reporting.makeBody, dom.reporting.BodyImpl).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const reporting = @import("dom").reporting;
const CORPViolationReportBody = interfaces.CORPViolationReportBody;

pub const State = CORPViolationReportBody.State;

const Body = reporting.BodyImpl(State);
pub const construction_args = Body.construction_args;
pub const InternalState = reporting.BodyInternal;
pub const initOwn = Body.initOwn;
pub const deinitOwn = Body.deinitOwn;

/// Getter for disposition
pub fn get_disposition(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try Body.fields(instance)).string("disposition") orelse "");
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try Body.fields(instance)).string("type") orelse "");
}

/// Getter for blockedURL
pub fn get_blockedURL(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try instance.ctx.allocator.dupe(u8, (try Body.fields(instance)).string("blockedURL") orelse "");
}

/// Getter for destination
pub fn get_destination(instance: *runtime.Instance) anyerror!enums.RequestDestination {
    return (try Body.fields(instance)).enumeration(enums.RequestDestination, "destination");
}

/// Operation: toJSON ([Default]: every attribute, ReportBody's none)
pub fn call_toJSON(instance: *runtime.Instance) anyerror!CORPViolationReportBody.CORPViolationReportBodyToJSON {
    const fields = try Body.fields(instance);
    return .{
        .disposition = runtime.DOMString.initInterned(fields.string("disposition") orelse ""),
        .type = runtime.DOMString.initInterned(fields.string("type") orelse ""),
        .blockedURL = fields.string("blockedURL") orelse "",
        .destination = fields.enumeration(enums.RequestDestination, "destination"),
    };
}
