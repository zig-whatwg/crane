//! The File Upload state's selection (HTML 4.10.5.1.18), for files a HOST
//! chooses by path: a remote end's DOM.setFileInputFiles, as Blink's
//! FileInputType::SetFilesFromPaths / SetFilesFromDirectory /
//! SetFilesAndDispatchEvents (third_party/blink/renderer/core/html/forms/
//! file_input_type.cc, Chrome 157.0.8103.78). Two halves:
//!
//! - The File for a chosen file: the platform's PickedFile (protocol 6.10.3
//!   `userFile` / `userDirectory`), its bytes read through `readPickedFile`,
//!   made by File's own constructor (an ArrayBuffer part, its name, its type
//!   and lastModified), with its webkitRelativePath for a file of a chosen
//!   directory (dom.blob_bytes.setRelativePath, File's step).
//! - The selection applied to the input: its files set (the `files`
//!   setter's "update the selected files"), then trusted `input` and
//!   `change` events - or `cancel` when the selection is the one it had.
//!
//! The platform answers through Replies that may come from any thread; Blink
//! runs DOM.setFileInputFiles synchronously, so this waits for each answer
//! WITHOUT running the agent's tasks (protocol section 4, "Synchronous spec
//! steps over asynchronous platforms"; the shape of execcommand/
//! clipboard_platform.zig's ReadRequest).
//!
//! DEVIATIONS from Blink, until file-backed Blob sources exist (queued:
//! tmp/plans/queue-0.1-audit.md, "From cdpd1", blobsrc1): Blink keeps the
//! path and reads the file when script reads it, so a file gone fails the
//! read with NotFoundError and one modified since its snapshot with
//! NotReadableError. Here the bytes are read when the files are selected: a
//! path that names no file gives a File of that name with no bytes (as
//! Blink's File, whose size reads 0 and lastModified now), and a later change
//! to the file is not seen.

const std = @import("std");
const runtime = @import("runtime");
const platform = @import("platform");
const interfaces = @import("interfaces");
const engine = @import("engine");
const dom = @import("dom");
const platform_state = @import("platform_state.zig");
const form_associated = @import("form_associated.zig");

// ---------------------------------------------------------------------------
// The type of a chosen file
// ---------------------------------------------------------------------------

// The extension tables below are copied from Chromium:
//   https://chromium.googlesource.com/chromium/src, net/base/mime_util.cc,
//   tag 157.0.8103.78 (commit 4b3d0dabb8250b6f152d2d85d79e7706e309d087):
//   kPrimaryMappings and kSecondaryMappings, in their order.
//   Copyright 2012 The Chromium Authors
//   Use of this source code is governed by a BSD-style license that can be
//   found in the LICENSE file. (BSD-3-Clause; THIRD_PARTY_NOTICES.md, text C.)
// Blink's File::CreateForUserProvidedFile takes a chosen file's type from its
// name (GetContentTypeFromFileName, kWellKnownContentTypes ->
// MIMETypeRegistry::GetWellKnownMIMETypeForExtension ->
// net::GetWellKnownMimeTypeFromExtension): these two tables only, never the
// OS's, the first match winning; "" when none matches.
const Mapping = struct { mime_type: []const u8, extensions: []const u8 };

const primary_mappings = [_]Mapping{
    .{ .mime_type = "video/webm", .extensions = "webm" },
    .{ .mime_type = "audio/mpeg", .extensions = "mp3" },
    .{ .mime_type = "application/wasm", .extensions = "wasm" },
    .{ .mime_type = "application/x-chrome-extension", .extensions = "crx" },
    .{ .mime_type = "application/xhtml+xml", .extensions = "xhtml,xht,xhtm" },
    .{ .mime_type = "audio/flac", .extensions = "flac" },
    .{ .mime_type = "audio/matroska", .extensions = "mka" },
    .{ .mime_type = "audio/mp3", .extensions = "mp3" },
    .{ .mime_type = "audio/ogg", .extensions = "ogg,oga,opus" },
    .{ .mime_type = "audio/wav", .extensions = "wav" },
    .{ .mime_type = "audio/webm", .extensions = "webm" },
    .{ .mime_type = "audio/x-m4a", .extensions = "m4a" },
    .{ .mime_type = "image/avif", .extensions = "avif" },
    .{ .mime_type = "image/gif", .extensions = "gif" },
    .{ .mime_type = "image/jpeg", .extensions = "jpeg,jpg,jpe" },
    .{ .mime_type = "image/jxl", .extensions = "jxl" },
    .{ .mime_type = "image/png", .extensions = "png" },
    .{ .mime_type = "image/apng", .extensions = "png,apng" },
    .{ .mime_type = "image/svg+xml", .extensions = "svg,svgz" },
    .{ .mime_type = "image/webp", .extensions = "webp" },
    .{ .mime_type = "multipart/related", .extensions = "mht,mhtml" },
    .{ .mime_type = "text/css", .extensions = "css" },
    .{ .mime_type = "text/html", .extensions = "html,htm,shtml,shtm" },
    .{ .mime_type = "text/javascript", .extensions = "js,mjs" },
    .{ .mime_type = "text/xml", .extensions = "xml" },
    .{ .mime_type = "video/matroska", .extensions = "mkv" },
    .{ .mime_type = "video/mp4", .extensions = "mp4,m4v" },
    .{ .mime_type = "video/ogg", .extensions = "ogv,ogm" },
    .{ .mime_type = "text/csv", .extensions = "csv" },
};

const secondary_mappings = [_]Mapping{
    .{ .mime_type = "image/x-icon", .extensions = "ico" },
    .{ .mime_type = "application/epub+zip", .extensions = "epub" },
    .{ .mime_type = "application/font-woff", .extensions = "woff" },
    .{ .mime_type = "application/gzip", .extensions = "gz,tgz" },
    .{ .mime_type = "application/javascript", .extensions = "js" },
    .{ .mime_type = "application/json", .extensions = "json" },
    .{ .mime_type = "application/msword", .extensions = "doc,dot" },
    .{ .mime_type = "application/octet-stream", .extensions = "bin,exe,com" },
    .{ .mime_type = "application/pdf", .extensions = "pdf" },
    .{ .mime_type = "application/pkcs7-mime", .extensions = "p7m,p7c,p7z" },
    .{ .mime_type = "application/pkcs7-signature", .extensions = "p7s" },
    .{ .mime_type = "application/postscript", .extensions = "ps,eps,ai" },
    .{ .mime_type = "application/rdf+xml", .extensions = "rdf" },
    .{ .mime_type = "application/rss+xml", .extensions = "rss" },
    .{ .mime_type = "application/rtf", .extensions = "rtf" },
    .{ .mime_type = "application/vnd.android.package-archive", .extensions = "apk" },
    .{ .mime_type = "application/vnd.mozilla.xul+xml", .extensions = "xul" },
    .{ .mime_type = "application/vnd.ms-excel", .extensions = "xls" },
    .{ .mime_type = "application/vnd.ms-powerpoint", .extensions = "ppt" },
    .{ .mime_type = "application/vnd.openxmlformats-officedocument.presentationml.presentation", .extensions = "pptx" },
    .{ .mime_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", .extensions = "xlsx" },
    .{ .mime_type = "application/vnd.openxmlformats-officedocument.wordprocessingml.document", .extensions = "docx" },
    .{ .mime_type = "application/x-gzip", .extensions = "gz,tgz" },
    .{ .mime_type = "application/x-mpegurl", .extensions = "m3u8" },
    .{ .mime_type = "application/x-shockwave-flash", .extensions = "swf,swl" },
    .{ .mime_type = "application/x-tar", .extensions = "tar" },
    .{ .mime_type = "application/x-x509-ca-cert", .extensions = "cer,crt" },
    .{ .mime_type = "application/zip", .extensions = "zip" },
    .{ .mime_type = "audio/webm", .extensions = "weba" },
    .{ .mime_type = "image/bmp", .extensions = "bmp" },
    .{ .mime_type = "image/jpeg", .extensions = "jfif,pjpeg,pjp" },
    .{ .mime_type = "image/tiff", .extensions = "tiff,tif" },
    .{ .mime_type = "image/vnd.microsoft.icon", .extensions = "ico" },
    .{ .mime_type = "image/x-png", .extensions = "png" },
    .{ .mime_type = "image/x-xbitmap", .extensions = "xbm" },
    .{ .mime_type = "message/rfc822", .extensions = "eml" },
    .{ .mime_type = "text/calendar", .extensions = "ics" },
    .{ .mime_type = "text/html", .extensions = "ehtml" },
    .{ .mime_type = "text/markdown", .extensions = "md" },
    .{ .mime_type = "text/plain", .extensions = "txt,text" },
    .{ .mime_type = "text/vtt", .extensions = "vtt" },
    .{ .mime_type = "text/x-sh", .extensions = "sh" },
    .{ .mime_type = "text/xml", .extensions = "xsl,xbl,xslt" },
    .{ .mime_type = "video/mpeg", .extensions = "mpeg,mpg,mpe" },
};
// (End of the copied tables.)

fn findMimeType(mappings: []const Mapping, extension: []const u8) ?[]const u8 {
    for (mappings) |mapping| {
        var it = std.mem.splitScalar(u8, mapping.extensions, ',');
        while (it.next()) |candidate| {
            if (std.ascii.eqlIgnoreCase(candidate, extension)) return mapping.mime_type;
        }
    }
    return null;
}

/// A chosen file's type from its name: the extension after the last '.',
/// through Chrome's well-known tables; "" when there is none.
pub fn wellKnownTypeForName(name: []const u8) []const u8 {
    const dot = std.mem.lastIndexOfScalar(u8, name, '.') orelse return "";
    const extension = name[dot + 1 ..];
    return findMimeType(&primary_mappings, extension) orelse findMimeType(&secondary_mappings, extension) orelse "";
}

// ---------------------------------------------------------------------------
// Waiting for the platform
// ---------------------------------------------------------------------------

fn futexWake(word: *std.atomic.Value(u32)) void {
    std.Io.Threaded.global_single_threaded.io().futexWake(u32, &word.raw, 1);
}

fn futexWait(word: *std.atomic.Value(u32), expected: u32) void {
    std.Io.Threaded.global_single_threaded.io().futexWaitTimeout(u32, &word.raw, expected, .none) catch {};
}

/// A chosen file, copied out of the platform's borrowed PickedFile.
const Picked = struct {
    token: platform.FileToken,
    name: []u8,
    mime_type: []u8,
    relative_path: []u8,
    size: u64,
    modified_ns: i64,

    fn copy(allocator: std.mem.Allocator, value: *const platform.PickedFile) error{OutOfMemory}!Picked {
        const name = try allocator.dupe(u8, value.name.slice());
        errdefer allocator.free(name);
        const mime_type = try allocator.dupe(u8, value.mime_type.slice());
        errdefer allocator.free(mime_type);
        const relative_path = try allocator.dupe(u8, value.relative_path.slice());
        return .{ .token = value.token, .name = name, .mime_type = mime_type, .relative_path = relative_path, .size = value.size, .modified_ns = value.last_modified.ns_since_epoch };
    }

    fn deinit(self: *Picked, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.mime_type);
        allocator.free(self.relative_path);
    }
};

/// One synchronous platform request whose answer is a `T`, kept as `Kept`
/// (`copy`, from any thread; `free` frees one never taken). Two references -
/// the caller's and the Reply's - and a futex word, as clipboard_platform's
/// ReadRequest.
fn Request(comptime T: type, comptime Kept: type, comptime copy: fn (std.mem.Allocator, *const T) error{OutOfMemory}!Kept, comptime free: fn (std.mem.Allocator, *Kept) void) type {
    return struct {
        allocator: std.mem.Allocator,
        refs: std.atomic.Value(u32) = .init(2),
        state: std.atomic.Value(u32) = .init(pending),
        kept: ?Kept = null,

        const Self = @This();
        const pending: u32 = 0;
        const delivered: u32 = 1;
        const dropped: u32 = 2;

        fn create(allocator: std.mem.Allocator) error{OutOfMemory}!*Self {
            const self = try allocator.create(Self);
            self.* = .{ .allocator = allocator };
            return self;
        }

        fn reply(self: *Self) platform.Reply(T) {
            return .{ .context = self, .deliver = &deliver, .drop = &drop };
        }

        fn deliver(context: *anyopaque, value: *const T) callconv(.c) void {
            const self: *Self = @ptrCast(@alignCast(context));
            // The value is borrowed for the call: copy what is kept.
            self.kept = copy(self.allocator, value) catch null;
            self.finish(if (self.kept != null) delivered else dropped);
        }

        fn drop(context: *anyopaque) callconv(.c) void {
            const self: *Self = @ptrCast(@alignCast(context));
            self.finish(dropped);
        }

        fn finish(self: *Self, state: u32) void {
            self.state.store(state, .release);
            futexWake(&self.state);
            self.release();
        }

        /// The answer, now the caller's (null: dropped). Waits for it.
        fn take(self: *Self) ?Kept {
            while (true) {
                const state = self.state.load(.acquire);
                if (state != pending) break;
                futexWait(&self.state, pending);
            }
            const kept = self.kept;
            self.kept = null;
            return kept;
        }

        fn release(self: *Self) void {
            if (self.refs.fetchSub(1, .acq_rel) != 1) return;
            if (self.kept) |*kept| free(self.allocator, kept);
            self.allocator.destroy(self);
        }
    };
}

fn copyPicked(allocator: std.mem.Allocator, value: *const platform.PickedFile) error{OutOfMemory}!Picked {
    return Picked.copy(allocator, value);
}

fn freePicked(allocator: std.mem.Allocator, kept: *Picked) void {
    kept.deinit(allocator);
}

fn copyPickedList(allocator: std.mem.Allocator, value: *const platform.PickedFiles) error{OutOfMemory}![]Picked {
    const out = try allocator.alloc(Picked, value.len);
    var done: usize = 0;
    errdefer {
        for (out[0..done]) |*picked| picked.deinit(allocator);
        allocator.free(out);
    }
    for (value.ptr[0..value.len], out) |*source, *target| {
        target.* = try Picked.copy(allocator, source);
        done += 1;
    }
    return out;
}

fn freePickedList(allocator: std.mem.Allocator, kept: *[]Picked) void {
    for (kept.*) |*picked| picked.deinit(allocator);
    allocator.free(kept.*);
}

fn copyBytes(allocator: std.mem.Allocator, value: *const platform.Bytes) error{OutOfMemory}![]u8 {
    return allocator.dupe(u8, value.slice());
}

fn freeBytes(allocator: std.mem.Allocator, kept: *[]u8) void {
    allocator.free(kept.*);
}

const FileRequest = Request(platform.PickedFile, Picked, copyPicked, freePicked);
const DirectoryRequest = Request(platform.PickedFiles, []Picked, copyPickedList, freePickedList);
const ReadRequest = Request(platform.Bytes, []u8, copyBytes, freeBytes);

fn userFile(allocator: std.mem.Allocator, browser: *platform.BrowserPlatform, path: []const u8) error{OutOfMemory}!?Picked {
    const request = try FileRequest.create(allocator);
    defer request.release();
    platform.userFile(browser, platform.Str.from(path), request.reply());
    return request.take();
}

fn userDirectory(allocator: std.mem.Allocator, browser: *platform.BrowserPlatform, path: []const u8) error{OutOfMemory}!?[]Picked {
    const request = try DirectoryRequest.create(allocator);
    defer request.release();
    platform.userDirectory(browser, platform.Str.from(path), request.reply());
    return request.take();
}

/// How much one readPickedFile asks for.
const read_chunk: u32 = 1 << 20;

/// A chosen file's bytes, OWNED, read whole; its token let go. Null when a
/// read drops (the file gone or changed since it was chosen: see the
/// deviations above).
fn readWhole(allocator: std.mem.Allocator, browser: *platform.BrowserPlatform, picked: *const Picked) error{OutOfMemory}!?[]u8 {
    defer platform.releasePickedFile(browser, picked.token);
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    while (true) {
        const request = try ReadRequest.create(allocator);
        defer request.release();
        platform.readPickedFile(browser, picked.token, bytes.items.len, read_chunk, request.reply());
        var part = request.take() orelse {
            bytes.deinit(allocator);
            return null;
        };
        defer freeBytes(allocator, &part);
        try bytes.appendSlice(allocator, part);
        if (part.len < read_chunk) break;
    }
    return try bytes.toOwnedSlice(allocator);
}

// ---------------------------------------------------------------------------
// The Files
// ---------------------------------------------------------------------------

/// A new File of `realm` holding `bytes` (copied), unwrapped: File's
/// constructor with one ArrayBuffer part, as script's `new File([buffer],
/// name, {type, lastModified})` (null lastModified: now).
fn makeFile(realm: runtime.Context, bytes: []const u8, name: []const u8, mime_type: []const u8, last_modified_ms: ?i64, relative_path: []const u8) !*runtime.Instance {
    const buffer = try engine.createArrayBuffer(realm, bytes);
    defer buffer.release();
    const parts = try engine.createSequenceOfValues(realm, &.{buffer.value});
    defer parts.release();
    const file = try interfaces.File.call_constructor(realm, parts.value, name, .passed(.{
        .base = .{ .type = runtime.DOMString.initInterned(mime_type) },
        .lastModified = last_modified_ms,
    }));
    const generation = runtime.SlabAllocator.generationOf(file);
    errdefer file.releaseIfUnwrapped(generation);
    if (relative_path.len != 0) try dom.blob_bytes.setRelativePath(file, relative_path);
    return file;
}

/// The File for `picked`: its bytes, its name, the platform's type or else
/// the name's well-known one, its modification time in milliseconds.
fn fileOfPicked(realm: runtime.Context, allocator: std.mem.Allocator, browser: *platform.BrowserPlatform, picked: *const Picked) !*runtime.Instance {
    const bytes = try readWhole(allocator, browser, picked);
    defer if (bytes) |b| allocator.free(b);
    const mime_type = if (picked.mime_type.len != 0) picked.mime_type else wellKnownTypeForName(picked.name);
    if (bytes == null) return makeFile(realm, "", picked.name, mime_type, null, picked.relative_path);
    return makeFile(realm, bytes.?, picked.name, mime_type, @divFloor(picked.modified_ns, std.time.ns_per_ms), picked.relative_path);
}

/// The File for the host's `path`: the platform's file, or - a path that
/// names none - a File of that name with no bytes (see the deviations).
fn fileOfPath(realm: runtime.Context, allocator: std.mem.Allocator, browser: *platform.BrowserPlatform, path: []const u8) !*runtime.Instance {
    var picked = (try userFile(allocator, browser, path)) orelse {
        const name = std.fs.path.basename(path);
        return makeFile(realm, "", name, wellKnownTypeForName(name), null, "");
    };
    defer picked.deinit(allocator);
    return fileOfPicked(realm, allocator, browser, &picked);
}

// ---------------------------------------------------------------------------
// The selection
// ---------------------------------------------------------------------------

/// Blink's FileInputType::SetFilesFromPaths(paths) on `input` (an input in
/// the File Upload state): nothing for no paths; with webkitdirectory, the
/// files of the directory `paths[0]` (SetFilesFromDirectory); else a File
/// per path - only the first without `multiple` - then
/// SetFilesAndDispatchEvents.
pub fn setFilesFromPaths(input: *runtime.Instance, paths: []const []const u8) !void {
    if (paths.len == 0) return;
    const realm = input.ctx;
    // Files are made, and the list handed on, through the realm's engine.
    if (!realm.hasEngine()) return error.NoEngine;
    const allocator = realm.allocator;
    const browser = platform_state.of(realm) orelse return error.NoPlatform;
    const list = try interfaces.FileList.init(allocator, realm);
    const list_generation = runtime.SlabAllocator.generationOf(list);
    // Set as the input's files below, the list is the input's; otherwise
    // (an unchanged selection) it goes here.
    defer list.releaseIfUnwrapped(list_generation);

    if (try hasAttribute(input, "webkitdirectory")) {
        if (try userDirectory(allocator, browser, paths[0])) |found| {
            var files = found;
            defer freePickedList(allocator, &files);
            for (files) |*picked| try appendFile(list, try fileOfPicked(realm, allocator, browser, picked));
        }
    } else {
        const count = if (try hasAttribute(input, "multiple")) paths.len else 1;
        for (paths[0..count]) |path| try appendFile(list, try fileOfPath(realm, allocator, browser, path));
    }
    try setFilesAndDispatchEvents(input, list);
}

fn appendFile(list: *runtime.Instance, file: *runtime.Instance) !void {
    const generation = runtime.SlabAllocator.generationOf(file);
    // The list keeps it from here (an edge, dom.file_lists.append).
    defer file.releaseIfUnwrapped(generation);
    try dom.file_lists.append(list, file);
}

fn hasAttribute(element: *runtime.Instance, comptime name: []const u8) !bool {
    return interfaces.Element.call_hasAttribute(element, runtime.DOMString.initInterned(name));
}

/// Blink's SetFilesAndDispatchEvents: the input's files become `list`, and
/// `input` then `change` are fired (bubbling; input composed too) - when the
/// selection changed (FileInputType::SetFiles: another length, or a file not
/// the same as the one at its index); otherwise `cancel` (bubbling).
fn setFilesAndDispatchEvents(input: *runtime.Instance, list: *runtime.Instance) !void {
    if (!try selectionChanged(input, list)) {
        try form_associated.fireSimpleEvent(input, "cancel", .{ .bubbles = true });
        return;
    }
    try interfaces.HTMLInputElement.set_files(input, list);
    try form_associated.fireSimpleEvent(input, "input", .{ .bubbles = true, .composed = true });
    try form_associated.fireSimpleEvent(input, "change", .{ .bubbles = true });
}

/// Whether `list` differs from `input`'s files. Blink's File::HasSameSource
/// compares the files' paths, which a File here does not keep: the name,
/// relative path, size and modification time stand for it.
fn selectionChanged(input: *runtime.Instance, list: *runtime.Instance) !bool {
    const current = (try interfaces.HTMLInputElement.get_files(input)) orelse return true;
    const count = try interfaces.FileList.get_length(list);
    if (count != try interfaces.FileList.get_length(current)) return true;
    for (0..count) |index| {
        const a = (try interfaces.FileList.call_item(list, @intCast(index))) orelse return true;
        const b = (try interfaces.FileList.call_item(current, @intCast(index))) orelse return true;
        if (!try sameFile(a, b)) return true;
    }
    return false;
}

fn sameFile(a: *runtime.Instance, b: *runtime.Instance) !bool {
    // File's name getter answers its own name, borrowed (interned).
    if (!std.mem.eql(u8, (try interfaces.File.get_name(a)).asSlice(), (try interfaces.File.get_name(b)).asSlice())) return false;
    // webkitRelativePath answers a copy the caller frees.
    const a_path = try interfaces.File.get_webkitRelativePath(a);
    defer a.ctx.allocator.free(a_path);
    const b_path = try interfaces.File.get_webkitRelativePath(b);
    defer b.ctx.allocator.free(b_path);
    if (!std.mem.eql(u8, a_path, b_path)) return false;
    if (try interfaces.File.get_lastModified(a) != try interfaces.File.get_lastModified(b)) return false;
    return try interfaces.Blob.get_size(a) == try interfaces.Blob.get_size(b);
}

test "a chosen file's type comes from Chrome's well-known tables, the first match winning, and is empty otherwise" {
    try std.testing.expectEqualStrings("image/png", wellKnownTypeForName("photo.PNG"));
    try std.testing.expectEqualStrings("text/javascript", wellKnownTypeForName("a.b.js"));
    try std.testing.expectEqualStrings("video/webm", wellKnownTypeForName("clip.webm"));
    try std.testing.expectEqualStrings("image/x-icon", wellKnownTypeForName("favicon.ico"));
    try std.testing.expectEqualStrings("text/markdown", wellKnownTypeForName("README.md"));
    try std.testing.expectEqualStrings("", wellKnownTypeForName("Makefile"));
    try std.testing.expectEqualStrings("", wellKnownTypeForName("data.unknownext"));
}
