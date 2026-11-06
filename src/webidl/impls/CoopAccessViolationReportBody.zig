//! Implementation for CoopAccessViolationReportBody interface
//!
//! HTML 7.1.3.3 COOP's access report body as Chromium queues it on a ReportingObserver (coop_reporting.checkAccess writes its members).
//! One of the report body interfaces of specs/supplementary/
//! reporting-interfaces.idl (the user's ruling of 2026-11-05): its members are
//! read from the native report record it was made from
//! (dom.reporting.makeBody, dom.reporting.BodyImpl).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const reporting = @import("dom").reporting;
const CoopAccessViolationReportBody = interfaces.CoopAccessViolationReportBody;

pub const State = CoopAccessViolationReportBody.State;

const Body = reporting.BodyImpl(State);
pub const construction_args = Body.construction_args;
pub const InternalState = reporting.BodyInternal;
pub const initOwn = Body.initOwn;
pub const deinitOwn = Body.deinitOwn;

/// Getter for sourceFile
pub fn get_sourceFile(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return if ((try Body.fields(instance)).string("sourceFile")) |value| runtime.DOMString.initInterned(value) else null;
}

/// Getter for lineNumber
pub fn get_lineNumber(instance: *runtime.Instance) anyerror!?u32 {
    return (try Body.fields(instance)).unsigned("lineNumber");
}

/// Getter for columnNumber
pub fn get_columnNumber(instance: *runtime.Instance) anyerror!?u32 {
    return (try Body.fields(instance)).unsigned("columnNumber");
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try Body.fields(instance)).string("type") orelse "");
}

/// Getter for property
pub fn get_property(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try Body.fields(instance)).string("property") orelse "");
}

/// Getter for openeeURL
pub fn get_openeeURL(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return if ((try Body.fields(instance)).string("openeeURL")) |value| runtime.DOMString.initInterned(value) else null;
}

/// Getter for openerURL
pub fn get_openerURL(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return if ((try Body.fields(instance)).string("openerURL")) |value| runtime.DOMString.initInterned(value) else null;
}

/// Getter for otherDocumentURL
pub fn get_otherDocumentURL(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return if ((try Body.fields(instance)).string("otherDocumentURL")) |value| runtime.DOMString.initInterned(value) else null;
}

/// Operation: toJSON. Chromium's CoopAccessViolationReportBody::
/// BuildJSONValue: the source location (LocationReportBody, null when
/// unknown), type and property, and the one window URL its type names -
/// openeeURL, openerURL or otherDocumentURL - only when the report has it.
pub fn call_toJSON(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const fields = try Body.fields(instance);
    var members: [6]engine.DictionaryMember = undefined;
    var count: usize = 0;
    members[count] = .{ .name = "sourceFile", .value = if (fields.string("sourceFile")) |value| .{ .string = .{ .data = value, .owned = false } } else .null };
    count += 1;
    members[count] = .{ .name = "lineNumber", .value = if (fields.unsigned("lineNumber")) |value| .{ .number = @floatFromInt(value) } else .null };
    count += 1;
    members[count] = .{ .name = "columnNumber", .value = if (fields.unsigned("columnNumber")) |value| .{ .number = @floatFromInt(value) } else .null };
    count += 1;
    members[count] = .{ .name = "type", .value = .{ .string = .{ .data = fields.string("type") orelse "", .owned = false } } };
    count += 1;
    members[count] = .{ .name = "property", .value = .{ .string = .{ .data = fields.string("property") orelse "", .owned = false } } };
    count += 1;
    for ([_][]const u8{ "openeeURL", "openerURL", "otherDocumentURL" }) |name| {
        const url = fields.string(name) orelse continue;
        members[count] = .{ .name = name, .value = .{ .string = .{ .data = url, .owned = false } } };
        count += 1;
        break;
    }
    const object = try engine.createDictionaryObject(engine.currentRealm() orelse instance.ctx, members[0..count]);
    return object.take();
}
