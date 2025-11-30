// XMLHttpRequest Event Tests
//
// Tests for XHR events and XMLHttpRequestEventTarget.
// Spec: https://xhr.spec.whatwg.org/
//
// Run with: zig build test-v8

// ============================================================================
// XMLHttpRequestEventTarget INTERFACE TESTS
// ============================================================================

// XMLHttpRequestEventTarget exists
assert.isFunction(XMLHttpRequestEventTarget, "XMLHttpRequestEventTarget should be a function")
assert.isNotNull(XMLHttpRequestEventTarget.prototype, "XMLHttpRequestEventTarget.prototype should exist")

// XMLHttpRequestEventTarget extends EventTarget
assert.strictEqual(XMLHttpRequestEventTarget.prototype.__proto__, EventTarget.prototype,
    "XMLHttpRequestEventTarget should extend EventTarget")

// ============================================================================
// XMLHttpRequestUpload INTERFACE TESTS
// ============================================================================

// XMLHttpRequestUpload exists
assert.isFunction(XMLHttpRequestUpload, "XMLHttpRequestUpload should be a function")
assert.isNotNull(XMLHttpRequestUpload.prototype, "XMLHttpRequestUpload.prototype should exist")

// XMLHttpRequestUpload extends XMLHttpRequestEventTarget
assert.strictEqual(XMLHttpRequestUpload.prototype.__proto__, XMLHttpRequestEventTarget.prototype,
    "XMLHttpRequestUpload should extend XMLHttpRequestEventTarget")

// ============================================================================
// PROGRESSEVENT INTERFACE TESTS
// ============================================================================

// ProgressEvent constructor exists
assert.isFunction(ProgressEvent, "ProgressEvent should be a function")
assert.isNotNull(ProgressEvent.prototype, "ProgressEvent.prototype should exist")

// ProgressEvent extends Event
assert.strictEqual(ProgressEvent.prototype.__proto__, Event.prototype,
    "ProgressEvent should extend Event")

// ProgressEvent constructor - creates instance
assert.isTrue((() => {
    const event = new ProgressEvent('progress');
    return event instanceof ProgressEvent;
})(), "new ProgressEvent('progress') should create ProgressEvent instance")

// ProgressEvent has correct type
assert.isTrue((() => {
    const event = new ProgressEvent('progress');
    return event.type === 'progress';
})(), "ProgressEvent type should match constructor argument")

// ProgressEvent default values
assert.isTrue((() => {
    const event = new ProgressEvent('progress');
    return event.lengthComputable === false;
})(), "ProgressEvent lengthComputable should default to false")

assert.isTrue((() => {
    const event = new ProgressEvent('progress');
    return event.loaded === 0;
})(), "ProgressEvent loaded should default to 0")

assert.isTrue((() => {
    const event = new ProgressEvent('progress');
    return event.total === 0;
})(), "ProgressEvent total should default to 0")

// ProgressEvent with options
assert.isTrue((() => {
    const event = new ProgressEvent('progress', {
        lengthComputable: true,
        loaded: 50,
        total: 100
    });
    return event.lengthComputable === true && event.loaded === 50 && event.total === 100;
})(), "ProgressEvent should accept options")

// ============================================================================
// EVENT HANDLER PROPERTIES ON XHR
// ============================================================================

// All event handlers should be settable
assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    let called = false;
    xhr.onloadstart = () => { called = true; };
    return typeof xhr.onloadstart === 'function';
})(), "onloadstart should be settable")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.onprogress = () => {};
    return typeof xhr.onprogress === 'function';
})(), "onprogress should be settable")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.onabort = () => {};
    return typeof xhr.onabort === 'function';
})(), "onabort should be settable")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.onerror = () => {};
    return typeof xhr.onerror === 'function';
})(), "onerror should be settable")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.onload = () => {};
    return typeof xhr.onload === 'function';
})(), "onload should be settable")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.ontimeout = () => {};
    return typeof xhr.ontimeout === 'function';
})(), "ontimeout should be settable")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.onloadend = () => {};
    return typeof xhr.onloadend === 'function';
})(), "onloadend should be settable")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.onreadystatechange = () => {};
    return typeof xhr.onreadystatechange === 'function';
})(), "onreadystatechange should be settable")

// ============================================================================
// EVENT HANDLER PROPERTIES ON UPLOAD
// ============================================================================

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.upload.onloadstart = () => {};
    return typeof xhr.upload.onloadstart === 'function';
})(), "upload.onloadstart should be settable")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.upload.onprogress = () => {};
    return typeof xhr.upload.onprogress === 'function';
})(), "upload.onprogress should be settable")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.upload.onabort = () => {};
    return typeof xhr.upload.onabort === 'function';
})(), "upload.onabort should be settable")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.upload.onerror = () => {};
    return typeof xhr.upload.onerror === 'function';
})(), "upload.onerror should be settable")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.upload.onload = () => {};
    return typeof xhr.upload.onload === 'function';
})(), "upload.onload should be settable")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.upload.ontimeout = () => {};
    return typeof xhr.upload.ontimeout === 'function';
})(), "upload.ontimeout should be settable")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.upload.onloadend = () => {};
    return typeof xhr.upload.onloadend === 'function';
})(), "upload.onloadend should be settable")

// ============================================================================
// ADDEVENTLISTENER ON XHR
// ============================================================================

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return typeof xhr.addEventListener === 'function';
})(), "xhr should have addEventListener")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return typeof xhr.removeEventListener === 'function';
})(), "xhr should have removeEventListener")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return typeof xhr.dispatchEvent === 'function';
})(), "xhr should have dispatchEvent")

// ============================================================================
// ADDEVENTLISTENER ON UPLOAD
// ============================================================================

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return typeof xhr.upload.addEventListener === 'function';
})(), "upload should have addEventListener")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return typeof xhr.upload.removeEventListener === 'function';
})(), "upload should have removeEventListener")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    return typeof xhr.upload.dispatchEvent === 'function';
})(), "upload should have dispatchEvent")

// ============================================================================
// READYSTATECHANGE EVENT
// ============================================================================

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    let called = false;
    xhr.onreadystatechange = () => { called = true; };
    xhr.open('GET', 'http://example.com/');
    return called;
})(), "onreadystatechange should fire on open()")

// ============================================================================
// EVENT TYPES
// ============================================================================

// Verify all XHR event types are valid ProgressEvent types
assert.isTrue((() => {
    const types = ['loadstart', 'progress', 'abort', 'error', 'load', 'timeout', 'loadend'];
    return types.every(type => {
        const event = new ProgressEvent(type);
        return event.type === type;
    });
})(), "All XHR event types should be valid ProgressEvent types")
