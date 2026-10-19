//! currentScript is chosen at execution entry and restored after nested scripts.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn currentScript() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.sc1Log = [];
        \\globalThis.sc1Loaded = 0;
        \\for (const mode of ['open', 'closed']) {
        \\  const host = document.body.appendChild(document.createElement('div'));
        \\  const root = host.attachShadow({mode});
        \\  const script = document.createElement('script');
        \\  const name = 'sc1Observe' + mode;
        \\  globalThis[name] = () => {
        \\    sc1Log.push(document.currentScript === null ? 'shadow' : 'exposed');
        \\    const inner = document.createElement('script');
        \\    globalThis.sc1Inner = inner;
        \\    inner.textContent = "sc1Log.push(document.currentScript === sc1Inner ? 'inner' : 'wrong-inner')";
        \\    document.body.appendChild(inner);
        \\    inner.remove();
        \\    sc1Log.push(document.currentScript === null ? 'restored' : 'wrong-restore');
        \\    document.body.appendChild(script);
        \\    sc1Log.push(document.currentScript === null ? 'moved' : 'wrong-move');
        \\  };
        \\  script.src = 'data:text/javascript,' + encodeURIComponent(name + '()');
        \\  script.onload = () => { ++sc1Loaded; script.remove(); host.remove(); };
        \\  root.appendChild(script);
        \\}
    );
    try page.turn();
    const result = try page.evaluate("sc1Loaded + ':' + sc1Log.join(',') + ':' + (document.currentScript === null)");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("2:shadow,inner,restored,moved,shadow,inner,restored,moved:true", result);
    // A getter-time filter would break a document script moved into a root.
    try page.run(
        \\globalThis.sc1MovedLog = [];
        \\const host = document.body.appendChild(document.createElement('div'));
        \\const root = host.attachShadow({mode: 'closed'});
        \\const outer = document.createElement('script');
        \\globalThis.sc1Move = () => {
        \\  sc1MovedLog.push(document.currentScript === outer);
        \\  root.appendChild(outer);
        \\  sc1MovedLog.push(document.currentScript === outer);
        \\};
        \\outer.textContent = 'sc1Move()';
        \\document.body.appendChild(outer);
        \\host.remove();
    );
    const moved = try page.evaluate("sc1MovedLog.join(',')");
    defer std.testing.allocator.free(moved);
    try std.testing.expectEqualStrings("true,true", moved);
}

test "HTML shadow scripts expose null at entry and restore it after nested execution" {
    try helpers.onFreshThread(currentScript);
}
