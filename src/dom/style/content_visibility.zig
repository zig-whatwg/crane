//! CSS Contain 2 sections 3.1 and 4: content-visibility applicability.
//! Read only native element facts and the caller's already-computed Display;
//! this module never resolves style or asks a layout host for geometry.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const css = @import("css");
const Display = css.style_values.Display;
const ComputedStyle = css.computed_style.ComputedStyle;
const node_creation = @import("../node_creation.zig");
const element_data = @import("../element_data.zig");
const image_sources = @import("../image_sources.zig");
const document_internals = @import("../document_internals.zig");

const html_namespace = "http://www.w3.org/1999/xhtml";
const svg_namespace = "http://www.w3.org/2000/svg";

/// Whether content-visibility can skip this element's contents. Its own
/// principal box remains rendered when its contents are skipped.
pub fn applies(element: *runtime.Instance, display: Display) bool {
    const names = node_creation.elementNames(element) orelse return false;
    const html = std.mem.eql(u8, names.namespace orelse "", html_namespace);
    // HTML Rendering 15.4.2: audio without controls generates no box,
    // including when an author supplies an otherwise eligible display.
    if (html and std.mem.eql(u8, names.local_name, "audio")) {
        const data = element_data.of(element) orelse return false;
        if (!element_data.hasAttribute(data, "controls")) return false;
    }
    if (display.canSizeContain(false)) return true;
    if (display.box != .normal or display.inner == .table) return false;
    return display.canSizeContain(replaced(element, names.local_name, names.namespace orelse ""));
}

/// CSS Contain 2 §4: whether already-computed style skips these contents.
/// Shared with rendering, rendered text and font eligibility. This reads
/// only the supplied style and native element facts; it never cascades.
pub fn contentsSkipped(element: *runtime.Instance, style: *const ComputedStyle) bool {
    return style.keyword(.content_visibility) == .hidden and applies(element, style.display());
}

fn replaced(element: *runtime.Instance, local_name: []const u8, namespace: []const u8) bool {
    if (std.mem.eql(u8, namespace, html_namespace)) {
        // HTML Rendering 15.4.1/.2. The image owner supplies its facts;
        // there is no private-state cast or reference into an impl.
        if (std.mem.eql(u8, local_name, "img")) return image_sources.replacedFacts(element) != null;
        inline for (.{ "canvas", "embed", "iframe", "video" }) |name| {
            if (std.mem.eql(u8, local_name, name)) return true;
        }
        if (std.mem.eql(u8, local_name, "audio")) {
            const data = element_data.of(element) orelse return false;
            return element_data.hasAttribute(data, "controls");
        }
        if (std.mem.eql(u8, local_name, "input")) {
            const data = element_data.of(element) orelse return false;
            return std.ascii.eqlIgnoreCase(element_data.getAttributeValue(data, "type", null), "image");
        }
        // object can represent fallback content. Its representation is not
        // exposed by an existing hook; keep today's non-atomic classification
        // until that owner supplies the fact (row 118 Q12 follow-up).
        return false;
    }
    if (!std.mem.eql(u8, namespace, svg_namespace) or !std.mem.eql(u8, local_name, "svg")) return false;
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return false;
    if (document_internals.getDocumentType(document) != .html) return false;
    const parent = (interfaces.Node.get_parentElement(element) catch null) orelse return true;
    const names = node_creation.elementNames(parent) orelse return false;
    // An outer SVG embedded in HTML is replaced; a nested SVG remains an
    // SVG graphics container. No viewport size is needed for this decision.
    return !std.mem.eql(u8, names.namespace orelse "", svg_namespace);
}
