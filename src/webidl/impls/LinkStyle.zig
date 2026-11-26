//! Implementation for the LinkStyle mixin (CSSOM §6.3.1):
//! readonly attribute CSSStyleSheet? sheet, shared by HTMLLinkElement,
//! HTMLStyleElement, SVGStyleElement, and ProcessingInstruction.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const LinkStyle = interfaces.LinkStyle;

pub const State = LinkStyle.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// Getter for sheet (CSSOM §6.3.1): return this's associated CSS style sheet,
/// or null if there is none.
pub fn get_sheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const record = dom.style_sheet_owners.sheetRecordOf(instance) orelse return null;
    return try dom.style.objects.sheetObject(record, instance.ctx);
}
