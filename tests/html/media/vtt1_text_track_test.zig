//! Lane vtt1: text tracks and their cues (HTML 4.8.11.11, WebVTT 9), in a
//! Browser, tests first.
//!
//! - A track's mode change reaches its media element's pending text track
//!   change notification whoever made the track: video.addTextTrack() then
//!   mode = 'showing' fired no `change` at video.textTracks
//!   (track-change-event.html blocked, no media needed).
//! - TextTrack.addCue/removeCue, the text track list of cues in text track
//!   cue order, TextTrackCue.track, VTTCue's members and getCueAsHTML were
//!   not implemented (NotImplemented; webvtt/api, interfaces/TextTrack*).
//! - A <track>'s parsed cues never reached its text track's list of cues
//!   (TODO(webvtt cues): webvtt/parsing and track-webvtt-* blocked).
//! - A cue the list holds, and the track a cue is in, outlive every script
//!   reference to them (the list's and the cue's edges).
//!
//! Each test runs on a thread of its own: a Browser's agent belongs to the
//! thread that made it (tests/html is one executable).
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");

/// Load an empty page, run each of `steps` (letting tasks run between
/// them), and fail with `globalThis.failed` when a step set it.
fn runSteps(steps: []const []const u8) !void {
    const Run = struct {
        steps: []const []const u8,
        failure: ?anyerror = null,

        fn thread(self: *@This()) void {
            self.body() catch |err| {
                self.failure = err;
            };
        }

        fn body(self: *@This()) !void {
            var browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
            defer browser.deinit();
            try browser.navigate("about:blank", .window);
            const page = browser.current_context orelse return error.TestUnexpectedResult;
            try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://example.test/" });
            for (self.steps) |step| {
                page.runScript(step) catch |err| {
                    std.debug.print("step threw: {s}\n", .{step});
                    return err;
                };
                var waits: usize = 0;
                while (true) : (waits += 1) {
                    _ = try browser.runEventLoopBlocking(20);
                    const pending = try page.evaluateScriptToString("String(globalThis.pending === true)", testing.allocator);
                    defer testing.allocator.free(pending);
                    if (!std.mem.eql(u8, pending, "true")) break;
                    if (waits == 250) {
                        std.debug.print("step never settled: {s}\n", .{step});
                        return error.TestUnexpectedResult;
                    }
                }
                const failed = try page.evaluateScriptToString("String(globalThis.failed || '')", testing.allocator);
                defer testing.allocator.free(failed);
                if (failed.len != 0) {
                    std.debug.print("check failed: {s}\n", .{failed});
                    return error.TestUnexpectedResult;
                }
            }
        }
    };
    var run: Run = .{ .steps = steps };
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "vtt1: a mode change of an addTextTrack() track fires change at textTracks, once per task" {
    try runSteps(&.{
        \\globalThis.video = document.createElement('video');
        \\globalThis.track = video.addTextTrack('subtitles', 'test', 'en');
        \\globalThis.changes = [];
        \\video.textTracks.onchange = (event) => changes.push(event.target === video.textTracks && !('track' in event));
        \\track.mode = 'showing';
        \\track.mode = 'disabled';
        \\if (changes.length !== 0) globalThis.failed = 'change fired synchronously';
        ,
        \\if (changes.length !== 1 || !changes[0]) globalThis.failed = 'changes after the task: ' + JSON.stringify(changes);
        ,
    });
}

test "vtt1: addCue keeps the text track list of cues in text track cue order" {
    try runSteps(&.{
        \\const video = document.createElement('video');
        \\const track = video.addTextTrack('subtitles');
        \\const cues = track.cues;
        \\const make = (start, end, id) => { const cue = new VTTCue(start, end, id); cue.id = id; track.addCue(cue); return cue; };
        \\const c = make(2, 3, 'c'), a = make(0, 1, 'a'), b2 = make(1, 2, 'b2'), b1 = make(1, 5, 'b1'), b3 = make(1, 2, 'b3');
        \\const order = () => Array.from({ length: cues.length }, (_, i) => cues[i].id).join(',');
        \\const checks = [];
        \\checks.push([order(), 'a,b1,b2,b3,c']);
        \\checks.push([String(a.track === track && cues === track.cues && cues instanceof TextTrackCueList), 'true']);
        \\checks.push([String(cues.getCueById('b2') === b2 && cues.getCueById('') === null && cues.getCueById('x') === null), 'true']);
        \\// A cue added again is the newest of its times; a moved start re-sorts.
        \\track.addCue(b2);
        \\checks.push([order(), 'a,b1,b3,b2,c']);
        \\c.startTime = -1;
        \\checks.push([order(), 'c,a,b1,b3,b2']);
        \\track.removeCue(a);
        \\checks.push([String(a.track) + ',' + order(), 'null,c,b1,b3,b2']);
        \\let threw = '';
        \\try { track.removeCue(a); } catch (e) { threw = e.name; }
        \\checks.push([threw, 'NotFoundError']);
        \\// A cue in another track's list leaves it.
        \\const other = video.addTextTrack('captions');
        \\other.addCue(c);
        \\checks.push([String(c.track === other) + ',' + order() + ',' + other.cues.length, 'true,b1,b3,b2,1']);
        \\track.mode = 'disabled';
        \\checks.push([String(track.cues) + ',' + String(track.activeCues) + ',' + cues.length, 'null,null,3']);
        \\track.mode = 'hidden';
        \\checks.push([String(track.cues === cues && track.activeCues.length === 0), 'true']);
        \\const bad = checks.filter(([got, want]) => got !== want);
        \\if (bad.length) globalThis.failed = JSON.stringify(bad);
        ,
    });
}

test "vtt1: VTTCue's members, defaults and setters (WebVTT 9.1)" {
    try runSteps(&.{
        \\const checks = [];
        \\const cue = new VTTCue(3, Infinity, 'foo');
        \\checks.push([[cue.startTime, cue.endTime, cue.text, cue.id, cue.region, cue.pauseOnExit, cue.vertical, cue.snapToLines, cue.line, cue.lineAlign, cue.position, cue.positionAlign, cue.size, cue.align, cue.track].map(String).join('|'),
        \\  '3|Infinity|foo||null|false||true|auto|start|auto|auto|100|center|null']);
        \\let threw = '';
        \\try { new VTTCue(0, NaN, ''); } catch (e) { threw += e.name; }
        \\try { new VTTCue(0, -Infinity, ''); } catch (e) { threw += ',' + e.name; }
        \\try { cue.endTime = NaN; } catch (e) { threw += ',' + e.name; }
        \\try { cue.position = 101; } catch (e) { threw += ',' + e.name; }
        \\try { cue.size = -1; } catch (e) { threw += ',' + e.name; }
        \\checks.push([threw, 'TypeError,TypeError,TypeError,IndexSizeError,IndexSizeError']);
        \\cue.line = -2; cue.position = 50; cue.positionAlign = 'line-left'; cue.vertical = 'rl'; cue.align = 'end'; cue.lineAlign = 'center'; cue.size = 10;
        \\cue.vertical = 'bogus';
        \\checks.push([[cue.line, cue.position, cue.positionAlign, cue.vertical, cue.align, cue.lineAlign, cue.size].join('|'), '-2|50|line-left|rl|end|center|10']);
        \\const region = new VTTRegion();
        \\checks.push([[region.id, region.width, region.lines, region.regionAnchorX, region.regionAnchorY, region.viewportAnchorX, region.viewportAnchorY, region.scroll].join('|'), '|100|3|0|100|0|100|']);
        \\region.id = 'r'; region.lines = 7; region.scroll = 'up'; region.width = 50;
        \\try { region.width = 101; } catch (e) { threw = e.name; }
        \\cue.region = region;
        \\checks.push([[cue.region === region, region.id, region.lines, region.scroll, region.width, threw].join('|'), 'true|r|7|up|50|IndexSizeError']);
        \\const bad = checks.filter(([got, want]) => got !== want);
        \\if (bad.length) globalThis.failed = JSON.stringify(bad);
        ,
    });
}

test "vtt1: getCueAsHTML applies the WebVTT cue text DOM construction rules" {
    try runSteps(&.{
        \\const cue = new VTTCue(0, 1, '<c.a.b>x</c><v Foo&amp;Bar>t</v><1:00:13.500><lang en-US>y</lang><ruby>r<rt>s</rt></ruby>&lt;');
        \\const frag = cue.getCueAsHTML();
        \\const describe = (node) => node.nodeType === Node.TEXT_NODE ? JSON.stringify(node.data)
        \\  : node.nodeType === Node.PROCESSING_INSTRUCTION_NODE ? '<?' + node.target + ' ' + node.data + '>'
        \\  : '<' + node.localName + Array.from(node.attributes, (a) => ' ' + a.name + '=' + a.value).join('') + '>' + Array.from(node.childNodes, describe).join('') + '</>';
        \\const got = Array.from(frag.childNodes, describe).join('');
        \\const want = '<span class=a b>"x"</><span title=Foo&Bar>"t"</><?timestamp 01:00:13.500><span lang=en-US>"y"</><ruby>"r"<rt>"s"</></>"<"';
        \\if (!(frag instanceof DocumentFragment) || frag.ownerDocument !== document || frag.firstChild.namespaceURI !== 'http://www.w3.org/1999/xhtml' || got !== want)
        \\  globalThis.failed = got;
        \\// Empty cue text: one empty Text node, as Chrome, Firefox and Safari answer.
        \\const empty = new VTTCue(0, 0, '').getCueAsHTML();
        \\if (empty.childNodes.length !== 1 || !(empty.firstChild instanceof Text) || empty.firstChild.data !== '')
        \\  globalThis.failed = 'empty cue text: ' + empty.childNodes.length + ' children';
        ,
    });
}

test "vtt1: a track element's parsed cues and regions reach its text track's list of cues" {
    try runSteps(&.{
        \\globalThis.pending = true;
        \\const video = document.createElement('video');
        \\const element = document.createElement('track');
        \\const vtt = 'WEBVTT\n\nREGION\nid:fred width:40% lines:5 scroll:up\n\none\n00:00:01.000 --> 00:00:02.000 region:fred align:start\nHello <b>there</b>\n\n00:00:00.500 --> 00:00:03.000 line:10% position:20%,line-right size:30% vertical:lr\nsecond\n';
        \\element.src = 'data:text/vtt,' + encodeURIComponent(vtt);
        \\element.track.mode = 'hidden';
        \\element.onerror = () => { globalThis.failed = 'error event'; globalThis.pending = false; };
        \\element.onload = () => {
        \\  const cues = element.track.cues;
        \\  const first = cues[0], second = cues[1];
        \\  const got = [cues.length, second.id, second.text, second.region && second.region.id, second.region && second.region.lines, second.region && second.region.scroll, second.align,
        \\    first.id, first.text, first.line, first.snapToLines, first.position, first.positionAlign, first.size, first.vertical, first.region === null, first.track === element.track].join('|');
        \\  const want = '2|one|Hello <b>there</b>|fred|5|up|start||second|10|false|20|line-right|30|lr|true|true';
        \\  if (got !== want) globalThis.failed = got;
        \\  // Setting src empties the list at once (an empty URL then fails).
        \\  element.onerror = null;
        \\  element.src = '';
        \\  if (cues.length !== 0 || first.track !== null) globalThis.failed = 'src change kept ' + cues.length + ' cues';
        \\  globalThis.pending = false;
        \\};
        \\video.append(element);
        ,
    });
}

test "vtt1: cues outlive script's references while their list holds them, and keep their track" {
    try runSteps(&.{
        \\globalThis.video = document.createElement('video');
        \\(() => {
        \\  const track = video.addTextTrack('metadata');
        \\  for (let i = 0; i < 50; ++i) { const cue = new VTTCue(i, i + 1, 'cue ' + i); cue.id = 'id' + i; track.addCue(cue); }
        \\  globalThis.loose = new VTTCue(0, 1, 'loose');
        \\  track.addCue(loose);
        \\})();
        \\TestUtils.gc(); TestUtils.gc();
        ,
        \\TestUtils.gc(); TestUtils.gc();
        \\{
        \\  const cues = video.textTracks[0].cues;
        \\  let bad = cues.length === 51 ? '' : 'length ' + cues.length;
        \\  for (let i = 0; i < 50 && !bad; ++i) if (cues.getCueById('id' + i).text !== 'cue ' + i) bad = 'cue ' + i;
        \\  if (bad) globalThis.failed = bad;
        \\}
        \\// The cue keeps its track though nothing else in script names it.
        \\globalThis.video = null;
        ,
        \\TestUtils.gc(); TestUtils.gc();
        \\if (!loose.track || loose.track.kind !== 'metadata' || loose.track.cues.length !== 51) globalThis.failed = 'the cue lost its track';
        ,
    });
}

/// VTTCue slab slots of `browser`, and how many of them have a wrapper -
/// read from the slab, so a cue whose teardown ran but whose slot was never
/// returned still counts.
const CueCounts = struct { cues: usize = 0, wrapped: usize = 0 };
fn cueCounts(browser: *browser_mod.Browser) CueCounts {
    const runtime = @import("runtime");
    var counts: CueCounts = .{};
    var live = browser.scope.slab.iterateLive();
    while (live.next()) |instance| {
        if (!std.mem.eql(u8, instance.vtable.name, "VTTCue")) continue;
        counts.cues += 1;
        if (runtime.instance_lifecycle.wasWrapped(instance)) counts.wrapped += 1;
    }
    return counts;
}

/// A page whose steps the test interleaves with its own native checks.
const Page = struct {
    browser: *browser_mod.Browser,
    page: *@import("browser").Context,

    fn open() !Page {
        var browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.TestUnexpectedResult;
        try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://example.test/" });
        return .{ .browser = browser, .page = page };
    }

    fn close(self: *Page) void {
        self.browser.deinit();
    }

    /// Run `script`, let its tasks run until `globalThis.pending` clears,
    /// and fail with `globalThis.failed` when it set it.
    fn step(self: *Page, script: []const u8) !void {
        self.page.runScript(script) catch |err| {
            std.debug.print("step threw: {s}\n", .{script});
            return err;
        };
        var waits: usize = 0;
        while (true) : (waits += 1) {
            _ = try self.browser.runEventLoopBlocking(20);
            const pending = try self.page.evaluateScriptToString("String(globalThis.pending === true)", testing.allocator);
            defer testing.allocator.free(pending);
            if (!std.mem.eql(u8, pending, "true")) break;
            if (waits == 250) return error.TestUnexpectedResult;
        }
        const failed = try self.page.evaluateScriptToString("String(globalThis.failed || '')", testing.allocator);
        defer testing.allocator.free(failed);
        if (failed.len != 0) {
            std.debug.print("check failed: {s}\n", .{failed});
            return error.TestUnexpectedResult;
        }
    }
};

fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            body() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

/// A 1,000-cue file: a track element loads it into the page's one video.
const thousand_cues =
    \\globalThis.pending = true;
    \\globalThis.video = document.createElement('video');
    \\const element = document.createElement('track');
    \\let vtt = 'WEBVTT\n\n';
    \\for (let i = 0; i < 1000; ++i) vtt += 'c' + i + '\n00:00:' + String(i % 60).padStart(2, '0') + '.000 --> 00:01:00.000\ncue ' + i + '\n\n';
    \\element.src = 'data:text/vtt,' + encodeURIComponent(vtt);
    \\element.track.mode = 'hidden';
    \\element.onerror = () => { globalThis.failed = 'error event'; globalThis.pending = false; };
    \\element.onload = () => {
    \\  if (element.track.cues.length !== 1000) globalThis.failed = 'cues: ' + element.track.cues.length;
    \\  globalThis.pending = false;
    \\};
    \\video.append(element);
    \\document.body.append(video);
;

test "vtt1: a 1,000-cue file makes no cue wrapper until script reads a cue" {
    try onThread(struct {
        fn body() !void {
            var page = try Page.open();
            defer page.close();
            try page.step(thousand_cues);
            try page.step("TestUtils.gc(); TestUtils.gc();");
            const loaded = cueCounts(page.browser);
            try testing.expectEqual(@as(usize, 1000), loaded.cues);
            try testing.expectEqual(@as(usize, 0), loaded.wrapped);
            // One read, one wrapper; the list keeps the cue by an edge now.
            try page.step(
                \\{
                \\  const cue = video.textTracks[0].cues.getCueById('c7');
                \\  if (!cue || cue.text !== 'cue 7') globalThis.failed = 'c7: ' + (cue && cue.text);
                \\}
            );
            const read = cueCounts(page.browser);
            try testing.expectEqual(@as(usize, 1000), read.cues);
            try testing.expectEqual(@as(usize, 1), read.wrapped);
            // Setting src frees every cue the list alone owned, at once.
            try page.step("{ const t = video.querySelector('track'); t.onerror = null; t.src = ''; }");
            try page.step("TestUtils.gc(); TestUtils.gc();");
            try testing.expectEqual(@as(usize, 0), cueCounts(page.browser).cues);
        }
    }.body);
}

test "vtt1: a cue script read, removed and dropped is collected while its track lives" {
    try onThread(struct {
        fn body() !void {
            var page = try Page.open();
            defer page.close();
            try page.step(thousand_cues);
            try page.step(
                \\globalThis.track = video.textTracks[0];
                \\(() => {
                \\  const cue = track.cues[0];
                \\  track.removeCue(cue);
                \\})();
            );
            try page.step("TestUtils.gc(); TestUtils.gc();");
            try page.step("TestUtils.gc(); TestUtils.gc();");
            // The removed cue went with its wrapper; the 999 the list owns
            // stay, and so does the track.
            try testing.expectEqual(@as(usize, 999), cueCounts(page.browser).cues);
            try page.step(
                \\if (track.cues.length !== 999 || track.cues[0].id !== 'c60') globalThis.failed = track.cues.length + ' ' + track.cues[0].id;
            );
        }
    }.body);
}
