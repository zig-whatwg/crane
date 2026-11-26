//! Lane mix1: shared WebIDL mixin inheritance across implementing interfaces
//! (src/webidl/AGENTS.md "Mixin members are inherited").
//!
//! Verifies both:
//! 1. Function-identity sharing: two interfaces including the same mixin share
//!    the exact same generated delegate function pointer (implemented once in
//!    the mixin impl, aliased by each includer).
//! 2. End-to-end JS runtime behaviour through shared mixin dispatch across
//!    Request/Response (Body), TextDecoder/TextDecoderStream, TextEncoder/
//!    TextEncoderStream, CompressionStream/DecompressionStream, ReadableStream
//!    readers, Document/ShadowRoot/XPathEvaluator, LinkStyle includers,
//!    PopoverTargetAttributes, ElementContentEditable, Navigator*, and
//!    MessagePort (MessageEventTarget).

const std = @import("std");
const testing = std.testing;
const interfaces = @import("interfaces");
const helpers = @import("edges_node_holders_helpers.zig");

fn expectEval(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const result = try page.evaluate(source);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings(expected, result);
}

test "includers of inherited mixins alias the exact same delegate function" {
    // WebGLRenderingContextBase
    try testing.expectEqual(interfaces.WebGLRenderingContext.call_clear, interfaces.WebGL2RenderingContext.call_clear);
    try testing.expectEqual(interfaces.WebGLRenderingContext.get_canvas, interfaces.WebGL2RenderingContext.get_canvas);
    // CanvasPath
    try testing.expectEqual(interfaces.CanvasRenderingContext2D.call_moveTo, interfaces.Path2D.call_moveTo);
    try testing.expectEqual(interfaces.CanvasRenderingContext2D.call_arc, interfaces.OffscreenCanvasRenderingContext2D.call_arc);
    // PaintTimingMixin
    try testing.expectEqual(interfaces.LargestContentfulPaint.get_paintTime, interfaces.PerformancePaintTiming.get_paintTime);
    // AbstractWorker
    try testing.expectEqual(interfaces.Worker.get_onerror, interfaces.SharedWorker.get_onerror);
    // MessageEventTarget
    try testing.expectEqual(interfaces.MessagePort.set_onmessage, interfaces.Worker.set_onmessage);
    // Navigator*
    try testing.expectEqual(interfaces.Navigator.get_userAgent, interfaces.WorkerNavigator.get_userAgent);
    try testing.expectEqual(interfaces.Navigator.get_language, interfaces.WorkerNavigator.get_language);
    try testing.expectEqual(interfaces.Navigator.get_onLine, interfaces.WorkerNavigator.get_onLine);
    try testing.expectEqual(interfaces.Navigator.get_hardwareConcurrency, interfaces.WorkerNavigator.get_hardwareConcurrency);
    // Body
    try testing.expectEqual(interfaces.Request.get_body, interfaces.Response.get_body);
    try testing.expectEqual(interfaces.Request.get_bodyUsed, interfaces.Response.get_bodyUsed);
    try testing.expectEqual(interfaces.Request.call_text, interfaces.Response.call_text);
    try testing.expectEqual(interfaces.Request.call_textStream, interfaces.Response.call_textStream);
    // Streams & Encoding
    try testing.expectEqual(interfaces.CompressionStream.get_readable, interfaces.TextDecoderStream.get_readable);
    try testing.expectEqual(interfaces.DecompressionStream.get_writable, interfaces.TextEncoderStream.get_writable);
    try testing.expectEqual(interfaces.ReadableStreamDefaultReader.get_closed, interfaces.ReadableStreamBYOBReader.get_closed);
    try testing.expectEqual(interfaces.ReadableStreamDefaultReader.call_cancel, interfaces.ReadableStreamBYOBReader.call_cancel);
    try testing.expectEqual(interfaces.TextDecoder.get_encoding, interfaces.TextDecoderStream.get_encoding);
    try testing.expectEqual(interfaces.TextDecoder.get_fatal, interfaces.TextDecoderStream.get_fatal);
    try testing.expectEqual(interfaces.TextDecoder.get_ignoreBOM, interfaces.TextDecoderStream.get_ignoreBOM);
    try testing.expectEqual(interfaces.TextEncoder.get_encoding, interfaces.TextEncoderStream.get_encoding);
    // DocumentOrShadowRoot, FontFaceSource, XPathEvaluatorBase, LinkStyle, PopoverTargetAttributes
    try testing.expectEqual(interfaces.Document.get_activeElement, interfaces.ShadowRoot.get_activeElement);
    try testing.expectEqual(interfaces.Document.get_customElementRegistry, interfaces.ShadowRoot.get_customElementRegistry);
    try testing.expectEqual(interfaces.Document.get_fonts, interfaces.WorkerGlobalScope.get_fonts);
    try testing.expectEqual(interfaces.Document.call_evaluate, interfaces.XPathEvaluator.call_evaluate);
    try testing.expectEqual(interfaces.HTMLStyleElement.get_sheet, interfaces.SVGStyleElement.get_sheet);
    try testing.expectEqual(interfaces.HTMLLinkElement.get_sheet, interfaces.ProcessingInstruction.get_sheet);
    try testing.expectEqual(interfaces.HTMLButtonElement.get_popoverTargetAction, interfaces.HTMLInputElement.get_popoverTargetAction);
    // AnimationFrameProvider
    try testing.expectEqual(interfaces.Window.call_requestAnimationFrame, interfaces.DedicatedWorkerGlobalScope.call_requestAnimationFrame);
}

fn bodyAndStreamsMixins() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\(async () => {
        \\  const req = new Request('https://example.test/', { method: 'POST', body: 'hello' });
        \\  const res = new Response('world');
        \\  const [t1, t2] = await Promise.all([req.text(), res.text()]);
        \\  const enc1 = new TextEncoder().encoding;
        \\  const enc2 = new TextEncoderStream().encoding;
        \\  const dec1 = new TextDecoder('utf-16le', { fatal: true, ignoreBOM: true });
        \\  const dec2 = new TextDecoderStream('utf-16le', { fatal: true, ignoreBOM: true });
        \\  const cs = new CompressionStream('gzip');
        \\  const rs = new ReadableStream({ start(c) { c.close(); } });
        \\  const r = rs.getReader();
        \\  await r.closed;
        \\  globalThis.__out = [
        \\    t1, t2, req.bodyUsed, res.bodyUsed,
        \\    enc1, enc2,
        \\    dec1.encoding, dec1.fatal, dec1.ignoreBOM,
        \\    dec2.encoding, dec2.fatal, dec2.ignoreBOM,
        \\    cs.readable instanceof ReadableStream,
        \\    cs.writable instanceof WritableStream,
        \\    dec2.readable instanceof ReadableStream,
        \\    dec2.writable instanceof WritableStream,
        \\  ].join('|');
        \\})();
    );
    try page.settle();
    try expectEval(page, "globalThis.__out", "hello|world|true|true|utf-8|utf-8|utf-16le|true|true|utf-16le|true|true|true|true|true|true");
}

fn domCssHtmlMixins() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try expectEval(page,
        \\(() => {
        \\  document.body.innerHTML = '<style>p{color:red}</style><svg><style>rect{fill:blue}</style></svg><div id=host></div><button id=b popovertargetaction="show"></button><input id=i popovertargetaction="hide"><div id=ed contenteditable="true"></div>';
        \\  const host = document.getElementById('host');
        \\  const sr = host.attachShadow({ mode: 'open' });
        \\  sr.innerHTML = '<style>span{color:green}</style><span>hi</span>';
        \\  const docX = document.evaluate('count(//div)', document, null, XPathResult.NUMBER_TYPE, null).numberValue;
        \\  const evX = new XPathEvaluator().evaluate('count(//div)', document, null, XPathResult.NUMBER_TYPE, null).numberValue;
        \\  const htmlSheet = document.querySelector('style').sheet;
        \\  const svgSheet = document.querySelector('svg style').sheet;
        \\  const b = document.getElementById('b');
        \\  const i = document.getElementById('i');
        \\  const ed = document.getElementById('ed');
        \\  return [
        \\    document.styleSheets === document.styleSheets,
        \\    sr.styleSheets === sr.styleSheets,
        \\    sr.styleSheets.length,
        \\    document.fonts === document.fonts,
        \\    docX, evX,
        \\    htmlSheet !== null,
        \\    svgSheet !== null,
        \\    b.popoverTargetAction,
        \\    i.popoverTargetAction,
        \\    ed.contentEditable,
        \\    ed.isContentEditable,
        \\  ].join('|');
        \\})()
    , "true|true|1|true|2|2|true|true|show|hide|true|true");
}

fn navigatorAndMessageEventTargetMixins() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\(async () => {
        \\  const ch = new MessageChannel();
        \\  const got = await new Promise((resolve) => {
        \\    ch.port1.onmessage = (e) => resolve(e.data);
        \\    ch.port2.postMessage('ping');
        \\  });
        \\  globalThis.__out = [
        \\    got,
        \\    navigator.appCodeName,
        \\    navigator.appName,
        \\    navigator.product,
        \\    navigator.vendor,
        \\    navigator.cookieEnabled,
        \\    navigator.onLine,
        \\    navigator.hardwareConcurrency >= 1,
        \\    navigator.languages === navigator.languages,
        \\    typeof navigator.platform === 'string' && navigator.platform.length > 0,
        \\  ].join('|');
        \\})();
    );
    try page.settle();
    try expectEval(page, "globalThis.__out", "ping|Mozilla|Netscape|Gecko|Crane|true|true|true|true|true");
}

test "shared Body, Streams, and Encoding mixin dispatch works across includers" {
    try helpers.onFreshThread(bodyAndStreamsMixins);
}

test "shared DocumentOrShadowRoot, FontFaceSource, XPath, LinkStyle, Popover, and ContentEditable mixins work" {
    try helpers.onFreshThread(domCssHtmlMixins);
}

test "shared Navigator* and MessageEventTarget mixins work" {
    try helpers.onFreshThread(navigatorAndMessageEventTargetMixins);
}
