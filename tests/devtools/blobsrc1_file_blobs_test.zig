//! File-backed Blob sources (lane blobsrc1; W3C File API + Blink BlobData /
//! FileStreamReader model):
//! - DOM.setFileInputFiles keeps a FileToken + snapshot (size + mtime) instead
//!   of eagerly reading bytes at selection.
//! - Missing file fails read with NotFoundError; modified file (size or mtime
//!   changed) fails read with NotReadableError.
//! - slice() and new Blob([file, ...]) keep lazy file parts without reading at
//!   construction time.
//! - Every consumer maps read failures per its spec: Blob methods & stream,
//!   FileReader, FileReaderSync, Request/Response/fetch, XMLHttpRequest,
//!   WebSocket, blob: URL fetch, FormData, createImageBitmap, IndexedDB
//!   (plus webkitRelativePath preserved across clone & IndexedDB).

const std = @import("std");
const testing = std.testing;
const harness = @import("cdpd1_harness.zig");
const Harness = harness.Harness;
const setUp = harness.setUp;
const site_mod = @import("cdpt2_site.zig");
const LoopbackListener = @import("loopback_listener").LoopbackListener;

const data_page = "data:text/html,<body><input type=file id=f><input type=file webkitdirectory id=d></body>";

fn fmt(h: *Harness, comptime format: []const u8, args: anytype) ![]const u8 {
    return std.fmt.allocPrint(h.arena(), format, args);
}

fn nodeOf(h: *Harness, comptime id: []const u8) !i64 {
    const got = try h.call("DOM.querySelector", "{\"nodeId\":1,\"selector\":\"#" ++ id ++ "\"}");
    return got.object.get("nodeId").?.integer;
}

fn evaluate(h: *Harness, expression: []const u8) ![]const u8 {
    var params: std.ArrayList(u8) = .empty;
    try params.appendSlice(h.arena(), "{\"expression\":");
    try params.appendSlice(h.arena(), try std.json.Stringify.valueAlloc(h.arena(), expression, .{}));
    try params.appendSlice(h.arena(), ",\"awaitPromise\":true,\"returnByValue\":true}");
    const got = try h.call("Runtime.evaluate", params.items);
    if (got.object.get("exceptionDetails")) |ex| {
        std.log.err("JS exception: {f}", .{std.json.fmt(ex, .{})});
        return error.JSException;
    }
    const result = got.object.get("result").?.object;
    if (result.get("value")) |v| {
        if (v == .string) return v.string;
    }
    return error.UnexpectedResult;
}

fn jsonPaths(h: *Harness, paths: []const []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try out.append(h.arena(), '[');
    for (paths, 0..) |path, i| {
        if (i != 0) try out.append(h.arena(), ',');
        try out.appendSlice(h.arena(), try std.json.Stringify.valueAlloc(h.arena(), path, .{}));
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
        try tmp.dir.writeFile(testing.io, .{ .sub_path = "a.txt", .data = "hello world" });
        try tmp.dir.writeFile(testing.io, .{ .sub_path = "b.txt", .data = "0123456789" });
        try tmp.dir.writeFile(testing.io, .{ .sub_path = "same_len.txt", .data = "abcdef" });
        try tmp.dir.writeFile(testing.io, .{ .sub_path = "empty.txt", .data = "" });
        try tmp.dir.createDirPath(testing.io, "dir/sub");
        try tmp.dir.writeFile(testing.io, .{ .sub_path = "dir/sub/leaf.txt", .data = "leaf-bytes" });
        var buffer: [std.fs.max_path_bytes]u8 = undefined;
        const len = try tmp.dir.realPathFile(testing.io, ".", &buffer);
        return .{ .tmp = tmp, .root = try h.arena().dupe(u8, buffer[0..len]) };
    }

    fn path(self: *const Files, h: *Harness, name: []const u8) ![]const u8 {
        return std.fs.path.join(h.arena(), &.{ self.root, name });
    }

    fn overwrite(self: *Files, name: []const u8, data: []const u8) !void {
        try self.tmp.dir.writeFile(testing.io, .{ .sub_path = name, .data = data });
    }

    /// Touch mtime without changing size (shifted +5 seconds so filesystems
    /// with 1s granularity still observe a distinct mtime).
    fn bumpMtime(self: *Files, name: []const u8) !void {
        const handle = try self.tmp.dir.openFile(testing.io, name, .{ .mode = .read_write });
        defer handle.close(testing.io);
        const st = try handle.stat(testing.io);
        const bumped: std.Io.Timestamp = .{ .nanoseconds = st.mtime.nanoseconds + 5 * std.time.ns_per_s };
        try handle.setTimestamps(testing.io, .{
            .access_timestamp = .{ .new = bumped },
            .modify_timestamp = .{ .new = bumped },
        });
    }

    fn remove(self: *Files, name: []const u8) !void {
        try self.tmp.dir.deleteFile(testing.io, name);
    }

    fn deinit(self: *Files) void {
        self.tmp.cleanup();
    }
};

/// Minimal RFC 6455 WebSocket handshake server that accepts one connection,
/// stays open until the client disconnects, and closes cleanly on stop().
const WsServer = struct {
    allocator: std.mem.Allocator,
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    stop_flag: std.atomic.Value(bool) = .init(false),

    fn start(allocator: std.mem.Allocator) !*WsServer {
        const self = try allocator.create(WsServer);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .listener = try LoopbackListener.open(.{}) };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
        return self;
    }

    fn stop(self: *WsServer) void {
        self.stop_flag.store(true, .release);
        self.listener.stop();
        if (self.thread) |t| t.join();
        self.listener.close();
        self.allocator.destroy(self);
    }

    fn url(self: *const WsServer, buf: []u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "ws://127.0.0.1:{d}/ws", .{self.listener.port()});
    }

    fn serve(self: *WsServer) void {
        while (self.listener.accept()) |stream| {
            defer stream.close(testing.io);
            handle(stream, &self.stop_flag) catch {};
        }
    }

    fn handle(stream: std.Io.net.Stream, stop_flag: *std.atomic.Value(bool)) !void {
        var in_buf: [4096]u8 = undefined;
        var reader = stream.reader(testing.io, &in_buf);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) {
            try reader.interface.fillMore();
        }
        const head = reader.interface.buffered();
        var key: []const u8 = "";
        var lines = std.mem.splitSequence(u8, head, "\r\n");
        while (lines.next()) |line| {
            if (std.ascii.startsWithIgnoreCase(line, "Sec-WebSocket-Key:")) {
                key = std.mem.trim(u8, line["Sec-WebSocket-Key:".len..], " \t");
            }
        }
        var sha = std.crypto.hash.Sha1.init(.{});
        sha.update(key);
        sha.update("258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
        var digest: [20]u8 = undefined;
        sha.final(&digest);
        var accept_buf: [28]u8 = undefined;
        const accept = std.base64.standard.Encoder.encode(&accept_buf, &digest);
        var out_buf: [512]u8 = undefined;
        var writer = stream.writer(testing.io, &out_buf);
        try writer.interface.print(
            "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {s}\r\n\r\n",
            .{accept},
        );
        try writer.interface.flush();
        while (!stop_flag.load(.acquire)) {
            var tmp: [64]u8 = undefined;
            const n = reader.interface.readSliceShort(&tmp) catch break;
            if (n == 0) break;
        }
    }
};

test "Blob.text/arrayBuffer/bytes/stream fail with NotFoundError when deleted and NotReadableError when modified (size or mtime)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, data_page, null);
    var files = try Files.init(&h);
    defer files.deinit();
    const f = try nodeOf(&h, "f");

    // 1. Deleted after selection -> NotFoundError on text/arrayBuffer/bytes/stream.
    try setFiles(&h, f, &.{try files.path(&h, "a.txt")});
    try files.remove("a.txt");
    try testing.expectEqualStrings(
        "NotFoundError|NotFoundError|NotFoundError|NotFoundError",
        try evaluate(&h,
            \\(async () => {
            \\  const file = document.getElementById('f').files[0];
            \\  const errOf = async (p) => { try { await p; return 'OK'; } catch (e) { return e.name; } };
            \\  const r = file.stream().getReader();
            \\  return [
            \\    await errOf(file.text()),
            \\    await errOf(file.arrayBuffer()),
            \\    await errOf(file.bytes()),
            \\    await errOf(r.read()),
            \\  ].join('|');
            \\})()
        ),
    );

    // 2. Modified (size changed) after selection -> NotReadableError.
    try setFiles(&h, f, &.{try files.path(&h, "b.txt")});
    try files.overwrite("b.txt", "changed-to-longer-content");
    try testing.expectEqualStrings(
        "NotReadableError|NotReadableError|NotReadableError|NotReadableError",
        try evaluate(&h,
            \\(async () => {
            \\  const file = document.getElementById('f').files[0];
            \\  const errOf = async (p) => { try { await p; return 'OK'; } catch (e) { return e.name; } };
            \\  const r = file.stream().getReader();
            \\  return [
            \\    await errOf(file.text()),
            \\    await errOf(file.arrayBuffer()),
            \\    await errOf(file.bytes()),
            \\    await errOf(r.read()),
            \\  ].join('|');
            \\})()
        ),
    );

    // 3. Modified (same size, mtime changed) -> NotReadableError.
    try setFiles(&h, f, &.{try files.path(&h, "same_len.txt")});
    try files.bumpMtime("same_len.txt");
    try testing.expectEqualStrings(
        "NotReadableError",
        try evaluate(&h, "(async () => { const f = document.getElementById('f').files[0]; try { await f.text(); return 'OK'; } catch (e) { return e.name; } })()"),
    );

    // 4. Missing path at selection -> size 0, read fails with NotFoundError.
    try setFiles(&h, f, &.{try files.path(&h, "does-not-exist.txt")});
    try testing.expectEqualStrings(
        "0|NotFoundError",
        try evaluate(&h, "(async () => { const f = document.getElementById('f').files[0]; try { await f.text(); return f.size + '|OK'; } catch (e) { return f.size + '|' + e.name; } })()"),
    );

    // 5. Empty (0-byte) file deleted after selection -> NotFoundError.
    try setFiles(&h, f, &.{try files.path(&h, "empty.txt")});
    try files.remove("empty.txt");
    try testing.expectEqualStrings(
        "NotFoundError",
        try evaluate(&h, "(async () => { const f = document.getElementById('f').files[0]; try { await f.text(); return 'OK'; } catch (e) { return e.name; } })()"),
    );
}

test "slice() and new Blob([file, tail]) keep lazy file parts without reading at construction" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, data_page, null);
    var files = try Files.init(&h);
    defer files.deinit();
    const f = try nodeOf(&h, "f");

    try setFiles(&h, f, &.{try files.path(&h, "a.txt")});
    // Slice and composite Blob read the right bytes while unchanged.
    try testing.expectEqualStrings(
        "world|5|head:hello world:tail|21|llo w",
        try evaluate(&h,
            \\(async () => {
            \\  const file = document.getElementById('f').files[0];
            \\  window.sliced = file.slice(6, 11);
            \\  window.composed = new Blob(['head:', file, ':tail']);
            \\  window.composedSlice = window.composed.slice(7, 12);
            \\  return [
            \\    await window.sliced.text(),
            \\    window.sliced.size,
            \\    await window.composed.text(),
            \\    window.composed.size,
            \\    await window.composedSlice.text(),
            \\  ].join('|');
            \\})()
        ),
    );
    // Delete the underlying file: previously created slice & composite Blob fail with NotFoundError!
    try files.remove("a.txt");
    try testing.expectEqualStrings(
        "NotFoundError|NotFoundError|NotFoundError",
        try evaluate(&h,
            \\(async () => {
            \\  const errOf = async (p) => { try { await p; return 'OK'; } catch (e) { return e.name; } };
            \\  return [
            \\    await errOf(window.sliced.text()),
            \\    await errOf(window.composed.text()),
            \\    await errOf(window.composedSlice.text()),
            \\  ].join('|');
            \\})()
        ),
    );
}

test "FileReader error/loadend, createImageBitmap InvalidStateError, blob: URL network error" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    const site = try site_mod.Site.start(testing.allocator);
    defer site.stop();
    var url_buf: [96]u8 = undefined;
    try setUp(&h, try site.url(&url_buf, "/echo"), null);
    _ = try evaluate(&h, "(() => { document.body.innerHTML = '<input type=file id=f>'; return 'ok'; })()");
    var files = try Files.init(&h);
    defer files.deinit();
    const f = try nodeOf(&h, "f");

    try setFiles(&h, f, &.{try files.path(&h, "a.txt")});
    // Create blob URL before deletion.
    _ = try evaluate(&h, "(() => { window.file = document.getElementById('f').files[0]; window.blobUrl = URL.createObjectURL(window.file); return window.blobUrl; })()");
    try testing.expectEqualStrings("hello world", try evaluate(&h, "(async () => await (await fetch(window.blobUrl)).text())()"));

    try files.remove("a.txt");

    // FileReader: error = NotFoundError, events = error,loadend (no loadstart/load).
    try testing.expectEqualStrings(
        "NotFoundError|error,loadend",
        try evaluate(&h,
            \\new Promise((resolve) => {
            \\  const fr = new FileReader();
            \\  const evs = [];
            \\  for (const t of ['loadstart', 'progress', 'load', 'error', 'loadend']) {
            \\    fr.addEventListener(t, () => evs.push(t));
            \\  }
            \\  fr.addEventListener('loadend', () => resolve((fr.error ? fr.error.name : 'null') + '|' + evs.join(',')));
            \\  fr.readAsText(window.file);
            \\})
        ),
    );

    // createImageBitmap: rejects with InvalidStateError.
    try testing.expectEqualStrings(
        "InvalidStateError",
        try evaluate(&h, "(async () => { try { await createImageBitmap(window.file); return 'OK'; } catch (e) { return e.name; } })()"),
    );

    // blob: URL fetch: fails with TypeError (network error).
    try testing.expectEqualStrings(
        "TypeError",
        try evaluate(&h, "(async () => { try { await fetch(window.blobUrl); return 'OK'; } catch (e) { return e.name; } })()"),
    );
    _ = try evaluate(&h, "(() => { URL.revokeObjectURL(window.blobUrl); return 'ok'; })()");
}

test "Request/Response/fetch, XHR, FormData, WebSocket, and IndexedDB + webkitRelativePath" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    const site = try site_mod.Site.start(testing.allocator);
    defer site.stop();
    const ws = try WsServer.start(testing.allocator);
    defer ws.stop();
    var url_buf: [96]u8 = undefined;
    var ws_buf: [96]u8 = undefined;
    try setUp(&h, try site.url(&url_buf, "/echo"), null);
    _ = try evaluate(&h, "(() => { document.body.innerHTML = '<input type=file id=f><input type=file webkitdirectory id=d>'; return 'ok'; })()");
    var files = try Files.init(&h);
    defer files.deinit();
    const f = try nodeOf(&h, "f");
    const d = try nodeOf(&h, "d");

    // 1. Store an unchanged directory file in IndexedDB: keeps webkitRelativePath and survives disk deletion!
    try setFiles(&h, d, &.{try files.path(&h, "dir")});
    try testing.expectEqualStrings(
        "dir/sub/leaf.txt|leaf-bytes",
        try evaluate(&h,
            \\(async () => {
            \\  const orig = document.getElementById('d').files[0];
            \\  const db = await new Promise((res, rej) => {
            \\    const req = indexedDB.open('blobsrc1_db', 1);
            \\    req.onupgradeneeded = () => req.result.createObjectStore('s');
            \\    req.onsuccess = () => res(req.result);
            \\    req.onerror = () => rej(req.error);
            \\  });
            \\  await new Promise((res, rej) => {
            \\    const tx = db.transaction('s', 'readwrite');
            \\    const req = tx.objectStore('s').put(orig, 'k1');
            \\    tx.oncomplete = () => res();
            \\    tx.onerror = () => rej(req.error || tx.error);
            \\  });
            \\  window._db = db;
            \\  const got = await new Promise((res, rej) => {
            \\    const tx = db.transaction('s', 'readonly');
            \\    const req = tx.objectStore('s').get('k1');
            \\    req.onsuccess = () => res(req.result);
            \\    req.onerror = () => rej(req.error);
            \\  });
            \\  return got.webkitRelativePath + '|' + await got.text();
            \\})()
        ),
    );
    // Delete leaf.txt on disk: already-stored IDB copy STILL reads its stored bytes!
    try files.remove("dir/sub/leaf.txt");
    try testing.expectEqualStrings(
        "dir/sub/leaf.txt|leaf-bytes",
        try evaluate(&h,
            \\(async () => {
            \\  const got = await new Promise((res, rej) => {
            \\    const tx = window._db.transaction('s', 'readonly');
            \\    const req = tx.objectStore('s').get('k1');
            \\    req.onsuccess = () => res(req.result);
            \\    req.onerror = () => rej(req.error);
            \\  });
            \\  return got.webkitRelativePath + '|' + await got.text();
            \\})()
        ),
    );

    // 2. Now select a.txt, create Response/Request/FormData BEFORE deletion, then delete a.txt.
    try setFiles(&h, f, &.{try files.path(&h, "a.txt")});
    _ = try evaluate(&h,
        \\(() => {
        \\  window.file = document.getElementById('f').files[0];
        \\  window.res = new Response(window.file);
        \\  window.req = new Request('/echo', { method: 'POST', body: window.file });
        \\  window.fd = new FormData();
        \\  window.fd.append('f', window.file);
        \\  return 'ok';
        \\})()
    );
    try files.remove("a.txt");

    // Response.text(), Request.text(), fetch(file), fetch(FormData) all fail!
    try testing.expectEqualStrings(
        "ERR|ERR|TypeError|TypeError",
        try evaluate(&h,
            \\(async () => {
            \\  const f1 = async (p) => { try { await p; return 'OK'; } catch (e) { return 'ERR'; } };
            \\  const f2 = async (p) => { try { await p; return 'OK'; } catch (e) { return e.name; } };
            \\  return [
            \\    await f1(window.res.text()),
            \\    await f1(window.req.text()),
            \\    await f2(fetch('/echo', { method: 'POST', body: window.file })),
            \\    await f2(fetch('/echo', { method: 'POST', body: window.fd })),
            \\  ].join('|');
            \\})()
        ),
    );

    // XHR.send(file) async -> network error (loadstart, error, loadend).
    try testing.expectEqualStrings(
        "error,loadend",
        try evaluate(&h,
            \\new Promise((resolve) => {
            \\  const xhr = new XMLHttpRequest();
            \\  const evs = [];
            \\  xhr.addEventListener('error', () => evs.push('error'));
            \\  xhr.addEventListener('loadend', () => { evs.push('loadend'); resolve(evs.join(',')); });
            \\  xhr.open('POST', '/echo');
            \\  xhr.send(window.file);
            \\})
        ),
    );

    // IndexedDB put of deleted file -> request fails with UnknownError and transaction aborts.
    try testing.expectEqualStrings(
        "UnknownError|abort",
        try evaluate(&h,
            \\new Promise((resolve) => {
            \\  const tx = window._db.transaction('s', 'readwrite');
            \\  const req = tx.objectStore('s').put(window.file, 'k2');
            \\  let reqErr = 'none';
            \\  req.onerror = () => { reqErr = req.error ? req.error.name : 'null'; };
            \\  tx.onabort = () => resolve(reqErr + '|abort');
            \\  tx.oncomplete = () => resolve(reqErr + '|complete');
            \\})
        ),
    );

    // WebSocket.send(deleted file) -> fails connection (error then close 1006, wasClean=false).
    const ws_url = try ws.url(&ws_buf);
    const ws_expr = try std.fmt.allocPrint(h.arena(),
        \\new Promise((resolve) => {{
        \\  const s = new WebSocket('{s}');
        \\  const evs = [];
        \\  s.onopen = () => s.send(window.file);
        \\  s.onerror = () => evs.push('error');
        \\  s.onclose = (e) => {{ evs.push('close:' + e.code + ':' + e.wasClean); resolve(evs.join(',')); }};
        \\}})
    , .{ws_url});
    try testing.expectEqualStrings("error,close:1006:false", try evaluate(&h, ws_expr));

    _ = try evaluate(&h, "(() => { window._db.close(); return 'ok'; })()");
}

test "structuredClone, MessageChannel, BroadcastChannel, and Worker FileReaderSync preserve lazy file-backed ref and webkitRelativePath" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    const site = try site_mod.Site.start(testing.allocator);
    defer site.stop();
    var url_buf: [96]u8 = undefined;
    try setUp(&h, try site.url(&url_buf, "/echo"), null);
    _ = try evaluate(&h, "(() => { document.body.innerHTML = '<input type=file webkitdirectory id=d>'; return 'ok'; })()");
    var files = try Files.init(&h);
    defer files.deinit();
    try files.overwrite("dir/sub/mod.txt", "before-mod");
    const d = try nodeOf(&h, "d");
    try setFiles(&h, d, &.{try files.path(&h, "dir")});

    // 1. structuredClone(file) and structuredClone(FileList) do NOT read disk at clone time,
    //    and preserve webkitRelativePath + snapshot.
    try testing.expectEqualStrings(
        "leaf.txt|dir/sub/leaf.txt|leaf-bytes|dir/sub/mod.txt|before-mod",
        try evaluate(&h,
            \\(async () => {
            \\  const files = document.getElementById('d').files;
            \\  const byName = {};
            \\  for (let i = 0; i < files.length; i++) byName[files[i].name] = files[i];
            \\  window.delClone = structuredClone(byName['leaf.txt']);
            \\  window.modClone = structuredClone(byName['mod.txt']);
            \\  window.listClone = structuredClone(files);
            \\  let listMod = null;
            \\  for (let i = 0; i < window.listClone.length; i++) {
            \\    if (window.listClone[i].name === 'mod.txt') listMod = window.listClone[i];
            \\  }
            \\  return [
            \\    window.delClone.name,
            \\    window.delClone.webkitRelativePath,
            \\    await window.delClone.text(),
            \\    listMod.webkitRelativePath,
            \\    await listMod.text(),
            \\  ].join('|');
            \\})()
        ),
    );

    // 2. MessageChannel + BroadcastChannel carry file-backed File lazily across listeners
    //    (plus an undelivered port message dropped on close to check 0 leaked tokens).
    try testing.expectEqualStrings(
        "dir/sub/leaf.txt|leaf-bytes|dir/sub/leaf.txt|leaf-bytes",
        try evaluate(&h,
            \\(async () => {
            \\  const mc = new MessageChannel();
            \\  const mcPromise = new Promise((resolve) => {
            \\    mc.port2.onmessage = async (e) => {
            \\      window.mcFile = e.data;
            \\      resolve(e.data.webkitRelativePath + '|' + await e.data.text());
            \\    };
            \\  });
            \\  mc.port1.postMessage(window.delClone);
            \\  const mcRes = await mcPromise;
            \\
            \\  // Undelivered queued message dropped when ports close (leak check).
            \\  const mcDrop = new MessageChannel();
            \\  mcDrop.port1.postMessage(window.delClone);
            \\  mcDrop.port1.close();
            \\  mcDrop.port2.close();
            \\
            \\  const bc1 = new BroadcastChannel('blobsrc1-ch');
            \\  const bc2 = new BroadcastChannel('blobsrc1-ch');
            \\  const bc3 = new BroadcastChannel('blobsrc1-ch');
            \\  const p2 = new Promise((resolve) => {
            \\    bc2.onmessage = async (e) => resolve(e.data.webkitRelativePath + '|' + await e.data.text());
            \\  });
            \\  const p3 = new Promise((resolve) => {
            \\    bc3.onmessage = (e) => { window.bcFile = e.data; resolve('ok'); };
            \\  });
            \\  bc1.postMessage(window.delClone);
            \\  const bcRes = await p2;
            \\  await p3;
            \\  bc1.close(); bc2.close(); bc3.close();
            \\  return mcRes + '|' + bcRes;
            \\})()
        ),
    );

    // 3. Dedicated Worker receives file-backed Files via postMessage and reads via FileReaderSync.
    try testing.expectEqualStrings(
        "ok:dir/sub/leaf.txt:leaf-bytes|ok:dir/sub/mod.txt:before-mod",
        try evaluate(&h,
            \\new Promise((resolve, reject) => {
            \\  const code = `
            \\    let delFile = null, modFile = null;
            \\    const reader = new FileReaderSync();
            \\    self.onmessage = (e) => {
            \\      if (e.data.cmd === 'store') {
            \\        delFile = e.data.delFile;
            \\        modFile = e.data.modFile;
            \\        self.postMessage(
            \\          'ok:' + delFile.webkitRelativePath + ':' + reader.readAsText(delFile) + '|' +
            \\          'ok:' + modFile.webkitRelativePath + ':' + reader.readAsText(modFile)
            \\        );
            \\      } else if (e.data.cmd === 'reread') {
            \\        const tryRead = (f) => {
            \\          try { return 'OK:' + reader.readAsText(f); }
            \\          catch (err) { return err.name; }
            \\        };
            \\        self.postMessage(tryRead(delFile) + '|' + tryRead(modFile));
            \\      }
            \\    };
            \\  `;
            \\  const url = URL.createObjectURL(new Blob([code], { type: 'application/javascript' }));
            \\  const w = new Worker(url);
            \\  window._worker = w;
            \\  window._workerUrl = url;
            \\  w.onerror = (e) => reject(new Error(e.message || 'worker error'));
            \\  w.onmessage = (e) => resolve(e.data);
            \\  w.postMessage({ cmd: 'store', delFile: window.delClone, modFile: window.modClone });
            \\})
        ),
    );

    // Now delete leaf.txt and modify mod.txt on disk!
    try files.remove("dir/sub/leaf.txt");
    try files.overwrite("dir/sub/mod.txt", "after-modification-longer");

    // Clones on main thread (structuredClone, MessageChannel, BroadcastChannel) AND in Worker
    // all detect the missing/modified backing files lazily!
    try testing.expectEqualStrings(
        "NotFoundError|NotFoundError|NotFoundError|NotReadableError",
        try evaluate(&h,
            \\(async () => {
            \\  const errOf = async (b) => { try { await b.text(); return 'OK'; } catch (e) { return e.name; } };
            \\  return [
            \\    await errOf(window.delClone),
            \\    await errOf(window.mcFile),
            \\    await errOf(window.bcFile),
            \\    await errOf(window.modClone),
            \\  ].join('|');
            \\})()
        ),
    );

    try testing.expectEqualStrings(
        "NotFoundError|NotReadableError",
        try evaluate(&h,
            \\new Promise((resolve) => {
            \\  window._worker.onmessage = (e) => resolve(e.data);
            \\  window._worker.postMessage({ cmd: 'reread' });
            \\})
        ),
    );

    _ = try evaluate(&h,
        \\(() => {
        \\  window._worker.terminate();
        \\  URL.revokeObjectURL(window._workerUrl);
        \\  return 'ok';
        \\})()
    );
}
