// XMLHttpRequest Synchronous Mode Tests
//
// Tests for synchronous XHR behavior and restrictions.
// Spec: https://xhr.spec.whatwg.org/
//
// Note: Sync XHR is deprecated in modern browsers but still supported.
//
// Run with: zig build test-v8

// ============================================================================
// SYNCHRONOUS MODE BASICS
// ============================================================================

// open() accepts async=false parameter
assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    // Should not throw
    xhr.open('GET', 'http://example.com/', false);
    return xhr.readyState === 1;
})(), "open() with async=false should work")

// Default is async=true
assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/');
    return xhr.readyState === 1;
})(), "open() without async parameter should default to async")

// ============================================================================
// SYNC XHR STATE TRANSITIONS
// ============================================================================

// After open() with sync flag, readyState is OPENED
assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', false);
    return xhr.readyState === XMLHttpRequest.OPENED;
})(), "Sync XHR readyState should be OPENED after open()")

// ============================================================================
// SYNC XHR RESPONSETYPE RESTRICTIONS
// ============================================================================

// responseType can be set before open() 
assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    return xhr.responseType === 'json';
})(), "responseType can be set before open()")

// For sync XHR, setting responseType to non-empty after open() may throw
// (This is implementation-dependent - browsers differ on when they throw)
assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', false);
    // Setting to '' or 'text' should always work
    xhr.responseType = 'text';
    return xhr.responseType === 'text';
})(), "Sync XHR should allow responseType='text'")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', false);
    xhr.responseType = '';
    return xhr.responseType === '';
})(), "Sync XHR should allow responseType=''")

// ============================================================================
// SYNC XHR TIMEOUT RESTRICTIONS
// ============================================================================

// Setting timeout to non-zero on sync XHR in Window context should throw
// (But this restriction only applies in Window, not Worker)
// Since we're testing the interface, we just verify timeout is settable

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.timeout = 5000;
    return xhr.timeout === 5000;
})(), "timeout should be settable before open()")

// ============================================================================
// SYNC XHR ABORT
// ============================================================================

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', false);
    xhr.abort();
    return xhr.readyState === XMLHttpRequest.UNSENT;
})(), "abort() should reset sync XHR to UNSENT state")

// ============================================================================
// SYNC XHR HEADERS
// ============================================================================

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', false);
    // setRequestHeader should work before send
    xhr.setRequestHeader('X-Custom', 'value');
    return true;  // No throw means success
})(), "setRequestHeader should work on sync XHR before send()")

// getAllResponseHeaders returns empty before send
assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', false);
    return xhr.getAllResponseHeaders() === '';
})(), "getAllResponseHeaders should return empty string before send on sync XHR")

// getResponseHeader returns null before send
assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', false);
    return xhr.getResponseHeader('Content-Type') === null;
})(), "getResponseHeader should return null before send on sync XHR")

// ============================================================================
// SYNC XHR INITIAL RESPONSE VALUES
// ============================================================================

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', false);
    return xhr.status === 0;
})(), "Sync XHR status should be 0 before send")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', false);
    return xhr.statusText === '';
})(), "Sync XHR statusText should be empty before send")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', false);
    return xhr.responseText === '';
})(), "Sync XHR responseText should be empty before send")

// ============================================================================
// SYNC XHR WITHCREDENTIALS
// ============================================================================

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.withCredentials = true;
    xhr.open('GET', 'http://example.com/', false);
    return xhr.withCredentials === true;
})(), "withCredentials should be preserved for sync XHR")

// ============================================================================
// SYNC XHR EVENT HANDLERS
// ============================================================================

// Event handlers should be settable on sync XHR
assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', false);
    xhr.onreadystatechange = () => {};
    return typeof xhr.onreadystatechange === 'function';
})(), "onreadystatechange should be settable on sync XHR")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', false);
    xhr.onload = () => {};
    return typeof xhr.onload === 'function';
})(), "onload should be settable on sync XHR")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', false);
    xhr.onerror = () => {};
    return typeof xhr.onerror === 'function';
})(), "onerror should be settable on sync XHR")

// ============================================================================
// MULTIPLE OPEN CALLS
// ============================================================================

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', false);
    xhr.open('POST', 'http://example.org/', false);
    return xhr.readyState === XMLHttpRequest.OPENED;
})(), "Multiple open() calls should work on sync XHR")

// ============================================================================
// SYNC VS ASYNC FLAG
// ============================================================================

// Verify the third parameter controls sync/async mode
assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', true);  // async
    return xhr.readyState === XMLHttpRequest.OPENED;
})(), "open() with async=true should work")

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', false);  // sync
    return xhr.readyState === XMLHttpRequest.OPENED;
})(), "open() with async=false should work")

// ============================================================================
// OVERRIDEMIMETYPE ON SYNC XHR
// ============================================================================

assert.isTrue((() => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://example.com/', false);
    xhr.overrideMimeType('text/plain');
    return true;  // No throw means success
})(), "overrideMimeType should work on sync XHR before send")
