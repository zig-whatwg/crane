//! Logical image-map focus and the MathML interfaces autofocus relies on.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");

fn areaEligibility() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const Case = struct { markup: []const u8, focusable: bool };
    const cases = [_]Case{
        .{ .markup = "<map name=m><area id=a href='#' shape=default></map><img usemap='#m'>", .focusable = true },
        .{ .markup = "<map id=m><area id=a href='' shape=default></map><img usemap='#m'>", .focusable = true },
        .{ .markup = "<map name=m><area id=a shape=default></map><img usemap='#m'>", .focusable = false },
        .{ .markup = "<map name=m><area id=a tabindex=0 shape=default></map><img usemap='#m'>", .focusable = true },
        .{ .markup = "<map name=m><area id=a href='#' tabindex=-1 shape=default></map><img usemap='#m'>", .focusable = false },
        .{ .markup = "<map name=m><area id=a href='#' tabindex=2 shape=default></map><img usemap='#m'>", .focusable = true },
        .{ .markup = "<map name=m><area id=a href='#' shape=default></map><img usemap='#m' style='display:none'>", .focusable = false },
        .{ .markup = "<map name=m><area id=a href='#' shape=default></map><img usemap='#m' inert>", .focusable = false },
        .{ .markup = "<map name=m><area id=a href='#' shape=default></map><img>", .focusable = false },
        .{ .markup = "<map name=m><area id=a href='#' shape=default></map><img usemap='m'>", .focusable = false },
        .{ .markup = "<map name=m><area id=a href='#' shape=default></map><img usemap='#'>", .focusable = false },
        .{ .markup = "<map name=m><area id=a href='#' shape=default></map><img usemap='#M'>", .focusable = false },
        .{ .markup = "<map name=m><area id=a href='#' shape=default></map><img usemap='page.html#m'>", .focusable = true },
        .{ .markup = "<map name=m></map><map name=m><area id=a href='#' shape=default></map><img usemap='#m'>", .focusable = false },
        .{ .markup = "<map name=m><span><area id=a href='#' shape=default></span></map><img usemap='#m'>", .focusable = true },
        .{ .markup = "<map name=m><area id=a href='#' shape=default inert></map><img usemap='#m'>", .focusable = false },
    };
    for (cases) |case| {
        const source = try std.fmt.allocPrint(std.testing.allocator, "document.body.innerHTML = `{s}`", .{case.markup});
        defer std.testing.allocator.free(source);
        try page.run(source);
        const document = page.browser.current_context.?.document_instance.?;
        const area = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("a"))).?;
        try std.testing.expectEqual(case.focusable, html.focus.isFocusableArea(area));
        if (case.focusable) {
            html.focus.focusMethod(area);
            try std.testing.expect((try interfaces.Document.get_activeElement(document)) == area);
            // Focus fixup must use the image's rendering, not area's own box.
            try std.testing.expect(html.focus.focusedAreaOf(document) == area);
        }
    }
}

fn parsedMathmlInterface() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<math id=m><mrow id=r autofocus tabindex=0></mrow></math>'");
    const result = try page.evaluate("[m instanceof MathMLElement, r instanceof MathMLElement, r.autofocus, r.tabIndex].join(',')");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("true,true,true,0", result);
}

fn createdMathmlInterface() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const result = try page.evaluate(
        \\(() => {
        \\  const element = document.createElementNS('http://www.w3.org/1998/Math/MathML', 'math');
        \\  const absent = element.autofocus;
        \\  element.autofocus = true;
        \\  const other = document.createElementNS('urn:af2:other', 'math');
        \\  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'a');
        \\  return [element instanceof MathMLElement, absent, element.hasAttribute('autofocus'),
        \\          other instanceof MathMLElement, typeof other.autofocus, svg instanceof SVGAElement].join(',');
        \\})()
    );
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("true,false,true,false,undefined,true", result);
}

fn nativeMathmlConstruction() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.createNullContext(std.testing.allocator);
    defer context.deinit();
    inline for (.{ interfaces.MathMLElement, interfaces.MathMLAnchorElement }) |Interface| {
        const element = try Interface.init(std.testing.allocator, &context);
        defer runtime.Instance.deinit(element);
        try std.testing.expectEqual(interfaces.Node.get_ELEMENT_NODE(), try interfaces.Node.get_nodeType(element));
        try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned("id"), .{ .domstring = runtime.DOMString.initInterned("native-math") });
        var id = try interfaces.Element.get_id(element);
        defer id.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("native-math", id.asSlice());
    }
}

fn mathmlTabindex() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const result = try page.evaluate(
        \\(() => {
        \\  const a = document.createElementNS('http://www.w3.org/1998/Math/MathML', 'a');
        \\  const row = document.createElementNS('http://www.w3.org/1998/Math/MathML', 'mrow');
        \\  const values = [a instanceof MathMLAnchorElement, a instanceof MathMLElement, a instanceof Element, a instanceof Node, a.tabIndex, row.tabIndex];
        \\  for (const value of ['  +2tail', '-1', 'bad', '2147483648', '\u000b0']) {
        \\    row.setAttribute('tabindex', value);
        \\    values.push(row.tabIndex);
        \\  }
        \\  return values.join(',');
        \\})()
    );
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("true,true,true,true,0,-1,2,-1,-1,-1,-1", result);
}

fn tabindexWhitespace() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<div id=a></div>'");
    const document = page.browser.current_context.?.document_instance.?;
    const element = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("a"))).?;
    const Case = struct { text: []const u8, value: ?i32 };
    const cases = [_]Case{
        .{ .text = "\x0b0", .value = null },
        .{ .text = "\t\n\x0c\r +2tail", .value = 2 },
        .{ .text = "-1", .value = -1 },
        .{ .text = "bad", .value = null },
        .{ .text = "2147483648", .value = null },
    };
    for (cases) |case| {
        try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned("tabindex"), .{ .domstring = runtime.DOMString.initInterned(case.text) });
        try std.testing.expectEqual(case.value, html.focus.tabindexValue(element));
        try std.testing.expectEqual(case.value != null, html.focus.isFocusableArea(element));
        try std.testing.expectEqual(case.value orelse -1, try interfaces.HTMLElement.get_tabIndex(element));
    }
}

test "area focus requires a rendered image and a matching image map" {
    try helpers.onFreshThread(areaEligibility);
}

test "parser-created MathML has its interface and autofocus reflection" {
    try helpers.onFreshThread(parsedMathmlInterface);
}

test "createElementNS selects MathMLElement only in its namespace" {
    try helpers.onFreshThread(createdMathmlInterface);
}

test "native MathML construction initializes and tears down Element and Node" {
    try helpers.onFreshThread(nativeMathmlConstruction);
}

test "MathML tabindex reads explicit integers and its historical defaults" {
    try helpers.onFreshThread(mathmlTabindex);
}

test "tabindex skips only HTML ASCII whitespace for focusability and reflection" {
    try helpers.onFreshThread(tabindexWhitespace);
}
