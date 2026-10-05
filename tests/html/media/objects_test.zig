//! HTML 4.8.11: owner hooks and the values exposed by media helper objects.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;
const hooks = dom.media_elements;

fn start() void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
}

test "MediaError creation preserves every defined code and an empty message" {
    start();
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    for ([_]hooks.ErrorCode{ .aborted, .network, .decode, .source_not_supported }, 1..) |code, value| {
        const object = try hooks.createError(&ctx, code);
        defer interfaces.MediaError.deinit(object);
        try testing.expectEqual(@as(u16, @intCast(value)), try interfaces.MediaError.get_code(object));
        var message = try interfaces.MediaError.get_message(object);
        defer message.deinit(testing.allocator);
        try testing.expectEqualStrings("", message.asSlice());
    }
}

test "empty TimeRanges reject every start and end index" {
    start();
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const ranges = try interfaces.TimeRanges.init(testing.allocator, &ctx);
    defer interfaces.TimeRanges.deinit(ranges);
    try testing.expectEqual(@as(u32, 0), try interfaces.TimeRanges.get_length(ranges));
    for ([_]u32{ 0, 1, std.math.maxInt(u32) }) |index| {
        try testing.expectError(error.IndexSizeError, interfaces.TimeRanges.call_start(ranges, index));
        try testing.expectError(error.IndexSizeError, interfaces.TimeRanges.call_end(ranges, index));
    }
}

test "TextTrack creation and updates own the attribute strings and one readiness state" {
    start();
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    var text = [_]u8{ 'e', 'n' };
    const track = try hooks.createTrackElementTrack(&ctx, .captions, runtime.DOMString.initInterned(&text), runtime.DOMString.initInterned("en"), runtime.DOMString.initInterned("captions"));
    defer interfaces.TextTrack.deinit(track);
    text[0] = 'x';
    try testing.expect((try interfaces.TextTrack.get_kind(track)) == ._captions_);
    try testing.expect((try interfaces.TextTrack.get_mode(track)) == ._disabled_);
    try testing.expectEqual(hooks.Readiness.not_loaded, hooks.trackReadiness(track));
    var label = try interfaces.TextTrack.get_label(track);
    defer label.deinit(testing.allocator);
    try testing.expectEqualStrings("en", label.asSlice());
    try hooks.updateTrackAttributes(track, .metadata, runtime.DOMString.initInterned("new"), runtime.DOMString.initInterned("fr"), runtime.DOMString.initInterned("id"));
    var language = try interfaces.TextTrack.get_language(track);
    defer language.deinit(testing.allocator);
    var id = try interfaces.TextTrack.get_id(track);
    defer id.deinit(testing.allocator);
    try testing.expectEqualStrings("fr", language.asSlice());
    try testing.expectEqualStrings("id", id.asSlice());
    try testing.expect((try interfaces.TextTrack.get_kind(track)) == ._metadata_);
    for ([_]hooks.Readiness{ .loading, .loaded, .failed, .not_loaded }) |readiness| {
        hooks.setTrackReadiness(track, readiness);
        try testing.expectEqual(readiness, hooks.trackReadiness(track));
    }
}

test "a severed track changes mode without reading its former element" {
    start();
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const track = try hooks.createTrackElementTrack(&ctx, .subtitles, .initEmpty(), .initEmpty(), .initEmpty());
    defer interfaces.TextTrack.deinit(track);
    const element = try interfaces.HTMLTrackElement.init(testing.allocator, &ctx);
    hooks.linkTrackElement(track, element);
    hooks.trackElementDestroyed(track);
    interfaces.HTMLTrackElement.deinit(element);
    try interfaces.TextTrack.set_mode(track, ._hidden_);
    try testing.expect((try interfaces.TextTrack.get_mode(track)) == ._hidden_);
    try testing.expectEqual(hooks.Readiness.not_loaded, hooks.trackReadiness(track));
}

test "source URL is absent for missing empty and invalid attributes" {
    start();
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const source = try interfaces.HTMLSourceElement.init(testing.allocator, &ctx);
    defer interfaces.HTMLSourceElement.deinit(source);
    try dom.node_creation.setElementNames(source, "http://www.w3.org/1999/xhtml", "source");
    try testing.expect(hooks.sourceURL(source) == null);
    try interfaces.HTMLSourceElement.set_src(source, "");
    try testing.expect(hooks.sourceURL(source) == null);
    try interfaces.HTMLSourceElement.set_src(source, "http://[");
    try testing.expect(hooks.sourceURL(source) == null);
    try interfaces.HTMLSourceElement.set_src(source, "https://example.test/media");
    try testing.expectEqualStrings("https://example.test/media", hooks.sourceURL(source).?);
    try interfaces.Element.call_removeAttribute(source, .initInterned("src"));
    try testing.expect(hooks.sourceURL(source) == null);
}

test "source URL retains its last-change document base until src changes again" {
    start();
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const old_document = try interfaces.Document.init(testing.allocator, &ctx);
    defer interfaces.Document.deinit(old_document);
    const new_document = try interfaces.Document.init(testing.allocator, &ctx);
    defer interfaces.Document.deinit(new_document);
    dom.document_lifecycle.setAboutBaseUrl(old_document, "https://old.test/path/");
    dom.document_lifecycle.setAboutBaseUrl(new_document, "https://new.test/elsewhere/");
    const source = try interfaces.HTMLSourceElement.init(testing.allocator, &ctx);
    defer interfaces.HTMLSourceElement.deinit(source);
    try dom.node_creation.setElementNames(source, "http://www.w3.org/1999/xhtml", "source");
    try dom.node_document.set(source, old_document);
    try interfaces.HTMLSourceElement.set_src(source, "movie.webm");
    _ = try interfaces.Document.call_adoptNode(new_document, source);
    try testing.expectEqualStrings("https://old.test/path/movie.webm", hooks.sourceURL(source).?);
    try interfaces.HTMLSourceElement.set_src(source, "movie.webm");
    try testing.expectEqualStrings("https://new.test/elsewhere/movie.webm", hooks.sourceURL(source).?);
}

test "an unread track element creates no orphan TextTrack allocation" {
    start();
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const element = try interfaces.HTMLTrackElement.init(testing.allocator, &ctx);
    defer interfaces.HTMLTrackElement.deinit(element);
    try testing.expectEqual(@as(u16, 0), try interfaces.HTMLTrackElement.get_readyState(element));
}

test "the first track getter seeds attributes set before lazy creation" {
    start();
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const element = try interfaces.HTMLTrackElement.init(testing.allocator, &ctx);
    defer interfaces.HTMLTrackElement.deinit(element);
    try dom.node_creation.setElementNames(element, "http://www.w3.org/1999/xhtml", "track");
    try interfaces.HTMLTrackElement.set_kind(element, .initInterned("captions"));
    try interfaces.HTMLTrackElement.set_label(element, .initInterned("before"));
    const child = try interfaces.HTMLTrackElement.get_track(element);
    defer interfaces.TextTrack.deinit(child); // The engine-free fixture owns it.
    var label = try interfaces.TextTrack.get_label(child);
    defer label.deinit(testing.allocator);
    try testing.expectEqualStrings("before", label.asSlice());
    try testing.expect((try interfaces.TextTrack.get_kind(child)) == ._captions_);
    try testing.expectEqual(child, try interfaces.HTMLTrackElement.get_track(element));
}

test "empty TextTrackCueList rejects every anonymous indexed getter" {
    start();
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const list = try interfaces.TextTrackCueList.init(testing.allocator, &ctx);
    defer interfaces.TextTrackCueList.deinit(list);
    try testing.expectEqual(@as(u32, 0), try interfaces.TextTrackCueList.get_length(list));
    for ([_]u32{ 0, 1, std.math.maxInt(u32) }) |index| {
        try testing.expectError(error.IndexSizeError, interfaces.TextTrackCueList.call_getter(list, index));
    }
}
