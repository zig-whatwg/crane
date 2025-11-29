//! WebIDL dictionary: RequestInit
//!
//! Manually implemented to handle all Fetch spec fields.
//! Spec: https://fetch.spec.whatwg.org/#requestinit

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

/// RequestInit dictionary for Request constructor
/// All fields are optional per the Fetch spec
pub const RequestInit = struct {
    /// HTTP method (GET, POST, etc.)
    method: ?runtime.ByteString = null,

    /// Headers to add to the request
    /// Can be: sequence<sequence<ByteString>>, record<ByteString, ByteString>, or Headers
    headers: ?typedefs.HeadersInit = null,

    /// Request body (BodyInit? = ReadableStream | Blob | BufferSource | FormData | URLSearchParams | USVString)
    /// Using anyopaque for now since BodyInit typedef is complex
    body: ?*const anyopaque = null,

    /// Referrer URL
    referrer: ?runtime.USVString = null,

    /// Referrer policy
    referrerPolicy: ?enums.ReferrerPolicy = null,

    /// Request mode (cors, no-cors, same-origin, navigate)
    mode: ?enums.RequestMode = null,

    /// Credentials mode (omit, same-origin, include)
    credentials: ?enums.RequestCredentials = null,

    /// Cache mode
    cache: ?enums.RequestCache = null,

    /// Redirect mode (follow, error, manual)
    redirect: ?enums.RequestRedirect = null,

    /// Subresource integrity value
    integrity: ?runtime.DOMString = null,

    /// Keep connection alive after page unload
    keepalive: ?bool = null,

    /// AbortSignal to abort the request
    signal: ?*runtime.Instance = null,

    /// Duplex mode (half)
    duplex: ?enums.RequestDuplex = null,

    /// Priority hint (high, low, auto)
    priority: ?enums.RequestPriority = null,

    /// Window (can only be null in spec)
    window: ?*const anyopaque = null,

    /// Private token (implementation detail)
    privateToken: ?*const anyopaque = null,
};
