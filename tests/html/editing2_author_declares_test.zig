//! Lane editing2: dom.style.engine.authorDeclares - whether the author
//! origin (style sheets and the style attribute, never the UA sheet or
//! presentational hints) declares a property for an element. The editing
//! join asks it about a <pre>'s white-space (Chrome and Safari add a
//! white-space span for an author-specified pre only:
//! editing/other/join-pre-and-other-block.html).
const std = @import("std");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const dom = @import("dom");
const helpers = @import("edges_node_holders_helpers.zig");

const white_space_names = [_][]const u8{ "white-space", "white-space-collapse", "text-wrap-mode", "text-wrap" };

const longhand_names = [_][]const u8{ "white-space-collapse", "text-wrap-mode" };

fn declaresAny(page: helpers.Page, id: []const u8, names: []const []const u8) !bool {
    const document = page.browser.current_context.?.document_instance.?;
    const element = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))) orelse return error.NoElement;
    return dom.style.engine.authorDeclares(element, names);
}

fn declares(page: helpers.Page, id: []const u8) !bool {
    return declaresAny(page, id, &white_space_names);
}

fn bothDirections() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<pre id=ua>x</pre><pre id=attr style="white-space: pre">x</pre>' +
        \\  '<div id=sheet>x</div><div id=other style="color: red">x</div><p id=longhand style="white-space-collapse: preserve">x</p>' +
        \\  '<pre id=later>x</pre><span id=nowhere>x</span>';
        \\const s = document.createElement('style');
        \\s.textContent = '#sheet { white-space: pre-wrap } #nowhere { color: blue }';
        \\document.head.appendChild(s);
    );
    // The UA sheet's pre { white-space: pre } alone: false.
    try std.testing.expect(!try declares(page, "ua"));
    // The style attribute, a sheet's rule, a longhand: true.
    try std.testing.expect(try declares(page, "attr"));
    try std.testing.expect(try declares(page, "sheet"));
    try std.testing.expect(try declares(page, "longhand"));
    // The shorthand in a sheet and in a style attribute is declared as its
    // longhands: the longhand names alone find it.
    try std.testing.expect(try declaresAny(page, "sheet", &longhand_names));
    try std.testing.expect(try declaresAny(page, "attr", &longhand_names));
    try std.testing.expect(!try declaresAny(page, "ua", &longhand_names));
    // Other properties, from either author source: false.
    try std.testing.expect(!try declares(page, "other"));
    try std.testing.expect(!try declares(page, "nowhere"));
    // A sheet added later for pre: true; removing it: false again.
    try page.run("const t = document.createElement('style'); t.id = 'pres'; t.textContent = 'pre { white-space: pre }'; document.head.appendChild(t);");
    try std.testing.expect(try declares(page, "later"));
    try std.testing.expect(try declares(page, "ua"));
    try page.run("document.getElementById('pres').remove();");
    try std.testing.expect(!try declares(page, "later"));
}

test "authorDeclares: the UA sheet alone is not an author declaration; sheets and style attributes are" {
    try helpers.onFreshThread(bothDirections);
}
