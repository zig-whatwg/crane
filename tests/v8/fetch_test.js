// Comprehensive Fetch API Tests (V8 Integration)
// Tests Fetch Standard implementation via JavaScript
// Spec: https://fetch.spec.whatwg.org/
//
// Run with: zig build test-v8
// Or: ./tests/v8/run_tests.sh
//
// Test format: Each test is an expression that evaluates to true/false.
// The test runner shows the failing expression when a test fails.

// ============================================================================
// HEADERS INTERFACE TESTS (Fetch Standard Section 2.2)
// ============================================================================

// Headers constructor exists
assert.isFunction(Headers, "Headers should be a function")
assert.isNotNull(Headers.prototype, "Headers.prototype should exist")

// Headers constructor - empty
assert.isTrue((() => {
    const h = new Headers();
    return h instanceof Headers;
})(), "new Headers() should create Headers instance")

// Headers constructor - from object
assert.isTrue((() => {
    const h = new Headers({ "Content-Type": "text/plain" });
    return h.get("content-type") === "text/plain";
})(), "Headers from object should work")

// Headers constructor - from array of pairs
assert.isTrue((() => {
    const h = new Headers([["Content-Type", "text/html"], ["X-Custom", "value"]]);
    return h.get("content-type") === "text/html" && h.get("x-custom") === "value";
})(), "Headers from array of pairs should work")

// Headers.append() - adds new header
assert.isTrue((() => {
    const h = new Headers();
    h.append("X-Test", "value1");
    return h.get("x-test") === "value1";
})(), "Headers.append should add new header")

// Headers.append() - appends to existing header
assert.isTrue((() => {
    const h = new Headers();
    h.append("X-Test", "value1");
    h.append("X-Test", "value2");
    return h.get("x-test") === "value1, value2";
})(), "Headers.append should append to existing header")

// Headers.delete() - removes header
assert.isTrue((() => {
    const h = new Headers({ "X-Test": "value" });
    h.delete("x-test");
    return h.get("x-test") === null;
})(), "Headers.delete should remove header")

// Headers.get() - returns null for missing header
assert.isTrue((() => {
    const h = new Headers();
    return h.get("missing") === null;
})(), "Headers.get should return null for missing header")

// Headers.get() - case-insensitive
assert.isTrue((() => {
    const h = new Headers({ "Content-Type": "text/plain" });
    return h.get("CONTENT-TYPE") === "text/plain";
})(), "Headers.get should be case-insensitive")

// Headers.has() - returns true for existing header
assert.isTrue((() => {
    const h = new Headers({ "X-Test": "value" });
    return h.has("x-test") === true;
})(), "Headers.has should return true for existing header")

// Headers.has() - returns false for missing header
assert.isTrue((() => {
    const h = new Headers();
    return h.has("missing") === false;
})(), "Headers.has should return false for missing header")

// Headers.set() - sets new header
assert.isTrue((() => {
    const h = new Headers();
    h.set("X-Test", "value");
    return h.get("x-test") === "value";
})(), "Headers.set should set new header")

// Headers.set() - replaces existing header
assert.isTrue((() => {
    const h = new Headers({ "X-Test": "old" });
    h.set("x-test", "new");
    return h.get("x-test") === "new";
})(), "Headers.set should replace existing header")

// Headers iteration - forEach
assert.isTrue((() => {
    const h = new Headers({ "A": "1", "B": "2" });
    let count = 0;
    h.forEach(() => count++);
    return count === 2;
})(), "Headers.forEach should iterate over entries")

// Headers iteration - entries()
assert.isTrue((() => {
    const h = new Headers({ "X-Test": "value" });
    const entries = [...h.entries()];
    return entries.length === 1 && entries[0][0] === "x-test" && entries[0][1] === "value";
})(), "Headers.entries() should return entries iterator")

// Headers iteration - keys()
assert.isTrue((() => {
    const h = new Headers({ "A": "1", "B": "2" });
    const keys = [...h.keys()];
    return keys.length === 2 && keys.includes("a") && keys.includes("b");
})(), "Headers.keys() should return keys iterator")

// Headers iteration - values()
assert.isTrue((() => {
    const h = new Headers({ "A": "1", "B": "2" });
    const values = [...h.values()];
    return values.length === 2 && values.includes("1") && values.includes("2");
})(), "Headers.values() should return values iterator")

// ============================================================================
// REQUEST INTERFACE TESTS (Fetch Standard Section 2.3)
// ============================================================================

// Request constructor exists
assert.isFunction(Request, "Request should be a function")
assert.isNotNull(Request.prototype, "Request.prototype should exist")

// Request constructor - from URL string
assert.isTrue((() => {
    const r = new Request("https://example.com/path");
    return r instanceof Request && r.url === "https://example.com/path";
})(), "Request from URL string should work")

// Request constructor - with method
assert.isTrue((() => {
    const r = new Request("https://example.com", { method: "POST" });
    return r.method === "POST";
})(), "Request with method should work")

// Request constructor - with headers object
assert.isTrue((() => {
    const r = new Request("https://example.com", {
        headers: { "Content-Type": "application/json" }
    });
    return r.headers.get("content-type") === "application/json";
})(), "Request with headers object should work")

// Request constructor - with Headers instance
assert.isTrue((() => {
    const h = new Headers({ "X-Custom": "value" });
    const r = new Request("https://example.com", { headers: h });
    return r.headers.get("x-custom") === "value";
})(), "Request with Headers instance should work")

// Request constructor - with body (string)
assert.isTrue((() => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "test data"
    });
    return r.body !== null && typeof r.body === "object";
})(), "Request with body should work")

// Request.method - GET by default
assert.isTrue((() => {
    const r = new Request("https://example.com");
    return r.method === "GET";
})(), "Request.method should default to GET")

// Request.method - normalized to uppercase
assert.isTrue((() => {
    const r = new Request("https://example.com", { method: "post" });
    return r.method === "POST";
})(), "Request.method should be normalized to uppercase")

// Request.url - full URL
assert.isTrue((() => {
    const r = new Request("https://example.com:8080/path?query=value#fragment");
    return r.url === "https://example.com:8080/path?query=value#fragment";
})(), "Request.url should contain full URL")

// Request.headers - returns Headers instance
assert.isTrue((() => {
    const r = new Request("https://example.com");
    return r.headers instanceof Headers;
})(), "Request.headers should return Headers instance")

// Request.headers - cached (same instance)
assert.isTrue((() => {
    const r = new Request("https://example.com");
    return r.headers === r.headers;
})(), "Request.headers should be cached")

// Request.bodyUsed - false initially
assert.isTrue((() => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "test"
    });
    return r.bodyUsed === false;
})(), "Request.bodyUsed should be false initially")

// Request.mode - default is "cors"
assert.isTrue((() => {
    const r = new Request("https://example.com");
    return r.mode === "cors";
})(), "Request.mode should default to 'cors'")

// Request.mode - can be set
assert.isTrue((() => {
    const r = new Request("https://example.com", { mode: "no-cors" });
    return r.mode === "no-cors";
})(), "Request.mode can be set")

// Request.credentials - default is "same-origin"
assert.isTrue((() => {
    const r = new Request("https://example.com");
    return r.credentials === "same-origin";
})(), "Request.credentials should default to 'same-origin'")

// Request.credentials - can be set
assert.isTrue((() => {
    const r = new Request("https://example.com", { credentials: "include" });
    return r.credentials === "include";
})(), "Request.credentials can be set")

// Request.cache - default is "default"
assert.isTrue((() => {
    const r = new Request("https://example.com");
    return r.cache === "default";
})(), "Request.cache should default to 'default'")

// Request.redirect - default is "follow"
assert.isTrue((() => {
    const r = new Request("https://example.com");
    return r.redirect === "follow";
})(), "Request.redirect should default to 'follow'")

// Request.integrity - empty by default
assert.isTrue((() => {
    const r = new Request("https://example.com");
    return r.integrity === "";
})(), "Request.integrity should be empty by default")

// Request.integrity - can be set
assert.isTrue((() => {
    const r = new Request("https://example.com", {
        integrity: "sha256-abc123"
    });
    return r.integrity === "sha256-abc123";
})(), "Request.integrity can be set")

// Request.keepalive - false by default
assert.isTrue((() => {
    const r = new Request("https://example.com");
    return r.keepalive === false;
})(), "Request.keepalive should be false by default")

// Request.clone() - creates new instance
assert.isTrue((() => {
    const r1 = new Request("https://example.com", { method: "POST" });
    const r2 = r1.clone();
    return r2 instanceof Request && r2 !== r1;
})(), "Request.clone() should create new instance")

// Request.clone() - preserves URL
assert.isTrue((() => {
    const r1 = new Request("https://example.com/path");
    const r2 = r1.clone();
    return r2.url === r1.url;
})(), "Request.clone() should preserve URL")

// Request.clone() - preserves method
assert.isTrue((() => {
    const r1 = new Request("https://example.com", { method: "POST" });
    const r2 = r1.clone();
    return r2.method === "POST";
})(), "Request.clone() should preserve method")

// Request.clone() - preserves headers
assert.isTrue((() => {
    const r1 = new Request("https://example.com", {
        headers: { "X-Test": "value" }
    });
    const r2 = r1.clone();
    return r2.headers.get("x-test") === "value";
})(), "Request.clone() should preserve headers")

// ============================================================================
// RESPONSE INTERFACE TESTS (Fetch Standard Section 2.4)
// ============================================================================

// Response constructor exists
assert.isFunction(Response, "Response should be a function")
assert.isNotNull(Response.prototype, "Response.prototype should exist")

// Response constructor - empty
assert.isTrue((() => {
    const r = new Response();
    return r instanceof Response;
})(), "new Response() should create Response instance")

// Response constructor - with body (string)
assert.isTrue((() => {
    const r = new Response("test data");
    return r.body !== null;
})(), "Response with body should work")

// Response constructor - with status
assert.isTrue((() => {
    const r = new Response(null, { status: 404 });
    return r.status === 404;
})(), "Response with status should work")

// Response constructor - with statusText
assert.isTrue((() => {
    const r = new Response(null, { status: 404, statusText: "Not Found" });
    return r.statusText === "Not Found";
})(), "Response with statusText should work")

// Response constructor - with headers
assert.isTrue((() => {
    const r = new Response(null, {
        headers: { "Content-Type": "text/html" }
    });
    return r.headers.get("content-type") === "text/html";
})(), "Response with headers should work")

// Response.status - 200 by default
assert.isTrue((() => {
    const r = new Response();
    return r.status === 200;
})(), "Response.status should default to 200")

// Response.statusText - "OK" by default
assert.isTrue((() => {
    const r = new Response();
    return r.statusText === "OK";
})(), "Response.statusText should default to 'OK'")

// Response.ok - true for 200-299
assert.isTrue((() => {
    const r = new Response(null, { status: 200 });
    return r.ok === true;
})(), "Response.ok should be true for 200")

// Response.ok - false for 404
assert.isTrue((() => {
    const r = new Response(null, { status: 404 });
    return r.ok === false;
})(), "Response.ok should be false for 404")

// Response.headers - returns Headers instance
assert.isTrue((() => {
    const r = new Response();
    return r.headers instanceof Headers;
})(), "Response.headers should return Headers instance")

// Response.headers - cached (same instance)
assert.isTrue((() => {
    const r = new Response();
    return r.headers === r.headers;
})(), "Response.headers should be cached")

// Response.bodyUsed - false initially
assert.isTrue((() => {
    const r = new Response("test");
    return r.bodyUsed === false;
})(), "Response.bodyUsed should be false initially")

// Response.type - default is "default"
assert.isTrue((() => {
    const r = new Response();
    return r.type === "default";
})(), "Response.type should default to 'default'")

// Response.redirected - false by default
assert.isTrue((() => {
    const r = new Response();
    return r.redirected === false;
})(), "Response.redirected should be false by default")

// Response.clone() - creates new instance
assert.isTrue((() => {
    const r1 = new Response("test", { status: 201 });
    const r2 = r1.clone();
    return r2 instanceof Response && r2 !== r1;
})(), "Response.clone() should create new instance")

// Response.clone() - preserves status
assert.isTrue((() => {
    const r1 = new Response(null, { status: 404 });
    const r2 = r1.clone();
    return r2.status === 404;
})(), "Response.clone() should preserve status")

// Response.clone() - preserves statusText
assert.isTrue((() => {
    const r1 = new Response(null, { status: 404, statusText: "Not Found" });
    const r2 = r1.clone();
    return r2.statusText === "Not Found";
})(), "Response.clone() should preserve statusText")

// Response.clone() - preserves headers
assert.isTrue((() => {
    const r1 = new Response(null, {
        headers: { "X-Custom": "value" }
    });
    const r2 = r1.clone();
    return r2.headers.get("x-custom") === "value";
})(), "Response.clone() should preserve headers")

// Response.error() - creates network error response
assert.isTrue((() => {
    const r = Response.error();
    return r instanceof Response && r.type === "error";
})(), "Response.error() should create error response")

// Response.redirect() - creates redirect response
assert.isTrue((() => {
    const r = Response.redirect("https://example.com", 302);
    return r.status === 302 && r.headers.get("location") === "https://example.com";
})(), "Response.redirect() should create redirect response")

// ============================================================================
// BODY MIXIN TESTS - text() (Fetch Standard Section 2.1)
// ============================================================================

// Request.text() - returns Promise
assert.isTrue((() => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "test data"
    });
    return r.text() instanceof Promise;
})(), "Request.text() should return Promise")

// Request.text() - resolves with string
assert.isTrue((async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "hello world"
    });
    const text = await r.text();
    return text === "hello world";
})(), "Request.text() should resolve with string")

// Response.text() - returns Promise
assert.isTrue((() => {
    const r = new Response("test data");
    return r.text() instanceof Promise;
})(), "Response.text() should return Promise")

// Response.text() - resolves with string
assert.isTrue((async () => {
    const r = new Response("hello world");
    const text = await r.text();
    return text === "hello world";
})(), "Response.text() should resolve with string")

// Response.text() - empty body returns empty string
assert.isTrue((async () => {
    const r = new Response();
    const text = await r.text();
    return text === "";
})(), "Response.text() with empty body should return empty string")

// ============================================================================
// BODY MIXIN TESTS - json() (Fetch Standard Section 2.1)
// ============================================================================

// Request.json() - returns Promise
assert.isTrue((() => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: JSON.stringify({ key: "value" })
    });
    return r.json() instanceof Promise;
})(), "Request.json() should return Promise")

// Request.json() - parses JSON object
assert.isTrue((async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: JSON.stringify({ name: "test", value: 123 })
    });
    const data = await r.json();
    return data.name === "test" && data.value === 123;
})(), "Request.json() should parse JSON object")

// Response.json() - returns Promise
assert.isTrue((() => {
    const r = new Response(JSON.stringify({ key: "value" }));
    return r.json() instanceof Promise;
})(), "Response.json() should return Promise")

// Response.json() - parses JSON object
assert.isTrue((async () => {
    const r = new Response(JSON.stringify({ name: "test", value: 123 }));
    const data = await r.json();
    return data.name === "test" && data.value === 123;
})(), "Response.json() should parse JSON object")

// Response.json() - parses JSON array
assert.isTrue((async () => {
    const r = new Response(JSON.stringify([1, 2, 3]));
    const data = await r.json();
    return Array.isArray(data) && data.length === 3 && data[0] === 1;
})(), "Response.json() should parse JSON array")

// Response.json() - rejects on invalid JSON
assert.isTrue((async () => {
    const r = new Response("not valid json");
    try {
        await r.json();
        return false; // Should have thrown
    } catch (e) {
        return e.name === "SyntaxError";
    }
})(), "Response.json() should reject on invalid JSON")

// ============================================================================
// BODY MIXIN TESTS - arrayBuffer() (Fetch Standard Section 2.1)
// ============================================================================

// Request.arrayBuffer() - returns Promise
assert.isTrue((() => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "test data"
    });
    return r.arrayBuffer() instanceof Promise;
})(), "Request.arrayBuffer() should return Promise")

// Request.arrayBuffer() - resolves with ArrayBuffer
assert.isTrue((async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "hello"
    });
    const buffer = await r.arrayBuffer();
    return buffer instanceof ArrayBuffer && buffer.byteLength === 5;
})(), "Request.arrayBuffer() should resolve with ArrayBuffer")

// Response.arrayBuffer() - returns Promise
assert.isTrue((() => {
    const r = new Response("test data");
    return r.arrayBuffer() instanceof Promise;
})(), "Response.arrayBuffer() should return Promise")

// Response.arrayBuffer() - resolves with ArrayBuffer
assert.isTrue((async () => {
    const r = new Response("hello");
    const buffer = await r.arrayBuffer();
    return buffer instanceof ArrayBuffer && buffer.byteLength === 5;
})(), "Response.arrayBuffer() should resolve with ArrayBuffer")

// Response.arrayBuffer() - empty body returns empty ArrayBuffer
assert.isTrue((async () => {
    const r = new Response();
    const buffer = await r.arrayBuffer();
    return buffer instanceof ArrayBuffer && buffer.byteLength === 0;
})(), "Response.arrayBuffer() with empty body should return empty ArrayBuffer")

// ============================================================================
// BODY MIXIN TESTS - blob() (Fetch Standard Section 2.1)
// ============================================================================

// Request.blob() - returns Promise
assert.isTrue((() => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "test data"
    });
    return r.blob() instanceof Promise;
})(), "Request.blob() should return Promise")

// Request.blob() - resolves with Blob
assert.isTrue((async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "hello world"
    });
    const blob = await r.blob();
    return blob instanceof Blob && blob.size === 11;
})(), "Request.blob() should resolve with Blob")

// Response.blob() - returns Promise
assert.isTrue((() => {
    const r = new Response("test data");
    return r.blob() instanceof Promise;
})(), "Response.blob() should return Promise")

// Response.blob() - resolves with Blob
assert.isTrue((async () => {
    const r = new Response("hello world");
    const blob = await r.blob();
    return blob instanceof Blob && blob.size === 11;
})(), "Response.blob() should resolve with Blob")

// Response.blob() - preserves Content-Type
assert.isTrue((async () => {
    const r = new Response("test", {
        headers: { "Content-Type": "text/plain" }
    });
    const blob = await r.blob();
    return blob.type === "text/plain";
})(), "Response.blob() should preserve Content-Type")

// Response.blob() - empty body returns empty Blob
assert.isTrue((async () => {
    const r = new Response();
    const blob = await r.blob();
    return blob instanceof Blob && blob.size === 0;
})(), "Response.blob() with empty body should return empty Blob")

// ============================================================================
// BODY MIXIN TESTS - bytes() (Fetch Standard Section 2.1)
// ============================================================================

// Request.bytes() - returns Promise
assert.isTrue((() => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "test data"
    });
    return r.bytes() instanceof Promise;
})(), "Request.bytes() should return Promise")

// Request.bytes() - resolves with Uint8Array
assert.isTrue((async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "hello"
    });
    const bytes = await r.bytes();
    return bytes instanceof Uint8Array && bytes.length === 5;
})(), "Request.bytes() should resolve with Uint8Array")

// Response.bytes() - returns Promise
assert.isTrue((() => {
    const r = new Response("test data");
    return r.bytes() instanceof Promise;
})(), "Response.bytes() should return Promise")

// Response.bytes() - resolves with Uint8Array
assert.isTrue((async () => {
    const r = new Response("hello");
    const bytes = await r.bytes();
    return bytes instanceof Uint8Array && bytes.length === 5;
})(), "Response.bytes() should resolve with Uint8Array")

// Response.bytes() - correct byte values
assert.isTrue((async () => {
    const r = new Response("ABC");
    const bytes = await r.bytes();
    return bytes[0] === 65 && bytes[1] === 66 && bytes[2] === 67; // ASCII values
})(), "Response.bytes() should return correct byte values")

// Response.bytes() - empty body returns empty Uint8Array
assert.isTrue((async () => {
    const r = new Response();
    const bytes = await r.bytes();
    return bytes instanceof Uint8Array && bytes.length === 0;
})(), "Response.bytes() with empty body should return empty Uint8Array")

// ============================================================================
// BODY MIXIN TESTS - formData() (Fetch Standard Section 2.1)
// ============================================================================

// Request.formData() - returns Promise
assert.isTrue((() => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "key1=value1&key2=value2",
        headers: { "Content-Type": "application/x-www-form-urlencoded" }
    });
    return r.formData() instanceof Promise;
})(), "Request.formData() should return Promise")

// Request.formData() - parses URL-encoded data
assert.isTrue((async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "name=John&age=30",
        headers: { "Content-Type": "application/x-www-form-urlencoded" }
    });
    const formData = await r.formData();
    return formData instanceof FormData &&
           formData.get("name") === "John" &&
           formData.get("age") === "30";
})(), "Request.formData() should parse URL-encoded data")

// Request.formData() - handles special characters
assert.isTrue((async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "message=hello+world&special=%40%23%24",
        headers: { "Content-Type": "application/x-www-form-urlencoded" }
    });
    const formData = await r.formData();
    return formData.get("message") === "hello world" &&
           formData.get("special") === "@#$";
})(), "Request.formData() should handle special characters")

// Request.formData() - parses multipart/form-data
assert.isTrue((async () => {
    const boundary = "----WebKitFormBoundary123";
    const body =
        `--${boundary}\r\n` +
        `Content-Disposition: form-data; name="field1"\r\n` +
        `\r\n` +
        `value1\r\n` +
        `--${boundary}\r\n` +
        `Content-Disposition: form-data; name="field2"\r\n` +
        `\r\n` +
        `value2\r\n` +
        `--${boundary}--`;
    
    const r = new Request("https://example.com", {
        method: "POST",
        body: body,
        headers: { "Content-Type": `multipart/form-data; boundary=${boundary}` }
    });
    const formData = await r.formData();
    return formData instanceof FormData &&
           formData.get("field1") === "value1" &&
           formData.get("field2") === "value2";
})(), "Request.formData() should parse multipart/form-data")

// Response.formData() - returns Promise
assert.isTrue((() => {
    const r = new Response("key=value", {
        headers: { "Content-Type": "application/x-www-form-urlencoded" }
    });
    return r.formData() instanceof Promise;
})(), "Response.formData() should return Promise")

// Response.formData() - parses URL-encoded data
assert.isTrue((async () => {
    const r = new Response("name=Alice&city=NYC", {
        headers: { "Content-Type": "application/x-www-form-urlencoded" }
    });
    const formData = await r.formData();
    return formData instanceof FormData &&
           formData.get("name") === "Alice" &&
           formData.get("city") === "NYC";
})(), "Response.formData() should parse URL-encoded data")

// Response.formData() - parses multipart/form-data
assert.isTrue((async () => {
    const boundary = "boundary123";
    const body =
        `--${boundary}\r\n` +
        `Content-Disposition: form-data; name="username"\r\n` +
        `\r\n` +
        `johndoe\r\n` +
        `--${boundary}--`;
    
    const r = new Response(body, {
        headers: { "Content-Type": `multipart/form-data; boundary=${boundary}` }
    });
    const formData = await r.formData();
    return formData instanceof FormData && formData.get("username") === "johndoe";
})(), "Response.formData() should parse multipart/form-data")

// Response.formData() - handles file upload in multipart
assert.isTrue((async () => {
    const boundary = "boundary123";
    const body =
        `--${boundary}\r\n` +
        `Content-Disposition: form-data; name="file"; filename="test.txt"\r\n` +
        `Content-Type: text/plain\r\n` +
        `\r\n` +
        `file contents here\r\n` +
        `--${boundary}--`;
    
    const r = new Response(body, {
        headers: { "Content-Type": `multipart/form-data; boundary=${boundary}` }
    });
    const formData = await r.formData();
    return formData instanceof FormData && formData.has("file");
})(), "Response.formData() should handle file upload")

// ============================================================================
// FORMDATA INTERFACE TESTS (XHR Standard)
// ============================================================================

// FormData constructor exists
assert.isFunction(FormData, "FormData should be a function")
assert.isNotNull(FormData.prototype, "FormData.prototype should exist")

// FormData constructor - empty
assert.isTrue((() => {
    const fd = new FormData();
    return fd instanceof FormData;
})(), "new FormData() should create FormData instance")

// FormData.append() - adds entry
assert.isTrue((() => {
    const fd = new FormData();
    fd.append("key", "value");
    return fd.get("key") === "value";
})(), "FormData.append should add entry")

// FormData.append() - allows duplicate keys
assert.isTrue((() => {
    const fd = new FormData();
    fd.append("key", "value1");
    fd.append("key", "value2");
    const values = fd.getAll("key");
    return values.length === 2 && values[0] === "value1" && values[1] === "value2";
})(), "FormData.append should allow duplicate keys")

// FormData.delete() - removes all entries with key
assert.isTrue((() => {
    const fd = new FormData();
    fd.append("key", "value1");
    fd.append("key", "value2");
    fd.delete("key");
    return fd.get("key") === null;
})(), "FormData.delete should remove all entries with key")

// FormData.get() - returns first value
assert.isTrue((() => {
    const fd = new FormData();
    fd.append("key", "value1");
    fd.append("key", "value2");
    return fd.get("key") === "value1";
})(), "FormData.get should return first value")

// FormData.get() - returns null for missing key
assert.isTrue((() => {
    const fd = new FormData();
    return fd.get("missing") === null;
})(), "FormData.get should return null for missing key")

// FormData.getAll() - returns all values
assert.isTrue((() => {
    const fd = new FormData();
    fd.append("key", "value1");
    fd.append("key", "value2");
    fd.append("key", "value3");
    const values = fd.getAll("key");
    return Array.isArray(values) && values.length === 3;
})(), "FormData.getAll should return all values")

// FormData.getAll() - returns empty array for missing key
assert.isTrue((() => {
    const fd = new FormData();
    const values = fd.getAll("missing");
    return Array.isArray(values) && values.length === 0;
})(), "FormData.getAll should return empty array for missing key")

// FormData.has() - returns true for existing key
assert.isTrue((() => {
    const fd = new FormData();
    fd.append("key", "value");
    return fd.has("key") === true;
})(), "FormData.has should return true for existing key")

// FormData.has() - returns false for missing key
assert.isTrue((() => {
    const fd = new FormData();
    return fd.has("missing") === false;
})(), "FormData.has should return false for missing key")

// FormData.set() - sets single value
assert.isTrue((() => {
    const fd = new FormData();
    fd.set("key", "value");
    return fd.get("key") === "value";
})(), "FormData.set should set single value")

// FormData.set() - replaces all existing values
assert.isTrue((() => {
    const fd = new FormData();
    fd.append("key", "value1");
    fd.append("key", "value2");
    fd.set("key", "new");
    const values = fd.getAll("key");
    return values.length === 1 && values[0] === "new";
})(), "FormData.set should replace all existing values")

// ============================================================================
// BODY USAGE TRACKING TESTS
// ============================================================================

// Request.bodyUsed - becomes true after reading
assert.isTrue((async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "test"
    });
    await r.text();
    return r.bodyUsed === true;
})(), "Request.bodyUsed should be true after reading")

// Request - cannot read body twice
assert.isTrue((async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "test"
    });
    await r.text();
    try {
        await r.text();
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})(), "Request cannot read body twice")

// Response.bodyUsed - becomes true after reading
assert.isTrue((async () => {
    const r = new Response("test");
    await r.text();
    return r.bodyUsed === true;
})(), "Response.bodyUsed should be true after reading")

// Response - cannot read body twice
assert.isTrue((async () => {
    const r = new Response("test");
    await r.text();
    try {
        await r.text();
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})(), "Response cannot read body twice")

// ============================================================================
// REQUEST VALIDATION TESTS
// ============================================================================

// Request - GET cannot have body
assert.isTrue((() => {
    try {
        new Request("https://example.com", {
            method: "GET",
            body: "test"
        });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})(), "GET request cannot have body")

// Request - HEAD cannot have body
assert.isTrue((() => {
    try {
        new Request("https://example.com", {
            method: "HEAD",
            body: "test"
        });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})(), "HEAD request cannot have body")

// Request - invalid URL throws
assert.isTrue((() => {
    try {
        new Request("not a valid url");
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})(), "Invalid URL should throw TypeError")

// Request - only-if-cached requires same-origin mode
assert.isTrue((() => {
    try {
        new Request("https://example.com", {
            cache: "only-if-cached",
            mode: "cors"
        });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})(), "only-if-cached cache requires same-origin mode")

// ============================================================================
// RESPONSE VALIDATION TESTS
// ============================================================================

// Response - invalid status throws (< 200)
assert.isTrue((() => {
    try {
        new Response(null, { status: 100 });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "RangeError";
    }
})(), "Response status < 200 should throw RangeError")

// Response - invalid status throws (> 599)
assert.isTrue((() => {
    try {
        new Response(null, { status: 600 });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "RangeError";
    }
})(), "Response status > 599 should throw RangeError")

// Response - null body status throws (204)
assert.isTrue((() => {
    try {
        new Response("test", { status: 204 });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})(), "Response with body and status 204 should throw TypeError")

// Response - null body status throws (205)
assert.isTrue((() => {
    try {
        new Response("test", { status: 205 });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})(), "Response with body and status 205 should throw TypeError")

// Response - null body status throws (304)
assert.isTrue((() => {
    try {
        new Response("test", { status: 304 });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})(), "Response with body and status 304 should throw TypeError")

// ============================================================================
// INTEGRATION TESTS - Complex Scenarios
// ============================================================================

// Complex Request - all options
assert.isTrue((() => {
    const r = new Request("https://api.example.com/users", {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer token123"
        },
        body: JSON.stringify({ name: "John" }),
        mode: "cors",
        credentials: "include",
        cache: "no-cache",
        redirect: "follow",
        integrity: "sha256-abc",
        keepalive: true
    });
    return r.method === "POST" &&
           r.mode === "cors" &&
           r.credentials === "include" &&
           r.cache === "no-cache" &&
           r.redirect === "follow" &&
           r.integrity === "sha256-abc" &&
           r.keepalive === true &&
           r.headers.get("content-type") === "application/json" &&
           r.headers.get("authorization") === "Bearer token123";
})(), "Complex Request with all options should work")

// Complex Response - all options
assert.isTrue((() => {
    const r = new Response(JSON.stringify({ success: true }), {
        status: 201,
        statusText: "Created",
        headers: {
            "Content-Type": "application/json",
            "X-Request-ID": "req-123"
        }
    });
    return r.status === 201 &&
           r.statusText === "Created" &&
           r.ok === true &&
           r.headers.get("content-type") === "application/json" &&
           r.headers.get("x-request-id") === "req-123";
})(), "Complex Response with all options should work")

// Chain body methods - text then JSON
assert.isTrue((async () => {
    const r1 = new Response(JSON.stringify({ name: "test" }));
    const text = await r1.text();
    
    const r2 = new Response(text);
    const data = await r2.json();
    
    return data.name === "test";
})(), "Chaining body methods should work")

// Clone preserves all body methods
assert.isTrue((async () => {
    const r1 = new Response("hello world");
    const r2 = r1.clone();
    
    const text1 = await r1.text();
    const text2 = await r2.text();
    
    return text1 === "hello world" && text2 === "hello world";
})(), "Clone should preserve body methods")

// Headers iteration maintains order
assert.isTrue((() => {
    const h = new Headers([
        ["Z-Last", "3"],
        ["A-First", "1"],
        ["M-Middle", "2"]
    ]);
    const keys = [...h.keys()];
    // Headers should be sorted alphabetically
    return keys[0] === "a-first" && keys[1] === "m-middle" && keys[2] === "z-last";
})(), "Headers should maintain alphabetical order")

// Multiple FormData entries with same name
assert.isTrue((() => {
    const fd = new FormData();
    fd.append("tags", "javascript");
    fd.append("tags", "webdev");
    fd.append("tags", "fetch");
    const tags = fd.getAll("tags");
    return tags.length === 3 &&
           tags[0] === "javascript" &&
           tags[1] === "webdev" &&
           tags[2] === "fetch";
})(), "Multiple FormData entries with same name should work")

// End of tests marker
assert.isTrue(true, "All fetch tests completed")
