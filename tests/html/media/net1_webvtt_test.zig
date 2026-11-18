//! The WebVTT parser (WebVTT 6.1-6.3, specs/w3c/webvtt.md), tests first.
//! fetch/metadata/track.https.sub.html and the three fetch/metadata/redirect/
//! track files wait for a <track> element's load event, which needs its
//! resource ("WEBVTT", record-header.py) to be successfully processed; Crane
//! had no text track format, so every track fired error.
const std = @import("std");
const testing = std.testing;
const webvtt = @import("html").webvtt;

fn parsed(bytes: []const u8) !webvtt.Result {
    return webvtt.parse(testing.allocator, bytes);
}

test "net1 webvtt: the file signature decides whether a file is processed (6.1 steps 4-10)" {
    const cases = [_]struct { []const u8, bool }{
        .{ "WEBVTT", true },
        .{ "WEBVTT\n", true },
        .{ "WEBVTT header text\n\n", true },
        .{ "WEBVTT\theader", true },
        .{ "\xEF\xBB\xBFWEBVTT", true }, // UTF-8 decode drops the byte order mark
        .{ "WEBVTT\r\n\r\n", true },
        .{ "WEBVT", false },
        .{ "", false },
        .{ "WEBVTTX", false },
        .{ "webvtt", false },
        .{ " WEBVTT", false },
        .{ "FOO\nWEBVTT", false },
    };
    for (cases) |case| {
        var result = try parsed(case[0]);
        defer result.deinit();
        testing.expectEqual(case[1], result.processed) catch |err| {
            std.debug.print("input: {any}\n", .{case[0]});
            return err;
        };
        try testing.expectEqual(@as(usize, 0), result.cues.len);
    }
}

test "net1 webvtt: cues with identifiers, timings, settings and text" {
    var result = try parsed(
        "WEBVTT\r\n" ++
            "\r\n" ++
            "first\r\n" ++
            "00:01.000 --> 00:02.500 align:start line:10% position:30%,line-left size:50%\r\n" ++
            "Hello\r\n" ++
            "world\r\n" ++
            "\r\n" ++
            "01:00:00.250 --> 01:00:01.000 vertical:rl line:-2,end\n" ++
            "No identifier\n",
    );
    defer result.deinit();
    try testing.expect(result.processed);
    try testing.expectEqual(@as(usize, 2), result.cues.len);

    const first = result.cues[0];
    try testing.expectEqualStrings("first", first.identifier);
    try testing.expectEqual(@as(f64, 1), first.start_time);
    try testing.expectEqual(@as(f64, 2.5), first.end_time);
    try testing.expectEqual(webvtt.TextAlignment.start, first.text_alignment);
    try testing.expectEqual(webvtt.Line{ .number = 10 }, first.line);
    try testing.expect(!first.snap_to_lines);
    try testing.expectEqual(webvtt.Position{ .number = 30 }, first.position);
    try testing.expectEqual(webvtt.PositionAlignment.line_left, first.position_alignment);
    try testing.expectEqual(@as(f64, 50), first.size);
    try testing.expectEqualStrings("Hello\nworld", first.text);

    const second = result.cues[1];
    try testing.expectEqualStrings("", second.identifier);
    try testing.expectEqual(@as(f64, 3600.25), second.start_time);
    try testing.expectEqual(@as(f64, 3601), second.end_time);
    try testing.expectEqual(webvtt.WritingDirection.vertical_growing_left, second.writing_direction);
    try testing.expectEqual(webvtt.Line{ .number = -2 }, second.line);
    try testing.expect(second.snap_to_lines);
    try testing.expectEqual(webvtt.LineAlignment.end, second.line_alignment);
    try testing.expectEqualStrings("No identifier", second.text);
}

test "net1 webvtt: a cue's defaults, and settings that do not parse leave them" {
    var result = try parsed("WEBVTT\n\n00:00.000 --> 00:01.000 align:middle line:abc position:101% size:-1% vertical:xx bogus nocolon: :x\ntext");
    defer result.deinit();
    try testing.expectEqual(@as(usize, 1), result.cues.len);
    const cue = result.cues[0];
    try testing.expectEqual(webvtt.TextAlignment.center, cue.text_alignment);
    try testing.expectEqual(webvtt.Line.auto, cue.line);
    try testing.expect(cue.snap_to_lines);
    try testing.expectEqual(webvtt.LineAlignment.start, cue.line_alignment);
    try testing.expectEqual(webvtt.Position.auto, cue.position);
    try testing.expectEqual(webvtt.PositionAlignment.auto, cue.position_alignment);
    try testing.expectEqual(@as(f64, 100), cue.size);
    try testing.expectEqual(webvtt.WritingDirection.horizontal, cue.writing_direction);
    try testing.expect(!cue.pause_on_exit);
    try testing.expect(cue.region == null);
}

test "net1 webvtt: timestamps (6.3 collect a WebVTT timestamp)" {
    const good = [_]struct { []const u8, f64 }{
        .{ "00:00.000", 0 },
        .{ "59:59.999", 3599.999 },
        .{ "00:00:01.500", 1.5 },
        .{ "100:00:00.000", 360000 },
    };
    for (good) |case| {
        var position: usize = 0;
        try testing.expectEqual(@as(?f64, case[1]), webvtt.collectTimestamp(case[0], &position));
    }
    // "60" is more than 59: the most significant units are hours, and
    // "60:00.000" has no third field - an error; so is "0:00.000" (one digit).
    const bad = [_][]const u8{ "60:00.000", "0:00.000", "00:0.000", "00:00.00", "00:00", "00:60.000", "00:00:60.000", "x0:00.000", "00:00,000" };
    for (bad) |input| {
        var position: usize = 0;
        testing.expectEqual(@as(?f64, null), webvtt.collectTimestamp(input, &position)) catch |err| {
            std.debug.print("input: {s}\n", .{input});
            return err;
        };
    }
}

test "net1 webvtt: an invalid timing line makes no cue, and a timing line breaks a block" {
    var result = try parsed("WEBVTT\n\nid\n00:00.000 -> 00:01.000\ntext\n\n00:02.000 --> 00:03.000\nkept\n00:04.000 --> 00:05.000\nnext block\n");
    defer result.deinit();
    // The first block's timing line has no "-->": a block that is no cue.
    // The second block's third line holds "-->" after the cue's own arrow: it
    // starts the next block.
    try testing.expectEqual(@as(usize, 2), result.cues.len);
    try testing.expectEqualStrings("kept", result.cues[0].text);
    try testing.expectEqual(@as(f64, 4), result.cues[1].start_time);
    try testing.expectEqualStrings("next block", result.cues[1].text);
}

test "net1 webvtt: STYLE and REGION blocks before the first cue, regions referenced by cues" {
    var result = try parsed(
        "WEBVTT\n\n" ++
            "STYLE\n::cue { color: red }\n\n" ++
            "REGION\nid:fred width:40% lines:5 regionanchor:0%,100% viewportanchor:10%,90% scroll:up\n\n" ++
            "00:00.000 --> 00:01.000 region:fred\nin the region\n\n" ++
            "00:01.000 --> 00:02.000 region:fred line:0\nline drops the region\n\n" ++
            "STYLE\nafter a cue: a cue identifier... no, text\n",
    );
    defer result.deinit();
    try testing.expectEqual(@as(usize, 1), result.stylesheets.len);
    try testing.expectEqualStrings("::cue { color: red }", result.stylesheets[0]);
    try testing.expectEqual(@as(usize, 1), result.regions.len);
    const region = result.regions[0];
    try testing.expectEqualStrings("fred", region.identifier);
    try testing.expectEqual(@as(f64, 40), region.width);
    try testing.expectEqual(@as(u32, 5), region.lines);
    try testing.expectEqual([2]f64{ 0, 100 }, region.anchor);
    try testing.expectEqual([2]f64{ 10, 90 }, region.viewport_anchor);
    try testing.expectEqual(webvtt.Scroll.up, region.scroll);
    try testing.expectEqual(@as(usize, 2), result.cues.len);
    try testing.expectEqual(@as(?usize, 0), result.cues[0].region);
    try testing.expect(result.cues[1].region == null);
}

test "net1 webvtt: NUL becomes U+FFFD and CR becomes LF (6.1 step 1)" {
    var result = try parsed("WEBVTT\r\r00:00.000 --> 00:01.000\ra\x00b\r");
    defer result.deinit();
    try testing.expectEqual(@as(usize, 1), result.cues.len);
    try testing.expectEqualStrings("a\u{FFFD}b", result.cues[0].text);
}

test "net1 webvtt: percentages (6.2 parse a percentage string)" {
    try testing.expectEqual(@as(?f64, 50), webvtt.parsePercentage("50%"));
    try testing.expectEqual(@as(?f64, 12.5), webvtt.parsePercentage("12.5%"));
    try testing.expectEqual(@as(?f64, 100), webvtt.parsePercentage("100%"));
    const bad = [_][]const u8{ "100.1%", "50", "%", ".5%", "5.%", "-1%", "1e2%", "50%%", "" };
    for (bad) |input| try testing.expectEqual(@as(?f64, null), webvtt.parsePercentage(input));
}

test "net1 webvtt: allocation failure frees what was made" {
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn run(allocator: std.mem.Allocator) !void {
            var result = try webvtt.parse(allocator, "WEBVTT\n\nREGION\nid:r\n\nc\n00:00.000 --> 00:01.000 region:r\nt\n\n");
            result.deinit();
        }
    }.run, .{});
}
