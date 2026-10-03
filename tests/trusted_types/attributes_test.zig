//! Trusted Types 3.8 "get Trusted Type data for attribute" and the factory's
//! getAttributeType / getPropertyType (2.3.1), on the cases WPT's
//! trusted-types/support/attributes.js and the getPropertyType table name.

const std = @import("std");
const testing = std.testing;
const trusted_types = @import("trusted_types");

const attributes = trusted_types.attributes;
const Kind = trusted_types.Kind;

const html_ns = attributes.html_namespace;
const svg_ns = attributes.svg_namespace;
const mathml_ns = attributes.mathml_namespace;
const xlink_ns = attributes.xlink_namespace;
const foo_ns = "https://example.com/namespace";

/// The event handler content attribute names the cases use.
fn isEventHandler(name: []const u8) bool {
    const names = [_][]const u8{ "onclick", "ondblclick", "onmousedown", "onmouseup", "onchange", "onfocus" };
    for (names) |n| if (std.mem.eql(u8, n, name)) return true;
    return false;
}

const Case = struct {
    element_ns: ?[]const u8,
    local_name: []const u8,
    attr_ns: ?[]const u8,
    attr: []const u8,
    kind: ?Kind,
    sink: []const u8 = "",
};

const cases = [_]Case{
    .{ .element_ns = html_ns, .local_name = "div", .attr_ns = null, .attr = "onclick", .kind = .script, .sink = "Element onclick" },
    .{ .element_ns = svg_ns, .local_name = "g", .attr_ns = null, .attr = "ondblclick", .kind = .script, .sink = "Element ondblclick" },
    .{ .element_ns = mathml_ns, .local_name = "mrow", .attr_ns = null, .attr = "onmousedown", .kind = .script, .sink = "Element onmousedown" },
    .{ .element_ns = html_ns, .local_name = "iframe", .attr_ns = null, .attr = "srcdoc", .kind = .html, .sink = "HTMLIFrameElement srcdoc" },
    .{ .element_ns = html_ns, .local_name = "script", .attr_ns = null, .attr = "src", .kind = .script_url, .sink = "HTMLScriptElement src" },
    .{ .element_ns = svg_ns, .local_name = "script", .attr_ns = null, .attr = "href", .kind = .script_url, .sink = "SVGScriptElement href" },
    .{ .element_ns = svg_ns, .local_name = "script", .attr_ns = xlink_ns, .attr = "href", .kind = .script_url, .sink = "SVGScriptElement href" },
    // Not sinks.
    .{ .element_ns = foo_ns, .local_name = "foo", .attr_ns = null, .attr = "onmouseup", .kind = null },
    .{ .element_ns = html_ns, .local_name = "div", .attr_ns = foo_ns, .attr = "onclick", .kind = null },
    .{ .element_ns = html_ns, .local_name = "div", .attr_ns = null, .attr = "ondoesnotexist", .kind = null },
    .{ .element_ns = html_ns, .local_name = "div", .attr_ns = null, .attr = "data-onclick", .kind = null },
    .{ .element_ns = html_ns, .local_name = "div", .attr_ns = null, .attr = "srcdoc", .kind = null },
    .{ .element_ns = foo_ns, .local_name = "iframe", .attr_ns = null, .attr = "srcdoc", .kind = null },
    .{ .element_ns = html_ns, .local_name = "iframe", .attr_ns = foo_ns, .attr = "srcdoc", .kind = null },
    .{ .element_ns = html_ns, .local_name = "iframe", .attr_ns = null, .attr = "data-srcdoc", .kind = null },
    .{ .element_ns = html_ns, .local_name = "div", .attr_ns = null, .attr = "src", .kind = null },
    .{ .element_ns = foo_ns, .local_name = "script", .attr_ns = null, .attr = "src", .kind = null },
    .{ .element_ns = html_ns, .local_name = "script", .attr_ns = foo_ns, .attr = "src", .kind = null },
    .{ .element_ns = html_ns, .local_name = "script", .attr_ns = null, .attr = "data-src", .kind = null },
    .{ .element_ns = svg_ns, .local_name = "g", .attr_ns = null, .attr = "href", .kind = null },
    .{ .element_ns = svg_ns, .local_name = "script", .attr_ns = foo_ns, .attr = "href", .kind = null },
    .{ .element_ns = html_ns, .local_name = "script", .attr_ns = null, .attr = "href", .kind = null },
    .{ .element_ns = svg_ns, .local_name = "script", .attr_ns = null, .attr = "src", .kind = null },
};

test "get Trusted Type data for attribute: every attributes.js case" {
    for (cases) |case| {
        const data = attributes.dataForAttribute(case.element_ns, case.local_name, case.attr, case.attr_ns, &isEventHandler);
        if (case.kind) |kind| {
            const d = data orelse {
                std.debug.print("expected {s} for <{s}> {s}\n", .{ @tagName(kind), case.local_name, case.attr });
                return error.TestExpectedEqual;
            };
            try testing.expectEqual(kind, d.kind);
            var buf: [64]u8 = undefined;
            try testing.expectEqualStrings(case.sink, d.sinkName(&buf));
        } else {
            try testing.expect(data == null);
        }
    }
}

test "getAttributeType lowercases names, defaults the element namespace to HTML and maps an empty attribute namespace to null" {
    const allocator = testing.allocator;
    try testing.expectEqual(@as(?Kind, .script_url), try attributes.getAttributeType(allocator, "SCRIPT", "SRC", null, null, &isEventHandler));
    try testing.expectEqual(@as(?Kind, .script_url), try attributes.getAttributeType(allocator, "script", "src", "", "", &isEventHandler));
    try testing.expectEqual(@as(?Kind, .html), try attributes.getAttributeType(allocator, "IFrame", "SrcDoc", html_ns, null, &isEventHandler));
    try testing.expectEqual(@as(?Kind, .script), try attributes.getAttributeType(allocator, "DIV", "OnClick", null, null, &isEventHandler));
    try testing.expectEqual(@as(?Kind, .script_url), try attributes.getAttributeType(allocator, "script", "href", svg_ns, xlink_ns, &isEventHandler));
    try testing.expectEqual(@as(?Kind, null), try attributes.getAttributeType(allocator, "foo", "bar", null, null, &isEventHandler));
    try testing.expectEqual(@as(?Kind, null), try attributes.getAttributeType(allocator, "script", "src", foo_ns, null, &isEventHandler));
}

test "getPropertyType: the table, case-sensitive properties, any interface for innerHTML and outerHTML" {
    const allocator = testing.allocator;
    try testing.expectEqual(@as(?Kind, .html), try attributes.getPropertyType(allocator, "div", "innerHTML", null));
    try testing.expectEqual(@as(?Kind, .html), try attributes.getPropertyType(allocator, "foo", "outerHTML", foo_ns));
    try testing.expectEqual(@as(?Kind, .html), try attributes.getPropertyType(allocator, "IFRAME", "srcdoc", ""));
    try testing.expectEqual(@as(?Kind, .script), try attributes.getPropertyType(allocator, "script", "innerText", null));
    try testing.expectEqual(@as(?Kind, .script), try attributes.getPropertyType(allocator, "script", "text", null));
    try testing.expectEqual(@as(?Kind, .script), try attributes.getPropertyType(allocator, "script", "textContent", null));
    try testing.expectEqual(@as(?Kind, .script_url), try attributes.getPropertyType(allocator, "Script", "src", html_ns));
    try testing.expectEqual(@as(?Kind, null), try attributes.getPropertyType(allocator, "script", "SRC", null));
    try testing.expectEqual(@as(?Kind, null), try attributes.getPropertyType(allocator, "script", "src", svg_ns));
    try testing.expectEqual(@as(?Kind, null), try attributes.getPropertyType(allocator, "div", "src", null));
    try testing.expectEqual(@as(?Kind, null), try attributes.getPropertyType(allocator, "foo", "bar", null));
}

test "a kind's interface and policy function names" {
    try testing.expectEqualStrings("TrustedHTML", Kind.html.interfaceName());
    try testing.expectEqualStrings("TrustedScript", Kind.script.interfaceName());
    try testing.expectEqualStrings("TrustedScriptURL", Kind.script_url.interfaceName());
    try testing.expectEqualStrings("createHTML", Kind.html.functionName());
    try testing.expectEqualStrings("createScript", Kind.script.functionName());
    try testing.expectEqualStrings("createScriptURL", Kind.script_url.functionName());
}
