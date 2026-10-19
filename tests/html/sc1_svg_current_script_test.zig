//! SVG scripts use HTML's currentScript document-tree-only rule.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

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
    try page.turn();
    const result = try page.evaluate("sc1SvgLoaded + ':' + sc1SvgLog.join(',') + ':' + (document.currentScript === null)");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("3:true,true,true,true,true,true:true", result);
}

test "SVG shadow scripts expose null and document scripts expose themselves even after moving" {
    try helpers.onFreshThread(svgCurrentScript);
}
