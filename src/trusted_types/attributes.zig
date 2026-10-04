//! Which content attributes and IDL attributes are Trusted Types sinks.
//!
//! - 3.8 "get Trusted Type data for attribute": given an element, an
//!   attribute's local name and namespace, the Trusted Type the attribute
//!   expects and the sink name a violation reports.
//! - 2.3.1 getAttributeType(tagName, attribute, elementNs, attrNs) and
//!   getPropertyType(tagName, property, elementNs): the same tables, keyed by
//!   a tag name.
//!
//! "Is an event handler content attribute" is HTML's knowledge, not this
//! table's: callers pass it as a predicate (src/dom/trusted_types.zig answers
//! it from the generated interfaces).
//!
//! Spec: https://w3c.github.io/trusted-types/dist/spec/#abstract-opdef-get-trusted-type-data-for-attribute

const std = @import("std");
const Kind = @import("root.zig").Kind;

pub const html_namespace = "http://www.w3.org/1999/xhtml";
pub const svg_namespace = "http://www.w3.org/2000/svg";
pub const mathml_namespace = "http://www.w3.org/1998/Math/MathML";
pub const xlink_namespace = "http://www.w3.org/1999/xlink";

/// Whether a local name is the name of an event handler content attribute.
pub const IsEventHandlerName = *const fn (name: []const u8) bool;

/// The interfaces the tables name, as DOM's "element interface" for a local
/// name and namespace gives them: the only rows keyed by an interface.
pub const ElementInterface = enum {
    html_iframe,
    html_script,
    svg_script,
    other,
};

/// DOM's element interface for `local_name` in `namespace`, as far as the
/// tables tell interfaces apart.
pub fn elementInterface(namespace: ?[]const u8, local_name: []const u8) ElementInterface {
    const ns = namespace orelse return .other;
    if (std.mem.eql(u8, ns, html_namespace)) {
        if (std.mem.eql(u8, local_name, "iframe")) return .html_iframe;
        if (std.mem.eql(u8, local_name, "script")) return .html_script;
    } else if (std.mem.eql(u8, ns, svg_namespace)) {
        if (std.mem.eql(u8, local_name, "script")) return .svg_script;
    }
    return .other;
}

/// A row of 3.8's table: the attribute's Trusted Type (the fourth member) and
/// its sink (the fifth).
pub const AttributeData = struct {
    kind: Kind,
    sink: Sink,

    pub const Sink = union(enum) {
        /// A table row's sink name.
        name: []const u8,
        /// Step 2.1: "Element " + the event handler attribute's name.
        event_handler: []const u8,
    };

    /// The sink name, in `buffer` when it has to be built; a name too long
    /// for `buffer` is cut (a sink name is only ever reported).
    pub fn sinkName(self: AttributeData, buffer: []u8) []const u8 {
        return switch (self.sink) {
            .name => |n| n,
            .event_handler => |attribute| std.fmt.bufPrint(buffer, "Element {s}", .{attribute}) catch buffer,
        };
    }

    /// The sink name, OWNED by `allocator`.
    pub fn allocSinkName(self: AttributeData, allocator: std.mem.Allocator) error{OutOfMemory}![]u8 {
        return switch (self.sink) {
            .name => |n| allocator.dupe(u8, n),
            .event_handler => |attribute| std.mem.concat(allocator, u8, &.{ "Element ", attribute }),
        };
    }
};

/// 3.8 "get Trusted Type data for attribute", given an element by its
/// namespace and local name, an attribute's local name and its namespace
/// (null for none). Null when the attribute is no sink. `attribute` is
/// borrowed by an event handler's sink.
pub fn dataForAttribute(
    element_namespace: ?[]const u8,
    element_local_name: []const u8,
    attribute: []const u8,
    attribute_namespace: ?[]const u8,
    is_event_handler_name: IsEventHandlerName,
) ?AttributeData {
    // 1. Let data be null.
    // 2. "If attributeNs is null, « HTML namespace, SVG namespace, MathML
    // namespace » contains element's namespace, and attribute is the name of
    // an event handler content attribute: return (Element, null, attribute,
    // TrustedScript, "Element " + attribute)."
    if (attribute_namespace == null) {
        if (element_namespace) |ns| {
            const markup = std.mem.eql(u8, ns, html_namespace) or
                std.mem.eql(u8, ns, svg_namespace) or
                std.mem.eql(u8, ns, mathml_namespace);
            if (markup and is_event_handler_name(attribute)) {
                return .{ .kind = .script, .sink = .{ .event_handler = attribute } };
            }
        }
    }
    // 3. "Find the row in the following table, where element is in the
    // first column, attributeNs is in the second column, and attribute is in
    // the third column."
    switch (elementInterface(element_namespace, element_local_name)) {
        .html_iframe => if (attribute_namespace == null and std.mem.eql(u8, attribute, "srcdoc")) {
            return .{ .kind = .html, .sink = .{ .name = "HTMLIFrameElement srcdoc" } };
        },
        .html_script => if (attribute_namespace == null and std.mem.eql(u8, attribute, "src")) {
            return .{ .kind = .script_url, .sink = .{ .name = "HTMLScriptElement src" } };
        },
        .svg_script => if (std.mem.eql(u8, attribute, "href")) {
            const ns_matches = if (attribute_namespace) |ns| std.mem.eql(u8, ns, xlink_namespace) else true;
            if (ns_matches) return .{ .kind = .script_url, .sink = .{ .name = "SVGScriptElement href" } };
        },
        .other => {},
    }
    // 4. Return data.
    return null;
}

/// TrustedTypePolicyFactory getAttributeType(tagName, attribute, elementNs,
/// attrNs) (2.3.1): the Trusted Type the attribute expects, or null.
/// `element_namespace` and `attribute_namespace` are the arguments as given
/// (null, empty or a namespace).
pub fn getAttributeType(
    allocator: std.mem.Allocator,
    tag_name: []const u8,
    attribute: []const u8,
    element_namespace: ?[]const u8,
    attribute_namespace: ?[]const u8,
    is_event_handler_name: IsEventHandlerName,
) error{OutOfMemory}!?Kind {
    // 1. "Set localName to tagName in ASCII lowercase."
    const local_name = try std.ascii.allocLowerString(allocator, tag_name);
    defer allocator.free(local_name);
    // 2. "Set attribute to attribute in ASCII lowercase."
    const attribute_lower = try std.ascii.allocLowerString(allocator, attribute);
    defer allocator.free(attribute_lower);
    // 3. "If elementNs is null or an empty string, set elementNs to HTML
    // namespace."
    const element_ns: []const u8 = if (element_namespace) |ns| (if (ns.len == 0) html_namespace else ns) else html_namespace;
    // 4. "If attrNs is an empty string, set attrNs to null."
    const attr_ns: ?[]const u8 = if (attribute_namespace) |ns| (if (ns.len == 0) null else ns) else null;
    // 5-8. The element interface for localName and elementNs, and its
    // attribute data's Trusted Type.
    const data = dataForAttribute(element_ns, local_name, attribute_lower, attr_ns, is_event_handler_name) orelse return null;
    // 9. Return expectedType.
    return data.kind;
}

/// TrustedTypePolicyFactory getPropertyType(tagName, property, elementNs)
/// (2.3.1): the Trusted Type the IDL attribute expects, or null.
pub fn getPropertyType(
    allocator: std.mem.Allocator,
    tag_name: []const u8,
    property: []const u8,
    element_namespace: ?[]const u8,
) error{OutOfMemory}!?Kind {
    // 1. "Set localName to tagName in ASCII lowercase."
    const local_name = try std.ascii.allocLowerString(allocator, tag_name);
    defer allocator.free(local_name);
    // 2. "If elementNs is null or an empty string, set elementNs to HTML
    // namespace."
    const element_ns: []const u8 = if (element_namespace) |ns| (if (ns.len == 0) html_namespace else ns) else html_namespace;
    // 3. "Let interface be the element interface for localName and elementNs."
    const interface = elementInterface(element_ns, local_name);
    // 4-5. The row whose first column is "*" or interface's name and whose
    // second is property.
    const Row = struct { interface: ?ElementInterface, property: []const u8, kind: Kind };
    const table = [_]Row{
        .{ .interface = .html_iframe, .property = "srcdoc", .kind = .html },
        .{ .interface = .html_script, .property = "innerText", .kind = .script },
        .{ .interface = .html_script, .property = "src", .kind = .script_url },
        .{ .interface = .html_script, .property = "text", .kind = .script },
        .{ .interface = .html_script, .property = "textContent", .kind = .script },
        .{ .interface = null, .property = "innerHTML", .kind = .html },
        .{ .interface = null, .property = "outerHTML", .kind = .html },
    };
    for (table) |row| {
        if (row.interface) |i| if (i != interface) continue;
        if (std.mem.eql(u8, row.property, property)) return row.kind;
    }
    // 6. Return expectedType.
    return null;
}
