//! Libcurl FFI bindings for Zig
//!
//! Provides minimal bindings for the libcurl easy interface.
//! Only exposes functions needed for WHATWG Fetch implementation.
//!
//! Reference: https://curl.se/libcurl/c/
//!
//! This module wraps the libcurl C API with type-safe Zig bindings,
//! re-exporting only the constants and functions needed for HTTP/HTTPS
//! network requests as required by the WHATWG Fetch specification.

const std = @import("std");

/// Import libcurl C API
pub const c = @cImport({
    @cInclude("curl/curl.h");
});

// =============================================================================
// Type Re-exports
// =============================================================================

/// Opaque handle for an easy (single transfer) session
pub const CURL = c.CURL;

/// Return code for easy interface functions
pub const CURLcode = c.CURLcode;

/// Return code for multi interface functions
pub const CURLMcode = c.CURLMcode;

/// Opaque handle for a multi (concurrent transfers) session
pub const CURLM = c.CURLM;

/// Message returned by curl_multi_info_read
pub const CURLMsg = c.CURLMsg;

/// Linked list for headers and other string lists
pub const curl_slist = c.struct_curl_slist;

/// Information retrieval codes for curl_easy_getinfo
pub const CURLINFO = c.CURLINFO;

/// Option codes for curl_easy_setopt
pub const CURLoption = c.CURLoption;

// =============================================================================
// Error Codes (CURLcode)
// =============================================================================

/// Success - no error
pub const CURLE_OK = c.CURLE_OK;

// DNS errors
/// Failed to resolve proxy
pub const CURLE_COULDNT_RESOLVE_PROXY = c.CURLE_COULDNT_RESOLVE_PROXY;
/// Failed to resolve host
pub const CURLE_COULDNT_RESOLVE_HOST = c.CURLE_COULDNT_RESOLVE_HOST;

// Connection errors
/// Failed to connect to host
pub const CURLE_COULDNT_CONNECT = c.CURLE_COULDNT_CONNECT;
/// Operation timed out
pub const CURLE_OPERATION_TIMEDOUT = c.CURLE_OPERATION_TIMEDOUT;

// TLS/SSL errors
/// SSL connection error
pub const CURLE_SSL_CONNECT_ERROR = c.CURLE_SSL_CONNECT_ERROR;
/// SSL engine not found
pub const CURLE_SSL_ENGINE_NOTFOUND = c.CURLE_SSL_ENGINE_NOTFOUND;
/// SSL engine set failed
pub const CURLE_SSL_ENGINE_SETFAILED = c.CURLE_SSL_ENGINE_SETFAILED;
/// Problem with the local certificate
pub const CURLE_SSL_CERTPROBLEM = c.CURLE_SSL_CERTPROBLEM;
/// Problem with the CA cert
pub const CURLE_SSL_CACERT = c.CURLE_SSL_CACERT;
/// Peer certificate verification failed
pub const CURLE_PEER_FAILED_VERIFICATION = c.CURLE_PEER_FAILED_VERIFICATION;
/// Issuer check failed
pub const CURLE_SSL_ISSUER_ERROR = c.CURLE_SSL_ISSUER_ERROR;
/// Pinned public key mismatch
pub const CURLE_SSL_PINNEDPUBKEYNOTMATCH = c.CURLE_SSL_PINNEDPUBKEYNOTMATCH;

// Transfer errors
/// Failure receiving network data
pub const CURLE_RECV_ERROR = c.CURLE_RECV_ERROR;
/// Failed sending network data
pub const CURLE_SEND_ERROR = c.CURLE_SEND_ERROR;
/// Server returned nothing
pub const CURLE_GOT_NOTHING = c.CURLE_GOT_NOTHING;

// Protocol errors
/// Unsupported protocol
pub const CURLE_UNSUPPORTED_PROTOCOL = c.CURLE_UNSUPPORTED_PROTOCOL;
/// HTTP response code >= 400
pub const CURLE_HTTP_RETURNED_ERROR = c.CURLE_HTTP_RETURNED_ERROR;
/// Weird server reply
pub const CURLE_WEIRD_SERVER_REPLY = c.CURLE_WEIRD_SERVER_REPLY;

// Other errors
/// Redirect loop or max redirects exceeded
pub const CURLE_TOO_MANY_REDIRECTS = c.CURLE_TOO_MANY_REDIRECTS;
/// URL malformed
pub const CURLE_URL_MALFORMAT = c.CURLE_URL_MALFORMAT;
/// Bad function argument
pub const CURLE_BAD_FUNCTION_ARGUMENT = c.CURLE_BAD_FUNCTION_ARGUMENT;
/// Transfer aborted by callback
pub const CURLE_ABORTED_BY_CALLBACK = c.CURLE_ABORTED_BY_CALLBACK;
/// Out of memory
pub const CURLE_OUT_OF_MEMORY = c.CURLE_OUT_OF_MEMORY;

// =============================================================================
// Option Codes (CURLoption)
// =============================================================================

// URL and method
/// URL to work with
pub const CURLOPT_URL = c.CURLOPT_URL;
/// Custom HTTP method (e.g., "DELETE", "PATCH")
pub const CURLOPT_CUSTOMREQUEST = c.CURLOPT_CUSTOMREQUEST;

// Headers
/// Linked list of headers
pub const CURLOPT_HTTPHEADER = c.CURLOPT_HTTPHEADER;

// Request body
/// POST data as string
pub const CURLOPT_POSTFIELDS = c.CURLOPT_POSTFIELDS;
/// Size of POST data
pub const CURLOPT_POSTFIELDSIZE = c.CURLOPT_POSTFIELDSIZE;
/// Size of POST data (large files)
pub const CURLOPT_POSTFIELDSIZE_LARGE = c.CURLOPT_POSTFIELDSIZE_LARGE;

// Response callbacks
/// Write callback function
pub const CURLOPT_WRITEFUNCTION = c.CURLOPT_WRITEFUNCTION;
/// User data for write callback
pub const CURLOPT_WRITEDATA = c.CURLOPT_WRITEDATA;
/// Header callback function
pub const CURLOPT_HEADERFUNCTION = c.CURLOPT_HEADERFUNCTION;
/// User data for header callback
pub const CURLOPT_HEADERDATA = c.CURLOPT_HEADERDATA;

// Timeouts
/// Total timeout in milliseconds
pub const CURLOPT_TIMEOUT_MS = c.CURLOPT_TIMEOUT_MS;
/// Connection timeout in milliseconds
pub const CURLOPT_CONNECTTIMEOUT_MS = c.CURLOPT_CONNECTTIMEOUT_MS;

// Redirects (WHATWG Fetch handles these manually)
/// Follow redirects automatically
pub const CURLOPT_FOLLOWLOCATION = c.CURLOPT_FOLLOWLOCATION;
/// Maximum number of redirects
pub const CURLOPT_MAXREDIRS = c.CURLOPT_MAXREDIRS;

// TLS/SSL options
/// Verify server's certificate
pub const CURLOPT_SSL_VERIFYPEER = c.CURLOPT_SSL_VERIFYPEER;
/// Verify server's hostname
pub const CURLOPT_SSL_VERIFYHOST = c.CURLOPT_SSL_VERIFYHOST;
/// Path to CA certificate bundle
pub const CURLOPT_CAINFO = c.CURLOPT_CAINFO;
/// Path to CA certificates directory
pub const CURLOPT_CAPATH = c.CURLOPT_CAPATH;
/// Client certificate file
pub const CURLOPT_SSLCERT = c.CURLOPT_SSLCERT;
/// Client private key file
pub const CURLOPT_SSLKEY = c.CURLOPT_SSLKEY;
/// SSL version to use
pub const CURLOPT_SSLVERSION = c.CURLOPT_SSLVERSION;
/// Enable/disable SSL session-ID caching (0 = disable, 1 = enable)
pub const CURLOPT_SSL_SESSIONID_CACHE = c.CURLOPT_SSL_SESSIONID_CACHE;

// Proxy options
/// Proxy URL
pub const CURLOPT_PROXY = c.CURLOPT_PROXY;
/// Proxy user:password
pub const CURLOPT_PROXYUSERPWD = c.CURLOPT_PROXYUSERPWD;
/// Hosts to bypass proxy
pub const CURLOPT_NOPROXY = c.CURLOPT_NOPROXY;

// HTTP version
/// HTTP version to use
pub const CURLOPT_HTTP_VERSION = c.CURLOPT_HTTP_VERSION;

// Encoding/compression
/// Accept-Encoding header (empty = all supported)
pub const CURLOPT_ACCEPT_ENCODING = c.CURLOPT_ACCEPT_ENCODING;

// Debugging
/// Verbose output
pub const CURLOPT_VERBOSE = c.CURLOPT_VERBOSE;
/// Debug callback function
pub const CURLOPT_DEBUGFUNCTION = c.CURLOPT_DEBUGFUNCTION;
/// User data for debug callback
pub const CURLOPT_DEBUGDATA = c.CURLOPT_DEBUGDATA;

// Connection options
/// Force a new connection (don't reuse cached)
pub const CURLOPT_FRESH_CONNECT = c.CURLOPT_FRESH_CONNECT;
/// Close connection after use (don't pool)
pub const CURLOPT_FORBID_REUSE = c.CURLOPT_FORBID_REUSE;

// Progress/abort
/// Disable progress meter
pub const CURLOPT_NOPROGRESS = c.CURLOPT_NOPROGRESS;
/// Progress callback function
pub const CURLOPT_XFERINFOFUNCTION = c.CURLOPT_XFERINFOFUNCTION;
/// User data for progress callback
pub const CURLOPT_XFERINFODATA = c.CURLOPT_XFERINFODATA;

// =============================================================================
// Info Codes (CURLINFO) for curl_easy_getinfo
// =============================================================================

/// HTTP response code
pub const CURLINFO_RESPONSE_CODE = c.CURLINFO_RESPONSE_CODE;
/// Total time of transfer (seconds)
pub const CURLINFO_TOTAL_TIME = c.CURLINFO_TOTAL_TIME;
/// Time for name lookup (seconds)
pub const CURLINFO_NAMELOOKUP_TIME = c.CURLINFO_NAMELOOKUP_TIME;
/// Time to connect (seconds)
pub const CURLINFO_CONNECT_TIME = c.CURLINFO_CONNECT_TIME;
/// Time to SSL/TLS handshake (seconds)
pub const CURLINFO_APPCONNECT_TIME = c.CURLINFO_APPCONNECT_TIME;
/// Time until transfer began (seconds)
pub const CURLINFO_PRETRANSFER_TIME = c.CURLINFO_PRETRANSFER_TIME;
/// Time to first byte (seconds)
pub const CURLINFO_STARTTRANSFER_TIME = c.CURLINFO_STARTTRANSFER_TIME;
/// Time spent in redirects (seconds)
pub const CURLINFO_REDIRECT_TIME = c.CURLINFO_REDIRECT_TIME;
/// Number of redirects followed
pub const CURLINFO_REDIRECT_COUNT = c.CURLINFO_REDIRECT_COUNT;
/// Remote IP address
pub const CURLINFO_PRIMARY_IP = c.CURLINFO_PRIMARY_IP;
/// Remote port
pub const CURLINFO_PRIMARY_PORT = c.CURLINFO_PRIMARY_PORT;
/// Effective URL (after redirects)
pub const CURLINFO_EFFECTIVE_URL = c.CURLINFO_EFFECTIVE_URL;
/// HTTP version used
pub const CURLINFO_HTTP_VERSION = c.CURLINFO_HTTP_VERSION;
/// Content-Type from response
pub const CURLINFO_CONTENT_TYPE = c.CURLINFO_CONTENT_TYPE;
/// Content-Length from response
pub const CURLINFO_CONTENT_LENGTH_DOWNLOAD_T = c.CURLINFO_CONTENT_LENGTH_DOWNLOAD_T;
/// Number of new connections made (0 = connection reused)
pub const CURLINFO_NUM_CONNECTS = c.CURLINFO_NUM_CONNECTS;

// =============================================================================
// HTTP Version Constants
// =============================================================================

/// Use whatever version curl decides
pub const CURL_HTTP_VERSION_NONE = c.CURL_HTTP_VERSION_NONE;
/// HTTP/1.0
pub const CURL_HTTP_VERSION_1_0 = c.CURL_HTTP_VERSION_1_0;
/// HTTP/1.1
pub const CURL_HTTP_VERSION_1_1 = c.CURL_HTTP_VERSION_1_1;
/// HTTP/2 (with TLS, negotiated via ALPN)
pub const CURL_HTTP_VERSION_2_0 = c.CURL_HTTP_VERSION_2_0;
/// HTTP/2 over TLS only (falls back to 1.1 for plain HTTP)
pub const CURL_HTTP_VERSION_2TLS = c.CURL_HTTP_VERSION_2TLS;
/// HTTP/2 prior knowledge (no upgrade from 1.1)
pub const CURL_HTTP_VERSION_2_PRIOR_KNOWLEDGE = c.CURL_HTTP_VERSION_2_PRIOR_KNOWLEDGE;
/// HTTP/3 (QUIC)
pub const CURL_HTTP_VERSION_3 = c.CURL_HTTP_VERSION_3;

// =============================================================================
// Cookie Options (CURLOPT)
// =============================================================================

/// Enable cookie engine - read cookies from file (empty string = enable only)
/// Reference: https://curl.se/libcurl/c/CURLOPT_COOKIEFILE.html
pub const CURLOPT_COOKIEFILE = c.CURLOPT_COOKIEFILE;

/// Write cookies to file on curl_easy_cleanup
/// Reference: https://curl.se/libcurl/c/CURLOPT_COOKIEJAR.html
pub const CURLOPT_COOKIEJAR = c.CURLOPT_COOKIEJAR;

/// Add/manipulate individual cookies (Netscape format or Set-Cookie header)
/// Special values: "ALL" (erase all), "SESS" (erase session), "FLUSH" (write to jar), "RELOAD" (reload from file)
/// Reference: https://curl.se/libcurl/c/CURLOPT_COOKIELIST.html
pub const CURLOPT_COOKIELIST = c.CURLOPT_COOKIELIST;

/// Start new cookie session (ignore session cookies from file)
/// Reference: https://curl.se/libcurl/c/CURLOPT_COOKIESESSION.html
pub const CURLOPT_COOKIESESSION = c.CURLOPT_COOKIESESSION;

/// Set share handle for sharing data (cookies, DNS, SSL sessions) between handles
/// Reference: https://curl.se/libcurl/c/CURLOPT_SHARE.html
pub const CURLOPT_SHARE = c.CURLOPT_SHARE;

// =============================================================================
// Cookie Info (CURLINFO)
// =============================================================================

/// Get all known cookies as a linked list (Netscape format)
/// Result: *?*curl_slist - MUST call slist_free_all() on result
/// Reference: https://curl.se/libcurl/c/CURLINFO_COOKIELIST.html
pub const CURLINFO_COOKIELIST = c.CURLINFO_COOKIELIST;

// =============================================================================
// Share Handle Types and Constants (CURLSH)
// =============================================================================

/// Opaque handle for sharing data between CURL easy handles
pub const CURLSH = c.CURLSH;

/// Return code for share interface functions
pub const CURLSHcode = c.CURLSHcode;

/// Success - no error
pub const CURLSHE_OK = c.CURLSHE_OK;
/// Bad option passed
pub const CURLSHE_BAD_OPTION = c.CURLSHE_BAD_OPTION;
/// Share already in use
pub const CURLSHE_IN_USE = c.CURLSHE_IN_USE;
/// Invalid share handle
pub const CURLSHE_INVALID = c.CURLSHE_INVALID;
/// Out of memory
pub const CURLSHE_NOMEM = c.CURLSHE_NOMEM;
/// Feature not built in
pub const CURLSHE_NOT_BUILT_IN = c.CURLSHE_NOT_BUILT_IN;

/// Share handle option: specify data type to share
pub const CURLSHOPT_SHARE = c.CURLSHOPT_SHARE;
/// Share handle option: specify data type to unshare
pub const CURLSHOPT_UNSHARE = c.CURLSHOPT_UNSHARE;
/// Share handle option: set lock function callback
pub const CURLSHOPT_LOCKFUNC = c.CURLSHOPT_LOCKFUNC;
/// Share handle option: set unlock function callback
pub const CURLSHOPT_UNLOCKFUNC = c.CURLSHOPT_UNLOCKFUNC;
/// Share handle option: user data for lock/unlock callbacks
pub const CURLSHOPT_USERDATA = c.CURLSHOPT_USERDATA;

/// Lock data type: cookie data
pub const CURL_LOCK_DATA_COOKIE = c.CURL_LOCK_DATA_COOKIE;
/// Lock data type: DNS cache
pub const CURL_LOCK_DATA_DNS = c.CURL_LOCK_DATA_DNS;
/// Lock data type: SSL session IDs
pub const CURL_LOCK_DATA_SSL_SESSION = c.CURL_LOCK_DATA_SSL_SESSION;
/// Lock data type: connection cache
pub const CURL_LOCK_DATA_CONNECT = c.CURL_LOCK_DATA_CONNECT;
/// Lock data type: PSL (Public Suffix List)
pub const CURL_LOCK_DATA_PSL = c.CURL_LOCK_DATA_PSL;

/// Lock access type: shared (read) access
pub const CURL_LOCK_ACCESS_SHARED = c.CURL_LOCK_ACCESS_SHARED;
/// Lock access type: exclusive (write) access
pub const CURL_LOCK_ACCESS_SINGLE = c.CURL_LOCK_ACCESS_SINGLE;

// =============================================================================
// Global Init Flags
// =============================================================================

/// Default initialization (SSL + Win32)
pub const CURL_GLOBAL_DEFAULT = c.CURL_GLOBAL_DEFAULT;
/// Initialize SSL
pub const CURL_GLOBAL_SSL = c.CURL_GLOBAL_SSL;
/// Initialize Win32 sockets
pub const CURL_GLOBAL_WIN32 = c.CURL_GLOBAL_WIN32;
/// Initialize everything
pub const CURL_GLOBAL_ALL = c.CURL_GLOBAL_ALL;
/// Initialize nothing (manual setup)
pub const CURL_GLOBAL_NOTHING = c.CURL_GLOBAL_NOTHING;

// =============================================================================
// Multi Interface Error Codes (CURLMcode)
// =============================================================================

/// Success - no error
pub const CURLM_OK = c.CURLM_OK;
/// Bad handle passed to function
pub const CURLM_BAD_HANDLE = c.CURLM_BAD_HANDLE;
/// Bad easy handle passed
pub const CURLM_BAD_EASY_HANDLE = c.CURLM_BAD_EASY_HANDLE;
/// Out of memory
pub const CURLM_OUT_OF_MEMORY = c.CURLM_OUT_OF_MEMORY;
/// Internal error
pub const CURLM_INTERNAL_ERROR = c.CURLM_INTERNAL_ERROR;
/// Bad socket passed
pub const CURLM_BAD_SOCKET = c.CURLM_BAD_SOCKET;
/// Unknown option
pub const CURLM_UNKNOWN_OPTION = c.CURLM_UNKNOWN_OPTION;
/// Message returned (used by curl_multi_info_read)
pub const CURLMSG_DONE = c.CURLMSG_DONE;

// =============================================================================
// Multi Interface Options (CURLMoption)
// =============================================================================

/// Max connections per host
pub const CURLMOPT_MAX_HOST_CONNECTIONS = c.CURLMOPT_MAX_HOST_CONNECTIONS;
/// Max total connections
pub const CURLMOPT_MAX_TOTAL_CONNECTIONS = c.CURLMOPT_MAX_TOTAL_CONNECTIONS;
/// Max pipeline length
pub const CURLMOPT_MAX_PIPELINE_LENGTH = c.CURLMOPT_MAX_PIPELINE_LENGTH;
/// Pipelining enabled (deprecated in HTTP/2)
pub const CURLMOPT_PIPELINING = c.CURLMOPT_PIPELINING;
/// Max connections in cache
pub const CURLMOPT_MAXCONNECTS = c.CURLMOPT_MAXCONNECTS;

// =============================================================================
// Pause Flags
// =============================================================================

/// Pause receiving data
pub const CURLPAUSE_RECV = c.CURLPAUSE_RECV;
/// Pause sending data
pub const CURLPAUSE_SEND = c.CURLPAUSE_SEND;
/// Pause both directions
pub const CURLPAUSE_ALL = c.CURLPAUSE_ALL;
/// Unpause (continue transfer)
pub const CURLPAUSE_CONT = c.CURLPAUSE_CONT;

// =============================================================================
// WebSocket Support (libcurl 7.86.0+)
// =============================================================================
// Reference: https://curl.se/libcurl/c/libcurl-ws.html

/// WebSocket frame flags for curl_ws_send() and curl_ws_frame.flags
/// Text frame (UTF-8 encoded data)
pub const CURLWS_TEXT = c.CURLWS_TEXT;
/// Binary frame (arbitrary data)
pub const CURLWS_BINARY = c.CURLWS_BINARY;
/// Continuation frame (fragment of a larger message)
pub const CURLWS_CONT = c.CURLWS_CONT;
/// Close frame (connection closing)
pub const CURLWS_CLOSE = c.CURLWS_CLOSE;
/// Ping frame (keepalive request)
pub const CURLWS_PING = c.CURLWS_PING;
/// Pong frame (keepalive response)
pub const CURLWS_PONG = c.CURLWS_PONG;
/// Frame offset info is valid in curl_ws_frame
pub const CURLWS_OFFSET = c.CURLWS_OFFSET;
/// Raw WebSocket mode (no automatic frame handling)
pub const CURLWS_RAW_MODE = c.CURLWS_RAW_MODE;

/// WebSocket frame metadata returned by curl_ws_recv() and curl_ws_meta()
/// Reference: https://curl.se/libcurl/c/curl_ws_meta.html
pub const curl_ws_frame = extern struct {
    /// Age of this struct (for versioning)
    age: c_int,
    /// Frame flags (CURLWS_TEXT, CURLWS_BINARY, etc.)
    flags: c_int,
    /// Offset into the message (for fragmented messages, when CURLWS_OFFSET is set)
    offset: c.curl_off_t,
    /// Bytes remaining in this frame
    bytesleft: c.curl_off_t,
    /// Total message length (if known)
    len: usize,
};

/// Connect-only mode values for CURLOPT_CONNECT_ONLY
/// 0 = normal transfer, 1 = HTTP connect only, 2 = WebSocket connect only
pub const CURL_CONNECT_ONLY_WEBSOCKET: c_long = 2;

/// CURLOPT for connect-only mode
pub const CURLOPT_CONNECT_ONLY = c.CURLOPT_CONNECT_ONLY;

// =============================================================================
// Global Functions
// =============================================================================

/// Initialize libcurl globally. Must be called before any other curl function.
/// Thread-safe: NO - call once at program start.
/// Returns CURLE_OK on success.
pub fn global_init(flags: c_long) CURLcode {
    return c.curl_global_init(flags);
}

/// Cleanup libcurl globally. Call at program exit.
/// Thread-safe: NO - call once at program end.
pub fn global_cleanup() void {
    c.curl_global_cleanup();
}

/// Get libcurl version string (e.g., "libcurl/8.15.0")
pub fn version() [*:0]const u8 {
    return c.curl_version();
}

// =============================================================================
// Easy Interface (single transfers)
// =============================================================================

/// Create a new easy handle for a single transfer.
/// Returns null on failure (out of memory).
pub fn easy_init() ?*CURL {
    return c.curl_easy_init();
}

/// Cleanup an easy handle and free all associated resources.
pub fn easy_cleanup(handle: *CURL) void {
    c.curl_easy_cleanup(handle);
}

/// Reset an easy handle to initial state.
/// Reuses the handle without reallocating - more efficient than init/cleanup.
pub fn easy_reset(handle: *CURL) void {
    c.curl_easy_reset(handle);
}

/// Duplicate an easy handle with all its options.
/// Returns null on failure.
pub fn easy_duphandle(handle: *CURL) ?*CURL {
    return c.curl_easy_duphandle(handle);
}

/// Set an option on an easy handle.
/// The value type depends on the option being set.
pub fn easy_setopt(handle: *CURL, option: CURLoption, value: anytype) CURLcode {
    return @call(.auto, c.curl_easy_setopt, .{ handle, option, value });
}

/// Perform the transfer (blocking).
/// Returns CURLE_OK on success, error code on failure.
pub fn easy_perform(handle: *CURL) CURLcode {
    return c.curl_easy_perform(handle);
}

/// Get information about a completed transfer.
/// The out parameter type depends on the info being retrieved.
pub fn easy_getinfo(handle: *CURL, info: CURLINFO, out: anytype) CURLcode {
    return @call(.auto, c.curl_easy_getinfo, .{ handle, info, out });
}

/// Pause or unpause a transfer.
/// Use CURLPAUSE_* constants for the bitmask.
pub fn easy_pause(handle: *CURL, bitmask: c_int) CURLcode {
    return c.curl_easy_pause(handle, bitmask);
}

/// Get human-readable error message for a CURLcode.
pub fn easy_strerror(code: CURLcode) [*:0]const u8 {
    return c.curl_easy_strerror(code);
}

// =============================================================================
// Multi Interface (concurrent transfers)
// =============================================================================

/// Create a new multi handle.
/// Returns null on failure.
pub fn multi_init() ?*CURLM {
    return c.curl_multi_init();
}

/// Cleanup a multi handle and all associated easy handles.
pub fn multi_cleanup(multi_handle: *CURLM) CURLMcode {
    return c.curl_multi_cleanup(multi_handle);
}

/// Add an easy handle to a multi handle.
pub fn multi_add_handle(multi_handle: *CURLM, easy_handle: *CURL) CURLMcode {
    return c.curl_multi_add_handle(multi_handle, easy_handle);
}

/// Remove an easy handle from a multi handle.
pub fn multi_remove_handle(multi_handle: *CURLM, easy_handle: *CURL) CURLMcode {
    return c.curl_multi_remove_handle(multi_handle, easy_handle);
}

/// Perform transfers on all easy handles attached to the multi handle.
/// Non-blocking - call repeatedly until still_running reaches 0.
pub fn multi_perform(multi_handle: *CURLM, still_running: *c_int) CURLMcode {
    return c.curl_multi_perform(multi_handle, still_running);
}

/// Wait for activity on any of the curl handles.
/// Blocks up to timeout_ms milliseconds.
/// Note: extra_fds is not currently supported - pass null for extra_fds and 0 for extra_nfds.
pub fn multi_poll(multi_handle: *CURLM, timeout_ms: c_int, numfds: *c_int) CURLMcode {
    return c.curl_multi_poll(multi_handle, null, 0, timeout_ms, numfds);
}

/// Read information about completed transfers.
/// Returns null when no more messages.
pub fn multi_info_read(multi_handle: *CURLM, msgs_in_queue: *c_int) ?*CURLMsg {
    return c.curl_multi_info_read(multi_handle, msgs_in_queue);
}

/// Set options on a multi handle.
pub fn multi_setopt(multi_handle: *CURLM, option: c.CURLMoption, value: anytype) CURLMcode {
    return @call(.auto, c.curl_multi_setopt, .{ multi_handle, option, value });
}

/// Get human-readable error message for a CURLMcode.
pub fn multi_strerror(code: CURLMcode) [*:0]const u8 {
    return c.curl_multi_strerror(code);
}

// =============================================================================
// Share Interface (shared cookie storage)
// =============================================================================

/// Create a new share handle for sharing data between CURL handles.
/// Returns null on failure (out of memory).
/// Reference: https://curl.se/libcurl/c/curl_share_init.html
pub fn share_init() ?*CURLSH {
    return c.curl_share_init();
}

/// Set options on a share handle.
/// Reference: https://curl.se/libcurl/c/curl_share_setopt.html
pub fn share_setopt(share: *CURLSH, option: c.CURLSHoption, value: anytype) CURLSHcode {
    return @call(.auto, c.curl_share_setopt, .{ share, option, value });
}

/// Clean up a share handle and free all associated resources.
/// Reference: https://curl.se/libcurl/c/curl_share_cleanup.html
pub fn share_cleanup(share: *CURLSH) CURLSHcode {
    return c.curl_share_cleanup(share);
}

/// Get human-readable error message for a CURLSHcode.
/// Reference: https://curl.se/libcurl/c/curl_share_strerror.html
pub fn share_strerror(code: CURLSHcode) [*:0]const u8 {
    return c.curl_share_strerror(code);
}

/// Lock function callback type for thread-safe sharing.
/// Called when curl needs to access shared data.
pub const LockFunction = *const fn (
    handle: *CURL,
    data: c_int, // CURL_LOCK_DATA_*
    access: c_int, // CURL_LOCK_ACCESS_*
    userptr: ?*anyopaque,
) callconv(.C) void;

/// Unlock function callback type for thread-safe sharing.
/// Called when curl is done accessing shared data.
pub const UnlockFunction = *const fn (
    handle: *CURL,
    data: c_int, // CURL_LOCK_DATA_*
    userptr: ?*anyopaque,
) callconv(.C) void;

// =============================================================================
// WebSocket Functions (libcurl 7.86.0+)
// =============================================================================

/// Send a WebSocket frame.
/// Reference: https://curl.se/libcurl/c/curl_ws_send.html
///
/// Parameters:
/// - handle: easy handle with established WebSocket connection
/// - buffer: data to send
/// - buflen: length of data
/// - sent: output - number of bytes sent
/// - fragsize: fragment size (0 = send as single frame)
/// - flags: frame type (CURLWS_TEXT, CURLWS_BINARY, CURLWS_CLOSE, CURLWS_PING, CURLWS_PONG)
///
/// Returns: CURLE_OK on success, error code on failure
/// Note: Use CURLOPT_CONNECT_ONLY=2 to establish WebSocket connection first
pub fn ws_send(handle: *CURL, buffer: [*]const u8, buflen: usize, sent: *usize, fragsize: usize, flags: c_uint) CURLcode {
    // fragsize needs to be curl_off_t (c_long) for the C API
    const fragsize_long: c_long = @intCast(fragsize);
    return c.curl_ws_send(handle, buffer, buflen, sent, fragsize_long, flags);
}

/// Receive a WebSocket frame.
/// Reference: https://curl.se/libcurl/c/curl_ws_recv.html
///
/// Parameters:
/// - handle: easy handle with established WebSocket connection
/// - buffer: buffer to receive data into
/// - buflen: size of buffer
/// - recv: output - number of bytes received
/// - meta: output - pointer to frame metadata (valid until next curl call)
///
/// Returns: CURLE_OK on success, CURLE_AGAIN if no data available, error code on failure
/// Note: Call ws_meta() after recv to get frame information
pub fn ws_recv(handle: *CURL, buffer: [*]u8, buflen: usize, recv_count: *usize, meta: *?*const curl_ws_frame) CURLcode {
    return c.curl_ws_recv(handle, buffer, buflen, recv_count, @ptrCast(meta));
}

/// Get WebSocket frame metadata from the last received frame.
/// Reference: https://curl.se/libcurl/c/curl_ws_meta.html
///
/// Parameters:
/// - handle: easy handle with established WebSocket connection
///
/// Returns: pointer to frame metadata, or null if not in WebSocket mode
/// Note: The returned pointer is only valid until the next curl_ws_recv() call
pub fn ws_meta(handle: *CURL) ?*const curl_ws_frame {
    return @ptrCast(c.curl_ws_meta(handle));
}

// =============================================================================
// String List (for headers)
// =============================================================================

/// Append a string to a curl_slist.
/// Pass null for list to create a new list.
/// Returns null on failure (out of memory).
pub fn slist_append(list: ?*curl_slist, string: [*:0]const u8) ?*curl_slist {
    return c.curl_slist_append(list, string);
}

/// Free an entire curl_slist.
/// Safe to call with null.
pub fn slist_free_all(list: ?*curl_slist) void {
    c.curl_slist_free_all(list);
}

/// Iterator for curl_slist linked list.
/// Provides Zig-idiomatic iteration over cookie lists.
pub const SlistIterator = struct {
    current: ?*curl_slist,

    /// Get the next string in the list.
    /// Returns null when list is exhausted.
    pub fn next(self: *SlistIterator) ?[]const u8 {
        if (self.current) |node| {
            const data = std.mem.span(node.data);
            self.current = node.next;
            return data;
        }
        return null;
    }
};

/// Create an iterator from a curl_slist.
/// Usage: var iter = slistIterator(list); while (iter.next()) |s| { ... }
pub fn slistIterator(list: ?*curl_slist) SlistIterator {
    return .{ .current = list };
}

/// Count items in a curl_slist.
pub fn slistCount(list: ?*curl_slist) usize {
    var count: usize = 0;
    var current = list;
    while (current) |node| {
        count += 1;
        current = node.next;
    }
    return count;
}

// =============================================================================
// Callback Types
// =============================================================================

/// Write callback function type.
/// Called when data is received from the server.
///
/// Parameters:
/// - data: pointer to received data
/// - size: always 1
/// - nmemb: number of bytes received
/// - userdata: user-provided pointer from CURLOPT_WRITEDATA
///
/// Returns: number of bytes handled (should equal size * nmemb to continue)
pub const WriteCallback = *const fn (
    [*]u8, // data pointer
    usize, // size (always 1)
    usize, // nmemb (number of bytes)
    *anyopaque, // userdata
) callconv(.C) usize;

/// Header callback function type.
/// Called for each header line received.
/// Same signature as WriteCallback.
pub const HeaderCallback = WriteCallback;

/// Progress callback function type.
/// Called periodically during transfer to report progress.
///
/// Parameters:
/// - userdata: user-provided pointer from CURLOPT_XFERINFODATA
/// - dltotal: total bytes to download (0 if unknown)
/// - dlnow: bytes downloaded so far
/// - ultotal: total bytes to upload (0 if unknown)
/// - ulnow: bytes uploaded so far
///
/// Returns: 0 to continue, non-zero to abort transfer
pub const ProgressCallback = *const fn (
    *anyopaque, // userdata
    c_longlong, // dltotal
    c_longlong, // dlnow
    c_longlong, // ultotal
    c_longlong, // ulnow
) callconv(.C) c_int;

// =============================================================================
// Helper Functions
// =============================================================================

/// Convert CURLcode to Zig error or success.
pub fn checkCode(code: CURLcode) !void {
    if (code != CURLE_OK) {
        return error.CurlError;
    }
}

/// Get error message as Zig slice.
pub fn getErrorMessage(code: CURLcode) []const u8 {
    return std.mem.span(easy_strerror(code));
}

// =============================================================================
// Tests
// =============================================================================

test "curl_ffi - constants defined" {
    // Verify key constants are available
    try std.testing.expect(CURLE_OK == 0);
    try std.testing.expect(CURL_HTTP_VERSION_1_1 != 0);
    try std.testing.expect(CURLOPT_URL != 0);
    try std.testing.expect(CURLINFO_RESPONSE_CODE != 0);
}

test "curl_ffi - version string" {
    // Note: This test requires libcurl to be linked
    // In a build without curl, this will fail to compile/link
    const ver = version();
    const version_str = std.mem.span(ver);
    try std.testing.expect(std.mem.startsWith(u8, version_str, "libcurl/"));
}

test "curl_ffi - error message" {
    const msg = getErrorMessage(CURLE_COULDNT_CONNECT);
    try std.testing.expect(msg.len > 0);
}

test "curl_ffi - websocket constants defined" {
    // Verify WebSocket constants are available (libcurl 7.86.0+)
    try std.testing.expect(CURLWS_TEXT != 0);
    try std.testing.expect(CURLWS_BINARY != 0);
    try std.testing.expect(CURLWS_CLOSE != 0);
    try std.testing.expect(CURLWS_PING != 0);
    try std.testing.expect(CURLWS_PONG != 0);
    try std.testing.expect(CURL_CONNECT_ONLY_WEBSOCKET == 2);
    try std.testing.expect(CURLOPT_CONNECT_ONLY != 0);
}

test "curl_ffi - websocket frame struct layout" {
    // Verify curl_ws_frame struct is properly defined
    const frame = curl_ws_frame{
        .age = 0,
        .flags = CURLWS_TEXT,
        .offset = 0,
        .bytesleft = 0,
        .len = 0,
    };
    try std.testing.expectEqual(@as(c_int, 0), frame.age);
    try std.testing.expectEqual(CURLWS_TEXT, @as(c_uint, @intCast(frame.flags)));
}

test "curl_ffi - cookie option constants defined" {
    // Verify cookie-related constants are available
    try std.testing.expect(CURLOPT_COOKIEFILE != 0);
    try std.testing.expect(CURLOPT_COOKIEJAR != 0);
    try std.testing.expect(CURLOPT_COOKIELIST != 0);
    try std.testing.expect(CURLOPT_COOKIESESSION != 0);
    try std.testing.expect(CURLOPT_SHARE != 0);
    try std.testing.expect(CURLINFO_COOKIELIST != 0);
}

test "curl_ffi - share handle constants defined" {
    // Verify share handle constants are available
    try std.testing.expectEqual(@as(c_int, 0), CURLSHE_OK);
    try std.testing.expect(CURLSHOPT_SHARE != 0);
    try std.testing.expect(CURLSHOPT_UNSHARE != 0);
    try std.testing.expect(CURL_LOCK_DATA_COOKIE != 0);
    try std.testing.expect(CURL_LOCK_DATA_DNS != 0);
    try std.testing.expect(CURL_LOCK_DATA_SSL_SESSION != 0);
}

test "curl_ffi - slist iterator" {
    // Test with null list
    var iter = slistIterator(null);
    try std.testing.expectEqual(@as(?[]const u8, null), iter.next());

    // Test count with null list
    try std.testing.expectEqual(@as(usize, 0), slistCount(null));
}

test "curl_ffi - share handle lifecycle" {
    // Test share handle creation and cleanup
    const share = share_init() orelse return error.ShareInitFailed;
    defer _ = share_cleanup(share);

    // Enable cookie sharing
    const result = share_setopt(share, CURLSHOPT_SHARE, CURL_LOCK_DATA_COOKIE);
    try std.testing.expect(result == CURLSHE_OK);
}
