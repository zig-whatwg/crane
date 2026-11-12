//! Document.open's replace-all stays inside its outer custom-element reaction
//! scope, so callbacks can replace the installed parser without losing owners.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const dom = @import("dom");

const Scenario = enum { replace_parser, write_marker };

fn exercise(scenario: Scenario) !void {
    var browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const document = page.document_instance orelse return error.TestUnexpectedResult;
    const before = dom.document_internals.getInternal(document) orelse return error.TestUnexpectedResult;
    try testing.expect(before.active_parser == null);
    try testing.expectEqual(@TypeOf(before.ready_state)._interactive_, before.ready_state);

    try page.runScript(if (scenario == .write_marker) "globalThis.writeFromCallback = true" else "globalThis.writeFromCallback = false");
    try page.runScript(
        \\globalThis.openObservations = [];
        \\customElements.define('dw-open-reentrant', class extends HTMLElement {
        \\  disconnectedCallback() {
        \\    const doc = this.ownerDocument;
        \\    openObservations.push(doc.readyState);
        \\    doc.open();
        \\    if (writeFromCallback)
        \\      doc.write('<!doctype html><body><p id="callback-marker">callback</p>');
        \\  }
        \\});
        \\document.body.appendChild(document.createElement('dw-open-reentrant'));
        \\document.open();
    );
    const after = dom.document_internals.getInternal(document) orelse return error.TestUnexpectedResult;
    try testing.expect(after.active_parser != null);
    try testing.expect(after.is_script_created_parser);
    try page.runScript("if (openObservations.length !== 1) throw new Error('disconnected callback did not run exactly once')");

    if (scenario == .write_marker) try page.runScript(
        \\if (openObservations[0] !== 'loading')
        \\  throw new Error('disconnected callback ran before the outer parser was installed');
        \\const callbackMarker = document.getElementById('callback-marker');
        \\if (!callbackMarker || callbackMarker.textContent !== 'callback')
        \\  throw new Error('outer open replaced the callback-created stream');
        \\document.write('<p id="continued-marker">continued</p>');
        \\if (document.getElementById('callback-marker') !== callbackMarker ||
        \\    document.getElementById('continued-marker').textContent !== 'continued')
        \\  throw new Error('the callback-created parser did not retain its input stream');
    );

    try page.runScript("document.close()");
    try testing.expect(dom.document_internals.getInternal(document).?.active_parser == null);
    // Browser teardown and std.testing.allocator also detect a parser whose
    // only Document reference was overwritten by the outer open invocation.
}

fn onFreshThread(scenario: Scenario) !void {
    const Run = struct {
        scenario: Scenario,
        failure: ?anyerror = null,

        fn thread(self: *@This()) void {
            exercise(self.scenario) catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{ .scenario = scenario };
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "document.open owns the parser installed by a disconnected callback" {
    try onFreshThread(.replace_parser);
}

test "document.open installs its parser before disconnected callbacks and preserves their writes" {
    try onFreshThread(.write_marker);
}
