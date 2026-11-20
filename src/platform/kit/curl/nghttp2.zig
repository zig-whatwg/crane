//! The part of nghttp2's C API (lib/includes/nghttp2/nghttp2.h, nghttp2
//! 1.70.0, build.zig.zon's pin) that kit/curl's WebSocket transport drives
//! an HTTP/2 connection with (websocket_h2.zig). Declared here, as
//! share.zig declares curl's share API: the library is the one build.zig
//! compiles from source and links into libcurl (buildNghttp2), so its
//! symbols are in every binary that links libcurl with HTTP/2 - and this
//! file is only reached when the platform was built with it
//! (platform_options.http2), so a build without HTTP/2 never refers to them.
//! The declarations follow nghttp2.h's types (nghttp2_ssize is ptrdiff_t,
//! enums are C ints); tests/fetch/net3_websocket_h2_test.zig runs a client
//! session against a server session through them.

/// nghttp2_session, nghttp2_session_callbacks, nghttp2_option: opaque.
pub const Session = opaque {};
pub const Callbacks = opaque {};

/// nghttp2_nv.
pub const Nv = extern struct {
    name: [*]const u8,
    value: [*]const u8,
    namelen: usize,
    valuelen: usize,
    flags: u8 = 0,

    pub fn of(name: []const u8, value: []const u8) Nv {
        return .{ .name = name.ptr, .value = value.ptr, .namelen = name.len, .valuelen = value.len };
    }
};

/// nghttp2_frame_hd: the first member of every nghttp2_frame variant (a
/// union), so a frame pointer reads as one.
pub const FrameHd = extern struct {
    length: usize,
    stream_id: i32,
    type: u8,
    flags: u8,
    reserved: u8,
};

/// nghttp2_settings_entry.
pub const SettingsEntry = extern struct {
    settings_id: i32,
    value: u32,
};

/// nghttp2_data_source (a union of `int fd` and `void *ptr`).
pub const DataSource = extern union {
    fd: c_int,
    ptr: ?*anyopaque,
};

/// nghttp2_data_source_read_callback2.
pub const ReadCallback = *const fn (session: *Session, stream_id: i32, buf: [*]u8, length: usize, data_flags: *u32, source: *DataSource, user_data: ?*anyopaque) callconv(.c) isize;

/// nghttp2_data_provider2.
pub const DataProvider = extern struct {
    source: DataSource,
    read_callback: ReadCallback,
};

pub const OnFrameRecv = *const fn (session: *Session, frame: *const FrameHd, user_data: ?*anyopaque) callconv(.c) c_int;
pub const OnDataChunkRecv = *const fn (session: *Session, flags: u8, stream_id: i32, data: [*]const u8, len: usize, user_data: ?*anyopaque) callconv(.c) c_int;
pub const OnStreamClose = *const fn (session: *Session, stream_id: i32, error_code: u32, user_data: ?*anyopaque) callconv(.c) c_int;
pub const OnHeader = *const fn (session: *Session, frame: *const FrameHd, name: [*]const u8, namelen: usize, value: [*]const u8, valuelen: usize, flags: u8, user_data: ?*anyopaque) callconv(.c) c_int;
pub const OnBeginHeaders = *const fn (session: *Session, frame: *const FrameHd, user_data: ?*anyopaque) callconv(.c) c_int;

// nghttp2_frame_type
pub const DATA: u8 = 0x00;
pub const HEADERS: u8 = 0x01;
pub const RST_STREAM: u8 = 0x03;
pub const SETTINGS: u8 = 0x04;
pub const GOAWAY: u8 = 0x07;

// nghttp2_flag
pub const FLAG_NONE: u8 = 0x00;
pub const FLAG_END_STREAM: u8 = 0x01;
pub const FLAG_ACK: u8 = 0x01;

// nghttp2_settings_id
pub const SETTINGS_ENABLE_PUSH: i32 = 0x02;
pub const SETTINGS_ENABLE_CONNECT_PROTOCOL: i32 = 0x08;

// nghttp2_error_code
pub const NO_ERROR: u32 = 0x00;
pub const CANCEL: u32 = 0x08;

// nghttp2_data_flag
pub const DATA_FLAG_EOF: u32 = 0x01;
pub const DATA_FLAG_NO_END_STREAM: u32 = 0x02;

// nghttp2_error
pub const ERR_WOULDBLOCK: c_int = -504;
pub const ERR_DEFERRED: c_int = -508;
pub const ERR_CALLBACK_FAILURE: c_int = -902;

pub extern fn nghttp2_session_callbacks_new(callbacks_ptr: *?*Callbacks) c_int;
pub extern fn nghttp2_session_callbacks_del(callbacks: *Callbacks) void;
pub extern fn nghttp2_session_callbacks_set_on_frame_recv_callback(cbs: *Callbacks, cb: OnFrameRecv) void;
pub extern fn nghttp2_session_callbacks_set_on_data_chunk_recv_callback(cbs: *Callbacks, cb: OnDataChunkRecv) void;
pub extern fn nghttp2_session_callbacks_set_on_stream_close_callback(cbs: *Callbacks, cb: OnStreamClose) void;
pub extern fn nghttp2_session_callbacks_set_on_header_callback(cbs: *Callbacks, cb: OnHeader) void;
pub extern fn nghttp2_session_callbacks_set_on_begin_headers_callback(cbs: *Callbacks, cb: OnBeginHeaders) void;
pub extern fn nghttp2_session_client_new(session_ptr: *?*Session, callbacks: *const Callbacks, user_data: ?*anyopaque) c_int;
pub extern fn nghttp2_session_server_new(session_ptr: *?*Session, callbacks: *const Callbacks, user_data: ?*anyopaque) c_int;
pub extern fn nghttp2_session_del(session: *Session) void;
pub extern fn nghttp2_submit_settings(session: *Session, flags: u8, iv: [*]const SettingsEntry, niv: usize) c_int;
pub extern fn nghttp2_submit_request2(session: *Session, pri_spec: ?*const anyopaque, nva: [*]const Nv, nvlen: usize, data_prd: ?*const DataProvider, stream_user_data: ?*anyopaque) i32;
pub extern fn nghttp2_submit_response2(session: *Session, stream_id: i32, nva: [*]const Nv, nvlen: usize, data_prd: ?*const DataProvider) c_int;
pub extern fn nghttp2_submit_rst_stream(session: *Session, flags: u8, stream_id: i32, error_code: u32) c_int;
pub extern fn nghttp2_session_mem_recv2(session: *Session, in: [*]const u8, inlen: usize) isize;
pub extern fn nghttp2_session_mem_send2(session: *Session, data_ptr: *[*]const u8) isize;
pub extern fn nghttp2_session_resume_data(session: *Session, stream_id: i32) c_int;
pub extern fn nghttp2_session_want_read(session: *Session) c_int;
pub extern fn nghttp2_session_want_write(session: *Session) c_int;
pub extern fn nghttp2_session_get_remote_settings(session: *Session, id: i32) u32;
pub extern fn nghttp2_strerror(lib_error_code: c_int) [*:0]const u8;
