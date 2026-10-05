//! The tree builder tells the DOM adapter about every element it removes from
//! its stack of open elements - "finished parsing children" - however the
//! element leaves it: popped by its end tag, by an implied end tag, removed
//! by the adoption agency while it is not the current node, or popped with
//! everything else when parsing stops at the end of the input.
//!
//! HTML keys element processing on that pop: "the element is popped off the
//! stack of open elements of an HTML parser" (the object element, 4.8.7;
//! media elements; select). Blink calls Element::FinishParsingChildren from
//! every removal (HTMLElementStack::PopCommon, RemoveNonTopCommon, PopAll),
//! and this is the same seam: src/dom/finish_parsing_children.zig is where an
//! element type hears it, through the adapter.
//!
//! What the adapter is told must not change what script can observe: text
//! the parser holds for the popped element reaches the adapter before the
//! notification, and no run of text is split by it.

const std = @import("std");
const testing = std.testing;

const html = @import("html");
const parser = html.parser;
const Tokenizer = parser.Tokenizer;
const TreeBuilder = parser.TreeBuilder;
const TreeNode = parser.TreeNode;

/// Everything the adapter hears, in order, as "<event>:<tag or length>".
const Recorder = struct {
    allocator: std.mem.Allocator,
    events: std.ArrayListUnmanaged([]u8) = .empty,

    fn deinit(self: *Recorder) void {
        for (self.events.items) |event| self.allocator.free(event);
        self.events.deinit(self.allocator);
    }

    fn add(self: *Recorder, comptime fmt: []const u8, args: anytype) void {
        const event = std.fmt.allocPrint(self.allocator, fmt, args) catch return;
        self.events.append(self.allocator, event) catch self.allocator.free(event);
    }

    fn nameOf(node: *TreeNode) []const u8 {
        return node.local_name orelse "?";
    }

    fn onNodeCreated(node: *TreeNode, context: ?*anyopaque) void {
        const self: *Recorder = @ptrCast(@alignCast(context.?));
        if (node.node_type == .element) self.add("created:{s}", .{nameOf(node)});
    }

    fn onChildAppended(parent: *TreeNode, child: *TreeNode, context: ?*anyopaque) void {
        _ = parent;
        _ = child;
        _ = context;
    }

    fn onTextContentChanged(node: *TreeNode, context: ?*anyopaque) void {
        const self: *Recorder = @ptrCast(@alignCast(context.?));
        if (node.node_type == .text) self.add("text:{d}", .{node.text_content.toSlice().len});
    }

    fn onTextModePopped(node: *TreeNode, context: ?*anyopaque) void {
        const self: *Recorder = @ptrCast(@alignCast(context.?));
        self.add("textpopped:{s}", .{nameOf(node)});
    }

    fn onFinished(node: *TreeNode, context: ?*anyopaque) void {
        const self: *Recorder = @ptrCast(@alignCast(context.?));
        self.add("finished:{s}", .{nameOf(node)});
    }

    fn onScript(script: *TreeNode, context: ?*anyopaque) void {
        _ = script;
        const self: *Recorder = @ptrCast(@alignCast(context.?));
        self.add("script", .{});
    }

    /// The index of `event`, which must have been heard.
    fn indexOf(self: *const Recorder, event: []const u8) !usize {
        for (self.events.items, 0..) |e, i| {
            if (std.mem.eql(u8, e, event)) return i;
        }
        std.debug.print("not heard: {s}\nheard:", .{event});
        for (self.events.items) |e| std.debug.print(" {s}", .{e});
        std.debug.print("\n", .{});
        return error.EventNotHeard;
    }

    fn count(self: *const Recorder, event: []const u8) usize {
        var n: usize = 0;
        for (self.events.items) |e| {
            if (std.mem.eql(u8, e, event)) n += 1;
        }
        return n;
    }
};

fn parse(allocator: std.mem.Allocator, source: []const u8, recorder: *Recorder) !void {
    var tokenizer = Tokenizer.init(allocator, source);
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    builder.scripting_enabled = true;
    builder.setScriptExecutionCallback(&Recorder.onScript, recorder);
    builder.setDomAdapterCallbacks(recorder, &Recorder.onNodeCreated, &Recorder.onChildAppended, &Recorder.onTextContentChanged);
    builder.setDomAdapterPoppedCallback(&Recorder.onTextModePopped);
    builder.setDomAdapterFinishedCallback(&Recorder.onFinished);
    try builder.parse();
}

test "an element's end tag pops it after its children, and its creation came first" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    try parse(testing.allocator, "<!DOCTYPE html><body><object data=x><p>fallback</p></object><div></div>", &recorder);

    const created = try recorder.indexOf("created:object");
    const p_finished = try recorder.indexOf("finished:p");
    const finished = try recorder.indexOf("finished:object");
    const div_created = try recorder.indexOf("created:div");
    try testing.expect(created < p_finished);
    try testing.expect(p_finished < finished);
    try testing.expect(finished < div_created);
    try testing.expectEqual(@as(usize, 1), recorder.count("finished:object"));
}

test "elements closed by implied end tags are popped too" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    // The second li implies the first's end tag, </ul> the second's; the
    // object's end tag implies the p's.
    try parse(testing.allocator, "<!DOCTYPE html><body><ul><li>a<li>b</ul><object><p>x</object>", &recorder);

    try testing.expectEqual(@as(usize, 2), recorder.count("finished:li"));
    try testing.expect(try recorder.indexOf("finished:ul") > try recorder.indexOf("finished:li"));
    try testing.expect(try recorder.indexOf("finished:p") < try recorder.indexOf("finished:object"));
}

test "the adoption agency's removal of a node that is not the current node is heard" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    // </a> finds the furthest block (div) below a; span, between them and
    // not a formatting element, leaves the stack while div is the current
    // node (the inner loop's "remove node from the stack of open elements").
    try parse(testing.allocator, "<!DOCTYPE html><body><a><span><div>x</a>y", &recorder);

    try testing.expectEqual(@as(usize, 1), recorder.count("finished:span"));
    try testing.expect(try recorder.indexOf("finished:span") < try recorder.indexOf("finished:div"));
}

test "parsing that stops at the end of the input pops every open element, current node first" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    try parse(testing.allocator, "<!DOCTYPE html><body><object><span>x", &recorder);

    const span = try recorder.indexOf("finished:span");
    const object = try recorder.indexOf("finished:object");
    const body = try recorder.indexOf("finished:body");
    const html_finished = try recorder.indexOf("finished:html");
    try testing.expect(span < object);
    try testing.expect(object < body);
    try testing.expect(body < html_finished);
    // Popped once each: nothing is left on the stack to pop again.
    try testing.expectEqual(@as(usize, 1), recorder.count("finished:object"));
    try testing.expectEqual(@as(usize, 1), recorder.count("finished:html"));
}

const e_acute = "\u{e9}"; // two bytes of UTF-8: never batched into a text run

test "the popped element's text reaches the adapter first, once" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    // A text node is made with its first character; the rest of its run is
    // one change notification.
    try parse(testing.allocator, "<!DOCTYPE html><body><object>" ++ e_acute ** 4 ++ "</object><p>" ++ e_acute ** 2 ++ "</p>", &recorder);

    const text = try recorder.indexOf("text:8");
    try testing.expect(text < try recorder.indexOf("finished:object"));
    try testing.expectEqual(@as(usize, 1), recorder.count("text:8"));
    try testing.expect(try recorder.indexOf("text:4") < try recorder.indexOf("finished:p"));
    try testing.expectEqual(@as(usize, 1), recorder.count("text:4"));
}

test "a script is popped before it runs, and a text mode element after its own steps" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    try parse(testing.allocator, "<!DOCTYPE html><head><style>p{}</style><script>1</script></head>", &recorder);

    try testing.expect(try recorder.indexOf("finished:script") < try recorder.indexOf("script"));
    try testing.expect(try recorder.indexOf("textpopped:style") < try recorder.indexOf("finished:style"));
    try testing.expectEqual(@as(usize, 1), recorder.count("finished:style"));
    try testing.expectEqual(@as(usize, 1), recorder.count("textpopped:style"));
}

/// The text notifications of parsing `source`, with or without the
/// finished-parsing-children callback set.
fn textEvents(allocator: std.mem.Allocator, source: []const u8, with_finished: bool) !Recorder {
    var recorder: Recorder = .{ .allocator = allocator };
    errdefer recorder.deinit();
    var tokenizer = Tokenizer.init(allocator, source);
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    builder.scripting_enabled = true;
    builder.setScriptExecutionCallback(&Recorder.onScript, &recorder);
    builder.setDomAdapterCallbacks(&recorder, &Recorder.onNodeCreated, &Recorder.onChildAppended, &Recorder.onTextContentChanged);
    builder.setDomAdapterPoppedCallback(&Recorder.onTextModePopped);
    if (with_finished) builder.setDomAdapterFinishedCallback(&Recorder.onFinished);
    try builder.parse();
    // Only what the adapter mirrors into the DOM: text, creations, scripts.
    var kept: std.ArrayListUnmanaged([]u8) = .empty;
    for (recorder.events.items) |e| {
        if (std.mem.startsWith(u8, e, "finished:")) {
            allocator.free(e);
        } else {
            try kept.append(allocator, e);
        }
    }
    recorder.events.deinit(allocator);
    recorder.events = kept;
    return recorder;
}

test "the pop notification changes no text, creation or script notification" {
    const inputs = [_][]const u8{
        // Foster parenting: the table's text runs are body's, around the table.
        "<!DOCTYPE html><body><table>" ++ e_acute ++ "<tr><td>" ++ e_acute ++ "</td></tr>" ++ e_acute ++ "</table>" ++ e_acute,
        // Mis-nested formatting: the adoption agency.
        "<!DOCTYPE html><body><b>" ++ e_acute ++ "<i>" ++ e_acute ++ "</b>" ++ e_acute ++ "</i>" ++ e_acute,
        "<!DOCTYPE html><body><a>" ++ e_acute ++ "<span><div>" ++ e_acute ++ "</a>" ++ e_acute,
        // Implied end tags and a script between runs.
        "<!DOCTYPE html><body><p>" ++ e_acute ++ "<ul><li>" ++ e_acute ++ "<li>" ++ e_acute ++ "</ul><script>1</script>" ++ e_acute,
        // Text left open at the end of the input.
        "<!DOCTYPE html><body><object><span>" ++ e_acute ++ e_acute,
        "<!DOCTYPE html><select><option>" ++ e_acute ++ "<option>" ++ e_acute ++ "</select>" ++ e_acute,
    };
    for (inputs) |source| {
        var without = try textEvents(testing.allocator, source, false);
        defer without.deinit();
        var with = try textEvents(testing.allocator, source, true);
        defer with.deinit();
        try testing.expectEqual(without.events.items.len, with.events.items.len);
        for (without.events.items, with.events.items) |a, b| try testing.expectEqualStrings(a, b);
    }
}
