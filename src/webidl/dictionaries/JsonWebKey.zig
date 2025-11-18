//! WebIDL dictionary: JsonWebKey
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const JsonWebKey = struct {
    kty: ?runtime.DOMString = null,
    use: ?runtime.DOMString = null,
    key_ops: ?anyopaque = null,
    alg: ?runtime.DOMString = null,
    ext: ?bool = null,
    crv: ?runtime.DOMString = null,
    x: ?runtime.DOMString = null,
    y: ?runtime.DOMString = null,
    d: ?runtime.DOMString = null,
    n: ?runtime.DOMString = null,
    e: ?runtime.DOMString = null,
    p: ?runtime.DOMString = null,
    q: ?runtime.DOMString = null,
    dp: ?runtime.DOMString = null,
    dq: ?runtime.DOMString = null,
    qi: ?runtime.DOMString = null,
    oth: ?anyopaque = null,
    k: ?runtime.DOMString = null,
};
