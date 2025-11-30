// XMLHttpRequest Basic Tests
//
// These tests verify basic XHR functionality.
// Spec: https://xhr.spec.whatwg.org/
//
// Run with: zig build test-v8

// ============================================================================
// XMLHttpRequest INTERFACE TESTS
// ============================================================================

// XMLHttpRequest constructor exists
assert.isFunction(XMLHttpRequest, "XMLHttpRequest should be a function")
assert.isNotNull(XMLHttpRequest.prototype, "XMLHttpRequest.prototype should exist")

// XMLHttpRequest extends EventTarget
assert.strictEqual(XMLHttpRequest.prototype.__proto__, XMLHttpRequestEventTarget.prototype, 
    "XMLHttpRequest should extend XMLHttpRequestEventTarget")

// XMLHttpRequest constructor - creates instance
assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return xhr instanceof XMLHttpRequest;
})(), "new XMLHttpRequest() should create XMLHttpRequest instance")

// ============================================================================
// READY STATE CONSTANTS
// ============================================================================

assert.strictEqual(XMLHttpRequest.UNSENT, 0, "XMLHttpRequest.UNSENT should be 0")
assert.strictEqual(XMLHttpRequest.OPENED, 1, "XMLHttpRequest.OPENED should be 1")
assert.strictEqual(XMLHttpRequest.HEADERS_RECEIVED, 2, "XMLHttpRequest.HEADERS_RECEIVED should be 2")
assert.strictEqual(XMLHttpRequest.LOADING, 3, "XMLHttpRequest.LOADING should be 3")
assert.strictEqual(XMLHttpRequest.DONE, 4, "XMLHttpRequest.DONE should be 4")

// Instance constants
assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return xhr.UNSENT === 0 && xhr.OPENED === 1 && xhr.HEADERS_RECEIVED === 2 && 
           xhr.LOADING === 3 && xhr.DONE === 4;
})(), "Instance should have ready state constants")

// ============================================================================
// INITIAL STATE
// ============================================================================

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return xhr.readyState === 0;
})(), "Initial readyState should be UNSENT (0)")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return xhr.status === 0;
})(), "Initial status should be 0")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return xhr.statusText === "";
})(), "Initial statusText should be empty string")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return xhr.responseText === "";
})(), "Initial responseText should be empty string")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return xhr.responseType === "";
})(), "Initial responseType should be empty string")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return xhr.timeout === 0;
})(), "Initial timeout should be 0")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return xhr.withCredentials === false;
})(), "Initial withCredentials should be false")

// ============================================================================
// OPEN METHOD
// ============================================================================

assert.isFunction(XMLHttpRequest.prototype.open, "XMLHttpRequest.prototype.open should exist")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/');
    return xhr.readyState === 1;
})(), "open() should set readyState to OPENED (1)")

// ============================================================================
// SEND METHOD
// ============================================================================

assert.isFunction(XMLHttpRequest.prototype.send, "XMLHttpRequest.prototype.send should exist")

// ============================================================================
// ABORT METHOD
// ============================================================================

assert.isFunction(XMLHttpRequest.prototype.abort, "XMLHttpRequest.prototype.abort should exist")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/');
    xhr.abort();
    return xhr.readyState === 0;
})(), "abort() should reset readyState to UNSENT (0)")

// ============================================================================
// SETREQUESTHEADER METHOD
// ============================================================================

assert.isFunction(XMLHttpRequest.prototype.setRequestHeader, 
    "XMLHttpRequest.prototype.setRequestHeader should exist")

// ============================================================================
// GETRESPONSEHEADER METHOD
// ============================================================================

assert.isFunction(XMLHttpRequest.prototype.getResponseHeader,
    "XMLHttpRequest.prototype.getResponseHeader should exist")

// ============================================================================
// GETALLRESPONSEHEADERS METHOD
// ============================================================================

assert.isFunction(XMLHttpRequest.prototype.getAllResponseHeaders,
    "XMLHttpRequest.prototype.getAllResponseHeaders should exist")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return xhr.getAllResponseHeaders() === "";
})(), "getAllResponseHeaders() should return empty string before request")

// ============================================================================
// OVERRIDEMIMETYPE METHOD
// ============================================================================

assert.isFunction(XMLHttpRequest.prototype.overrideMimeType,
    "XMLHttpRequest.prototype.overrideMimeType should exist")

// ============================================================================
// UPLOAD PROPERTY
// ============================================================================

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return xhr.upload !== null && xhr.upload !== undefined;
})(), "xhr.upload should exist")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return xhr.upload instanceof XMLHttpRequestUpload;
})(), "xhr.upload should be an XMLHttpRequestUpload instance")

// ============================================================================
// RESPONSETYPE PROPERTY
// ============================================================================

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.responseType = 'text';
    return xhr.responseType === 'text';
})(), "responseType should be settable to 'text'")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.responseType = 'arraybuffer';
    return xhr.responseType === 'arraybuffer';
})(), "responseType should be settable to 'arraybuffer'")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.responseType = 'blob';
    return xhr.responseType === 'blob';
})(), "responseType should be settable to 'blob'")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    return xhr.responseType === 'json';
})(), "responseType should be settable to 'json'")

// ============================================================================
// EVENT HANDLER PROPERTIES
// ============================================================================

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return 'onreadystatechange' in xhr;
})(), "xhr should have onreadystatechange property")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return 'onloadstart' in xhr;
})(), "xhr should have onloadstart property")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return 'onprogress' in xhr;
})(), "xhr should have onprogress property")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return 'onabort' in xhr;
})(), "xhr should have onabort property")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return 'onerror' in xhr;
})(), "xhr should have onerror property")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return 'onload' in xhr;
})(), "xhr should have onload property")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return 'ontimeout' in xhr;
})(), "xhr should have ontimeout property")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return 'onloadend' in xhr;
})(), "xhr should have onloadend property")

// ============================================================================
// TIMEOUT PROPERTY
// ============================================================================

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.timeout = 5000;
    return xhr.timeout === 5000;
})(), "timeout should be settable")

// ============================================================================
// WITHCREDENTIALS PROPERTY
// ============================================================================

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.withCredentials = true;
    return xhr.withCredentials === true;
})(), "withCredentials should be settable to true")
