//! Lane editing2, unit 1: the Editing spec's configuration commands
//! (specs/w3c/execCommand.md, "The styleWithCSS command", "The useCSS
//! command", "Methods to query and execute commands").
//!
//! styleWithCSS has a state (the Document's CSS styling flag) and no value,
//! so queryCommandValue answers ""; useCSS has neither. Chrome 155,
//! Firefox 158 and Safari 27 all agree (integrator probe 2026-10-26,
//! tmp/analysis/integrator-probes-1026l/results/swc-*.json; WPT
//! editing/run/misc.html). contentReadOnly is not a command of the spec and
//! none of the three supports it (WPT editing/other/legacy-edit-command.html
//! ?command=contentReadOnly, 8/8 in each at wpt.fyi df642c4142).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

const setup_script =
    \\document.body.innerHTML = '<div contenteditable id=host>foo</div>';
    \\globalThis.q = (name) => [document.queryCommandState(name), JSON.stringify(document.queryCommandValue(name)), document.queryCommandIndeterm(name), document.queryCommandSupported(name), document.queryCommandEnabled(name)].join(',');
;

const Step = struct {
    /// Script run first (an execCommand call, or "" for none); its result
    /// is compared with `returns` when that is not null.
    script: []const u8,
    returns: ?[]const u8,
    /// The command queried afterwards, and q()'s expected answer:
    /// state, JSON value, indeterm, supported, enabled.
    query: []const u8,
    expected: []const u8,
};

const steps = [_]Step{
    // The CSS styling flag starts false; no value either way.
    .{ .script = "", .returns = null, .query = "styleWithCSS", .expected = "false,\"\",false,true,true" },
    .{ .script = "document.execCommand('styleWithCSS', false, 'true')", .returns = "true", .query = "styleWithCSS", .expected = "true,\"\",false,true,true" },
    // The flag persists across other commands and queries.
    .{ .script = "document.queryCommandState('bold')", .returns = "false", .query = "stylewithcss", .expected = "true,\"\",false,true,true" },
    // Only an ASCII case-insensitive "false" clears it.
    .{ .script = "document.execCommand('styleWithCSS', false, 'FaLsE')", .returns = "true", .query = "styleWithCSS", .expected = "false,\"\",false,true,true" },
    .{ .script = "document.execCommand('styleWithCSS', false, 'truer')", .returns = "true", .query = "styleWithCSS", .expected = "true,\"\",false,true,true" },
    .{ .script = "document.execCommand('styleWithCSS', false, ' false')", .returns = "true", .query = "styleWithCSS", .expected = "true,\"\",false,true,true" },
    .{ .script = "document.execCommand('styleWithCSS', false, 'false')", .returns = "true", .query = "styleWithCSS", .expected = "false,\"\",false,true,true" },
    .{ .script = "document.execCommand('styleWithCSS', false, 'fals\\u00e9')", .returns = "true", .query = "styleWithCSS", .expected = "true,\"\",false,true,true" },
    .{ .script = "document.execCommand('styleWithCSS', false, 'false')", .returns = "true", .query = "styleWithCSS", .expected = "false,\"\",false,true,true" },
    // No value is the IDL default "", which is not "false".
    .{ .script = "document.execCommand('styleWithCSS')", .returns = "true", .query = "styleWithCSS", .expected = "true,\"\",false,true,true" },
    // Command names are ASCII case-insensitive.
    .{ .script = "document.execCommand('STYLEWITHCSS', false, 'FALSE')", .returns = "true", .query = "StyleWithCss", .expected = "false,\"\",false,true,true" },
    // useCSS: the inverse action; no state and no value of its own.
    .{ .script = "document.execCommand('useCSS', false, 'false')", .returns = "true", .query = "styleWithCSS", .expected = "true,\"\",false,true,true" },
    .{ .script = "", .returns = null, .query = "useCSS", .expected = "false,\"\",false,true,true" },
    .{ .script = "document.execCommand('usecss', false, 'TRUE')", .returns = "true", .query = "styleWithCSS", .expected = "false,\"\",false,true,true" },
    .{ .script = "document.execCommand('UseCss', false, '')", .returns = "true", .query = "styleWithCSS", .expected = "false,\"\",false,true,true" },
    .{ .script = "document.execCommand('useCSS', false, 'FaLsE')", .returns = "true", .query = "styleWithCSS", .expected = "true,\"\",false,true,true" },
    // contentReadOnly is not supported: execCommand returns false.
    .{ .script = "document.execCommand('contentReadOnly', false, 'true')", .returns = "false", .query = "contentReadOnly", .expected = "false,\"\",false,false,false" },
    // An unknown command answers like an unsupported one.
    .{ .script = "", .returns = null, .query = "noSuchCommand", .expected = "false,\"\",false,false,false" },
};

fn configurationCommands() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    var failures: usize = 0;
    for (steps) |step| {
        if (step.script.len != 0) {
            const returned = try page.evaluate(step.script);
            defer std.testing.allocator.free(returned);
            if (step.returns) |want| if (!std.mem.eql(u8, returned, want)) {
                std.debug.print("{s}: returned {s}, expected {s}\n", .{ step.script, returned, want });
                failures += 1;
            };
        }
        const source = try std.fmt.allocPrint(std.testing.allocator, "q({f})", .{std.json.fmt(step.query, .{})});
        defer std.testing.allocator.free(source);
        const answer = try page.evaluate(source);
        defer std.testing.allocator.free(answer);
        if (!std.mem.eql(u8, answer, step.expected)) {
            std.debug.print("after {s}: q({s}) = {s}, expected {s}\n", .{ step.script, step.query, answer, step.expected });
            failures += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "styleWithCSS and useCSS: the CSS styling flag, state and no value" {
    try helpers.onFreshThread(configurationCommands);
}

fn flagIsPerDocument() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    // The CSS styling flag belongs to the Document: another document's is
    // still false.
    try page.run("document.execCommand('styleWithCSS', false, 'true')");
    const other = try page.evaluate("(() => { const d = document.implementation.createHTMLDocument(''); return String(d.queryCommandState('styleWithCSS')) + ',' + document.queryCommandState('styleWithCSS'); })()");
    defer std.testing.allocator.free(other);
    try std.testing.expectEqualStrings("false,true", other);
}

test "the CSS styling flag is per Document" {
    try helpers.onFreshThread(flagIsPerDocument);
}
