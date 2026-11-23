//! The live DOM over CDP (lane cdpd1, D9; roadmap cdp-live-dom):
//! DOM.setFileInputFiles - Blink's InspectorDOMAgent::setFileInputFiles and
//! HTMLInputElement::SetFilesFromPaths (file_input_type.cc, Chrome
//! 157.0.8103.78), over the platform's files a host names by path
//! (protocol 6.10.3 userFile / userDirectory) and html.file_selection.
//!
//! The files are made in a temporary directory of this process, the
//! Browser's own: its platform reads them by path.

const std = @import("std");
const testing = std.testing;
const harness = @import("cdpd1_harness.zig");
const Harness = harness.Harness;
const setUp = harness.setUp;

const page = "data:text/html,<body><input type=file id=f><input type=file multiple id=m>" ++
    "<input type=file webkitdirectory id=d><input id=t>" ++
    "<script>window.seen = []; for (const i of document.querySelectorAll('input')) " ++
    "for (const t of ['input', 'change', 'cancel']) i.addEventListener(t, (e) => seen.push(i.id + ':' + e.type + ':' + e.bubbles + ':' + e.composed + ':' + e.isTrusted));</script></body>";

fn fmt(h: *Harness, comptime format: []const u8, args: anytype) ![]const u8 {
    return std.fmt.allocPrint(h.arena(), format, args);
}

/// The node id of the element `#id` (DOM.querySelector on the document).
fn nodeOf(h: *Harness, comptime id: []const u8) !i64 {
    const got = try h.call("DOM.querySelector", "{\"nodeId\":1,\"selector\":\"#" ++ id ++ "\"}");
    return got.object.get("nodeId").?.integer;
}

/// What `expression` evaluates to in the page, awaited, as a string.
fn evaluate(h: *Harness, comptime expression: []const u8) ![]const u8 {
    const got = try h.call("Runtime.evaluate", "{\"expression\":\"" ++ expression ++ "\",\"awaitPromise\":true,\"returnByValue\":true}");
    return got.object.get("result").?.object.get("value").?.string;
}

/// `paths` as a JSON array of strings.
fn jsonPaths(h: *Harness, paths: []const []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try out.append(h.arena(), '[');
    for (paths, 0..) |path, i| {
        if (i != 0) try out.append(h.arena(), ',');
        try out.print(h.arena(), "\"{s}\"", .{path});
    }
    try out.append(h.arena(), ']');
    return out.items;
}

fn setFiles(h: *Harness, node: i64, paths: []const []const u8) !void {
    _ = try h.call("DOM.setFileInputFiles", try fmt(h, "{{\"nodeId\":{d},\"files\":{s}}}", .{ node, try jsonPaths(h, paths) }));
}

const Files = struct {
    tmp: testing.TmpDir,
    root: []const u8,

    fn init(h: *Harness) !Files {
        var tmp = testing.tmpDir(.{});
        errdefer tmp.cleanup();
        try tmp.dir.writeFile(testing.io, .{ .sub_path = "hello.txt", .data = "hello world" });
        try tmp.dir.writeFile(testing.io, .{ .sub_path = "pic.PNG", .data = "\x89PNG" });
        try tmp.dir.createDirPath(testing.io, "album/inner");
        try tmp.dir.writeFile(testing.io, .{ .sub_path = "album/z.md", .data = "# z" });
        try tmp.dir.writeFile(testing.io, .{ .sub_path = "album/inner/a.bin", .data = "aa" });
        var buffer: [std.fs.max_path_bytes]u8 = undefined;
        const len = try tmp.dir.realPathFile(testing.io, ".", &buffer);
        return .{ .tmp = tmp, .root = try h.arena().dupe(u8, buffer[0..len]) };
    }

    fn path(self: *const Files, h: *Harness, name: []const u8) ![]const u8 {
        return std.fs.path.join(h.arena(), &.{ self.root, name });
    }

    fn deinit(self: *Files) void {
        self.tmp.cleanup();
    }
};

test "setFileInputFiles selects the files at the paths: name, type from the name, bytes and lastModified; then input and change, trusted and bubbling" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    var files = try Files.init(&h);
    defer files.deinit();
    const f = try nodeOf(&h, "f");
    try setFiles(&h, f, &.{try files.path(&h, "hello.txt")});
    try testing.expectEqualStrings("hello.txt|11|text/plain|hello world|true", try evaluate(&h, "(async () => { const x = document.getElementById('f').files[0]; return [x.name, x.size, x.type, await x.text(), x.lastModified > 0].join('|'); })()"));
    try testing.expectEqualStrings("f:input:true:true:true,f:change:true:false:true", try evaluate(&h, "seen.join()"));
    // Blink's well-known table, case-insensitive: .PNG is image/png.
    try setFiles(&h, f, &.{try files.path(&h, "pic.PNG")});
    try testing.expectEqualStrings("pic.PNG|image/png|4", try evaluate(&h, "(() => { const x = document.getElementById('f').files[0]; return [x.name, x.type, x.size].join('|'); })()"));
}

test "the same selection again is cancel, not change; no paths changes nothing; without multiple only the first path is taken" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    var files = try Files.init(&h);
    defer files.deinit();
    const f = try nodeOf(&h, "f");
    const m = try nodeOf(&h, "m");
    const hello = try files.path(&h, "hello.txt");
    const pic = try files.path(&h, "pic.PNG");
    try setFiles(&h, f, &.{ hello, pic });
    try setFiles(&h, f, &.{hello});
    try setFiles(&h, f, &.{});
    try setFiles(&h, m, &.{ hello, pic });
    try testing.expectEqualStrings("1:hello.txt|2:hello.txt,pic.PNG", try evaluate(&h, "(() => { const n = (id) => [...document.getElementById(id).files].map((x) => x.name).join(); return '1:' + n('f') + '|2:' + n('m'); })()"));
    try testing.expectEqualStrings("f:input,f:change,f:cancel,m:input,m:change", try evaluate(&h, "seen.map((s) => s.split(':').slice(0, 2).join(':')).join()"));
}

test "a path naming no file gives a File of that name with no bytes (Blink: size 0); webkitdirectory takes the directory's files with their relative paths" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    var files = try Files.init(&h);
    defer files.deinit();
    try setFiles(&h, try nodeOf(&h, "f"), &.{try files.path(&h, "missing.txt")});
    try testing.expectEqualStrings("missing.txt|0|text/plain", try evaluate(&h, "(() => { const x = document.getElementById('f').files[0]; return [x.name, x.size, x.type].join('|'); })()"));
    try setFiles(&h, try nodeOf(&h, "d"), &.{try files.path(&h, "album")});
    try testing.expectEqualStrings("album/inner/a.bin:a.bin:application/octet-stream:2,album/z.md:z.md:text/markdown:3", try evaluate(&h, "[...document.getElementById('d').files].map((x) => [x.webkitRelativePath, x.name, x.type, x.size].join(':')).join()"));
}

test "a node that is no file input is an error, as Blink's" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const t = try nodeOf(&h, "t");
    try testing.expectEqualStrings("Node is not a file input element", try h.errorMessage(try h.sendOn(0, "DOM.setFileInputFiles", try fmt(&h, "{{\"nodeId\":{d},\"files\":[\"/x\"]}}", .{t}))));
}
