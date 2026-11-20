//! A WebSocket over HTTP/2 (RFC 8441), the client side, for kit/curl's
//! WebSocket transport: an nghttp2 client session on a connection curl made
//! and handed over raw (CURLOPT_CONNECT_ONLY with ALPN "h2" - the
//! zig-whatwg/curl fork leaves such a connection without curl's own HTTP/2
//! layer), with one extended CONNECT stream whose DATA frames carry the
//! WebSocket Protocol's bytes (websocket_frames.zig) "as if it were the TCP
//! connection" (RFC 8441 section 5).
//!
//! The model is Firefox's (netwerk/protocol/http/nsHttpConnection.cpp
//! MoveTransactionsToSpdy, nsHttpConnectionMgr.cpp
//! TryDispatchExtendedCONNECTransaction): a WebSocket's connection offers h2
//! in ALPN; when h2 is chosen, the WebSocket waits for the server's SETTINGS,
//! and only a server that sent SETTINGS_ENABLE_CONNECT_PROTOCOL = 1 gets an
//! extended CONNECT (RFC 8441 section 3: "a client MAY use the Extended
//! CONNECT ... upon receipt of" it); one that did not is left for a fresh
//! HTTP/1.1 connection. Chrome uses WebSockets over HTTP/2 too, but only on
//! an HTTP/2 connection it already has (net/http/http_stream_factory_job.cc);
//! the page's connections here are inside libcurl's pool, out of reach.
//!
//! No I/O here: the transport feeds what arrives to `receive` and writes
//! what `output` gives, so tests run a client against an nghttp2 server
//! session in memory. One owner, one thread (the WebSocket's agent's).

const std = @import("std");
const ng = @import("nghttp2.zig");

pub const Field = struct {
    name: []const u8,
    value: []const u8,
};

/// Where the CONNECT goes (RFC 8441 section 5: the target URI's scheme is
/// "https" for wss:, "http" for ws:; the rest is the WebSocket URI's).
pub const Target = struct {
    scheme: []const u8,
    /// host[:port], as Host would carry it.
    authority: []const u8,
    /// "/" path ["?" query].
    path: []const u8,
};

pub const Error = error{ OutOfMemory, ProtocolError };

pub const Session = struct {
    allocator: std.mem.Allocator,
    session: *ng.Session,
    /// The extended CONNECT stream, or 0 before it is submitted.
    stream_id: i32 = 0,
    /// The server's first SETTINGS frame arrived (RFC 8441 section 3: what
    /// the client waits for before it may use the extended CONNECT).
    settings_seen: bool = false,
    /// The response to the CONNECT: its :status (0 until a final one came)
    /// and its fields, OWNED.
    status: u16 = 0,
    fields: std.ArrayList(Field) = .empty,
    response_done: bool = false,
    /// WebSocket bytes the server sent on the stream, not yet decoded.
    in: std.ArrayList(u8) = .empty,
    in_start: usize = 0,
    /// WebSocket bytes for the server, not yet taken by a DATA frame.
    out: std.ArrayList(u8) = .empty,
    out_start: usize = 0,
    /// The data provider ran out and waits for `queue` to resume it.
    deferred: bool = false,
    /// Our side of the stream is ending: END_STREAM after `out` drains.
    ending: bool = false,
    /// The server ended its side of the stream (END_STREAM): RFC 8441
    /// section 5's "orderly TCP-level closure".
    remote_ended: bool = false,
    /// The stream closed (both sides, or a RST_STREAM), with this code.
    closed: bool = false,
    close_code: u32 = ng.NO_ERROR,
    /// A callback ran out of memory: the session is lost.
    out_of_memory: bool = false,

    pub fn init(allocator: std.mem.Allocator) Error!*Session {
        var callbacks: ?*ng.Callbacks = null;
        if (ng.nghttp2_session_callbacks_new(&callbacks) != 0) return error.OutOfMemory;
        defer ng.nghttp2_session_callbacks_del(callbacks.?);
        ng.nghttp2_session_callbacks_set_on_frame_recv_callback(callbacks.?, onFrameRecv);
        ng.nghttp2_session_callbacks_set_on_data_chunk_recv_callback(callbacks.?, onDataChunkRecv);
        ng.nghttp2_session_callbacks_set_on_stream_close_callback(callbacks.?, onStreamClose);
        ng.nghttp2_session_callbacks_set_on_header_callback(callbacks.?, onHeader);

        const self = try allocator.create(Session);
        errdefer allocator.destroy(self);
        var session: ?*ng.Session = null;
        if (ng.nghttp2_session_client_new(&session, callbacks.?, self) != 0) return error.OutOfMemory;
        self.* = .{ .allocator = allocator, .session = session.? };
        errdefer ng.nghttp2_session_del(self.session);
        // The client's connection preface ends in its SETTINGS (RFC 9113
        // 3.4). No server push: nothing here would take a pushed stream.
        const settings = [_]ng.SettingsEntry{.{ .settings_id = ng.SETTINGS_ENABLE_PUSH, .value = 0 }};
        if (ng.nghttp2_submit_settings(self.session, ng.FLAG_NONE, &settings, settings.len) != 0) return error.OutOfMemory;
        return self;
    }

    pub fn deinit(self: *Session) void {
        ng.nghttp2_session_del(self.session);
        for (self.fields.items) |field| {
            self.allocator.free(field.name);
            self.allocator.free(field.value);
        }
        self.fields.deinit(self.allocator);
        self.in.deinit(self.allocator);
        self.out.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Feed what arrived from the server.
    pub fn receive(self: *Session, bytes: []const u8) Error!void {
        if (bytes.len == 0) return;
        const n = ng.nghttp2_session_mem_recv2(self.session, bytes.ptr, bytes.len);
        if (self.out_of_memory) return error.OutOfMemory;
        if (n < 0) return error.ProtocolError;
    }

    /// The next bytes for the server, appended to `wire` until it holds at
    /// least `limit` bytes or the session has nothing more to send.
    pub fn output(self: *Session, wire: *std.ArrayList(u8), limit: usize) Error!void {
        while (wire.items.len < limit) {
            var data: [*]const u8 = undefined;
            const n = ng.nghttp2_session_mem_send2(self.session, &data);
            if (self.out_of_memory) return error.OutOfMemory;
            if (n < 0) return error.ProtocolError;
            if (n == 0) return;
            try wire.appendSlice(self.allocator, data[0..@intCast(n)]);
        }
    }

    /// Whether the server allows an extended CONNECT: the value of its
    /// SETTINGS_ENABLE_CONNECT_PROTOCOL, once its SETTINGS has arrived.
    pub fn extendedConnectAllowed(self: *Session) bool {
        return ng.nghttp2_session_get_remote_settings(self.session, ng.SETTINGS_ENABLE_CONNECT_PROTOCOL) == 1;
    }

    /// Submit the extended CONNECT (RFC 8441 sections 4 and 5): the four
    /// pseudo-header fields and :protocol "websocket", then
    /// sec-websocket-version 13 and the caller's fields, names lowercased
    /// (RFC 9113 8.2.1). No Upgrade, Connection, Host or Sec-WebSocket-Key
    /// (section 5: "MUST NOT be included", and the key processing "has been
    /// superseded by the :protocol pseudo-header field").
    pub fn connect(self: *Session, target: Target, fields: []const Field) Error!void {
        std.debug.assert(self.stream_id == 0);
        var nva: std.ArrayList(ng.Nv) = .empty;
        defer nva.deinit(self.allocator);
        // The lowercased names, kept until nghttp2 has copied them.
        var names: std.ArrayList([]u8) = .empty;
        defer {
            for (names.items) |name| self.allocator.free(name);
            names.deinit(self.allocator);
        }
        try nva.appendSlice(self.allocator, &.{
            .of(":method", "CONNECT"),
            .of(":protocol", "websocket"),
            .of(":scheme", target.scheme),
            .of(":path", target.path),
            .of(":authority", target.authority),
            .of("sec-websocket-version", "13"),
        });
        for (fields) |field| {
            const name = try std.ascii.allocLowerString(self.allocator, field.name);
            names.append(self.allocator, name) catch |err| {
                self.allocator.free(name);
                return err;
            };
            try nva.append(self.allocator, .of(name, field.value));
        }
        const provider: ng.DataProvider = .{ .source = .{ .ptr = self }, .read_callback = readData };
        const id = ng.nghttp2_submit_request2(self.session, null, nva.items.ptr, nva.items.len, &provider, null);
        if (id < 0) return if (id == -901) error.OutOfMemory else error.ProtocolError;
        self.stream_id = id;
    }

    /// Queue WebSocket bytes for the server.
    pub fn queue(self: *Session, bytes: []const u8) Error!void {
        if (self.out_start > 0 and self.out_start == self.out.items.len) {
            self.out.clearRetainingCapacity();
            self.out_start = 0;
        }
        try self.out.appendSlice(self.allocator, bytes);
        self.resumeData();
    }

    /// End our side of the stream once what is queued has gone (END_STREAM:
    /// RFC 8441 section 5's orderly close).
    pub fn end(self: *Session) void {
        self.ending = true;
        self.resumeData();
    }

    /// Reset the stream (RST_STREAM CANCEL: RFC 8441 section 5's abrupt
    /// close), if it is still open.
    pub fn cancel(self: *Session) void {
        if (self.stream_id > 0 and !self.closed) _ = ng.nghttp2_submit_rst_stream(self.session, ng.FLAG_NONE, self.stream_id, ng.CANCEL);
    }

    /// How many queued bytes have not gone into a DATA frame yet.
    pub fn unsent(self: *const Session) usize {
        return self.out.items.len - self.out_start;
    }

    /// The bytes the server sent that the caller has not taken.
    pub fn pending(self: *const Session) []const u8 {
        return self.in.items[self.in_start..];
    }

    /// The caller decoded `n` of `pending()`.
    pub fn consumed(self: *Session, n: usize) void {
        self.in_start += n;
        if (self.in_start == self.in.items.len) {
            self.in.clearRetainingCapacity();
            self.in_start = 0;
        }
    }

    fn resumeData(self: *Session) void {
        if (!self.deferred or self.stream_id <= 0) return;
        self.deferred = false;
        _ = ng.nghttp2_session_resume_data(self.session, self.stream_id);
    }

    fn of(user_data: ?*anyopaque) *Session {
        return @ptrCast(@alignCast(user_data.?));
    }

    fn readData(_: *ng.Session, stream_id: i32, buf: [*]u8, length: usize, data_flags: *u32, source: *ng.DataSource, _: ?*anyopaque) callconv(.c) isize {
        const self: *Session = @ptrCast(@alignCast(source.ptr.?));
        std.debug.assert(stream_id == self.stream_id);
        const available = self.out.items.len - self.out_start;
        if (available == 0) {
            if (self.ending) {
                data_flags.* |= ng.DATA_FLAG_EOF;
                return 0;
            }
            self.deferred = true;
            return ng.ERR_DEFERRED;
        }
        const n = @min(available, length);
        @memcpy(buf[0..n], self.out.items[self.out_start..][0..n]);
        self.out_start += n;
        if (self.out_start == self.out.items.len and self.ending) data_flags.* |= ng.DATA_FLAG_EOF;
        return @intCast(n);
    }

    fn onFrameRecv(_: *ng.Session, frame: *const ng.FrameHd, user_data: ?*anyopaque) callconv(.c) c_int {
        const self = of(user_data);
        switch (frame.type) {
            ng.SETTINGS => if (frame.flags & ng.FLAG_ACK == 0) {
                self.settings_seen = true;
            },
            ng.HEADERS => if (frame.stream_id == self.stream_id) {
                // A final status ends the response head; 1xx heads are
                // interim (RFC 9110 15.2) and their fields are dropped.
                if (!self.response_done) {
                    if (self.status >= 200) {
                        self.response_done = true;
                    } else {
                        self.status = 0;
                        self.clearFields();
                    }
                }
                if (frame.flags & ng.FLAG_END_STREAM != 0) self.remote_ended = true;
            },
            ng.DATA => if (frame.stream_id == self.stream_id and frame.flags & ng.FLAG_END_STREAM != 0) {
                self.remote_ended = true;
            },
            else => {},
        }
        return 0;
    }

    fn onHeader(_: *ng.Session, frame: *const ng.FrameHd, name_ptr: [*]const u8, namelen: usize, value_ptr: [*]const u8, valuelen: usize, _: u8, user_data: ?*anyopaque) callconv(.c) c_int {
        const self = of(user_data);
        if (frame.type != ng.HEADERS or frame.stream_id != self.stream_id or self.response_done) return 0;
        const name = name_ptr[0..namelen];
        const value = value_ptr[0..valuelen];
        if (std.mem.eql(u8, name, ":status")) {
            self.status = std.fmt.parseInt(u16, value, 10) catch 0;
            return 0;
        }
        if (name.len > 0 and name[0] == ':') return 0;
        const name_copy = self.allocator.dupe(u8, name) catch return self.oom();
        const value_copy = self.allocator.dupe(u8, value) catch {
            self.allocator.free(name_copy);
            return self.oom();
        };
        self.fields.append(self.allocator, .{ .name = name_copy, .value = value_copy }) catch {
            self.allocator.free(name_copy);
            self.allocator.free(value_copy);
            return self.oom();
        };
        return 0;
    }

    fn onDataChunkRecv(_: *ng.Session, _: u8, stream_id: i32, data: [*]const u8, len: usize, user_data: ?*anyopaque) callconv(.c) c_int {
        const self = of(user_data);
        if (stream_id != self.stream_id) return 0;
        if (self.in_start > 0 and self.in_start == self.in.items.len) {
            self.in.clearRetainingCapacity();
            self.in_start = 0;
        }
        self.in.appendSlice(self.allocator, data[0..len]) catch return self.oom();
        return 0;
    }

    fn onStreamClose(_: *ng.Session, stream_id: i32, error_code: u32, user_data: ?*anyopaque) callconv(.c) c_int {
        const self = of(user_data);
        if (stream_id != self.stream_id) return 0;
        self.closed = true;
        self.close_code = error_code;
        return 0;
    }

    fn oom(self: *Session) c_int {
        self.out_of_memory = true;
        return ng.ERR_CALLBACK_FAILURE;
    }

    fn clearFields(self: *Session) void {
        for (self.fields.items) |field| {
            self.allocator.free(field.name);
            self.allocator.free(field.value);
        }
        self.fields.clearRetainingCapacity();
    }
};
