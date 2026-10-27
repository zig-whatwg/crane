//! Lane editing3, unit 1: the Editing spec's "wrap" a list of consecutive
//! sibling nodes (specs/w3c/execCommand.md, "Wrapping a list of nodes"),
//! src/html/execcommand/wrap.zig - shared with lane editing4.
//!
//! Each case builds the editing host's children in script, wraps a run of
//! them from Zig with a sibling criteria and new parent instructions, and
//! reads the host's innerHTML (and where it matters, the selection) back.
const std = @import("std");
const html = @import("html");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const helpers = @import("edges_node_holders_helpers.zig");

const execcommand = html.execcommand;
const common = execcommand.common;
const wrap_mod = execcommand.wrap;
const Instance = runtime.Instance;

const setup_script =
    \\document.body.innerHTML = '<div contenteditable id=host></div>';
    \\globalThis.hostHTML = () => document.getElementById('host').innerHTML;
    \\globalThis.selectionText = () => { const s = getSelection(); if (!s.rangeCount) return 'none'; const r = s.getRangeAt(0); const name = (n) => n.nodeType === 3 ? '"' + n.data + '"' : n.nodeName; return name(r.startContainer) + ':' + r.startOffset + '-' + name(r.endContainer) + ':' + r.endOffset; };
;

const Fixture = struct {
    page: helpers.Page,
    document: *Instance,
    host: *Instance,
    edit: common.Edit,

    fn open(markup: []const u8) !Fixture {
        const page = try helpers.Page.open();
        errdefer page.close();
        try page.run(setup_script);
        const source = try std.fmt.allocPrint(std.testing.allocator, "document.getElementById('host').innerHTML = {f};", .{std.json.fmt(markup, .{})});
        defer std.testing.allocator.free(source);
        try page.run(source);
        const document = page.browser.current_context.?.document_instance.?;
        const host = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("host"))).?;
        const selection = (try interfaces.Document.call_getSelection(document)).?;
        return .{ .page = page, .document = document, .host = host, .edit = .{ .document = document, .selection = selection, .allocator = document.ctx.allocator } };
    }

    fn close(self: *Fixture) void {
        self.page.close();
    }

    fn child(self: *Fixture, index: u32) !*Instance {
        return (try common.childAt(self.host, index)).?;
    }

    fn expectHTML(self: *Fixture, expected: []const u8) !void {
        const actual = try self.page.evaluate("hostHTML()");
        defer std.testing.allocator.free(actual);
        try std.testing.expectEqualStrings(expected, actual);
    }

    fn expectSelection(self: *Fixture, expected: []const u8) !void {
        const actual = try self.page.evaluate("selectionText()");
        defer std.testing.allocator.free(actual);
        try std.testing.expectEqualStrings(expected, actual);
    }
};

/// Sibling criteria and new parent instructions over one element name:
/// siblings that are that HTML element match, and a new one is created;
/// `create = false` makes the instructions return null.
const Named = struct {
    name: []const u8,
    create: bool = true,

    pub fn siblingCriteria(self: Named, node: *Instance) anyerror!bool {
        return try common.isHtmlElementNamed(node, self.name);
    }

    pub fn newParent(self: Named, edit: *common.Edit) anyerror!?*Instance {
        if (!self.create) return null;
        return try edit.createElement(self.name);
    }
};

fn wrapsInANewParent() !void {
    var fixture = try Fixture.open("foo");
    defer fixture.close();
    // The selection around the text: after the wrap it is inside the new
    // parent (step 10.2 moves the point after the inserted wrapper, then the
    // move preserving ranges carries both points in).
    try fixture.page.run("const r = document.createRange(); r.setStart(host, 0); r.setEnd(host, 1); getSelection().removeAllRanges(); getSelection().addRange(r);");
    const text = try fixture.child(0);
    const result = try wrap_mod.wrap(&fixture.edit, &.{text}, Named{ .name = "b" });
    try std.testing.expect(result != null);
    try fixture.expectHTML("<b>foo</b>");
    try fixture.expectSelection("B:0-B:1");
}

test "wrap: a new parent from the instructions, the selection carried in" {
    try helpers.onFreshThread(wrapsInANewParent);
}

fn joinsAPreviousSiblingAcrossInvisibleNodes() !void {
    // The spec's own example: bolding <b>foo</b><!--bar-->[baz] gives
    // <b>foo<!--bar-->baz</b> (step 4 takes the invisible comment along).
    var fixture = try Fixture.open("<b>foo</b><!--bar-->baz");
    defer fixture.close();
    const result = try wrap_mod.wrap(&fixture.edit, &.{try fixture.child(2)}, Named{ .name = "b" });
    try std.testing.expect(result != null);
    try fixture.expectHTML("<b>foo<!--bar-->baz</b>");
}

test "wrap: a matching previous sibling takes the nodes, invisible ones too" {
    try helpers.onFreshThread(joinsAPreviousSiblingAcrossInvisibleNodes);
}

fn mergesBothSiblings() !void {
    // Steps 6 and 15: both siblings match - the nodes join the previous
    // one, then the next one's children follow and it goes.
    var fixture = try Fixture.open("<b>a</b>x<b>c</b>");
    defer fixture.close();
    _ = try wrap_mod.wrap(&fixture.edit, &.{try fixture.child(1)}, Named{ .name = "b", .create = false });
    try fixture.expectHTML("<b>axc</b>");
}

test "wrap: a node between two matching siblings merges them" {
    try helpers.onFreshThread(mergesBothSiblings);
}

fn joinsTheNextSibling() !void {
    // Step 7 and step 13.2: the nodes go in front of the next sibling's
    // children.
    var fixture = try Fixture.open("x<i>c</i>");
    defer fixture.close();
    _ = try wrap_mod.wrap(&fixture.edit, &.{try fixture.child(0)}, Named{ .name = "i", .create = false });
    try fixture.expectHTML("<i>xc</i>");
}

test "wrap: a matching next sibling takes the nodes at its start" {
    try helpers.onFreshThread(joinsTheNextSibling);
}

fn nullInstructionsAbort() !void {
    // Step 9: no sibling matches and the instructions return null.
    var fixture = try Fixture.open("<i>a</i>x");
    defer fixture.close();
    const result = try wrap_mod.wrap(&fixture.edit, &.{try fixture.child(1)}, Named{ .name = "b", .create = false });
    try std.testing.expect(result == null);
    try fixture.expectHTML("<i>a</i>x");
}

test "wrap: no match and no new parent leaves the tree alone" {
    try helpers.onFreshThread(nullInstructionsAbort);
}

fn invisibleNodesAreNotWrapped() !void {
    // Step 1: every member invisible and none a br.
    var fixture = try Fixture.open("<span></span>");
    defer fixture.close();
    const result = try wrap_mod.wrap(&fixture.edit, &.{try fixture.child(0)}, Named{ .name = "b" });
    try std.testing.expect(result == null);
    try fixture.expectHTML("<span></span>");
}

test "wrap: an invisible list is not wrapped" {
    try helpers.onFreshThread(invisibleNodesAreNotWrapped);
}

fn trailingBrGoesAlong() !void {
    // Step 3: the line's trailing br goes into the wrapper with it, and
    // step 16 then removes it as extraneous at the wrapper's end.
    var fixture = try Fixture.open("foo<br>bar");
    defer fixture.close();
    _ = try wrap_mod.wrap(&fixture.edit, &.{try fixture.child(0)}, Named{ .name = "blockquote" });
    try fixture.expectHTML("<blockquote>foo</blockquote>bar");
}

test "wrap: a trailing br goes with its line into a block wrapper" {
    try helpers.onFreshThread(trailingBrGoesAlong);
}

fn blockParentGetsALineBreak() !void {
    // Step 12.1: appending an inline line to a block whose last visible
    // child is inline needs a br between the lines.
    var fixture = try Fixture.open("<div>a</div>b");
    defer fixture.close();
    _ = try wrap_mod.wrap(&fixture.edit, &.{try fixture.child(1)}, Named{ .name = "div", .create = false });
    try fixture.expectHTML("<div>a<br>b</div>");
}

test "wrap: an inline line appended to a block gets a br before it" {
    try helpers.onFreshThread(blockParentGetsALineBreak);
}

fn blockParentGetsALeadingLineBreak() !void {
    // Step 13.1: the mirror image at the start of the next sibling block.
    var fixture = try Fixture.open("a<div>b</div>");
    defer fixture.close();
    _ = try wrap_mod.wrap(&fixture.edit, &.{try fixture.child(0)}, Named{ .name = "div", .create = false });
    try fixture.expectHTML("<div>a<br>b</div>");
}

test "wrap: an inline line prepended to a block gets a br after it" {
    try helpers.onFreshThread(blockParentGetsALeadingLineBreak);
}

fn emptiedParentIsRemoved() !void {
    // Step 14: the original parent, editable and now empty, goes. The new
    // parent comes from the instructions as an existing element elsewhere
    // (the toggle-lists use).
    var fixture = try Fixture.open("<ol><li>a</li></ol><p><span>x</span></p>");
    defer fixture.close();
    const Existing = struct {
        host: *Instance,
        pub fn siblingCriteria(self: @This(), node: *Instance) anyerror!bool {
            _ = self;
            _ = node;
            return false;
        }
        pub fn newParent(self: @This(), edit: *common.Edit) anyerror!?*Instance {
            _ = edit;
            return try common.firstChild(self.host);
        }
    };
    const p = try fixture.child(1);
    const span = (try common.firstChild(p)).?;
    _ = try wrap_mod.wrap(&fixture.edit, &.{span}, Existing{ .host = fixture.host });
    try fixture.expectHTML("<ol><li>a</li><span>x</span></ol>");
}

test "wrap: an editable original parent left empty is removed" {
    try helpers.onFreshThread(emptiedParentIsRemoved);
}

fn churnedRangesSurviveTheSweep() !void {
    // Step 10.2 moves boundary points of every live range of the document.
    // A boundary write redraws the range's edges and can allocate, so a V8
    // collection may run between two writes and free ranges script let go
    // of: the sweep must never hold a range pointer outside the live list's
    // walk (src/dom/live_range_list.zig; lane rangeuaf). Thousands of
    // garbage ranges sit at the boundary the sweep moves.
    var fixture = try Fixture.open("foo");
    defer fixture.close();
    var round: usize = 0;
    while (round < 20) : (round += 1) {
        try fixture.page.run(
            \\host.innerHTML = 'foo';
            \\for (let i = 0; i < 2000; i++) { const r = document.createRange(); r.setStart(host, 0); r.setEnd(host, 1); }
            \\TestUtils.gc();
            \\for (let i = 0; i < 2000; i++) { const r = document.createRange(); r.setStart(host, 0); r.setEnd(host, 0); }
        );
        const text = try fixture.child(0);
        const result = try wrap_mod.wrap(&fixture.edit, &.{text}, Named{ .name = "b" });
        try std.testing.expect(result != null);
        try fixture.expectHTML("<b>foo</b>");
    }
}

test "wrap: the step 10.2 sweep survives ranges collected mid-sweep" {
    try helpers.onFreshThread(churnedRangesSurviveTheSweep);
}
