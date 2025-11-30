// Fetch Integration Tests with Mock HTTP Server
// Tests actual fetch() calls against a local mock server
// Spec: https://fetch.spec.whatwg.org/
//
// Prerequisites: Mock HTTP server running on localhost:8080
// Run with: zig build test-v8-fetch
//
// These tests make REAL network requests to a mock server, testing:
// - Actual fetch() function calls
// - HTTP request/response round-trips
// - Network error handling
// - CORS behavior
// - Redirect handling
// - Various status codes

// Simple async test runner
const tests = [];
let passed = 0;
let failed = 0;

function test(name, fn) {
    tests.push({ name, fn });
}

async function runTests() {
    console.log("Running fetch integration tests...\n");
    const failures = [];
    
    for (const t of tests) {
        try {
            const result = await t.fn();
            if (result === true) {
                passed++;
            } else {
                failed++;
                failures.push("FAIL: " + t.name + " (returned " + result + ")");
            }
        } catch (e) {
            failed++;
            failures.push("ERROR: " + t.name + " (" + e.message + ")");
        }
    }
    
    // Print failures at the end for visibility
    if (failures.length > 0) {
        console.log("Failures:");
        for (const f of failures) {
            console.log("  " + f);
        }
        console.log("");
    }
    
    console.log(passed + "/" + (passed + failed) + " tests passed");
    return failed === 0;
}

// ============================================================================
// BASIC FETCH TESTS
// ============================================================================

// fetch() function exists
test("fetch() function exists", () => {
    return typeof fetch === "function";
});

// fetch() returns Promise
test("fetch() returns Promise", () => {
    const promise = fetch("http://localhost:8080/api/test");
    return promise instanceof Promise;
});

// fetch() - simple GET request
test("fetch() returns Response for simple GET", async () => {
    const response = await fetch("http://localhost:8080/api/test");
    return response instanceof Response;
});

// fetch() - response has correct status
test("fetch() response has correct status", async () => {
    const response = await fetch("http://localhost:8080/api/test");
    return response.status === 200;
});

// fetch() - response is ok
test("fetch() response is ok", async () => {
    const response = await fetch("http://localhost:8080/api/test");
    return response.ok === true;
});

// fetch() - can read response body
test("fetch() response body is readable", async () => {
    const response = await fetch("http://localhost:8080/api/test");
    const text = await response.text();
    return typeof text === "string" && text.length > 0;
});

// ============================================================================
// JSON API TESTS
// ============================================================================

// fetch() - GET JSON data
test("fetch() GET JSON data", async () => {
    const response = await fetch("http://localhost:8080/api/users");
    const data = await response.json();
    return Array.isArray(data) && data.length > 0;
});

// fetch() - POST JSON data
test("fetch() POST JSON data", async () => {
    const response = await fetch("http://localhost:8080/api/users", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify({ name: "John Doe", email: "john@example.com" })
    });
    return response.status === 201;
});

// fetch() - response includes correct headers
test("fetch() response includes correct headers", async () => {
    const response = await fetch("http://localhost:8080/api/users");
    const ct = response.headers.get("content-type");
    return ct === "application/json";
});

// fetch() - complex JSON response
test("fetch() handles complex JSON response", async () => {
    const response = await fetch("http://localhost:8080/api/users/123");
    const user = await response.json();
    return user.id === 123 && !!user.name && !!user.email;
});

// ============================================================================
// HTTP METHODS TESTS
// ============================================================================

// fetch() - GET method (default)
test("fetch() GET method works", async () => {
    const response = await fetch("http://localhost:8080/api/test");
    return response.status === 200;
});

// fetch() - POST method
test("fetch() POST method works", async () => {
    const response = await fetch("http://localhost:8080/api/posts", {
        method: "POST",
        body: "test data"
    });
    return response.status === 201;
});

// fetch() - PUT method
test("fetch() PUT method works", async () => {
    const response = await fetch("http://localhost:8080/api/posts/1", {
        method: "PUT",
        body: JSON.stringify({ title: "Updated" })
    });
    return response.status === 200;
});

// fetch() - PATCH method
test("fetch() PATCH method works", async () => {
    const response = await fetch("http://localhost:8080/api/posts/1", {
        method: "PATCH",
        body: JSON.stringify({ title: "Patched" })
    });
    return response.status === 200;
});

// fetch() - DELETE method
test("fetch() DELETE method works", async () => {
    const response = await fetch("http://localhost:8080/api/posts/1", {
        method: "DELETE"
    });
    return response.status === 204;
});

// fetch() - HEAD method
test("fetch() HEAD method works", async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        method: "HEAD"
    });
    return response.status === 200;
});

// ============================================================================
// REQUEST HEADERS TESTS
// ============================================================================

// fetch() - custom headers sent
test("fetch() sends custom headers", async () => {
    const response = await fetch("http://localhost:8080/echo/headers", {
        headers: {
            "X-Custom-Header": "test-value",
            "Authorization": "Bearer token123"
        }
    });
    const echoed = await response.json();
    // Headers may be echoed with original case
    return (echoed["x-custom-header"] === "test-value" || echoed["X-Custom-Header"] === "test-value") &&
           (echoed["authorization"] === "Bearer token123" || echoed["Authorization"] === "Bearer token123");
});

// fetch() - Content-Type header
test("fetch() sends Content-Type header", async () => {
    const response = await fetch("http://localhost:8080/echo/headers", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify({ key: "value" })
    });
    const echoed = await response.json();
    // Headers may be echoed with original case
    return echoed["content-type"] === "application/json" || echoed["Content-Type"] === "application/json";
});

// ============================================================================
// RESPONSE STATUS TESTS
// ============================================================================

// fetch() - 200 OK
test("fetch() handles 200 OK", async () => {
    const response = await fetch("http://localhost:8080/status/200");
    return response.status === 200 && response.ok === true;
});

// fetch() - 201 Created
test("fetch() handles 201 Created", async () => {
    const response = await fetch("http://localhost:8080/status/201");
    return response.status === 201 && response.ok === true;
});

// fetch() - 204 No Content
test("fetch() handles 204 No Content", async () => {
    const response = await fetch("http://localhost:8080/status/204");
    return response.status === 204 && response.ok === true;
});

// fetch() - 400 Bad Request
test("fetch() handles 400 Bad Request", async () => {
    const response = await fetch("http://localhost:8080/status/400");
    return response.status === 400 && response.ok === false;
});

// fetch() - 401 Unauthorized
test("fetch() handles 401 Unauthorized", async () => {
    const response = await fetch("http://localhost:8080/status/401");
    return response.status === 401 && response.ok === false;
});

// fetch() - 403 Forbidden
test("fetch() handles 403 Forbidden", async () => {
    const response = await fetch("http://localhost:8080/status/403");
    return response.status === 403 && response.ok === false;
});

// fetch() - 404 Not Found
test("fetch() handles 404 Not Found", async () => {
    const response = await fetch("http://localhost:8080/status/404");
    return response.status === 404 && response.ok === false;
});

// fetch() - 500 Internal Server Error
test("fetch() handles 500 Internal Server Error", async () => {
    const response = await fetch("http://localhost:8080/status/500");
    return response.status === 500 && response.ok === false;
});

// fetch() - 503 Service Unavailable
test("fetch() handles 503 Service Unavailable", async () => {
    const response = await fetch("http://localhost:8080/status/503");
    return response.status === 503 && response.ok === false;
});

// ============================================================================
// REDIRECT TESTS
// ============================================================================

// fetch() - follows redirects by default
test("fetch() follows redirects by default", async () => {
    const response = await fetch("http://localhost:8080/redirect/permanent");
    return response.status === 200 && response.redirected === true;
});

// fetch() - redirect sets final URL
test("fetch() redirect sets final URL", async () => {
    const response = await fetch("http://localhost:8080/redirect/permanent");
    return response.url === "http://localhost:8080/redirect/target";
});

// fetch() - 301 Moved Permanently
test("fetch() handles 301 redirect", async () => {
    const response = await fetch("http://localhost:8080/redirect/301");
    return response.redirected === true;
});

// fetch() - 302 Found
test("fetch() handles 302 redirect", async () => {
    const response = await fetch("http://localhost:8080/redirect/302");
    return response.redirected === true;
});

// fetch() - 307 Temporary Redirect
test("fetch() handles 307 redirect", async () => {
    const response = await fetch("http://localhost:8080/redirect/307");
    return response.redirected === true;
});

// fetch() - redirect: "manual" doesn't follow
test("fetch() redirect:'manual' does not follow", async () => {
    const response = await fetch("http://localhost:8080/redirect/permanent", {
        redirect: "manual"
    });
    return response.status === 301 && response.redirected === false;
});

// fetch() - redirect: "error" throws on redirect
test("fetch() redirect:'error' throws on redirect", async () => {
    try {
        await fetch("http://localhost:8080/redirect/permanent", {
            redirect: "error"
        });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
});

// ============================================================================
// BODY FORMATS TESTS
// ============================================================================

// fetch() - text/plain response
test("fetch() handles text/plain response", async () => {
    const response = await fetch("http://localhost:8080/content/text");
    const text = await response.text();
    return text === "Hello, World!";
});

// fetch() - application/json response
test("fetch() handles application/json response", async () => {
    const response = await fetch("http://localhost:8080/content/json");
    const data = await response.json();
    return data.message === "success";
});

// fetch() - POST with text body
test("fetch() POST with text body", async () => {
    const response = await fetch("http://localhost:8080/echo/body", {
        method: "POST",
        body: "plain text data"
    });
    const echoed = await response.text();
    return echoed === "plain text data";
});

// fetch() - POST with JSON body
test("fetch() POST with JSON body", async () => {
    const response = await fetch("http://localhost:8080/echo/body", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ key: "value", number: 42 })
    });
    const echoed = await response.json();
    return echoed.key === "value" && echoed.number === 42;
});

// fetch() - POST with URLSearchParams
test("fetch() POST with URLSearchParams", async () => {
    const params = new URLSearchParams();
    params.append("key1", "value1");
    params.append("key2", "value2");
    
    const response = await fetch("http://localhost:8080/echo/body", {
        method: "POST",
        body: params
    });
    const echoed = await response.text();
    return echoed === "key1=value1&key2=value2";
});

// ============================================================================
// RESPONSE HEADERS TESTS
// ============================================================================

// fetch() - response has headers
test("fetch() response has custom headers", async () => {
    const response = await fetch("http://localhost:8080/headers/custom");
    return response.headers.get("x-custom-header") === "custom-value";
});

// fetch() - response Content-Type header
test("fetch() response has Content-Type header", async () => {
    const response = await fetch("http://localhost:8080/content/json");
    return response.headers.get("content-type") === "application/json";
});

// fetch() - response Content-Length header
test("fetch() response has Content-Length header", async () => {
    const response = await fetch("http://localhost:8080/content/text");
    const length = response.headers.get("content-length");
    return length && parseInt(length) > 0;
});

// ============================================================================
// CACHE CONTROL TESTS (ignored by this implementation, but should not error)
// ============================================================================

// fetch() - cache: "default"
test("fetch() cache:'default' works", async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        cache: "default"
    });
    return response.status === 200;
});

// fetch() - cache: "no-cache"
test("fetch() cache:'no-cache' works", async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        cache: "no-cache"
    });
    return response.status === 200;
});

// fetch() - cache: "no-store"
test("fetch() cache:'no-store' works", async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        cache: "no-store"
    });
    return response.status === 200;
});

// ============================================================================
// CREDENTIALS TESTS (ignored by this implementation, but should not error)
// ============================================================================

// fetch() - credentials: "omit"
test("fetch() credentials:'omit' works", async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        credentials: "omit"
    });
    return response.ok === true;
});

// fetch() - credentials: "same-origin"
test("fetch() credentials:'same-origin' works", async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        credentials: "same-origin"
    });
    return response.ok === true;
});

// fetch() - credentials: "include"
test("fetch() credentials:'include' works", async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        credentials: "include"
    });
    return response.ok === true;
});

// ============================================================================
// ERROR HANDLING TESTS
// ============================================================================

// fetch() - network error rejects Promise
test("fetch() network error rejects Promise", async () => {
    try {
        await fetch("http://localhost:9999/nonexistent");
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
});

// fetch() - invalid URL rejects
test("fetch() invalid URL rejects", async () => {
    try {
        await fetch("not a valid url");
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
});

// ============================================================================
// ABORT SIGNAL TESTS
// ============================================================================

// AbortController exists
test("AbortController exists", () => {
    return typeof AbortController === "function";
});

// fetch() - abort before request
test("fetch() aborts if signal already aborted", async () => {
    const controller = new AbortController();
    controller.abort();
    
    try {
        await fetch("http://localhost:8080/api/test", {
            signal: controller.signal
        });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "AbortError";
    }
});

// ============================================================================
// COMPLEX SCENARIOS
// ============================================================================

// fetch() - multiple requests in parallel
test("fetch() multiple parallel requests work", async () => {
    const promises = [
        fetch("http://localhost:8080/api/users"),
        fetch("http://localhost:8080/api/posts")
    ];
    
    const responses = await Promise.all(promises);
    return responses.every(r => r.ok === true);
});

// fetch() - sequential requests
test("fetch() sequential requests work", async () => {
    const r1 = await fetch("http://localhost:8080/api/users");
    const users = await r1.json();
    
    const r2 = await fetch("http://localhost:8080/api/users/" + users[0].id);
    const user = await r2.json();
    
    return user.id === users[0].id;
});

// fetch() - request/response cycle
test("fetch() request/response cycle works", async () => {
    // POST to create
    const createResponse = await fetch("http://localhost:8080/api/posts", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "Test Post", content: "Content" })
    });
    const created = await createResponse.json();
    
    // GET to verify
    const getResponse = await fetch("http://localhost:8080/api/posts/" + created.id);
    const retrieved = await getResponse.json();
    
    return retrieved.title === "Test Post";
});

// fetch() - handles large response
test("fetch() handles large response", async () => {
    const response = await fetch("http://localhost:8080/content/large");
    const text = await response.text();
    return text.length > 10000; // 10KB+
});

// Run all tests
runTests();
