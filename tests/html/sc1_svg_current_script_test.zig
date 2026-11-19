//! SVG scripts use HTML's currentScript document-tree-only rule.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

/// Run the event loop until `count` SVG scripts have run (`sc1SvgLoaded`),
/// for at most 10 s of turns; the caller's expectation names what is missing.
fn runUntilLoaded(page: helpers.Page, count: u32) !void {
    var expected_buf: [16]u8 = undefined;
    const expected = try std.fmt.bufPrint(&expected_buf, "{d}", .{count});
    var turns: usize = 0;
    while (turns < 500) : (turns += 1) {
        const loaded = try page.evaluate("String(sc1SvgLoaded)");
        defer std.testing.allocator.free(loaded);
        if (std.mem.eql(u8, loaded, expected)) return;
        _ = try page.browser.runEventLoopBlocking(20);
    }
}

fn svgCurrentScript() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.sc1SvgLog = [];
        \\globalThis.sc1SvgLoaded = 0;
        \\for (const mode of ['document', 'open', 'closed']) {
        \\  const host = document.body.appendChild(document.createElement('div'));
        \\  const root = host.attachShadow({mode: mode === 'document' ? 'closed' : mode});
        \\  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        \\  (mode === 'document' ? document.body : root).appendChild(svg);
        \\  const script = document.createElementNS('http://www.w3.org/2000/svg', 'script');
        \\  const expected = mode === 'document' ? script : null;
        \\  const name = 'sc1SvgObserve' + mode;
        \\  globalThis[name] = () => {
        \\    sc1SvgLog.push(document.currentScript === expected);
        \\    (mode === 'document' ? root : document.body).appendChild(script);
        \\    sc1SvgLog.push(document.currentScript === expected);
        \\  };
        \\  script.setAttribute('href', 'data:text/javascript,' + encodeURIComponent(name + '()'));
        \\  script.onload = () => { ++sc1SvgLoaded; script.remove(); svg.remove(); host.remove(); };
        \\  svg.appendChild(script);
        \\}
    );
    // A script-inserted external SVG script is force-async (SVG 2 15.2, as
    // HTML's): fetched in parallel and run when its response arrives - a
    // task some turns away, later still on a loaded host. Wait until all
    // three ran, not for one turn.
    try runUntilLoaded(page, 3);
    const result = try page.evaluate("sc1SvgLoaded + ':' + sc1SvgLog.join(',') + ':' + (document.currentScript === null)");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("3:true,true,true,true,true,true:true", result);
}

test "SVG shadow scripts expose null and document scripts expose themselves even after moving" {
    try helpers.onFreshThread(svgCurrentScript);
}
