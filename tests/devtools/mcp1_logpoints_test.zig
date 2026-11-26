//! Lane mcp1, batch 4b item 3a: set_logpoints on script URLs as
//! chrome-devtools-mcp v1.13.0 answers it (src/tools/logpoints.ts over
//! LogpointManager and DevTools' BreakpointManager in its second, "DevTools
//! universe" session). Each answer below is Chrome for Testing 157's,
//! recorded by the differential suite (tools/mcp_diff case "logpoints:
//! script URLs", chat2, 2026-11-25) on the same two files, served here:
//! - a location binds when V8 resolves it, and keeps the line and column
//!   asked for (a column 0 when none was given: DevTools' raw location);
//! - an inline script's location is the document's;
//! - output is console.log's, and an expression that throws is V8's
//!   exception with no text (V8Debugger::BreakpointConditionEvaluated);
//! - the set replaces the last one, survives a reload, and a location no
//!   script contains is reported after the logpoints that were applied.

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;
const LoopbackListener = @import("loopback_listener").LoopbackListener;

/// tools/mcp_diff/fixtures/logpoints.js: line numbers matter.
const script =
    \\// Logpoint fixture: line numbers matter (tools/mcp_diff cases "logpoints: ...").
    \\function add(x, y) {
    \\  const sum = x + y;
    \\  return sum;
    \\}
    \\
    \\// a comment line
    \\window.run = n => {
    \\  const doubled = add(n, n);
    \\  return doubled;
    \\};
    \\
;

/// tools/mcp_diff/fixtures/logpoints.html.
const page =
    \\<!doctype html>
    \\<title>Logpoints</title>
    \\<script src="logpoints.js"></script>
    \\<script>
    \\  window.inline = n => {
    \\    const tripled = n * 3;
    \\    return tripled;
    \\  };
    \\</script>
    \\
;

/// tools/mcp_diff/fixtures/logpoints-dup.html: two scripts of one file name.
const duplicates_page =
    \\<!doctype html>
    \\<title>Duplicates</title>
    \\<script src="lp-a/same.js"></script>
    \\<script src="lp-b/same.js"></script>
    \\
;

/// tools/mcp_diff/fixtures/lp-sm/*: source map fixtures.
const sm_page =
    \\<!doctype html>
    \\<title>Source map logpoints</title>
    \\<script src="bundle.js"></script>
    \\<script src="inline-map.js"></script>
    \\<script src="same-url.js"></script>
    \\<script src="indexed.js"></script>
    \\<script src="chunk1.js"></script>
    \\<script src="chunk2.js"></script>
    \\<script src="broken-map.js"></script>
    \\
;

const sm_bundle_js =
    \\function doubleAdd(a, b) { const total = a + b; return total * 2; }
    \\window.calcRun = n => { const out = doubleAdd(n, 3); return out; };
    \\//# sourceMappingURL=bundle.js.map
    \\
;

const sm_bundle_map =
    \\{"version":3,"sources":["src/calc.ts"],"sourcesContent":["// calc.ts comment\nexport function doubleAdd(a: number, b: number): number {\n  const total = a + b;\n  return total * 2;\n}\n\nwindow.calcRun = (n: number) => {\n  const out = doubleAdd(n, 3);\n  return out;\n};\n"],"names":[],"mappings":"AACA,2BACE,qBACA;AAGF,wBACE,6BACA"}
    \\
;

const sm_inline_js =
    \\window.inlineMapped = v => { const res = v + 10; return res; };
    \\//# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbInNyYy9pbmxpbmUudHMiXSwic291cmNlc0NvbnRlbnQiOlsiLy8gaDFcbi8vIGgyXG53aW5kb3cuaW5saW5lTWFwcGVkID0gKHY6IG51bWJlcikgPT4ge1xuICBjb25zdCByZXMgPSB2ICsgMTA7XG4gIHJldHVybiByZXM7XG59O1xuIl0sIm5hbWVzIjpbXSwibWFwcGluZ3MiOiJBQUVBLDZCQUNFLG9CQUNBIn0=
    \\
;

const sm_same_url_js =
    \\window.viteFn = x => {
    \\  const y = x * 5;
    \\  return y;
    \\};
    \\//# sourceMappingURL=same-url.js.map
    \\
;

const sm_same_url_map =
    \\{"version":3,"sources":["same-url.js"],"sourcesContent":["// line 1\n// line 2\n// line 3\nwindow.viteFn = (x: number) => {\n  const y = x * 5;\n  return y;\n};\n"],"names":[],"mappings":"AAGA;EACE;EACA"}
    \\
;

const sm_indexed_js =
    \\window.secA = a => { const r = a + 1; return r; };
    \\window.secB = b => { const r = b + 2; return r; };
    \\//# sourceMappingURL=indexed.js.map
    \\
;

const sm_indexed_map =
    \\)]}'
    \\{"version":3,"sections":[{"offset":{"line":0,"column":0},"map":{"version":3,"sourceRoot":"webpack:///app/","sources":["sec-a.ts"],"names":[],"mappings":"AACA,qBACE,iBACA"}},{"offset":{"line":1,"column":0},"map":{"version":3,"sourceRoot":"webpack:///app/","sources":["sec-b.ts"],"names":[],"mappings":"AAEA,qBACE,iBACA"}}]}
    \\
;

const sm_chunk1_js =
    \\window.c1 = v => { const t = v + 1; return t; };
    \\//# sourceMappingURL=chunk1.js.map
    \\
;

const sm_chunk1_map =
    \\{"version":3,"sources":["shared.ts"],"sourcesContent":["// shared\nexport function tag(v) {\n  return v;\n}\n"],"names":[],"mappings":"AACA,mBAAE,iBACA"}
    \\
;

const sm_chunk2_js =
    \\// pad
    \\window.c2 = v => { const t = v + 2; return t; };
    \\//# sourceMappingURL=chunk2.js.map
    \\
;

const sm_chunk2_map =
    \\{"version":3,"sources":["shared.ts"],"sourcesContent":["// shared\nexport function tag(v) {\n  return v;\n}\n"],"names":[],"mappings":";AACA,mBAAE,iBACA"}
    \\
;

const sm_broken_js =
    \\window.brokenMapFn = v => { const z = v * 2; return z; };
    \\//# sourceMappingURL=does-not-exist.js.map
    \\
;

const sm_rebuild_html =
    \\<!doctype html>
    \\<title>Rebuild</title>
    \\<script src="rebuild.js"></script>
    \\
;

const sm_rebuild_v1_js =
    \\window.rebuilt = n => { const out = n + 1; return out; };
    \\//# sourceMappingURL=rebuild.js.map
    \\
;

const sm_rebuild_v1_map =
    \\{"version":3,"sources":["src/rebuild.ts"],"sourcesContent":["// v1\n"],"names":[],"mappings":"AAAA,wBACE,mBACA"}
    \\
;

const sm_rebuild_v2_js =
    \\// rebuilt line 1
    \\// rebuilt line 2
    \\window.rebuilt = n => { const out = n + 10; return out; };
    \\//# sourceMappingURL=rebuild.js.map
    \\
;

const sm_rebuild_v2_map =
    \\{"version":3,"sources":["src/rebuild.ts"],"sourcesContent":["// v2\n"],"names":[],"mappings":";;AAAA,wBACE,oBACA"}
    \\
;

const sm_slow_html =
    \\<!doctype html>
    \\<title>Slow map</title>
    \\<script src="slow.js"></script>
    \\
;

const sm_slow_js =
    \\window.slowFn = n => { const out = n + 1; return out; };
    \\//# sourceMappingURL=slow.js.map
    \\
;

const sm_slow_map =
    \\{"version":3,"sources":["src/slow.ts"],"sourcesContent":["// slow\n"],"names":[],"mappings":"AAAA,uBACE,mBACA"}
    \\
;

/// tools/mcp_diff/fixtures/lp-min/*: minified variable-name fixtures.
const min_page =
    \\<!doctype html>
    \\<title>Minified logpoints</title>
    \\<script src="min.js"></script>
    \\<script src="closure.js"></script>
    \\<script src="syntax.js"></script>
    \\<script src="nonames.js"></script>
    \\
;

const min_cart_js =
    \\function checkout(a,b){const c=a-b;return c}window.minCheckout=checkout;
    \\//# sourceMappingURL=min.js.map
    \\
;

const min_cart_map =
    \\{"version":3,"sources":["src/cart.ts"],"sourcesContent":["export function checkout(cartTotal: number, discount: number): number {\n  const finalAmount = cartTotal - discount;\n  return finalAmount;\n}\n"],"names":["cartTotal","discount","finalAmount"],"mappings":"AAAA,kBAAyBA,EAAmBC,GAC1C,MAAMC,EAAcF,EAAYC,EAChC,OAAOC"}
    \\
;

const min_closure_js =
    \\function makeAdder(e){const t=10;return function(n){const r=n*2;const o=e+r;return o}}window.minClosure=makeAdder;
    \\//# sourceMappingURL=closure.js.map
    \\
;

const min_closure_map =
    \\{"version":3,"sources":["src/closure.ts"],"sourcesContent":["export function makeAdder(outerBase: number) {\n  const factor = 10;\n  return function inner(step: number) {\n    const factor = step * 2;\n    const result = outerBase + factor;\n    return result;\n  };\n}\n"],"names":["outerBase","factor","step","result"],"mappings":"AAAA,mBAA0BA,GACxB,MAAMC,KACN,gBAAsBC,GACpB,MAAMD,EAASC,IACf,MAAMC,EAASH,EAAYC,EAC3B,OAAOE"}
    \\
;

const min_syntax_js =
    \\function inspectItem(t){const{price:e,label:n}=t;let r=0;for(let o=0;o<2;o++){r+=e}try{throw new Error(n)}catch(i){return r+":"+i.message}}window.minSyntax=inspectItem;
    \\//# sourceMappingURL=syntax.js.map
    \\
;

const min_syntax_map =
    \\{"version":3,"sources":["src/syntax.ts"],"sourcesContent":["export function inspectItem(item: { price: number; label: string }) {\n  const { price, label } = item;\n  let total = 0;\n  for (let idx = 0; idx < 2; idx++) {\n    total += price;\n  }\n  try {\n    throw new Error(label);\n  } catch (err) {\n    return total + ':' + err.message;\n  }\n}\n"],"names":["item","price","label","total","idx","err"],"mappings":"AAAA,qBAA4BA,GAC1B,YAAQC,QAAOC,GAAUF,EACzB,IAAIG,IACJ,QAASC,aACPD,GAASF,EAEX,oBACkBC,GAChB,MAAOG,GACP,OAAOF,MAAcE"}
    \\
;

const min_nonames_js =
    \\function calcTax(x){const y=x*2;return y}window.minNoNames=calcTax;
    \\//# sourceMappingURL=nonames.js.map
    \\
;

const min_nonames_map =
    \\{"version":3,"sources":["src/nonames.ts"],"sourcesContent":["export function calcTax(subtotal: number) {\n  const tax = subtotal * 2;\n  return tax;\n}\n"],"names":[],"mappings":"AAAA,oBACE,MAAM,CAAG,CAAG,CAAQ,GACpB,OAAO,CAAG"}
    \\
;

const Site = struct {
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),
    rebuild_version: std.atomic.Value(u32) = .init(1),
    release_slow: std.atomic.Value(bool) = .init(true),

    fn start(self: *Site) !void {
        self.* = .{ .listener = try LoopbackListener.open(.{}) };
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
    }

    fn stop(self: *Site) void {
        self.release_slow.store(true, .release);
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
    }

    fn serve(self: *Site) void {
        while (self.listener.accept()) |stream| {
            _ = self.active.fetchAdd(1, .acq_rel);
            const thread = std.Thread.spawn(.{}, answerAndClose, .{ self, stream }) catch {
                _ = self.active.fetchSub(1, .acq_rel);
                stream.close(std.testing.io);
                continue;
            };
            thread.detach();
        }
    }

    fn answerAndClose(self: *Site, stream: std.Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(std.testing.io);
        self.answer(stream) catch {};
    }

    fn answer(self: *Site, stream: std.Io.net.Stream) !void {
        var input: [8192]u8 = undefined;
        var reader = stream.reader(std.testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) try reader.interface.fillMore();
        const head = reader.interface.buffered();
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        _ = parts.next();
        const path = parts.next() orelse return;
        const v2 = self.rebuild_version.load(.acquire) == 2;
        const body: []const u8, const content_type: []const u8 = if (std.mem.eql(u8, path, "/logpoints.html"))
            .{ page, "text/html" }
        else if (std.mem.eql(u8, path, "/logpoints.js"))
            .{ script, "text/javascript" }
        else if (std.mem.eql(u8, path, "/logpoints-dup.html"))
            .{ duplicates_page, "text/html" }
        else if (std.mem.eql(u8, path, "/lp-a/same.js"))
            .{ "window.a = () => 1;\n", "text/javascript" }
        else if (std.mem.eql(u8, path, "/lp-b/same.js"))
            .{ "window.b = () => 2;\n", "text/javascript" }
        else if (std.mem.eql(u8, path, "/title.html"))
            .{ "<!doctype html><title>Fixture title</title><p>hello</p>\n", "text/html" }
        else if (std.mem.eql(u8, path, "/lp-sm/page.html"))
            .{ sm_page, "text/html" }
        else if (std.mem.eql(u8, path, "/lp-sm/bundle.js"))
            .{ sm_bundle_js, "text/javascript" }
        else if (std.mem.eql(u8, path, "/lp-sm/bundle.js.map"))
            .{ sm_bundle_map, "application/json" }
        else if (std.mem.eql(u8, path, "/lp-sm/inline-map.js"))
            .{ sm_inline_js, "text/javascript" }
        else if (std.mem.eql(u8, path, "/lp-sm/same-url.js"))
            .{ sm_same_url_js, "text/javascript" }
        else if (std.mem.eql(u8, path, "/lp-sm/same-url.js.map"))
            .{ sm_same_url_map, "application/json" }
        else if (std.mem.eql(u8, path, "/lp-sm/indexed.js"))
            .{ sm_indexed_js, "text/javascript" }
        else if (std.mem.eql(u8, path, "/lp-sm/indexed.js.map"))
            .{ sm_indexed_map, "application/json" }
        else if (std.mem.eql(u8, path, "/lp-sm/chunk1.js"))
            .{ sm_chunk1_js, "text/javascript" }
        else if (std.mem.eql(u8, path, "/lp-sm/chunk1.js.map"))
            .{ sm_chunk1_map, "application/json" }
        else if (std.mem.eql(u8, path, "/lp-sm/chunk2.js"))
            .{ sm_chunk2_js, "text/javascript" }
        else if (std.mem.eql(u8, path, "/lp-sm/chunk2.js.map"))
            .{ sm_chunk2_map, "application/json" }
        else if (std.mem.eql(u8, path, "/lp-sm/broken-map.js"))
            .{ sm_broken_js, "text/javascript" }
        else if (std.mem.eql(u8, path, "/lp-sm/rebuild.html"))
            .{ sm_rebuild_html, "text/html" }
        else if (std.mem.eql(u8, path, "/lp-sm/rebuild.js"))
            .{ if (v2) sm_rebuild_v2_js else sm_rebuild_v1_js, "text/javascript" }
        else if (std.mem.eql(u8, path, "/lp-sm/rebuild.js.map"))
            .{ if (v2) sm_rebuild_v2_map else sm_rebuild_v1_map, "application/json" }
        else if (std.mem.eql(u8, path, "/lp-sm/slow.html"))
            .{ sm_slow_html, "text/html" }
        else if (std.mem.eql(u8, path, "/lp-sm/slow.js"))
            .{ sm_slow_js, "text/javascript" }
        else if (std.mem.eql(u8, path, "/lp-sm/slow.js.map")) blk: {
            while (!self.release_slow.load(.acquire)) {
                std.Io.sleep(std.testing.io, .fromMilliseconds(5), .awake) catch {};
            }
            break :blk .{ sm_slow_map, "application/json" };
        } else if (std.mem.eql(u8, path, "/lp-min/page.html"))
            .{ min_page, "text/html" }
        else if (std.mem.eql(u8, path, "/lp-min/min.js"))
            .{ min_cart_js, "text/javascript" }
        else if (std.mem.eql(u8, path, "/lp-min/min.js.map"))
            .{ min_cart_map, "application/json" }
        else if (std.mem.eql(u8, path, "/lp-min/closure.js"))
            .{ min_closure_js, "text/javascript" }
        else if (std.mem.eql(u8, path, "/lp-min/closure.js.map"))
            .{ min_closure_map, "application/json" }
        else if (std.mem.eql(u8, path, "/lp-min/syntax.js"))
            .{ min_syntax_js, "text/javascript" }
        else if (std.mem.eql(u8, path, "/lp-min/syntax.js.map"))
            .{ min_syntax_map, "application/json" }
        else if (std.mem.eql(u8, path, "/lp-min/nonames.js"))
            .{ min_nonames_js, "text/javascript" }
        else if (std.mem.eql(u8, path, "/lp-min/nonames.js.map"))
            .{ min_nonames_map, "application/json" }
        else
            .{ "", "text/plain" };
        var output: [1024]u8 = undefined;
        var writer = stream.writer(std.testing.io, &output);
        const status = if (body.len == 0) "404 Not Found" else "200 OK";
        try writer.interface.print("HTTP/1.1 {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n", .{ status, content_type, body.len });
        try writer.interface.writeAll(body);
        try writer.interface.flush();
    }
};

/// One call and Chrome's answer to it ("{fixture}": the site's origin).
const Step = struct {
    tool: []const u8,
    args: []const u8,
    answer: []const u8,
    is_error: bool = false,
};

const logged = "Logged output appears in list_console_messages once a line executes; objects show as [object Object] there, get_console_message shows them as JSON.";
const source_mapped_note = "Source-mapped locations are re-resolved automatically when a matching source map loads again (for example after a reload with a regenerated bundle). Note: on the first page load after a rebuild, code that runs during the load itself is not logged yet; if a load-time logpoint stays silent right after a rebuild, reload once more before concluding that the line does not run.";

/// tools/mcp_diff case "logpoints: script URLs": Chrome 157's answers.
const chrome_157 = [_]Step{
    .{ .tool = "navigate_page", .args = "{\"pageId\":1,\"url\":\"{fixture}/logpoints.html\"}", .answer = "Successfully navigated to {fixture}/logpoints.html.\n## Pages\n1: Logpoints ({fixture}/logpoints.html) [selected]" },
    .{
        .tool = "set_logpoints",
        .args = "{\"pageId\":1,\"logpoints\":[\"logpoints.js:4 'sum', sum\",\"logpoints.html:7 'tripled', tripled\",\"logpoints.js:6 'blank'\",\"logpoints.js:3:9 'column', x\"]}",
        .answer = "4 logpoint(s) set on the page:\n- {fixture}/logpoints.js:4:1 logging `'sum', sum` [bound]\n- {fixture}/logpoints.html:7:1 logging `'tripled', tripled` [bound]\n- {fixture}/logpoints.js:6:1 logging `'blank'` [bound]\n- {fixture}/logpoints.js:3:9 logging `'column', x` [bound]\n" ++ logged,
    },
    .{ .tool = "evaluate_script", .args = "{\"pageId\":1,\"function\":\"() => [window.run(2), window.inline(3)]\"}", .answer = "Script ran on page and returned:\n```json\n[4,9]\n```" },
    .{ .tool = "list_console_messages", .args = "{\"pageId\":1}", .answer = "## Console messages\nShowing 1-3 of 3 (Page 1 of 1).\nmsgid=1 [log] column 2 (2 args)\nmsgid=2 [log] sum 4 (2 args)\nmsgid=3 [log] tripled 9 (2 args)" },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"logpoints.js:4 'sum again', sum\"]}", .answer = "1 logpoint(s) set on the page:\n- {fixture}/logpoints.js:4:1 logging `'sum again', sum` [bound]\n" ++ logged },
    .{ .tool = "navigate_page", .args = "{\"pageId\":1,\"type\":\"reload\"}", .answer = "Successfully reloaded the page.\n## Pages\n1: Logpoints ({fixture}/logpoints.html) [selected]" },
    .{ .tool = "evaluate_script", .args = "{\"pageId\":1,\"function\":\"() => window.run(5)\"}", .answer = "Script ran on page and returned:\n```json\n10\n```" },
    .{ .tool = "list_console_messages", .args = "{\"pageId\":1}", .answer = "## Console messages\nShowing 1-1 of 1 (Page 1 of 1).\nmsgid=4 [log] sum again 10 (2 args)" },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"missing.js:1 x\"]}", .is_error = true, .answer = "Error: No parsed script or original source file matches \"missing.js\". The url must match the URL of a script as served to the browser or an original source file from a source map, exactly or as a path suffix." },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"logpoints.js:4 sum)\"]}", .is_error = true, .answer = "Error: The logpoint expression `sum)` does not compile: Unexpected token ')'. Provide the expression like arguments to console.log(...)." },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"logpoints.js 1\"]}", .is_error = true, .answer = "Error: Invalid logpoint \"logpoints.js 1\". Expected the format <url>:<lineNumber>[:<columnNumber>] <expression>, for example \"src/app.ts:42 'total', cart.total\"." },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"logpoints.js:0 x\"]}", .is_error = true, .answer = "Error: Invalid logpoint \"logpoints.js:0 x\": line and column numbers are 1-based." },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"logpoints.js:4 'kept'\",\"logpoints.js:30 'past the end'\"]}", .is_error = true, .answer = "1 logpoint(s) set on the page:\n- {fixture}/logpoints.js:4:1 logging `'kept'` [bound]\nError: No executable code at {fixture}/logpoints.js:30 (for example a comment, type annotation or empty line, or a line not mapped to the generated script). Pick lines containing executable code. The other logpoints were applied." },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"logpoints.js:4 (() => { throw new Error('boom') })()\"]}", .answer = "1 logpoint(s) set on the page:\n- {fixture}/logpoints.js:4:1 logging `(() => { throw new Error('boom') })()` [bound]\n" ++ logged },
    .{ .tool = "evaluate_script", .args = "{\"pageId\":1,\"function\":\"() => window.run(1)\"}", .answer = "Script ran on page and returned:\n```json\n2\n```" },
    .{ .tool = "list_console_messages", .args = "{\"pageId\":1}", .answer = "## Console messages\nShowing 1-2 of 2 (Page 1 of 1).\nmsgid=4 [log] sum again 10 (2 args)\nmsgid=5 [error]  (0 args)" },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[]}", .answer = "No logpoints are set on the page." },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[]}", .answer = "No logpoints are set on the page." },
};

/// tools/mcp_diff case "logpoints: lookups, documents, pauses": Chrome
/// 157's answers (chat2, 2026-11-25).
const chrome_157_lookups = [_]Step{
    .{ .tool = "navigate_page", .args = "{\"pageId\":1,\"url\":\"{fixture}/logpoints-dup.html\"}", .answer = "Successfully navigated to {fixture}/logpoints-dup.html.\n## Pages\n1: Duplicates ({fixture}/logpoints-dup.html) [selected]" },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"same.js:1 'x'\"]}", .is_error = true, .answer = "Error: \"same.js\" matches multiple sources: {fixture}/lp-a/same.js, {fixture}/lp-b/same.js. Specify a longer path." },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"c/same.js:1 'x'\"]}", .is_error = true, .answer = "Error: No parsed script or original source file matches \"c/same.js\". The url must match the URL of a script as served to the browser or an original source file from a source map, exactly or as a path suffix. Sources with the same file name: {fixture}/lp-a/same.js, {fixture}/lp-b/same.js." },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"lp-a/same.js:1 'a'\"]}", .answer = "1 logpoint(s) set on the page:\n- {fixture}/lp-a/same.js:1:1 logging `'a'` [bound]\n" ++ logged },
    // The universe skips all pauses: the debugger statement does not stop.
    .{ .tool = "evaluate_script", .args = "{\"pageId\":1,\"function\":\"() => { debugger; return window.a() + window.b(); }\"}", .answer = "Script ran on page and returned:\n```json\n3\n```" },
    .{ .tool = "list_console_messages", .args = "{\"pageId\":1}", .answer = "## Console messages\n<no console messages found>" },
    .{ .tool = "navigate_page", .args = "{\"pageId\":1,\"url\":\"{fixture}/title.html\"}", .answer = "Successfully navigated to {fixture}/title.html.\n## Pages\n1: Fixture title ({fixture}/title.html) [selected]" },
    // A document with no script: found, never bound.
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"title.html:1 'doc'\"]}", .is_error = true, .answer = "No logpoints are set on the page.\nError: No executable code at {fixture}/title.html:1 (for example a comment, type annotation or empty line, or a line not mapped to the generated script). Pick lines containing executable code. The other logpoints were applied." },
    // The last page's scripts are gone from the workspace.
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"lp-a/same.js:1 'a'\"]}", .is_error = true, .answer = "Error: No parsed script or original source file matches \"lp-a/same.js\". The url must match the URL of a script as served to the browser or an original source file from a source map, exactly or as a path suffix." },
};

/// tools/mcp_diff case "logpoints: source maps": Chrome 157's answers (chat.local, 2026-11-25).
const chrome_157_source_maps = [_]Step{
    .{ .tool = "navigate_page", .args = "{\"pageId\":1,\"url\":\"{fixture}/lp-sm/page.html\"}", .answer = "Successfully navigated to {fixture}/lp-sm/page.html.\n## Pages\n1: Source map logpoints ({fixture}/lp-sm/page.html) [selected]" },
    .{
        .tool = "set_logpoints",
        .args = "{\"pageId\":1,\"logpoints\":[\"src/calc.ts:4 'total', total\",\"bundle.js:2:54 'out', out\"]}",
        .answer = "2 logpoint(s) set on the page:\n- {fixture}/lp-sm/src/calc.ts:4:3 logging `'total', total` [bound via source map at {fixture}/lp-sm/bundle.js:1:49]\n- {fixture}/lp-sm/src/calc.ts:9:3 logging `'out', out` [bound via source map at {fixture}/lp-sm/bundle.js:2:54]\n" ++ source_mapped_note ++ "\n" ++ logged,
    },
    .{ .tool = "evaluate_script", .args = "{\"pageId\":1,\"function\":\"() => window.calcRun(4)\"}", .answer = "Script ran on page and returned:\n```json\n14\n```" },
    .{ .tool = "list_console_messages", .args = "{\"pageId\":1}", .answer = "## Console messages\nShowing 1-2 of 2 (Page 1 of 1).\nmsgid=1 [log] total 7 (2 args)\nmsgid=2 [log] out 14 (2 args)" },
    .{
        .tool = "set_logpoints",
        .args = "{\"pageId\":1,\"logpoints\":[\"src/calc.ts:4 'first', total\",\"bundle.js:1:49 'second', total\"]}",
        .answer = "1 logpoint(s) set on the page:\n- {fixture}/lp-sm/src/calc.ts:4:3 logging `'second', total` [bound via source map at {fixture}/lp-sm/bundle.js:1:49]\n" ++ source_mapped_note ++ "\n" ++ logged,
    },
    .{
        .tool = "set_logpoints",
        .args = "{\"pageId\":1,\"logpoints\":[\"src/calc.ts:4 'kept', total\",\"src/calc.ts:1 'comment'\"]}",
        .is_error = true,
        .answer = "1 logpoint(s) set on the page:\n- {fixture}/lp-sm/src/calc.ts:4:3 logging `'kept', total` [bound via source map at {fixture}/lp-sm/bundle.js:1:49]\nError: No executable code at {fixture}/lp-sm/src/calc.ts:1 (for example a comment, type annotation or empty line, or a line not mapped to the generated script). Pick lines containing executable code. The other logpoints were applied.",
    },
    .{ .tool = "navigate_page", .args = "{\"pageId\":1,\"type\":\"reload\"}", .answer = "Successfully reloaded the page.\n## Pages\n1: Source map logpoints ({fixture}/lp-sm/page.html) [selected]" },
    .{ .tool = "evaluate_script", .args = "{\"pageId\":1,\"function\":\"() => window.calcRun(6)\"}", .answer = "Script ran on page and returned:\n```json\n18\n```" },
    .{ .tool = "list_console_messages", .args = "{\"pageId\":1}", .answer = "## Console messages\nShowing 1-1 of 1 (Page 1 of 1).\nmsgid=3 [log] kept 9 (2 args)" },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[]}", .answer = "No logpoints are set on the page." },
};

/// tools/mcp_diff case "logpoints: inline, same-url, indexed, and shared maps":
/// Chrome 157's answers (chat.local, 2026-11-25).
const chrome_157_source_maps_variants = [_]Step{
    .{ .tool = "navigate_page", .args = "{\"pageId\":1,\"url\":\"{fixture}/lp-sm/page.html\"}", .answer = "Successfully navigated to {fixture}/lp-sm/page.html.\n## Pages\n1: Source map logpoints ({fixture}/lp-sm/page.html) [selected]" },
    .{
        .tool = "set_logpoints",
        .args = "{\"pageId\":1,\"logpoints\":[\"src/inline.ts:5 'res', res\",\"same-url.js:6 'y', y\",\"sec-a.ts:4 'a', r\",\"sec-b.ts:5 'b', r\",\"shared.ts:3 't', t\",\"broken-map.js:1:46 'z', z\"]}",
        .answer = "6 logpoint(s) set on the page:\n- {fixture}/lp-sm/src/inline.ts:5:3 logging `'res', res` [bound via source map at {fixture}/lp-sm/inline-map.js:1:50]\n- {fixture}/lp-sm/same-url.js:6:3 logging `'y', y` [bound via source map at {fixture}/lp-sm/same-url.js:3:3]\n- webpack:///app/sec-a.ts:4:3 logging `'a', r` [bound via source map at {fixture}/lp-sm/indexed.js:1:39]\n- webpack:///app/sec-b.ts:5:3 logging `'b', r` [bound via source map at {fixture}/lp-sm/indexed.js:2:39]\n- {fixture}/lp-sm/shared.ts:3:3 logging `'t', t` [bound via source map at {fixture}/lp-sm/chunk1.js:1:37, {fixture}/lp-sm/chunk2.js:2:37]\n- {fixture}/lp-sm/broken-map.js:1:46 logging `'z', z` [bound]\n" ++ source_mapped_note ++ "\n" ++ logged,
    },
    .{ .tool = "evaluate_script", .args = "{\"pageId\":1,\"function\":\"() => [window.inlineMapped(5), window.viteFn(3), window.secA(10), window.secB(20), window.c1(7), window.c2(8), window.brokenMapFn(9)]\"}", .answer = "Script ran on page and returned:\n```json\n[15,15,11,22,8,10,18]\n```" },
    .{ .tool = "list_console_messages", .args = "{\"pageId\":1}", .answer = "## Console messages\nShowing 1-7 of 7 (Page 1 of 1).\nmsgid=1 [log] res 15 (2 args)\nmsgid=2 [log] y 15 (2 args)\nmsgid=3 [log] a 11 (2 args)\nmsgid=4 [log] b 22 (2 args)\nmsgid=5 [log] t 8 (2 args)\nmsgid=6 [log] t 10 (2 args)\nmsgid=7 [log] z 18 (2 args)" },
    .{
        .tool = "set_logpoints",
        .args = "{\"pageId\":1,\"logpoints\":[\"same-url.js:1 'unmapped-same-url'\"]}",
        .answer = "1 logpoint(s) set on the page:\n- {fixture}/lp-sm/same-url.js:1 logging `'unmapped-same-url'` [bound via source map at {fixture}/lp-sm/same-url.js:1:1]\n" ++ source_mapped_note ++ "\n" ++ logged,
    },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[]}", .answer = "No logpoints are set on the page." },
};

fn run(steps: []const Step) !void {
    var site: Site = undefined;
    try site.start();
    defer site.stop();
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();
    const origin = try std.fmt.allocPrint(a, "http://127.0.0.1:{d}", .{site.listener.port()});
    for (steps, 1..) |step, call| {
        const args = try std.mem.replaceOwned(u8, a, step.args, "{fixture}", origin);
        const expected = try std.mem.replaceOwned(u8, a, step.answer, "{fixture}", origin);
        const r = h.tool(step.tool, args) catch |err| {
            std.debug.print("call {d} ({s}) failed: {t}\n", .{ call, step.tool, err });
            return err;
        };
        testing.expectEqualStrings(expected, r.text) catch |err| {
            std.debug.print("call {d} ({s})\n", .{ call, step.tool });
            return err;
        };
        try testing.expectEqual(step.is_error, r.is_error);
    }
}

test "set_logpoints: script URLs and an inline script, as Chrome 157's server answers" {
    try run(&chrome_157);
}

test "set_logpoints: an ambiguous suffix, the same-file-name hint, a document with no script, a navigation; no pause" {
    try run(&chrome_157_lookups);
}

test "set_logpoints: external source maps, generated-to-original normalization, unmapped lines, reload" {
    try run(&chrome_157_source_maps);
}

test "set_logpoints: inline data:, same-url, indexed XSSI, shared multi-bundle, and 404 maps" {
    try run(&chrome_157_source_maps_variants);
}

test "set_logpoints: rebuilt bundle across reload re-resolves source-mapped logpoint" {
    var site: Site = undefined;
    try site.start();
    defer site.stop();
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();
    const origin = try std.fmt.allocPrint(a, "http://127.0.0.1:{d}", .{site.listener.port()});

    const nav_args = try std.fmt.allocPrint(a, "{{\"pageId\":1,\"url\":\"{s}/lp-sm/rebuild.html\"}}", .{origin});
    _ = try h.tool("navigate_page", nav_args);
    const set_r1 = try h.tool("set_logpoints", "{\"pageId\":1,\"logpoints\":[\"src/rebuild.ts:3 'out', out\"]}");
    const exp_r1 = try std.fmt.allocPrint(
        a,
        "1 logpoint(s) set on the page:\n- {s}/lp-sm/src/rebuild.ts:3:3 logging `'out', out` [bound via source map at {s}/lp-sm/rebuild.js:1:44]\n" ++ source_mapped_note ++ "\n" ++ logged,
        .{ origin, origin },
    );
    try testing.expectEqualStrings(exp_r1, set_r1.text);
    _ = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => window.rebuilt(5)\"}");
    const msg1 = try h.tool("list_console_messages", "{\"pageId\":1}");
    try testing.expectEqualStrings("## Console messages\nShowing 1-1 of 1 (Page 1 of 1).\nmsgid=1 [log] out 6 (2 args)", msg1.text);

    // Swap the served bundle and source map to v2 (shifted down 2 lines, +1 column) and reload.
    site.rebuild_version.store(2, .release);
    _ = try h.tool("navigate_page", "{\"pageId\":1,\"type\":\"reload\"}");
    _ = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => window.rebuilt(5)\"}");
    const msg2 = try h.tool("list_console_messages", "{\"pageId\":1}");
    try testing.expectEqualStrings("## Console messages\nShowing 1-1 of 1 (Page 1 of 1).\nmsgid=2 [log] out 15 (2 args)", msg2.text);

    const set_r2 = try h.tool("set_logpoints", "{\"pageId\":1,\"logpoints\":[\"src/rebuild.ts:3 'out', out\"]}");
    const exp_r2 = try std.fmt.allocPrint(
        a,
        "1 logpoint(s) set on the page:\n- {s}/lp-sm/src/rebuild.ts:3:3 logging `'out', out` [bound via source map at {s}/lp-sm/rebuild.js:3:45]\n" ++ source_mapped_note ++ "\n" ++ logged,
        .{ origin, origin },
    );
    try testing.expectEqualStrings(exp_r2, set_r2.text);
}

test "set_logpoints: slow source map times out with Chrome's messages, continues in background, and succeeds on retry" {
    var site: Site = undefined;
    try site.start();
    defer site.stop();
    site.release_slow.store(false, .release);

    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();
    const origin = try std.fmt.allocPrint(a, "http://127.0.0.1:{d}", .{site.listener.port()});

    const nav_args = try std.fmt.allocPrint(a, "{{\"pageId\":1,\"url\":\"{s}/lp-sm/slow.html\"}}", .{origin});
    _ = try h.tool("navigate_page", nav_args);
    // Keep the wait short so test-verify runs fast; the message still reports Chrome's 5-second wording.
    h.mcp_server.session.pages.items[0].logpoints.source_map_timeout_ms = 80;

    // 1. Served script whose source map is still loading: refuses with Chrome's message.
    const r_served = try h.tool("set_logpoints", "{\"pageId\":1,\"logpoints\":[\"slow.js:1 'x'\"]}");
    try testing.expect(r_served.is_error);
    const exp_served = try std.fmt.allocPrint(a, "Error: The source map of {s}/lp-sm/slow.js was still loading after 5 seconds; retry.", .{origin});
    try testing.expectEqualStrings(exp_served, r_served.text);

    // 2. Original source while map is still loading: reports timeout note.
    const r_orig = try h.tool("set_logpoints", "{\"pageId\":1,\"logpoints\":[\"src/slow.ts:3 'out', out\"]}");
    try testing.expect(r_orig.is_error);
    try testing.expectEqualStrings(
        "Error: No parsed script or original source file matches \"src/slow.ts\". The url must match the URL of a script as served to the browser or an original source file from a source map, exactly or as a path suffix. Some source maps were still loading after 5 seconds; retry if the file comes from a source map.",
        r_orig.text,
    );

    // 3. Release the held source map; background load finishes and retry succeeds.
    h.mcp_server.session.pages.items[0].logpoints.source_map_timeout_ms = 5_000;
    site.release_slow.store(true, .release);
    const r_retry = try h.tool("set_logpoints", "{\"pageId\":1,\"logpoints\":[\"src/slow.ts:3 'out', out\"]}");
    try testing.expect(!r_retry.is_error);
    const exp_retry = try std.fmt.allocPrint(
        a,
        "1 logpoint(s) set on the page:\n- {s}/lp-sm/src/slow.ts:3:3 logging `'out', out` [bound via source map at {s}/lp-sm/slow.js:1:43]\n" ++ source_mapped_note ++ "\n" ++ logged,
        .{ origin, origin },
    );
    try testing.expectEqualStrings(exp_retry, r_retry.text);
}

/// tools/mcp_diff case "logpoints: minified variable names".
const chrome_157_minified = [_]Step{
    .{ .tool = "navigate_page", .args = "{\"pageId\":1,\"url\":\"{fixture}/lp-min/page.html\"}", .answer = "Successfully navigated to {fixture}/lp-min/page.html.\n## Pages\n1: Minified logpoints ({fixture}/lp-min/page.html) [selected]" },
    .{
        .tool = "set_logpoints",
        .args = "{\"pageId\":1,\"logpoints\":[\"src/cart.ts:3 'amt', finalAmount, cartTotal, discount, JSON.stringify({finalAmount, cartTotal: cartTotal + 1}), `t=${finalAmount}`, [1].map(finalAmount => finalAmount + discount)[0]\",\"src/closure.ts:6 'closure', outerBase, factor, step, result\",\"src/syntax.ts:10 'caught', total, price, item.price, err.message\",\"src/nonames.ts:3 'tax', tax, subtotal\"]}",
        .answer = "4 logpoint(s) set on the page:\n" ++
            "- {fixture}/lp-min/src/cart.ts:3:3 logging `'amt', finalAmount, cartTotal, discount, JSON.stringify({finalAmount, cartTotal: cartTotal + 1}), `t=${finalAmount}`, [1].map(finalAmount => finalAmount + discount)[0]` [bound via source map at {fixture}/lp-min/min.js:1:36]\n" ++
            "- {fixture}/lp-min/src/closure.ts:6:5 logging `'closure', outerBase, factor, step, result` [bound via source map at {fixture}/lp-min/closure.js:1:77]\n" ++
            "- {fixture}/lp-min/src/syntax.ts:10:5 logging `'caught', total, price, item.price, err.message` [bound via source map at {fixture}/lp-min/syntax.js:1:116]\n" ++
            "- {fixture}/lp-min/src/nonames.ts:3:3 logging `'tax', tax, subtotal` [bound via source map at {fixture}/lp-min/nonames.js:1:33]\n" ++
            source_mapped_note ++ "\n" ++ logged,
    },
    .{ .tool = "evaluate_script", .args = "{\"pageId\":1,\"function\":\"() => [window.minCheckout(100, 15), window.minClosure(100)(7), window.minSyntax({price: 10, label: 'hat'}), window.minNoNames(25)]\"}", .answer = "Script ran on page and returned:\n```json\n[85,114,\"20:hat\",50]\n```" },
    .{
        .tool = "list_console_messages",
        .args = "{\"pageId\":1}",
        .answer = "## Console messages\nShowing 1-4 of 4 (Page 1 of 1).\n" ++
            "msgid=1 [log] amt 85 100 15 {\"finalAmount\":85,\"cartTotal\":101} t=85 16 (7 args)\n" ++
            "msgid=2 [log] closure 100 14 7 114 (5 args)\n" ++
            "msgid=3 [log] caught 20 10 10 hat (5 args)\n" ++
            "msgid=4 [log] tax 50 25 (3 args)",
    },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[]}", .answer = "No logpoints are set on the page." },
};

test "set_logpoints: minified variable names via scope analysis, closures, destructuring, and findEntryRanges" {
    try run(&chrome_157_minified);
}
