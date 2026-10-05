//! A DOM tree walk must run each media element's most-derived destructor.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;
test "subtree teardown releases source track audio and video owner allocations" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const parent = try interfaces.HTMLElement.init(testing.allocator, &ctx);
    defer interfaces.HTMLElement.deinit(parent);
    try dom.node_creation.setElementNames(parent, "http://www.w3.org/1999/xhtml", "div");
    inline for (.{ "HTMLAudioElement", "HTMLVideoElement", "HTMLSourceElement", "HTMLTrackElement" }, .{ "audio", "video", "source", "track" }) |interface_name, name| {
        const element = try @field(interfaces, interface_name).init(testing.allocator, &ctx);
        try dom.node_creation.setElementNames(element, "http://www.w3.org/1999/xhtml", name);
        _ = try interfaces.Node.call_appendChild(parent, element);
    }
    // The parent's recursive deinit, not explicit child cleanups, owns release.
}
