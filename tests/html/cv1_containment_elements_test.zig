//! HTML Rendering §15.4 and CSS Contain 2 §3.1/§4: replaced inlines.
const std = @import("std");
const dom = @import("dom");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

test "content visibility classifies inline replaced elements from existing element facts" {
    if (comptime @hasDecl(dom.style, "content_visibility")) return helpers.onFreshThread(Checks.elements);
    return error.MissingContainmentApplicability;
}

const Checks = struct {
    fn elements() !void {
        const page = try helpers.Page.open();
        defer page.close();
        try page.run(
            \\document.body.innerHTML = '<span id=span></span><img id=img><canvas id=canvas></canvas><embed id=embed><iframe id=iframe></iframe><video id=video></video><audio id=audio></audio><audio id=controls controls></audio><input id=image type=image><input id=text type=text><object id=object></object><svg id=svg><svg id=nested></svg></svg>';
        );
        const doc = page.browser.current_context.?.document_instance.?;
        const Case = struct { id: []const u8, expected: bool };
        for ([_]Case{
            .{ .id = "span", .expected = false },
            .{ .id = "img", .expected = true },
            .{ .id = "canvas", .expected = true },
            .{ .id = "embed", .expected = true },
            .{ .id = "iframe", .expected = true },
            .{ .id = "video", .expected = true },
            .{ .id = "audio", .expected = false },
            .{ .id = "controls", .expected = true },
            .{ .id = "image", .expected = true },
            .{ .id = "text", .expected = false },
            .{ .id = "object", .expected = false }, // no representation hook; Q12
            .{ .id = "svg", .expected = true },
            .{ .id = "nested", .expected = false },
        }) |case| {
            const element = (try interfaces.Document.call_getElementById(doc, runtime.DOMString.initInterned(case.id))).?;
            try std.testing.expectEqual(case.expected, dom.style.content_visibility.applies(element, .inline_flow));
        }
    }
};
