//! Lane media1: HTML media element resource selection, pause-on-remove,
//! candidate source removal/moving, MediaSource.isTypeSupported / error
//! sequence, and HTMLTrackElement same-URL src mutation — tests first.
//!
//! Each test runs on a thread of its own: a Browser's agent belongs to the
//! thread that made it (tests/html is one executable).
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");

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

test "media1: inserting a media element into a document does not invoke resource selection" {
    try runSteps(&.{
        \\const v = document.createElement('video');
        \\const a = document.createElement('audio');
        \\document.body.appendChild(v);
        \\document.body.appendChild(a);
        \\if (v.networkState !== v.NETWORK_EMPTY) globalThis.failed = 'video networkState after append: ' + v.networkState;
        \\if (a.networkState !== a.NETWORK_EMPTY) globalThis.failed = 'audio networkState after append: ' + a.networkState;
        \\const frag = document.createDocumentFragment();
        \\const v2 = document.createElement('video');
        \\frag.appendChild(v2);
        \\if (v2.networkState !== v2.NETWORK_EMPTY) globalThis.failed = 'fragment networkState: ' + v2.networkState;
        \\document.body.appendChild(frag);
        \\if (v2.networkState !== v2.NETWORK_EMPTY) globalThis.failed = 'fragment inserted networkState: ' + v2.networkState;
        \\const div = document.createElement('div');
        \\const v3 = document.createElement('video');
        \\div.appendChild(v3);
        \\document.body.appendChild(div);
        \\if (v3.networkState !== v3.NETWORK_EMPTY) globalThis.failed = 'parent inserted networkState: ' + v3.networkState;
        ,
    });
}

test "media1: setAttributeNS with non-null namespace does not trigger load or count as src" {
    try runSteps(&.{
        \\globalThis.v = document.createElement('video');
        \\globalThis.loadstarts = 0;
        \\v.onloadstart = () => { globalThis.loadstarts++; };
        \\document.body.appendChild(v);
        \\v.setAttributeNS('bogus', 'src', '');
        \\v.load();
        ,
        \\if (globalThis.loadstarts !== 0) globalThis.failed = 'loadstart fired for namespaced src: ' + globalThis.loadstarts;
        \\if (v.networkState !== v.NETWORK_EMPTY) globalThis.failed = 'networkState: ' + v.networkState;
        ,
    });
}

test "media1: removing a playing media element pauses at stable state without invoking resource selection" {
    try runSteps(&.{
        \\globalThis.v = document.createElement('video');
        \\document.body.appendChild(v);
        \\globalThis.events = [];
        \\globalThis.rejected = null;
        \\v.onpause = () => globalThis.events.push('pause');
        \\v.ontimeupdate = () => globalThis.events.push('timeupdate');
        \\globalThis.p = v.play().catch(e => { globalThis.rejected = e.name; });
        ,
        \\if (v.networkState !== v.NETWORK_EMPTY) globalThis.failed = 'networkState before remove: ' + v.networkState;
        \\if (v.paused) globalThis.failed = 'should not be paused before remove';
        \\v.parentNode.removeChild(v);
        \\if (v.paused) globalThis.failed = 'should not be paused synchronously after remove';
        \\if (v.networkState !== v.NETWORK_EMPTY) globalThis.failed = 'networkState after remove: ' + v.networkState;
        ,
        \\if (!v.paused) globalThis.failed = 'should be paused after stable state';
        \\if (v.networkState !== v.NETWORK_EMPTY) globalThis.failed = 'networkState after stable state: ' + v.networkState;
        \\if (globalThis.rejected !== 'AbortError') globalThis.failed = 'play promise rejection: ' + globalThis.rejected;
        \\if (globalThis.events.join(',') !== 'timeupdate,pause') globalThis.failed = 'events: ' + globalThis.events.join(',');
        ,
    });
}

test "media1: moving a media element within the document does not cancel its load or pause it" {
    try runSteps(&.{
        \\globalThis.v = document.createElement('video');
        \\document.body.appendChild(v);
        \\globalThis.errorCount = 0;
        \\v.src = 'data:,';
        \\document.body.appendChild(v); // move within document must not cancel load
        \\v.onerror = () => {
        \\  globalThis.errorCount++;
        \\  if (globalThis.errorCount === 1) document.body.removeChild(v);
        \\};
        ,
        \\if (globalThis.errorCount !== 1) globalThis.failed = 'errorCount: ' + globalThis.errorCount;
        ,
    });
}

test "media1: removing or moving the active candidate source suppresses its error event" {
    try runSteps(&.{
        \\globalThis.v = document.createElement('video');
        \\globalThis.s1 = document.createElement('source');
        \\globalThis.s2 = document.createElement('source');
        \\s1.src = 'data:,';
        \\s2.src = 'data:,';
        \\globalThis.s1Errors = 0;
        \\globalThis.s2Errors = 0;
        \\s1.addEventListener('error', () => { globalThis.s1Errors++; });
        \\s2.addEventListener('error', () => { globalThis.s2Errors++; });
        \\v.appendChild(s1);
        \\v.appendChild(s2);
        \\// Wait until s1 is selected (loadstart fires right as s1 fetch starts), then remove s1.
        \\v.addEventListener('loadstart', () => {
        \\  if (s1.parentNode === v) v.removeChild(s1);
        \\});
        ,
        \\if (globalThis.s1Errors !== 0) globalThis.failed = 'error fired on removed candidate: ' + globalThis.s1Errors;
        \\if (globalThis.s2Errors !== 1) globalThis.failed = 'second source should fail: ' + globalThis.s2Errors;
        ,
    });
}

test "media1: moveBefore of a source within a waiting media element reconsiders it" {
    try runSteps(&.{
        \\globalThis.v = document.createElement('video');
        \\globalThis.a = document.createElement('source');
        \\globalThis.b = document.createElement('source');
        \\v.appendChild(a);
        \\v.appendChild(b);
        \\document.body.appendChild(v);
        ,
        \\if (v.networkState !== v.NETWORK_NO_SOURCE) globalThis.failed = 'networkState before move: ' + v.networkState;
        \\globalThis.aErrors = 0;
        \\a.onerror = () => { globalThis.aErrors++; };
        \\v.moveBefore(a, null);
        ,
        \\if (globalThis.aErrors !== 1) globalThis.failed = 'aErrors after moveBefore: ' + globalThis.aErrors;
        \\if (v.networkState !== v.NETWORK_NO_SOURCE) globalThis.failed = 'networkState after move: ' + v.networkState;
        ,
    });
}

test "media1: MediaSource.isTypeSupported returns false and empty src sets error before volumechange" {
    try runSteps(&.{
        \\if (MediaSource.isTypeSupported('video/mp4; codecs="avc1.42E01E"') !== false) {
        \\  globalThis.failed = 'isTypeSupported should return false';
        \\}
        \\globalThis.audio = document.createElement('audio');
        \\document.body.appendChild(audio);
        \\globalThis.events = [];
        \\globalThis.errorAtVolumeChange = undefined;
        \\audio.src = '';
        \\if (audio.error !== null) globalThis.failed = 'initial error should be null';
        \\audio.volume = 0;
        \\audio.onvolumechange = () => {
        \\  globalThis.events.push('volumechange');
        \\  if (globalThis.events.length === 1) {
        \\    globalThis.errorAtVolumeChange = audio.error ? audio.error.code : null;
        \\    audio.volume = 1;
        \\  }
        \\};
        \\audio.onloadstart = () => globalThis.events.push('loadstart');
        \\audio.onerror = () => globalThis.events.push('error');
        ,
        \\if (globalThis.errorAtVolumeChange !== MediaError.MEDIA_ERR_SRC_NOT_SUPPORTED) {
        \\  globalThis.failed = 'errorAtVolumeChange: ' + globalThis.errorAtVolumeChange;
        \\}
        \\if (globalThis.events.join(',') !== 'volumechange,loadstart,error,volumechange') {
        \\  globalThis.failed = 'events: ' + globalThis.events.join(',');
        \\}
        ,
    });
}

test "media1: setting track.src to the same URL keeps cues; changing it clears cues immediately" {
    try runSteps(&.{
        \\globalThis.v = document.createElement('video');
        \\globalThis.trackEl = document.createElement('track');
        \\trackEl.default = true;
        \\const vtt = 'data:text/vtt,WEBVTT%0A%0A00:00:00.000%20--%3E%2000:00:01.000%0Ahi';
        \\trackEl.src = vtt;
        \\v.appendChild(trackEl);
        \\document.body.appendChild(v);
        \\globalThis.loads = 0;
        \\trackEl.onload = () => { globalThis.loads++; };
        ,
        \\if (globalThis.loads !== 1) globalThis.failed = 'initial load count: ' + globalThis.loads;
        \\if (trackEl.track.cues.length !== 1) globalThis.failed = 'initial cue count: ' + trackEl.track.cues.length;
        \\// Setting src to the same URL must keep cues and not fire load again.
        \\trackEl.src = trackEl.getAttribute('src');
        \\if (trackEl.track.cues.length !== 1) globalThis.failed = 'cues after same-URL set: ' + trackEl.track.cues.length;
        ,
        \\if (globalThis.loads !== 1) globalThis.failed = 'load count after same-URL set: ' + globalThis.loads;
        \\if (trackEl.track.cues.length !== 1) globalThis.failed = 'cues after same-URL settle: ' + trackEl.track.cues.length;
        \\// Setting src to a different URL immediately empties cues.
        \\trackEl.src = 'data:text/vtt,WEBVTT%0A%0A00:00:00.000%20--%3E%2000:00:02.000%0Abye';
        \\if (trackEl.track.cues.length !== 0) globalThis.failed = 'cues after different-URL set: ' + trackEl.track.cues.length;
        ,
        \\if (globalThis.loads !== 2) globalThis.failed = 'load count after second URL: ' + globalThis.loads;
        \\if (trackEl.track.cues.length !== 1 || trackEl.track.cues[0].text !== 'bye') {
        \\  globalThis.failed = 'second cue text: ' + (trackEl.track.cues[0] && trackEl.track.cues[0].text);
        \\}
        ,
    });
}
