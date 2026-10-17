//! updateCurrentEntry captures its entry before StructuredSerializeForStorage.
//! A getter can replace that entry and collect before currententrychange's
//! `from` is read; the synchronous API call must keep the captured object.
const std = @import("std");
const browser_mod = @import("browser");
const helpers = @import("edges_node_holders_helpers.zig");

fn replaceDuringSerialization() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://example.test/nv2-state-gc" });
    try page.runScript(
        \\const nav = navigation;
        \\const originalId = nav.currentEntry.id;
        \\let changed = false;
        \\let from;
        \\nav.oncurrententrychange = event => {
        \\  if (event.navigationType === null) {
        \\    changed = true;
        \\    from = event.from;
        \\  }
        \\};
        \\nav.updateCurrentEntry({state: {get value() {
        \\  nav.navigate('#replacement', {history: 'replace', state: 'replacement state'});
        \\  TestUtils.gc();
        \\  const churn = [];
        \\  for (let i = 0; i < 64; ++i) churn.push(document.createElement('i'));
        \\  TestUtils.gc();
        \\  return 'serialized state';
        \\}}});
        \\if (!changed || from.id !== originalId || from === nav.currentEntry)
        \\  throw new Error('currententrychange lost the captured entry');
        \\if (nav.currentEntry.getState() !== 'replacement state')
        \\  throw new Error('updateCurrentEntry overwrote the replacement entry');
        \\nav.oncurrententrychange = null;
        \\from = null;
    );
}

test "updateCurrentEntry preserves its captured entry across replacement and collection" {
    try helpers.onFreshThread(replaceDuringSerialization);
}
