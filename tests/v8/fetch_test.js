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
typeof Headers === "function"
Headers.prototype !== undefined

// Headers constructor - empty
(() => {
    const h = new Headers();
    return h instanceof Headers;
})()

// Headers constructor - from object
(() => {
    const h = new Headers({ "Content-Type": "text/plain" });
    return h.get("content-type") === "text/plain";
})()

// Headers constructor - from array of pairs
(() => {
    const h = new Headers([["Content-Type", "text/html"], ["X-Custom", "value"]]);
    return h.get("content-type") === "text/html" && h.get("x-custom") === "value";
})()

// Headers.append() - adds new header
(() => {
    const h = new Headers();
    h.append("X-Test", "value1");
    return h.get("x-test") === "value1";
})()

// Headers.append() - appends to existing header
(() => {
    const h = new Headers();
    h.append("X-Test", "value1");
    h.append("X-Test", "value2");
    return h.get("x-test") === "value1, value2";
})()

// Headers.delete() - removes header
(() => {
    const h = new Headers({ "X-Test": "value" });
    h.delete("x-test");
    return h.get("x-test") === null;
})()

// Headers.get() - returns null for missing header
(() => {
    const h = new Headers();
    return h.get("missing") === null;
})()

// Headers.get() - case-insensitive
(() => {
    const h = new Headers({ "Content-Type": "text/plain" });
    return h.get("CONTENT-TYPE") === "text/plain";
})()

// Headers.has() - returns true for existing header
(() => {
    const h = new Headers({ "X-Test": "value" });
    return h.has("x-test") === true;
})()

// Headers.has() - returns false for missing header
(() => {
    const h = new Headers();
    return h.has("missing") === false;
})()

// Headers.set() - sets new header
(() => {
    const h = new Headers();
    h.set("X-Test", "value");
    return h.get("x-test") === "value";
})()

// Headers.set() - replaces existing header
(() => {
    const h = new Headers({ "X-Test": "old" });
    h.set("x-test", "new");
    return h.get("x-test") === "new";
})()

// Headers iteration - forEach
(() => {
    const h = new Headers({ "A": "1", "B": "2" });
    let count = 0;
    h.forEach(() => count++);
    return count === 2;
})()

// Headers iteration - entries()
(() => {
    const h = new Headers({ "X-Test": "value" });
    const entries = [...h.entries()];
    return entries.length === 1 && entries[0][0] === "x-test" && entries[0][1] === "value";
})()

// Headers iteration - keys()
(() => {
    const h = new Headers({ "A": "1", "B": "2" });
    const keys = [...h.keys()];
    return keys.length === 2 && keys.includes("a") && keys.includes("b");
})()

// Headers iteration - values()
(() => {
    const h = new Headers({ "A": "1", "B": "2" });
    const values = [...h.values()];
    return values.length === 2 && values.includes("1") && values.includes("2");
})()

// ============================================================================
// REQUEST INTERFACE TESTS (Fetch Standard Section 2.3)
// ============================================================================

// Request constructor exists
typeof Request === "function"
Request.prototype !== undefined

// Request constructor - from URL string
(() => {
    const r = new Request("https://example.com/path");
    return r instanceof Request && r.url === "https://example.com/path";
})()

// Request constructor - with method
(() => {
    const r = new Request("https://example.com", { method: "POST" });
    return r.method === "POST";
})()

// Request constructor - with headers object
(() => {
    const r = new Request("https://example.com", {
        headers: { "Content-Type": "application/json" }
    });
    return r.headers.get("content-type") === "application/json";
})()

// Request constructor - with Headers instance
(() => {
    const h = new Headers({ "X-Custom": "value" });
    const r = new Request("https://example.com", { headers: h });
    return r.headers.get("x-custom") === "value";
})()

// Request constructor - with body (string)
(() => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "test data"
    });
    return r.body !== null && typeof r.body === "object";
})()

// Request.method - GET by default
(() => {
    const r = new Request("https://example.com");
    return r.method === "GET";
})()

// Request.method - normalized to uppercase
(() => {
    const r = new Request("https://example.com", { method: "post" });
    return r.method === "POST";
})()

// Request.url - full URL
(() => {
    const r = new Request("https://example.com:8080/path?query=value#fragment");
    return r.url === "https://example.com:8080/path?query=value#fragment";
})()

// Request.headers - returns Headers instance
(() => {
    const r = new Request("https://example.com");
    return r.headers instanceof Headers;
})()

// Request.headers - cached (same instance)
(() => {
    const r = new Request("https://example.com");
    return r.headers === r.headers;
})()

// Request.bodyUsed - false initially
(() => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "test"
    });
    return r.bodyUsed === false;
})()

// Request.mode - default is "cors"
(() => {
    const r = new Request("https://example.com");
    return r.mode === "cors";
})()

// Request.mode - can be set
(() => {
    const r = new Request("https://example.com", { mode: "no-cors" });
    return r.mode === "no-cors";
})()

// Request.credentials - default is "same-origin"
(() => {
    const r = new Request("https://example.com");
    return r.credentials === "same-origin";
})()

// Request.credentials - can be set
(() => {
    const r = new Request("https://example.com", { credentials: "include" });
    return r.credentials === "include";
})()

// Request.cache - default is "default"
(() => {
    const r = new Request("https://example.com");
    return r.cache === "default";
})()

// Request.redirect - default is "follow"
(() => {
    const r = new Request("https://example.com");
    return r.redirect === "follow";
})()

// Request.integrity - empty by default
(() => {
    const r = new Request("https://example.com");
    return r.integrity === "";
})()

// Request.integrity - can be set
(() => {
    const r = new Request("https://example.com", {
        integrity: "sha256-abc123"
    });
    return r.integrity === "sha256-abc123";
})()

// Request.keepalive - false by default
(() => {
    const r = new Request("https://example.com");
    return r.keepalive === false;
})()

// Request.clone() - creates new instance
(() => {
    const r1 = new Request("https://example.com", { method: "POST" });
    const r2 = r1.clone();
    return r2 instanceof Request && r2 !== r1;
})()

// Request.clone() - preserves URL
(() => {
    const r1 = new Request("https://example.com/path");
    const r2 = r1.clone();
    return r2.url === r1.url;
})()

// Request.clone() - preserves method
(() => {
    const r1 = new Request("https://example.com", { method: "POST" });
    const r2 = r1.clone();
    return r2.method === "POST";
})()

// Request.clone() - preserves headers
(() => {
    const r1 = new Request("https://example.com", {
        headers: { "X-Test": "value" }
    });
    const r2 = r1.clone();
    return r2.headers.get("x-test") === "value";
})()

// ============================================================================
// RESPONSE INTERFACE TESTS (Fetch Standard Section 2.4)
// ============================================================================

// Response constructor exists
typeof Response === "function"
Response.prototype !== undefined

// Response constructor - empty
(() => {
    const r = new Response();
    return r instanceof Response;
})()

// Response constructor - with body (string)
(() => {
    const r = new Response("test data");
    return r.body !== null;
})()

// Response constructor - with status
(() => {
    const r = new Response(null, { status: 404 });
    return r.status === 404;
})()

// Response constructor - with statusText
(() => {
    const r = new Response(null, { status: 404, statusText: "Not Found" });
    return r.statusText === "Not Found";
})()

// Response constructor - with headers
(() => {
    const r = new Response(null, {
        headers: { "Content-Type": "text/html" }
    });
    return r.headers.get("content-type") === "text/html";
})()

// Response.status - 200 by default
(() => {
    const r = new Response();
    return r.status === 200;
})()

// Response.statusText - "OK" by default
(() => {
    const r = new Response();
    return r.statusText === "OK";
})()

// Response.ok - true for 200-299
(() => {
    const r = new Response(null, { status: 200 });
    return r.ok === true;
})()

// Response.ok - false for 404
(() => {
    const r = new Response(null, { status: 404 });
    return r.ok === false;
})()

// Response.headers - returns Headers instance
(() => {
    const r = new Response();
    return r.headers instanceof Headers;
})()

// Response.headers - cached (same instance)
(() => {
    const r = new Response();
    return r.headers === r.headers;
})()

// Response.bodyUsed - false initially
(() => {
    const r = new Response("test");
    return r.bodyUsed === false;
})()

// Response.type - default is "default"
(() => {
    const r = new Response();
    return r.type === "default";
})()

// Response.redirected - false by default
(() => {
    const r = new Response();
    return r.redirected === false;
})()

// Response.clone() - creates new instance
(() => {
    const r1 = new Response("test", { status: 201 });
    const r2 = r1.clone();
    return r2 instanceof Response && r2 !== r1;
})()

// Response.clone() - preserves status
(() => {
    const r1 = new Response(null, { status: 404 });
    const r2 = r1.clone();
    return r2.status === 404;
})()

// Response.clone() - preserves statusText
(() => {
    const r1 = new Response(null, { status: 404, statusText: "Not Found" });
    const r2 = r1.clone();
    return r2.statusText === "Not Found";
})()

// Response.clone() - preserves headers
(() => {
    const r1 = new Response(null, {
        headers: { "X-Custom": "value" }
    });
    const r2 = r1.clone();
    return r2.headers.get("x-custom") === "value";
})()

// Response.error() - creates network error response
(() => {
    const r = Response.error();
    return r instanceof Response && r.type === "error";
})()

// Response.redirect() - creates redirect response
(() => {
    const r = Response.redirect("https://example.com", 302);
    return r.status === 302 && r.headers.get("location") === "https://example.com";
})()

// ============================================================================
// BODY MIXIN TESTS - text() (Fetch Standard Section 2.1)
// ============================================================================

// Request.text() - returns Promise
(() => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "test data"
    });
    return r.text() instanceof Promise;
})()

// Request.text() - resolves with string
(async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "hello world"
    });
    const text = await r.text();
    return text === "hello world";
})()

// Response.text() - returns Promise
(() => {
    const r = new Response("test data");
    return r.text() instanceof Promise;
})()

// Response.text() - resolves with string
(async () => {
    const r = new Response("hello world");
    const text = await r.text();
    return text === "hello world";
})()

// Response.text() - empty body returns empty string
(async () => {
    const r = new Response();
    const text = await r.text();
    return text === "";
})()

// ============================================================================
// BODY MIXIN TESTS - json() (Fetch Standard Section 2.1)
// ============================================================================

// Request.json() - returns Promise
(() => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: JSON.stringify({ key: "value" })
    });
    return r.json() instanceof Promise;
})()

// Request.json() - parses JSON object
(async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: JSON.stringify({ name: "test", value: 123 })
    });
    const data = await r.json();
    return data.name === "test" && data.value === 123;
})()

// Response.json() - returns Promise
(() => {
    const r = new Response(JSON.stringify({ key: "value" }));
    return r.json() instanceof Promise;
})()

// Response.json() - parses JSON object
(async () => {
    const r = new Response(JSON.stringify({ name: "test", value: 123 }));
    const data = await r.json();
    return data.name === "test" && data.value === 123;
})()

// Response.json() - parses JSON array
(async () => {
    const r = new Response(JSON.stringify([1, 2, 3]));
    const data = await r.json();
    return Array.isArray(data) && data.length === 3 && data[0] === 1;
})()

// Response.json() - rejects on invalid JSON
(async () => {
    const r = new Response("not valid json");
    try {
        await r.json();
        return false; // Should have thrown
    } catch (e) {
        return e.name === "SyntaxError";
    }
})()

// ============================================================================
// BODY MIXIN TESTS - arrayBuffer() (Fetch Standard Section 2.1)
// ============================================================================

// Request.arrayBuffer() - returns Promise
(() => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "test data"
    });
    return r.arrayBuffer() instanceof Promise;
})()

// Request.arrayBuffer() - resolves with ArrayBuffer
(async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "hello"
    });
    const buffer = await r.arrayBuffer();
    return buffer instanceof ArrayBuffer && buffer.byteLength === 5;
})()

// Response.arrayBuffer() - returns Promise
(() => {
    const r = new Response("test data");
    return r.arrayBuffer() instanceof Promise;
})()

// Response.arrayBuffer() - resolves with ArrayBuffer
(async () => {
    const r = new Response("hello");
    const buffer = await r.arrayBuffer();
    return buffer instanceof ArrayBuffer && buffer.byteLength === 5;
})()

// Response.arrayBuffer() - empty body returns empty ArrayBuffer
(async () => {
    const r = new Response();
    const buffer = await r.arrayBuffer();
    return buffer instanceof ArrayBuffer && buffer.byteLength === 0;
})()

// ============================================================================
// BODY MIXIN TESTS - blob() (Fetch Standard Section 2.1)
// ============================================================================

// Request.blob() - returns Promise
(() => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "test data"
    });
    return r.blob() instanceof Promise;
})()

// Request.blob() - resolves with Blob
(async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "hello world"
    });
    const blob = await r.blob();
    return blob instanceof Blob && blob.size === 11;
})()

// Response.blob() - returns Promise
(() => {
    const r = new Response("test data");
    return r.blob() instanceof Promise;
})()

// Response.blob() - resolves with Blob
(async () => {
    const r = new Response("hello world");
    const blob = await r.blob();
    return blob instanceof Blob && blob.size === 11;
})()

// Response.blob() - preserves Content-Type
(async () => {
    const r = new Response("test", {
        headers: { "Content-Type": "text/plain" }
    });
    const blob = await r.blob();
    return blob.type === "text/plain";
})()

// Response.blob() - empty body returns empty Blob
(async () => {
    const r = new Response();
    const blob = await r.blob();
    return blob instanceof Blob && blob.size === 0;
})()

// ============================================================================
// BODY MIXIN TESTS - bytes() (Fetch Standard Section 2.1)
// ============================================================================

// Request.bytes() - returns Promise
(() => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "test data"
    });
    return r.bytes() instanceof Promise;
})()

// Request.bytes() - resolves with Uint8Array
(async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "hello"
    });
    const bytes = await r.bytes();
    return bytes instanceof Uint8Array && bytes.length === 5;
})()

// Response.bytes() - returns Promise
(() => {
    const r = new Response("test data");
    return r.bytes() instanceof Promise;
})()

// Response.bytes() - resolves with Uint8Array
(async () => {
    const r = new Response("hello");
    const bytes = await r.bytes();
    return bytes instanceof Uint8Array && bytes.length === 5;
})()

// Response.bytes() - correct byte values
(async () => {
    const r = new Response("ABC");
    const bytes = await r.bytes();
    return bytes[0] === 65 && bytes[1] === 66 && bytes[2] === 67; // ASCII values
})()

// Response.bytes() - empty body returns empty Uint8Array
(async () => {
    const r = new Response();
    const bytes = await r.bytes();
    return bytes instanceof Uint8Array && bytes.length === 0;
})()

// ============================================================================
// BODY MIXIN TESTS - formData() (Fetch Standard Section 2.1)
// ============================================================================

// Request.formData() - returns Promise
(() => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "key1=value1&key2=value2",
        headers: { "Content-Type": "application/x-www-form-urlencoded" }
    });
    return r.formData() instanceof Promise;
})()

// Request.formData() - parses URL-encoded data
(async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "name=John&age=30",
        headers: { "Content-Type": "application/x-www-form-urlencoded" }
    });
    const formData = await r.formData();
    return formData instanceof FormData &&
           formData.get("name") === "John" &&
           formData.get("age") === "30";
})()

// Request.formData() - handles special characters
(async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "message=hello+world&special=%40%23%24",
        headers: { "Content-Type": "application/x-www-form-urlencoded" }
    });
    const formData = await r.formData();
    return formData.get("message") === "hello world" &&
           formData.get("special") === "@#$";
})()

// Request.formData() - parses multipart/form-data
(async () => {
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
})()

// Response.formData() - returns Promise
(() => {
    const r = new Response("key=value", {
        headers: { "Content-Type": "application/x-www-form-urlencoded" }
    });
    return r.formData() instanceof Promise;
})()

// Response.formData() - parses URL-encoded data
(async () => {
    const r = new Response("name=Alice&city=NYC", {
        headers: { "Content-Type": "application/x-www-form-urlencoded" }
    });
    const formData = await r.formData();
    return formData instanceof FormData &&
           formData.get("name") === "Alice" &&
           formData.get("city") === "NYC";
})()

// Response.formData() - parses multipart/form-data
(async () => {
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
})()

// Response.formData() - handles file upload in multipart
(async () => {
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
})()

// ============================================================================
// FORMDATA INTERFACE TESTS (XHR Standard)
// ============================================================================

// FormData constructor exists
typeof FormData === "function"
FormData.prototype !== undefined

// FormData constructor - empty
(() => {
    const fd = new FormData();
    return fd instanceof FormData;
})()

// FormData.append() - adds entry
(() => {
    const fd = new FormData();
    fd.append("key", "value");
    return fd.get("key") === "value";
})()

// FormData.append() - allows duplicate keys
(() => {
    const fd = new FormData();
    fd.append("key", "value1");
    fd.append("key", "value2");
    const values = fd.getAll("key");
    return values.length === 2 && values[0] === "value1" && values[1] === "value2";
})()

// FormData.delete() - removes all entries with key
(() => {
    const fd = new FormData();
    fd.append("key", "value1");
    fd.append("key", "value2");
    fd.delete("key");
    return fd.get("key") === null;
})()

// FormData.get() - returns first value
(() => {
    const fd = new FormData();
    fd.append("key", "value1");
    fd.append("key", "value2");
    return fd.get("key") === "value1";
})()

// FormData.get() - returns null for missing key
(() => {
    const fd = new FormData();
    return fd.get("missing") === null;
})()

// FormData.getAll() - returns all values
(() => {
    const fd = new FormData();
    fd.append("key", "value1");
    fd.append("key", "value2");
    fd.append("key", "value3");
    const values = fd.getAll("key");
    return Array.isArray(values) && values.length === 3;
})()

// FormData.getAll() - returns empty array for missing key
(() => {
    const fd = new FormData();
    const values = fd.getAll("missing");
    return Array.isArray(values) && values.length === 0;
})()

// FormData.has() - returns true for existing key
(() => {
    const fd = new FormData();
    fd.append("key", "value");
    return fd.has("key") === true;
})()

// FormData.has() - returns false for missing key
(() => {
    const fd = new FormData();
    return fd.has("missing") === false;
})()

// FormData.set() - sets single value
(() => {
    const fd = new FormData();
    fd.set("key", "value");
    return fd.get("key") === "value";
})()

// FormData.set() - replaces all existing values
(() => {
    const fd = new FormData();
    fd.append("key", "value1");
    fd.append("key", "value2");
    fd.set("key", "new");
    const values = fd.getAll("key");
    return values.length === 1 && values[0] === "new";
})()

// ============================================================================
// BODY USAGE TRACKING TESTS
// ============================================================================

// Request.bodyUsed - becomes true after reading
(async () => {
    const r = new Request("https://example.com", {
        method: "POST",
        body: "test"
    });
    await r.text();
    return r.bodyUsed === true;
})()

// Request - cannot read body twice
(async () => {
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
})()

// Response.bodyUsed - becomes true after reading
(async () => {
    const r = new Response("test");
    await r.text();
    return r.bodyUsed === true;
})()

// Response - cannot read body twice
(async () => {
    const r = new Response("test");
    await r.text();
    try {
        await r.text();
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})()

// ============================================================================
// REQUEST VALIDATION TESTS
// ============================================================================

// Request - GET cannot have body
(() => {
    try {
        new Request("https://example.com", {
            method: "GET",
            body: "test"
        });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})()

// Request - HEAD cannot have body
(() => {
    try {
        new Request("https://example.com", {
            method: "HEAD",
            body: "test"
        });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})()

// Request - invalid URL throws
(() => {
    try {
        new Request("not a valid url");
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})()

// Request - only-if-cached requires same-origin mode
(() => {
    try {
        new Request("https://example.com", {
            cache: "only-if-cached",
            mode: "cors"
        });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})()

// ============================================================================
// RESPONSE VALIDATION TESTS
// ============================================================================

// Response - invalid status throws (< 200)
(() => {
    try {
        new Response(null, { status: 100 });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "RangeError";
    }
})()

// Response - invalid status throws (> 599)
(() => {
    try {
        new Response(null, { status: 600 });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "RangeError";
    }
})()

// Response - null body status throws (204)
(() => {
    try {
        new Response("test", { status: 204 });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})()

// Response - null body status throws (205)
(() => {
    try {
        new Response("test", { status: 205 });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})()

// Response - null body status throws (304)
(() => {
    try {
        new Response("test", { status: 304 });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})()

// ============================================================================
// INTEGRATION TESTS - Complex Scenarios
// ============================================================================

// Complex Request - all options
(() => {
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
})()

// Complex Response - all options
(() => {
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
})()

// Chain body methods - text then JSON
(async () => {
    const r1 = new Response(JSON.stringify({ name: "test" }));
    const text = await r1.text();
    
    const r2 = new Response(text);
    const data = await r2.json();
    
    return data.name === "test";
})()

// Clone preserves all body methods
(async () => {
    const r1 = new Response("hello world");
    const r2 = r1.clone();
    
    const text1 = await r1.text();
    const text2 = await r2.text();
    
    return text1 === "hello world" && text2 === "hello world";
})()

// Headers iteration maintains order
(() => {
    const h = new Headers([
        ["Z-Last", "3"],
        ["A-First", "1"],
        ["M-Middle", "2"]
    ]);
    const keys = [...h.keys()];
    // Headers should be sorted alphabetically
    return keys[0] === "a-first" && keys[1] === "m-middle" && keys[2] === "z-last";
})()

// Multiple FormData entries with same name
(() => {
    const fd = new FormData();
    fd.append("tags", "javascript");
    fd.append("tags", "webdev");
    fd.append("tags", "fetch");
    const tags = fd.getAll("tags");
    return tags.length === 3 &&
           tags[0] === "javascript" &&
           tags[1] === "webdev" &&
           tags[2] === "fetch";
})()

// End of tests marker
true
