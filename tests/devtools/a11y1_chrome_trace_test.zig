//! The accessibility tree against Chrome (lane a11y1, batch 1; roadmap
//! cdp-mcp's Accessibility domain, design tmp/plans/a11y1-design.md): a list
//! of pages and, on each, the Accessibility domain's commands - getFullAXTree
//! (the main frame, a child frame by frameId, a depth), queryAXTree by name
//! and role, getPartialAXTree, and the commands that need enable - run over
//! CDP, every answer compared, node by node, with what Chrome for Testing
//! 157.0.8103.78 answered for the same commands
//! (tests/devtools/fixtures/a11y1-chrome157-trace.txt).
//!
//! What chrome-devtools-mcp's take_snapshot, uids and wait_for need (main,
//! 4:58 PM ET 2026-11-23) is checked by construction here:
//! - getFullAXTree per frame, an iframe's subtree in its own frame's tree
//!   (the "frames" page: the main frame, then the child frame by the id
//!   Page.getFrameTree gives);
//! - nodes[0] the root, RootWebArea (every full tree's first line);
//! - the fields of each AXNode, ignored nodes included;
//! - queryAXTree by name / role / both, from an objectId;
//! - nodeId == backendDOMNodeId for every node with a DOM node: both are
//!   renamed through ONE map (`Names`), so a node whose two ids differ shows
//!   two different names.
//!
//! The fixture is Chrome's raw answers, one line per command (`step <label>
//! <json>`); both sides are put in the same canonical form at compare time
//! (`canonical`): one line per AXNode, object keys sorted, DOM-backed ids
//! renamed in order of first appearance ("n1", "n2"...; Chrome's renderer
//! hands DOMNodeIds to other subsystems too, so its numbers are not Crane's),
//! Chrome's generated negative ids likewise ("g1"...), frame ids ("frame1").
//! Name and description `sources` are left out until batch 2 adds them
//! (`compare_sources`). Accessibility events are batch 3's and are not in
//! this comparison.
//!
//! RECORDING the fixture: run Chrome for Testing 157 with
//! `--headless=new --remote-debugging-port=<port> --user-data-dir=<empty dir> about:blank`
//! and this test with CRANE_CDP_TRACE_CHROME_PORT=<port> and
//! CRANE_A11Y_TRACE_OUT=<file>: it drives that Chrome instead and writes the
//! raw trace. CRANE_A11Y_TRACE_OUT on a Crane run writes Crane's raw trace,
//! and CRANE_A11Y_TRACE_CANONICAL=<file> both canonical traces, to diff whole.

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");

const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

const fixture_path = "tests/devtools/fixtures/a11y1-chrome157-trace.txt";

/// Batch 2 compares the name and description sources too.
const compare_sources = false;

/// One command of a step. Selectors are document.querySelector's, run by
/// Runtime.evaluate in the page ("document" for the document itself).
const Action = union(enum) {
    /// Accessibility.getFullAXTree of the main frame.
    full: struct { depth: ?i64 = null },
    /// Accessibility.getFullAXTree of the main frame's n-th child frame, by
    /// the id Page.getFrameTree gives it.
    frame: usize,
    /// Accessibility.queryAXTree from the node `selector` finds (objectId).
    query: struct { selector: []const u8, name: ?[]const u8 = null, role: ?[]const u8 = null },
    /// Accessibility.getPartialAXTree of the node `selector` finds, named by
    /// its backendNodeId (DOM.describeNode).
    partial: struct { selector: []const u8, relatives: ?bool = null },
    /// Accessibility.getAXNodeAndAncestors of the node `selector` finds.
    ancestors: []const u8,
    /// Accessibility.getRootAXNode; its nodeId is kept for `children`.
    root,
    /// Accessibility.getChildAXNodes of the kept root.
    children,
    /// Any command with literal params.
    raw: struct { method: []const u8, params: []const u8 = "{}" },
    /// Page script, then a settle; recorded as an empty answer.
    script: []const u8,
};

const Step = struct { label: []const u8, action: Action };

const Page = struct { label: []const u8, html: []const u8, steps: []const Step };

const full: Action = .{ .full = .{} };

const pages = [_]Page{
    .{
        .label = "mcp",
        .html = "<!doctype html><html><head><title>MCP</title></head><body><h1>Hello world</h1><button>Click me</button>" ++
            "<input type=text value=value aria-label=Field><select><option value=v1>Option 1</option><option value=v2>Option 2</option></select>" ++
            "<a href=\"https://example.com/\">Link</a><textarea></textarea><input type=checkbox></body></html>",
        .steps = &.{
            .{ .label = "full", .action = full },
            .{ .label = "query-name", .action = .{ .query = .{ .selector = "document", .name = "Click me" } } },
            .{ .label = "query-name-role", .action = .{ .query = .{ .selector = "document", .name = "Click me", .role = "button" } } },
            .{ .label = "query-role", .action = .{ .query = .{ .selector = "document", .role = "option" } } },
            .{ .label = "query-text", .action = .{ .query = .{ .selector = "body", .name = "Hello world" } } },
            .{ .label = "query-none", .action = .{ .query = .{ .selector = "document", .name = "Nothing here" } } },
        },
    },
    .{
        .label = "forms",
        .html = "<!doctype html><html lang=en><head><title>Forms</title></head><body><form aria-label=\"Sign up\">" ++
            "<label for=n>Name</label> <input id=n required>" ++
            "<label>Email <input type=email placeholder=\"you@example.com\"></label>" ++
            "<input type=password aria-label=Password autocomplete=off>" ++
            "<input type=checkbox id=c checked> <label for=c>Agree</label> <input type=checkbox aria-label=Maybe id=m>" ++
            "<input type=radio name=r aria-label=A checked> <input type=radio name=r aria-label=B>" ++
            "<input type=range min=0 max=10 value=3 aria-label=Volume>" ++
            "<input type=number value=5 min=1 max=9 aria-label=Count>" ++
            "<input type=search aria-label=Find value=q>" ++
            "<input disabled value=off aria-label=Off> <input readonly value=ro aria-label=RO>" ++
            "<input type=url aria-label=Site><input type=tel aria-label=Phone>" ++
            "<input type=date aria-label=Day><input type=color aria-label=Hue><input type=file aria-label=Upload>" ++
            "<textarea aria-label=Notes>hello</textarea>" ++
            "<select aria-label=Pick><option>One</option><option selected>Two</option><optgroup label=More><option>Three</option></optgroup></select>" ++
            "<select multiple aria-label=Many><option>X</option><option selected>Y</option></select>" ++
            "<fieldset><legend>Shipping</legend><input aria-label=Street></fieldset>" ++
            "<button type=submit>Send</button> <button type=button aria-pressed=true>Bold</button> <button type=button aria-haspopup=menu aria-expanded=false>Menu</button>" ++
            "<input type=submit> <input type=reset> <input type=button value=Go> <input type=image alt=Map>" ++
            "<input type=hidden value=h>" ++
            "<meter value=0.5 aria-label=Level></meter><progress value=30 max=100 aria-label=Load></progress><output>42</output>" ++
            "<details open><summary>More</summary><p>Inside</p></details>" ++
            "</form><script>document.getElementById('m').indeterminate = true;</script></body></html>",
        .steps = &.{
            .{ .label = "full", .action = full },
            .{ .label = "query-name", .action = .{ .query = .{ .selector = "document", .name = "Name" } } },
            .{ .label = "query-role", .action = .{ .query = .{ .selector = "form", .role = "checkbox" } } },
            .{ .label = "partial", .action = .{ .partial = .{ .selector = "input[id=n]" } } },
            .{ .label = "partial-alone", .action = .{ .partial = .{ .selector = "select", .relatives = false } } },
        },
    },
    .{
        .label = "structure",
        .html = "<!doctype html><html lang=en><head><title>Structure</title><style>.u{text-transform:uppercase}</style></head><body>" ++
            "<header><h1>Site</h1><nav aria-label=Primary><ul><li><a href=\"/a\">Home</a></li><li><a href=\"/b\" aria-current=page>About</a></li></ul></nav></header>" ++
            "<main><article><h2>Post</h2><p>Some <strong>bold</strong>, <em>emph</em>, <code>x()</code>, <abbr title=\"HyperText\">HTML</abbr>, <mark>m</mark>, " ++
            "<del>d</del><ins>i</ins>, <s>s</s>, <sub>2</sub><sup>3</sup>, <time datetime=2026-01-01>Jan</time>, <dfn>term</dfn>, <q>quoted</q>.</p>" ++
            "<p class=u>shout</p><blockquote>Quote</blockquote><hr>" ++
            "<h3 aria-level=5>Deep</h3><h6>Six</h6>" ++
            "<ol><li>one</li><li>two<ul><li>nested</li></ul></li></ol>" ++
            "<dl><dt>Term</dt><dd>Def</dd></dl>" ++
            "<figure><img alt=\"Pixel\"><figcaption>Cap</figcaption></figure><img alt=\"\"><img>" ++
            "<table><caption>Scores</caption><thead><tr><th>Name</th><th>Pts</th></tr></thead><tbody><tr><td>A</td><td>1</td></tr></tbody></table>" ++
            "<section aria-label=Extra><p>In section</p></section><section><p>Unnamed</p></section>" ++
            "<aside><p>Side</p></aside><address>Addr</address><hgroup><h4>Hg</h4></hgroup>" ++
            "<a>no href</a> <span>plain span</span> <div>plain div</div><search>s</search>" ++
            "</article></main><aside aria-label=Top>Top aside</aside><footer><p>Foot</p></footer></body></html>",
        .steps = &.{
            .{ .label = "full", .action = full },
            .{ .label = "query-role", .action = .{ .query = .{ .selector = "document", .role = "listitem" } } },
            .{ .label = "query-heading", .action = .{ .query = .{ .selector = "main", .role = "heading" } } },
            .{ .label = "partial", .action = .{ .partial = .{ .selector = "td" } } },
        },
    },
    .{
        .label = "aria",
        .html = "<!doctype html><html lang=en><head><title>ARIA</title></head><body>" ++
            "<div role=tablist aria-label=Tabs><button role=tab aria-selected=true aria-controls=p1 id=t1>One</button><button role=tab aria-selected=false>Two</button></div>" ++
            "<div role=tabpanel id=p1 aria-labelledby=t1>Panel</div>" ++
            "<ul role=tree aria-label=Files><li role=treeitem aria-expanded=true aria-level=1>src<ul role=group><li role=treeitem aria-level=2 aria-selected=true>a.zig</li></ul></li></ul>" ++
            "<div role=menu aria-label=Actions aria-orientation=vertical><div role=menuitem>Cut</div><div role=menuitemcheckbox aria-checked=true>Wrap</div><div role=menuitemradio aria-checked=false>Left</div></div>" ++
            "<div role=combobox aria-expanded=false aria-haspopup=listbox aria-controls=lb aria-label=City aria-autocomplete=list tabindex=0></div>" ++
            "<div role=listbox id=lb aria-label=Cities aria-multiselectable=true><div role=option aria-selected=true>Paris</div><div role=option>Rome</div></div>" ++
            "<div role=slider aria-valuenow=40 aria-valuemin=0 aria-valuemax=100 aria-valuetext=\"40 percent\" aria-label=Zoom tabindex=0></div>" ++
            "<div role=checkbox aria-checked=mixed tabindex=0>Partial</div><div role=switch aria-checked=true aria-label=Wifi></div>" ++
            "<span id=lbl>Label from elsewhere</span><span id=desc>A description</span>" ++
            "<div role=button tabindex=0 aria-labelledby=lbl aria-describedby=desc>X</div>" ++
            "<button aria-description=\"More info\" title=Tip>Help</button>" ++
            "<input aria-label=Code aria-invalid=true aria-errormessage=err aria-required=true><span id=err>Bad</span>" ++
            "<div role=region aria-label=Status aria-live=polite aria-busy=true>Loading</div><div role=alert>Saved</div>" ++
            "<div role=dialog aria-modal=true aria-label=Confirm><p>Sure?</p></div>" ++
            "<div role=heading aria-level=4>H4</div>" ++
            "<div aria-owns=owned role=list aria-label=Owner></div><div role=listitem id=owned>Owned item</div>" ++
            "<div role=none>none text</div><div role=presentation tabindex=0>focusable presentation</div>" ++
            "<div role=\"foo button\">Fallback</div><div role=img aria-label=Chart><span>inner</span></div>" ++
            "<a href=\"/x\" aria-keyshortcuts=\"Alt+X\" aria-roledescription=shortcut>Jump</a>" ++
            "<div aria-disabled=true role=button>Off</div>" ++
            "<div role=textbox contenteditable=true aria-multiline=true aria-label=Editor>text</div><div contenteditable=true>rich</div>" ++
            "<div role=progressbar aria-valuenow=5 aria-label=P></div><div role=separator aria-orientation=vertical></div>" ++
            "<div role=grid aria-label=G aria-readonly=true><div role=row><div role=gridcell>c</div></div></div>" ++
            "<div aria-details=det aria-label=WithDetails role=group></div><div id=det>Details</div>" ++
            "</body></html>",
        .steps = &.{
            .{ .label = "full", .action = full },
            .{ .label = "query-tab", .action = .{ .query = .{ .selector = "document", .role = "tab" } } },
            .{ .label = "query-label", .action = .{ .query = .{ .selector = "document", .name = "Label from elsewhere" } } },
            .{ .label = "partial", .action = .{ .partial = .{ .selector = "[role=tablist]", .relatives = false } } },
        },
    },
    .{
        .label = "hidden",
        .html = "<!doctype html><html lang=en><head><title>Hidden</title><style>.v{visibility:hidden}.s{visibility:visible}.n{display:none}.c{content-visibility:hidden}.o{opacity:0}</style></head><body>" ++
            "<p>Visible</p><div class=n>display none <button>no</button></div><div hidden>hidden attr</div>" ++
            "<div class=v>vis hidden <span class=s>but visible child</span></div>" ++
            "<div aria-hidden=true>aria hidden <button>focusable</button></div>" ++
            "<div inert>inert text <button>inert button</button></div>" ++
            "<div class=c><p>content visibility</p></div><div class=o>transparent</div>" ++
            "<span id=hid class=n>hidden label</span><button aria-labelledby=hid>by hidden</button>" ++
            "<div aria-hidden=false>aria hidden false</div><input type=hidden value=x>" ++
            "<noscript>ns</noscript><template><p>tpl</p></template></body></html>",
        .steps = &.{
            .{ .label = "full", .action = full },
            .{ .label = "query-hidden", .action = .{ .query = .{ .selector = "document", .name = "focusable" } } },
            .{ .label = "partial-none", .action = .{ .partial = .{ .selector = ".n button" } } },
            .{ .label = "partial-aria-hidden", .action = .{ .partial = .{ .selector = "[aria-hidden=true] button" } } },
        },
    },
    .{
        .label = "shadow",
        .html = "<!doctype html><html lang=en><head><title>Shadow</title><style>.b::before{content:\"Before \"}.a::after{content:\" after\" / \"alt after\"}.dc{display:contents}</style></head><body>" ++
            "<div id=host><template shadowrootmode=open><p>Shadow text <slot></slot></p><button>Inner</button></template><span>slotted</span></div>" ++
            "<p class=b>Main</p><p class=a>Tail</p><ul><li>marker item</li></ul><ol start=3><li>numbered</li></ol>" ++
            "<div class=dc><button>In contents</button></div><my-el><span>custom</span></my-el></body></html>",
        .steps = &.{
            .{ .label = "full", .action = full },
            .{ .label = "query-shadow", .action = .{ .query = .{ .selector = "div[id=host]", .role = "button" } } },
            .{ .label = "partial-slotted", .action = .{ .partial = .{ .selector = "div[id=host] span" } } },
        },
    },
    .{
        .label = "frames",
        .html = "<!doctype html><html lang=en><head><title>Frames</title></head><body><h1>Outer</h1>" ++
            "<iframe title=Inner srcdoc=\"<!doctype html><title>In</title><button>In frame</button><p>frame text</p>\"></iframe>" ++
            "<p>after</p></body></html>",
        .steps = &.{
            .{ .label = "full", .action = full },
            .{ .label = "child-frame", .action = .{ .frame = 0 } },
            .{ .label = "depth-2", .action = .{ .full = .{ .depth = 2 } } },
            .{ .label = "bad-frame", .action = .{ .raw = .{ .method = "Accessibility.getFullAXTree", .params = "{\"frameId\":\"NOPE\"}" } } },
        },
    },
    .{
        .label = "text",
        .html = "<!doctype html><html lang=en><head><title>Text</title></head><body>" ++
            "<div>alpha <b>beta</b> gamma</div><div>   spaced   out   </div>" ++
            "<p>line one<br>line two</p><pre>pre one\npre two</pre><div style=\"white-space:pre-line\">a\nb</div>" ++
            "<span>inline</span> <span>words</span><div><span>x</span><span>y</span></div><p>&nbsp;</p>" ++
            "</body></html>",
        .steps = &.{
            .{ .label = "full", .action = full },
        },
    },
    .{
        .label = "enabled",
        .html = "<!doctype html><html lang=en><head><title>Enabled</title></head><body><main><h1>Top</h1><p>para <a href=\"/l\">link</a></p></main></body></html>",
        .steps = &.{
            .{ .label = "root-disabled", .action = .{ .raw = .{ .method = "Accessibility.getRootAXNode" } } },
            .{ .label = "children-disabled", .action = .{ .raw = .{ .method = "Accessibility.getChildAXNodes", .params = "{\"id\":\"1\"}" } } },
            .{ .label = "disable-disabled", .action = .{ .raw = .{ .method = "Accessibility.disable" } } },
            .{ .label = "enable", .action = .{ .raw = .{ .method = "Accessibility.enable" } } },
            .{ .label = "enable-again", .action = .{ .raw = .{ .method = "Accessibility.enable" } } },
            .{ .label = "root", .action = .root },
            .{ .label = "children", .action = .children },
            .{ .label = "children-bad", .action = .{ .raw = .{ .method = "Accessibility.getChildAXNodes", .params = "{\"id\":\"bogus\"}" } } },
            .{ .label = "ancestors", .action = .{ .ancestors = "a" } },
            .{ .label = "focus-link", .action = .{ .script = "document.querySelector('a').focus();" } },
            .{ .label = "ancestors-focused", .action = .{ .ancestors = "a" } },
            .{ .label = "partial-no-node", .action = .{ .raw = .{ .method = "Accessibility.getPartialAXTree", .params = "{}" } } },
            .{ .label = "query-no-node", .action = .{ .raw = .{ .method = "Accessibility.queryAXTree", .params = "{\"accessibleName\":\"x\"}" } } },
            .{ .label = "disable", .action = .{ .raw = .{ .method = "Accessibility.disable" } } },
            .{ .label = "root-after-disable", .action = .{ .raw = .{ .method = "Accessibility.getRootAXNode" } } },
        },
    },
};

/// Expected differences: the canonical line Chrome answered (which must be
/// in the canonical fixture exactly once) and the one Crane answers in its
/// place, each with its reason. Golden-rule-2 rows (main's D4: Crane's role,
/// in Chrome's vocabulary) and needs-renderer rows (soft wraps: main's D1)
/// go here.
const Deviation = struct { chrome: []const u8, crane: []const u8 };
const deviations = [_]Deviation{};

/// CRANE_A11Y_TRACE_VERBOSE set: each step's progress on stderr.
fn progress(comptime format: []const u8, args: anytype) void {
    if (std.c.getenv("CRANE_A11Y_TRACE_VERBOSE") == null) return;
    std.debug.print("a11y1 trace: " ++ format ++ "\n", args);
}

/// `s` as a JSON string.
fn jsonString(allocator: Allocator, s: []const u8, out: *std.ArrayList(u8)) error{OutOfMemory}!void {
    try out.append(allocator, '"');
    for (s) |c| switch (c) {
        '"' => try out.appendSlice(allocator, "\\\""),
        '\\' => try out.appendSlice(allocator, "\\\\"),
        '\n' => try out.appendSlice(allocator, "\\n"),
        '\r' => try out.appendSlice(allocator, "\\r"),
        '\t' => try out.appendSlice(allocator, "\\t"),
        0...8, 11, 12, 14...31 => try out.print(allocator, "\\u{x:0>4}", .{c}),
        else => try out.append(allocator, c),
    };
    try out.append(allocator, '"');
}

/// `html` as a data: URL, percent-encoding what a URL would end or alter.
fn dataUrl(allocator: Allocator, html: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, "data:text/html,");
    for (html) |c| switch (c) {
        '%', '#', '\n', '\r', '\t' => try out.print(allocator, "%{X:0>2}", .{c}),
        else => try out.append(allocator, c),
    };
    return out.toOwnedSlice(allocator);
}

/// A call whose params are built with `format`; OWNED.
fn callf(allocator: Allocator, client: *cdp.Client, method: []const u8, comptime format: []const u8, args: anytype) !std.json.Parsed(std.json.Value) {
    const params = try std.fmt.allocPrint(allocator, format, args);
    defer allocator.free(params);
    return client.call(method, params, "");
}

fn evaluate(allocator: Allocator, client: *cdp.Client, expression: []const u8, by_value: bool) !std.json.Parsed(std.json.Value) {
    var params: std.ArrayList(u8) = .empty;
    defer params.deinit(allocator);
    try params.appendSlice(allocator, "{\"expression\":");
    try jsonString(allocator, expression, &params);
    try params.print(allocator, ",\"awaitPromise\":true,\"returnByValue\":{s}}}", .{if (by_value) "true" else "false"});
    return client.call("Runtime.evaluate", params.items, "");
}

/// A rendering update and a task after it.
fn settle(allocator: Allocator, client: *cdp.Client) !void {
    var got = try evaluate(allocator, client, "new Promise((resolve) => requestAnimationFrame(() => setTimeout(resolve, 0)))", true);
    got.deinit();
}

/// The objectId of what `selector` finds (the document for "document"),
/// OWNED.
fn objectOf(allocator: Allocator, client: *cdp.Client, selector: []const u8) ![]u8 {
    var expression: std.ArrayList(u8) = .empty;
    defer expression.deinit(allocator);
    if (std.mem.eql(u8, selector, "document")) {
        try expression.appendSlice(allocator, "document");
    } else {
        try expression.appendSlice(allocator, "document.querySelector(");
        try jsonString(allocator, selector, &expression);
        try expression.append(allocator, ')');
    }
    var got = try evaluate(allocator, client, expression.items, false);
    defer got.deinit();
    const id = cdp.stringAt(got.value, "result.result.objectId") orelse return error.NoObject;
    return allocator.dupe(u8, id);
}

/// The backendNodeId of what `selector` finds.
fn backendOf(allocator: Allocator, client: *cdp.Client, selector: []const u8) !i64 {
    const object = try objectOf(allocator, client, selector);
    defer allocator.free(object);
    var got = try callf(allocator, client, "DOM.describeNode", "{{\"objectId\":\"{s}\"}}", .{object});
    defer got.deinit();
    const id = cdp.at(got.value, "result.node.backendNodeId") orelse return error.NoNode;
    return id.integer;
}

/// The id of the main frame's n-th child frame.
fn childFrame(allocator: Allocator, client: *cdp.Client, index: usize) ![]u8 {
    var got = try client.call("Page.getFrameTree", "{}", "");
    defer got.deinit();
    const children = cdp.at(got.value, "result.frameTree.childFrames") orelse return error.NoChildFrame;
    if (index >= children.array.items.len) return error.NoChildFrame;
    const id = cdp.stringAt(children.array.items[index], "frame.id") orelse return error.NoChildFrame;
    return allocator.dupe(u8, id);
}

/// The answer as raw JSON: `{"result":...}` or `{"error":...}`, OWNED.
fn answerJson(allocator: Allocator, got: std.json.Value) ![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    const w = &out.writer;
    if (got.object.get("result")) |r| {
        w.writeAll("{\"result\":") catch return error.OutOfMemory;
        std.json.Stringify.value(r, .{}, w) catch return error.OutOfMemory;
    } else {
        w.writeAll("{\"error\":") catch return error.OutOfMemory;
        std.json.Stringify.value(got.object.get("error") orelse .null, .{}, w) catch return error.OutOfMemory;
    }
    w.writeAll("}") catch return error.OutOfMemory;
    return out.toOwnedSlice();
}

/// Run every page's steps on `client`, writing each answer raw.
fn runPages(allocator: Allocator, client: *cdp.Client, out: *std.ArrayList(u8)) !void {
    var page_enable = try client.call("Page.enable", "{}", "");
    page_enable.deinit();
    for (pages) |page| {
        progress("page {s}", .{page.label});
        try out.print(allocator, "page {s}\n", .{page.label});
        const url = try dataUrl(allocator, page.html);
        defer allocator.free(url);
        var params: std.ArrayList(u8) = .empty;
        defer params.deinit(allocator);
        try params.appendSlice(allocator, "{\"url\":");
        try jsonString(allocator, url, &params);
        try params.append(allocator, '}');
        var nav = try client.call("Page.navigate", params.items, "");
        nav.deinit();
        var loaded = try client.waitEvent("Page.loadEventFired");
        loaded.deinit();
        try settle(allocator, client);
        var root_id: ?[]u8 = null;
        defer if (root_id) |r| allocator.free(r);
        for (page.steps) |step| {
            progress("step {s}", .{step.label});
            var got = switch (step.action) {
                .full => |f| if (f.depth) |d|
                    try callf(allocator, client, "Accessibility.getFullAXTree", "{{\"depth\":{d}}}", .{d})
                else
                    try client.call("Accessibility.getFullAXTree", "{}", ""),
                .frame => |index| blk: {
                    const frame = try childFrame(allocator, client, index);
                    defer allocator.free(frame);
                    break :blk try callf(allocator, client, "Accessibility.getFullAXTree", "{{\"frameId\":\"{s}\"}}", .{frame});
                },
                .query => |q| blk: {
                    const object = try objectOf(allocator, client, q.selector);
                    defer allocator.free(object);
                    var text: std.ArrayList(u8) = .empty;
                    defer text.deinit(allocator);
                    try text.print(allocator, "{{\"objectId\":\"{s}\"", .{object});
                    if (q.name) |n| {
                        try text.appendSlice(allocator, ",\"accessibleName\":");
                        try jsonString(allocator, n, &text);
                    }
                    if (q.role) |r| {
                        try text.appendSlice(allocator, ",\"role\":");
                        try jsonString(allocator, r, &text);
                    }
                    try text.append(allocator, '}');
                    break :blk try client.call("Accessibility.queryAXTree", text.items, "");
                },
                .partial => |p| blk: {
                    const id = try backendOf(allocator, client, p.selector);
                    if (p.relatives) |r| break :blk try callf(allocator, client, "Accessibility.getPartialAXTree", "{{\"backendNodeId\":{d},\"fetchRelatives\":{s}}}", .{ id, if (r) "true" else "false" });
                    break :blk try callf(allocator, client, "Accessibility.getPartialAXTree", "{{\"backendNodeId\":{d}}}", .{id});
                },
                .ancestors => |selector| blk: {
                    const id = try backendOf(allocator, client, selector);
                    break :blk try callf(allocator, client, "Accessibility.getAXNodeAndAncestors", "{{\"backendNodeId\":{d}}}", .{id});
                },
                .root => blk: {
                    const answer = try client.call("Accessibility.getRootAXNode", "{}", "");
                    if (cdp.stringAt(answer.value, "result.node.nodeId")) |id| root_id = try allocator.dupe(u8, id);
                    break :blk answer;
                },
                .children => try callf(allocator, client, "Accessibility.getChildAXNodes", "{{\"id\":\"{s}\"}}", .{root_id orelse "0"}),
                .raw => |r| try client.call(r.method, r.params, ""),
                .script => |source| blk: {
                    const answer = try evaluate(allocator, client, source, true);
                    try settle(allocator, client);
                    break :blk answer;
                },
            };
            defer got.deinit();
            const json = try answerJson(allocator, got.value);
            defer allocator.free(json);
            try out.print(allocator, "step {s} {s}\n", .{ step.label, json });
        }
        // The nodes of the page's user-agent shadow trees (Chrome's form
        // controls' insides), which Crane does not have: `canonical` sets
        // them apart (`userAgentNodes`).
        var document = try client.call("DOM.getDocument", "{\"depth\":-1,\"pierce\":true}", "");
        defer document.deinit();
        try out.appendSlice(allocator, "ua");
        if (cdp.at(document.value, "result.root")) |root| try userAgentIds(allocator, root, false, out);
        try out.append(allocator, '\n');
        // Events are batch 3's comparison.
        _ = client.dropQueued("Accessibility.loadComplete");
        _ = client.dropQueued("Accessibility.nodesUpdated");
        _ = client.dropQueued("DOM.documentUpdated");
    }
}

/// The backendNodeIds of every node in a user-agent shadow root under
/// `node` (a DOM.Node), as " <id>" each.
fn userAgentIds(allocator: Allocator, node: std.json.Value, inside: bool, out: *std.ArrayList(u8)) !void {
    if (node != .object) return;
    if (inside) if (node.object.get("backendNodeId")) |id| try out.print(allocator, " {d}", .{id.integer});
    if (node.object.get("children")) |children| for (children.array.items) |child| try userAgentIds(allocator, child, inside, out);
    if (node.object.get("shadowRoots")) |roots| for (roots.array.items) |root| {
        const kind = if (root.object.get("shadowRootType")) |t| t.string else "";
        try userAgentIds(allocator, root, inside or std.mem.eql(u8, kind, "user-agent"), out);
    };
    if (node.object.get("contentDocument")) |child| try userAgentIds(allocator, child, false, out);
    if (node.object.get("pseudoElements")) |pseudos| for (pseudos.array.items) |p| try userAgentIds(allocator, p, inside, out);
}

/// Expected differences in shape that come from DOM Crane does not have:
/// Chrome's user-agent shadow trees inside form controls and details.
/// Crane, with no such trees, answers a menu-list select's pop-up as a
/// nodeless object (Blink keeps it while closed: "keep structure of
/// <select size=1>") and has no other object for them; so in Chrome's
/// answer the pop-up loses its DOM node (and gets a generated id), and every
/// other user-agent node goes, its page-DOM descendants (options, slotted
/// content) given to its nearest kept ancestor, its nodeless ones (a text's
/// inline boxes) going with it. Applied to both sides with each side's own
/// list (Crane's is empty).
fn userAgentNodes(arena: Allocator, nodes: *std.json.Array, ua: *const std.AutoHashMapUnmanaged(i64, void)) !void {
    if (ua.count() == 0) return;
    var by_id: std.StringHashMapUnmanaged(usize) = .empty;
    for (nodes.items, 0..) |n, i| try by_id.put(arena, n.object.get("nodeId").?.string, i);
    const Fate = enum { keep, nodeless, drop };
    const fates = try arena.alloc(Fate, nodes.items.len);
    for (nodes.items, 0..) |n, i| {
        fates[i] = .keep;
        const backend = n.object.get("backendDOMNodeId") orelse continue;
        if (!ua.contains(backend.integer)) continue;
        const role = if (n.object.get("role")) |r| (if (r.object.get("value")) |v| v.string else "") else "";
        fates[i] = if (std.mem.eql(u8, role, "MenuListPopup")) .nodeless else .drop;
    }
    // A nodeless node under a dropped one goes too (parents come first in
    // every answer's order but partial ones, which name parents by id).
    var changed = true;
    while (changed) {
        changed = false;
        for (nodes.items, 0..) |n, i| {
            if (fates[i] != .keep or n.object.get("backendDOMNodeId") != null) continue;
            const parent_id = if (n.object.get("parentId")) |p| p.string else continue;
            const parent = by_id.get(parent_id) orelse continue;
            if (fates[parent] == .drop) {
                fates[i] = .drop;
                changed = true;
            }
        }
    }
    var renamed: std.StringHashMapUnmanaged([]const u8) = .empty;
    for (nodes.items, 0..) |n, i| if (fates[i] == .nodeless) {
        const id = n.object.get("nodeId").?.string;
        try renamed.put(arena, id, try std.fmt.allocPrint(arena, "-9{s}", .{id}));
    };
    const Flat = struct {
        fn children(a: Allocator, list: []const std.json.Value, ids: *const std.StringHashMapUnmanaged(usize), all: []const std.json.Value, fate: []const Fate, names: *const std.StringHashMapUnmanaged([]const u8), out: *std.json.Array) !void {
            for (list) |child| {
                const id = child.string;
                const index = ids.get(id) orelse {
                    try out.append(child);
                    continue;
                };
                switch (fate[index]) {
                    .keep => try out.append(child),
                    .nodeless => try out.append(.{ .string = names.get(id).? }),
                    .drop => if (all[index].object.get("childIds")) |grand| try children(a, grand.array.items, ids, all, fate, names, out),
                }
            }
        }
    };
    var kept = std.json.Array.init(arena);
    for (nodes.items, 0..) |*n, i| {
        if (fates[i] == .drop) continue;
        if (n.object.get("childIds")) |child_ids| {
            var flat = std.json.Array.init(arena);
            try Flat.children(arena, child_ids.array.items, &by_id, nodes.items, fates, &renamed, &flat);
            try n.object.put(arena, "childIds", .{ .array = flat });
        }
        if (n.object.get("parentId")) |parent| {
            var at = parent.string;
            while (by_id.get(at)) |p| {
                if (fates[p] != .drop) break;
                at = (nodes.items[p].object.get("parentId") orelse break).string;
            }
            try n.object.put(arena, "parentId", .{ .string = renamed.get(at) orelse at });
        }
        if (fates[i] == .nodeless) {
            try n.object.put(arena, "nodeId", .{ .string = renamed.get(n.object.get("nodeId").?.string).? });
            _ = n.object.orderedRemove("backendDOMNodeId");
        }
        try kept.append(n.*);
    }
    nodes.* = kept;
}

/// First-appearance renaming of the ids that are not Crane's to match.
const Names = struct {
    map: std.StringHashMapUnmanaged([]const u8) = .empty,
    counts: [3]usize = .{ 0, 0, 0 },

    const Kind = enum(u2) { node, generated, frame };

    fn deinit(self: *Names, allocator: Allocator) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        self.map.deinit(allocator);
    }

    fn name(self: *Names, allocator: Allocator, kind: Kind, key: []const u8) ![]const u8 {
        const full_key = try std.fmt.allocPrint(allocator, "{d}:{s}", .{ @backingInt(kind), key });
        if (self.map.get(full_key)) |n| {
            allocator.free(full_key);
            return n;
        }
        errdefer allocator.free(full_key);
        self.counts[@backingInt(kind)] += 1;
        const prefix = [_][]const u8{ "n", "g", "frame" };
        const n = try std.fmt.allocPrint(allocator, "{s}{d}", .{ prefix[@backingInt(kind)], self.counts[@backingInt(kind)] });
        errdefer allocator.free(n);
        try self.map.put(allocator, full_key, n);
        return n;
    }

    /// An AX node id ("12", "-1000000002") or a DOM backend id (12).
    fn axId(self: *Names, allocator: Allocator, value: std.json.Value) ![]const u8 {
        var buffer: [32]u8 = undefined;
        const text = switch (value) {
            // An i64 has at most 20 characters.
            .integer => |n| std.fmt.bufPrint(&buffer, "{d}", .{n}) catch unreachable,
            .string => |s| s,
            else => "?",
        };
        return self.name(allocator, if (std.mem.startsWith(u8, text, "-")) .generated else .node, text);
    }
};

fn idKey(key: []const u8) bool {
    for ([_][]const u8{ "nodeId", "parentId", "backendDOMNodeId" }) |k| if (std.mem.eql(u8, key, k)) return true;
    return false;
}

/// The value as canonical text: keys sorted, renamed ids, dropped fields.
fn canonical(allocator: Allocator, names: *Names, value: std.json.Value, out: *std.ArrayList(u8)) error{OutOfMemory}!void {
    switch (value) {
        .object => |object| {
            var keys: std.ArrayList([]const u8) = .empty;
            defer keys.deinit(allocator);
            var it = object.iterator();
            while (it.next()) |entry| {
                if (!compare_sources and std.mem.eql(u8, entry.key_ptr.*, "sources")) continue;
                try keys.append(allocator, entry.key_ptr.*);
            }
            std.mem.sort([]const u8, keys.items, {}, struct {
                fn less(_: void, a: []const u8, b: []const u8) bool {
                    return std.mem.lessThan(u8, a, b);
                }
            }.less);
            try out.append(allocator, '{');
            for (keys.items, 0..) |key, i| {
                if (i != 0) try out.append(allocator, ',');
                try out.print(allocator, "{s}:", .{key});
                const v = object.get(key).?;
                if (idKey(key)) {
                    try out.appendSlice(allocator, try names.axId(allocator, v));
                } else if (std.mem.eql(u8, key, "frameId")) {
                    try out.appendSlice(allocator, try names.name(allocator, .frame, if (v == .string) v.string else "?"));
                } else if (std.mem.eql(u8, key, "childIds")) {
                    try out.append(allocator, '[');
                    for (v.array.items, 0..) |child, n| {
                        if (n != 0) try out.append(allocator, ',');
                        try out.appendSlice(allocator, try names.axId(allocator, child));
                    }
                    try out.append(allocator, ']');
                } else {
                    try canonical(allocator, names, v, out);
                }
            }
            try out.append(allocator, '}');
        },
        .array => |array| {
            try out.append(allocator, '[');
            for (array.items, 0..) |item, i| {
                if (i != 0) try out.append(allocator, ',');
                try canonical(allocator, names, item, out);
            }
            try out.append(allocator, ']');
        },
        .string => |s| try jsonString(allocator, s, out),
        .integer => |n| try out.print(allocator, "{d}", .{n}),
        .float => |f| try out.print(allocator, "{d}", .{f}),
        .bool => |b| try out.appendSlice(allocator, if (b) "true" else "false"),
        .null => try out.appendSlice(allocator, "null"),
        .number_string => |s| try out.appendSlice(allocator, s),
    }
}

/// A raw trace in canonical form: `page` and `step` lines, then one line
/// per AXNode an answer holds (`  node {...}`) or its error
/// (`  error <message>`). OWNED.
fn canonicalTrace(allocator: Allocator, raw: []const u8) ![]u8 {
    var names: Names = .{};
    defer names.deinit(allocator);
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();
    // Each page's user-agent nodes, from its `ua` line (after its steps).
    var ua_by_page: std.StringHashMapUnmanaged(std.AutoHashMapUnmanaged(i64, void)) = .empty;
    {
        var page: []const u8 = "";
        var scan = std.mem.splitScalar(u8, raw, '\n');
        while (scan.next()) |line| {
            if (std.mem.startsWith(u8, line, "page ")) page = line["page ".len..];
            if (!std.mem.startsWith(u8, line, "ua")) continue;
            var set: std.AutoHashMapUnmanaged(i64, void) = .empty;
            var ids = std.mem.tokenizeScalar(u8, line["ua".len..], ' ');
            while (ids.next()) |id| try set.put(scratch.allocator(), std.fmt.parseInt(i64, id, 10) catch continue, {});
            try ua_by_page.put(scratch.allocator(), page, set);
        }
    }
    const empty: std.AutoHashMapUnmanaged(i64, void) = .empty;
    var ua: *const std.AutoHashMapUnmanaged(i64, void) = &empty;
    var lines = std.mem.splitScalar(u8, raw, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.startsWith(u8, line, "page ")) {
            try out.print(allocator, "{s}\n", .{line});
            ua = ua_by_page.getPtr(line["page ".len..]) orelse &empty;
            continue;
        }
        if (!std.mem.startsWith(u8, line, "step ")) continue;
        const rest = line["step ".len..];
        const space = std.mem.indexOfScalar(u8, rest, ' ') orelse continue;
        try out.print(allocator, "step {s}\n", .{rest[0..space]});
        var parsed = std.json.parseFromSlice(std.json.Value, allocator, rest[space + 1 ..], .{}) catch {
            try out.appendSlice(allocator, "  unparsable\n");
            continue;
        };
        defer parsed.deinit();
        if (parsed.value.object.getPtr("result")) |result| if (result.object.getPtr("nodes")) |nodes| try userAgentNodes(parsed.arena.allocator(), &nodes.array, ua);
        if (parsed.value.object.get("error")) |e| {
            const message = if (e == .object) (if (e.object.get("message")) |m| m.string else "?") else "?";
            const code = if (e == .object) (if (e.object.get("code")) |c| c.integer else 0) else 0;
            try out.print(allocator, "  error {d} {s}\n", .{ code, message });
            continue;
        }
        const result = parsed.value.object.get("result") orelse continue;
        if (result.object.get("nodes")) |nodes| {
            for (nodes.array.items) |node| {
                try out.appendSlice(allocator, "  node ");
                try canonical(allocator, &names, node, &out);
                try out.append(allocator, '\n');
            }
            if (nodes.array.items.len == 0) try out.appendSlice(allocator, "  (no nodes)\n");
        } else if (result.object.get("node")) |node| {
            try out.appendSlice(allocator, "  node ");
            try canonical(allocator, &names, node, &out);
            try out.append(allocator, '\n');
        } else {
            try out.appendSlice(allocator, "  ok ");
            try canonical(allocator, &names, result, &out);
            try out.append(allocator, '\n');
        }
    }
    return out.toOwnedSlice(allocator);
}

/// The canonical fixture with `deviations` applied, OWNED;
/// error.DeviationNotFound when a block is not in it exactly once.
fn expectedTrace(allocator: Allocator, canonical_chrome: []const u8) ![]u8 {
    var text = try allocator.dupe(u8, canonical_chrome);
    errdefer allocator.free(text);
    for (deviations) |deviation| {
        if (std.mem.count(u8, text, deviation.chrome) != 1) {
            std.debug.print("deviation not found exactly once:\n{s}\n", .{deviation.chrome});
            return error.DeviationNotFound;
        }
        const next = try std.mem.replaceOwned(u8, allocator, text, deviation.chrome, deviation.crane);
        allocator.free(text);
        text = next;
    }
    return text;
}

/// Line by line, the first `limit` differences, each under its page and
/// step; whether the two are equal.
fn reportDifferences(expected: []const u8, actual: []const u8, limit: usize) bool {
    var e_lines = std.mem.splitScalar(u8, expected, '\n');
    var a_lines = std.mem.splitScalar(u8, actual, '\n');
    var page: []const u8 = "";
    var step: []const u8 = "";
    var shown: usize = 0;
    var equal = true;
    while (true) {
        const e = e_lines.next();
        const a = a_lines.next();
        if (e == null and a == null) break;
        const el = e orelse "";
        const al = a orelse "";
        if (std.mem.startsWith(u8, el, "page ")) page = el;
        if (std.mem.startsWith(u8, el, "step ")) step = el;
        if (std.mem.eql(u8, el, al)) continue;
        equal = false;
        if (shown < limit) {
            std.debug.print("{s} / {s}\n  chrome: {s}\n  crane:  {s}\n", .{ page, step, el, al });
        }
        shown += 1;
    }
    if (shown > limit) std.debug.print("... {d} differing lines in all\n", .{shown});
    return equal;
}

/// The page target's WebSocket path on a server at `port`, from /json/list.
fn pagePath(allocator: Allocator, port: u16) ![]u8 {
    var tries: usize = 0;
    while (true) : (tries += 1) {
        var list = try cdp.httpGet(allocator, port, "/json/list", &.{"Host: 127.0.0.1"});
        defer list.deinit();
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, list.body, .{}) catch null;
        if (parsed) |p| {
            defer p.deinit();
            for (p.value.array.items) |entry| {
                if (!std.mem.eql(u8, entry.object.get("type").?.string, "page")) continue;
                return std.fmt.allocPrint(allocator, "/devtools/page/{s}", .{entry.object.get("id").?.string});
            }
        }
        if (tries == 100) return error.NoPage;
        @import("platform").sleepThread(20 * std.time.ns_per_ms);
    }
}

fn writeFile(path: []const u8, bytes: []const u8) !void {
    const io = testing.io;
    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, bytes);
}

test "the Accessibility domain's answers for a list of pages and commands equal Chrome 157's, node by node" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    var trace: std.ArrayList(u8) = .empty;
    defer trace.deinit(allocator);

    // Record mode: drive a Chrome for Testing 157 instead and write its trace.
    if (std.c.getenv("CRANE_CDP_TRACE_CHROME_PORT")) |port_text| {
        const port = try std.fmt.parseInt(u16, std.mem.span(port_text), 10);
        const path = try pagePath(allocator, port);
        defer allocator.free(path);
        progress("Chrome page target {s}", .{path});
        const client = try cdp.Client.openWebSocket(allocator, port, path, null);
        defer client.close();
        if (client.upgrade_status != 101) return error.UpgradeRefused;
        try runPages(allocator, client, &trace);
        try writeFile(std.mem.span(std.c.getenv("CRANE_A11Y_TRACE_OUT") orelse return error.NoOutPath), trace.items);
        return;
    }

    const host = try browser_mod.BrowserHost.start(allocator, .{});
    defer host.stop();
    _ = try host.createTab(.{});
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const path = try pagePath(allocator, server.port);
    defer allocator.free(path);
    const client = try cdp.Client.openWebSocket(allocator, server.port, path, null);
    defer client.close();
    try runPages(allocator, client, &trace);
    if (std.c.getenv("CRANE_A11Y_TRACE_OUT")) |out| try writeFile(std.mem.span(out), trace.items);

    const recorded = std.Io.Dir.cwd().readFileAlloc(testing.io, fixture_path, allocator, .limited(16 * 1024 * 1024)) catch |err| {
        std.debug.print("no Chrome fixture at {s} ({t})\n", .{ fixture_path, err });
        return err;
    };
    defer allocator.free(recorded);
    const chrome = try canonicalTrace(allocator, recorded);
    defer allocator.free(chrome);
    const expected = try expectedTrace(allocator, chrome);
    defer allocator.free(expected);
    const crane = try canonicalTrace(allocator, trace.items);
    defer allocator.free(crane);
    if (std.c.getenv("CRANE_A11Y_TRACE_CANONICAL")) |out| {
        const both = try std.fmt.allocPrint(allocator, "=== chrome (expected)\n{s}=== crane\n{s}", .{ expected, crane });
        defer allocator.free(both);
        try writeFile(std.mem.span(out), both);
    }
    try testing.expect(reportDifferences(expected, crane, 40));
}

test "canonical form: one rename map for AX node ids and backend ids, generated ids apart, sources dropped" {
    const allocator = testing.allocator;
    const raw =
        \\page p
        \\step full {"result":{"nodes":[{"nodeId":"7","backendDOMNodeId":7,"childIds":["9","-1000000002"],"role":{"type":"internalRole","value":"RootWebArea"},"frameId":"ABC","name":{"type":"computedString","value":"T","sources":[{"type":"attribute"}]}},{"nodeId":"-1000000002","parentId":"7","childIds":[]}]}}
        \\step bad {"error":{"code":-32602,"message":"Frame with the given frameId is not found."}}
        \\
    ;
    const got = try canonicalTrace(allocator, raw);
    defer allocator.free(got);
    try testing.expectEqualStrings(
        \\page p
        \\step full
        \\  node {backendDOMNodeId:n1,childIds:[n2,g1],frameId:frame1,name:{type:"computedString",value:"T"},nodeId:n1,role:{type:"internalRole",value:"RootWebArea"}}
        \\  node {childIds:[],nodeId:g1,parentId:n1}
        \\step bad
        \\  error -32602 Frame with the given frameId is not found.
        \\
    , got);
}

test "data URLs keep the page's text and escape what would end or alter it" {
    const allocator = testing.allocator;
    const url = try dataUrl(allocator, "<p>a%b#c\nd</p>");
    defer allocator.free(url);
    try testing.expectEqualStrings("data:text/html,<p>a%25b%23c%0Ad</p>", url);
}

test "user-agent nodes: a select's pop-up kept nodeless, other user-agent nodes gone with their nodeless children, page nodes given to the nearest kept ancestor" {
    const allocator = testing.allocator;
    const raw =
        \\page p
        \\step full {"result":{"nodes":[{"nodeId":"1","backendDOMNodeId":1,"childIds":["12"],"role":{"value":"textbox"}},{"nodeId":"2","backendDOMNodeId":2,"childIds":["15"],"role":{"value":"combobox"}},{"nodeId":"12","backendDOMNodeId":12,"parentId":"1","childIds":["31"],"role":{"value":"generic"}},{"nodeId":"15","backendDOMNodeId":15,"parentId":"2","childIds":["40"],"role":{"value":"MenuListPopup"}},{"nodeId":"31","backendDOMNodeId":31,"parentId":"12","childIds":["-2"],"role":{"value":"StaticText"}},{"nodeId":"40","backendDOMNodeId":40,"parentId":"15","childIds":["19"],"role":{"value":"none"}},{"nodeId":"-2","parentId":"31","childIds":[],"role":{"value":"InlineTextBox"}},{"nodeId":"19","backendDOMNodeId":19,"parentId":"40","childIds":[],"role":{"value":"option"}}]}}
        \\ua 12 15 31 40
        \\
    ;
    const got = try canonicalTrace(allocator, raw);
    defer allocator.free(got);
    try testing.expectEqualStrings(
        \\page p
        \\step full
        \\  node {backendDOMNodeId:n1,childIds:[],nodeId:n1,role:{value:"textbox"}}
        \\  node {backendDOMNodeId:n2,childIds:[g1],nodeId:n2,role:{value:"combobox"}}
        \\  node {childIds:[n3],nodeId:g1,parentId:n2,role:{value:"MenuListPopup"}}
        \\  node {backendDOMNodeId:n3,childIds:[],nodeId:n3,parentId:g1,role:{value:"option"}}
        \\
    , got);
}
