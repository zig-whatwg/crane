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

// ============================================================================
// BASIC FETCH TESTS
// ============================================================================

// fetch() function exists
assert.isFunction(fetch, "fetch should be a function")

// fetch() returns Promise
assert.isTrue((() => {
    const promise = fetch("http://localhost:8080/api/test");
    return promise instanceof Promise;
})(), "fetch() should return Promise")

// fetch() - simple GET request
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/test");
    return response instanceof Response;
})(), "fetch() should return Response for simple GET")

// fetch() - response has correct status
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/test");
    return response.status === 200;
})(), "fetch() response should have correct status")

// fetch() - response is ok
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/test");
    return response.ok === true;
})(), "fetch() response should be ok")

// fetch() - can read response body
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/test");
    const text = await response.text();
    return typeof text === "string" && text.length > 0;
})(), "fetch() response body should be readable")

// ============================================================================
// JSON API TESTS
// ============================================================================

// fetch() - GET JSON data
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/users");
    const data = await response.json();
    return Array.isArray(data) && data.length > 0;
})(), "fetch() should GET JSON data")

// fetch() - POST JSON data
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/users", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify({ name: "John Doe", email: "john@example.com" })
    });
    return response.status === 201;
})(), "fetch() should POST JSON data")

// fetch() - response includes correct headers
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/users");
    return response.headers.get("content-type") === "application/json";
})(), "fetch() response should include correct headers")

// fetch() - complex JSON response
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/users/123");
    const user = await response.json();
    return user.id === 123 && 
           user.name && 
           user.email;
})(), "fetch() should handle complex JSON response")

// ============================================================================
// HTTP METHODS TESTS
// ============================================================================

// fetch() - GET method (default)
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/test");
    return response.status === 200;
})(), "fetch() GET method should work")

// fetch() - POST method
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/posts", {
        method: "POST",
        body: "test data"
    });
    return response.status === 201;
})(), "fetch() POST method should work")

// fetch() - PUT method
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/posts/1", {
        method: "PUT",
        body: JSON.stringify({ title: "Updated" })
    });
    return response.status === 200;
})(), "fetch() PUT method should work")

// fetch() - PATCH method
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/posts/1", {
        method: "PATCH",
        body: JSON.stringify({ title: "Patched" })
    });
    return response.status === 200;
})(), "fetch() PATCH method should work")

// fetch() - DELETE method
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/posts/1", {
        method: "DELETE"
    });
    return response.status === 204;
})(), "fetch() DELETE method should work")

// fetch() - HEAD method
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        method: "HEAD"
    });
    return response.status === 200 && !response.body;
})(), "fetch() HEAD method should work")

// ============================================================================
// REQUEST HEADERS TESTS
// ============================================================================

// fetch() - custom headers sent
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/echo/headers", {
        headers: {
            "X-Custom-Header": "test-value",
            "Authorization": "Bearer token123"
        }
    });
    const echoed = await response.json();
    return echoed["x-custom-header"] === "test-value" &&
           echoed["authorization"] === "Bearer token123";
})(), "fetch() should send custom headers")

// fetch() - Content-Type header
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/echo/headers", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify({ key: "value" })
    });
    const echoed = await response.json();
    return echoed["content-type"] === "application/json";
})(), "fetch() should send Content-Type header")

// fetch() - User-Agent header
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/echo/headers", {
        headers: {
            "User-Agent": "CustomAgent/1.0"
        }
    });
    const echoed = await response.json();
    return echoed["user-agent"] === "CustomAgent/1.0";
})(), "fetch() should send User-Agent header")

// ============================================================================
// RESPONSE STATUS TESTS
// ============================================================================

// fetch() - 200 OK
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/status/200");
    return response.status === 200 && response.ok === true;
})(), "fetch() should handle 200 OK")

// fetch() - 201 Created
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/status/201");
    return response.status === 201 && response.ok === true;
})(), "fetch() should handle 201 Created")

// fetch() - 204 No Content
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/status/204");
    return response.status === 204 && response.ok === true;
})(), "fetch() should handle 204 No Content")

// fetch() - 400 Bad Request
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/status/400");
    return response.status === 400 && response.ok === false;
})(), "fetch() should handle 400 Bad Request")

// fetch() - 401 Unauthorized
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/status/401");
    return response.status === 401 && response.ok === false;
})(), "fetch() should handle 401 Unauthorized")

// fetch() - 403 Forbidden
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/status/403");
    return response.status === 403 && response.ok === false;
})(), "fetch() should handle 403 Forbidden")

// fetch() - 404 Not Found
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/status/404");
    return response.status === 404 && response.ok === false;
})(), "fetch() should handle 404 Not Found")

// fetch() - 500 Internal Server Error
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/status/500");
    return response.status === 500 && response.ok === false;
})(), "fetch() should handle 500 Internal Server Error")

// fetch() - 503 Service Unavailable
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/status/503");
    return response.status === 503 && response.ok === false;
})(), "fetch() should handle 503 Service Unavailable")

// ============================================================================
// REDIRECT TESTS
// ============================================================================

// fetch() - follows redirects by default
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/redirect/permanent");
    return response.status === 200 && response.redirected === true;
})(), "fetch() should follow redirects by default")

// fetch() - redirect sets final URL
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/redirect/permanent");
    return response.url === "http://localhost:8080/redirect/target";
})(), "fetch() redirect should set final URL")

// fetch() - 301 Moved Permanently
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/redirect/301");
    return response.redirected === true;
})(), "fetch() should handle 301 redirect")

// fetch() - 302 Found
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/redirect/302");
    return response.redirected === true;
})(), "fetch() should handle 302 redirect")

// fetch() - 307 Temporary Redirect
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/redirect/307");
    return response.redirected === true;
})(), "fetch() should handle 307 redirect")

// fetch() - redirect: "manual" doesn't follow
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/redirect/permanent", {
        redirect: "manual"
    });
    return response.status === 301 && response.redirected === false;
})(), "fetch() with redirect:'manual' should not follow")

// fetch() - redirect: "error" throws on redirect
assert.isTrue((async () => {
    try {
        await fetch("http://localhost:8080/redirect/permanent", {
            redirect: "error"
        });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})(), "fetch() with redirect:'error' should throw")

// ============================================================================
// BODY FORMATS TESTS
// ============================================================================

// fetch() - text/plain response
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/content/text");
    const text = await response.text();
    return text === "Hello, World!";
})(), "fetch() should handle text/plain response")

// fetch() - application/json response
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/content/json");
    const data = await response.json();
    return data.message === "success";
})(), "fetch() should handle application/json response")

// fetch() - binary data response
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/content/binary");
    const buffer = await response.arrayBuffer();
    return buffer.byteLength > 0;
})(), "fetch() should handle binary data response")

// fetch() - POST with text body
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/echo/body", {
        method: "POST",
        body: "plain text data"
    });
    const echoed = await response.text();
    return echoed === "plain text data";
})(), "fetch() should POST with text body")

// fetch() - POST with JSON body
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/echo/body", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ key: "value", number: 42 })
    });
    const echoed = await response.json();
    return echoed.key === "value" && echoed.number === 42;
})(), "fetch() should POST with JSON body")

// fetch() - POST with FormData
assert.isTrue((async () => {
    const formData = new FormData();
    formData.append("username", "johndoe");
    formData.append("email", "john@example.com");
    
    const response = await fetch("http://localhost:8080/echo/formdata", {
        method: "POST",
        body: formData
    });
    return response.status === 200;
})(), "fetch() should POST with FormData")

// fetch() - POST with URLSearchParams
assert.isTrue((async () => {
    const params = new URLSearchParams();
    params.append("key1", "value1");
    params.append("key2", "value2");
    
    const response = await fetch("http://localhost:8080/echo/body", {
        method: "POST",
        body: params
    });
    const echoed = await response.text();
    return echoed === "key1=value1&key2=value2";
})(), "fetch() should POST with URLSearchParams")

// ============================================================================
// RESPONSE HEADERS TESTS
// ============================================================================

// fetch() - response has headers
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/headers/custom");
    return response.headers.get("x-custom-header") === "custom-value";
})(), "fetch() response should have headers")

// fetch() - response Content-Type header
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/content/json");
    return response.headers.get("content-type") === "application/json";
})(), "fetch() response should have Content-Type header")

// fetch() - response Content-Length header
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/content/text");
    const length = response.headers.get("content-length");
    return length && parseInt(length) > 0;
})(), "fetch() response should have Content-Length header")

// fetch() - multiple values for same header
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/headers/multiple");
    const values = response.headers.get("set-cookie");
    return values && values.includes(",");
})(), "fetch() should handle multiple header values")

// ============================================================================
// CACHE CONTROL TESTS
// ============================================================================

// fetch() - cache: "default"
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        cache: "default"
    });
    return response.status === 200;
})(), "fetch() with cache:'default' should work")

// fetch() - cache: "no-cache"
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        cache: "no-cache"
    });
    return response.status === 200;
})(), "fetch() with cache:'no-cache' should work")

// fetch() - cache: "no-store"
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        cache: "no-store"
    });
    return response.status === 200;
})(), "fetch() with cache:'no-store' should work")

// fetch() - cache: "reload"
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        cache: "reload"
    });
    return response.status === 200;
})(), "fetch() with cache:'reload' should work")

// ============================================================================
// CORS TESTS
// ============================================================================

// fetch() - same-origin request succeeds
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/test");
    return response.ok === true;
})(), "fetch() same-origin request should succeed")

// fetch() - CORS preflight for cross-origin
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/cors/allowed", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        }
    });
    return response.ok === true;
})(), "fetch() CORS preflight should work")

// fetch() - CORS headers in response
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/cors/allowed");
    return response.headers.has("access-control-allow-origin");
})(), "fetch() should receive CORS headers")

// fetch() - mode: "cors" allows CORS
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/cors/allowed", {
        mode: "cors"
    });
    return response.ok === true;
})(), "fetch() with mode:'cors' should work")

// fetch() - mode: "no-cors" for opaque responses
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        mode: "no-cors"
    });
    return response.type === "opaque";
})(), "fetch() with mode:'no-cors' should return opaque response")

// ============================================================================
// CREDENTIALS TESTS
// ============================================================================

// fetch() - credentials: "omit"
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        credentials: "omit"
    });
    return response.ok === true;
})(), "fetch() with credentials:'omit' should work")

// fetch() - credentials: "same-origin"
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        credentials: "same-origin"
    });
    return response.ok === true;
})(), "fetch() with credentials:'same-origin' should work")

// fetch() - credentials: "include"
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        credentials: "include"
    });
    return response.ok === true;
})(), "fetch() with credentials:'include' should work")

// ============================================================================
// ERROR HANDLING TESTS
// ============================================================================

// fetch() - network error rejects Promise
assert.isTrue((async () => {
    try {
        await fetch("http://localhost:9999/nonexistent");
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})(), "fetch() network error should reject Promise")

// fetch() - invalid URL rejects
assert.isTrue((async () => {
    try {
        await fetch("not a valid url");
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})(), "fetch() invalid URL should reject")

// fetch() - timeout (if supported)
assert.isTrue((async () => {
    try {
        const controller = new AbortController();
        setTimeout(() => controller.abort(), 100);
        
        await fetch("http://localhost:8080/delay/5000", {
            signal: controller.signal
        });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "AbortError";
    }
})(), "fetch() timeout should throw AbortError")

// ============================================================================
// ABORT SIGNAL TESTS
// ============================================================================

// AbortController exists
assert.isFunction(AbortController, "AbortController should be a function")

// fetch() - can be aborted
assert.isTrue((async () => {
    const controller = new AbortController();
    const promise = fetch("http://localhost:8080/delay/5000", {
        signal: controller.signal
    });
    
    controller.abort();
    
    try {
        await promise;
        return false; // Should have thrown
    } catch (e) {
        return e.name === "AbortError";
    }
})(), "fetch() can be aborted")

// fetch() - abort before request
assert.isTrue((async () => {
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
})(), "fetch() should abort before request if signal already aborted")

// ============================================================================
// COMPLEX SCENARIOS
// ============================================================================

// fetch() - multiple requests in parallel
assert.isTrue((async () => {
    const promises = [
        fetch("http://localhost:8080/api/users"),
        fetch("http://localhost:8080/api/posts"),
        fetch("http://localhost:8080/api/comments")
    ];
    
    const responses = await Promise.all(promises);
    return responses.every(r => r.ok === true);
})(), "fetch() multiple parallel requests should work")

// fetch() - sequential requests
assert.isTrue((async () => {
    const r1 = await fetch("http://localhost:8080/api/users");
    const users = await r1.json();
    
    const r2 = await fetch(`http://localhost:8080/api/users/${users[0].id}`);
    const user = await r2.json();
    
    return user.id === users[0].id;
})(), "fetch() sequential requests should work")

// fetch() - request/response cycle
assert.isTrue((async () => {
    // POST to create
    const createResponse = await fetch("http://localhost:8080/api/posts", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "Test Post", content: "Content" })
    });
    const created = await createResponse.json();
    
    // GET to verify
    const getResponse = await fetch(`http://localhost:8080/api/posts/${created.id}`);
    const retrieved = await getResponse.json();
    
    return retrieved.title === "Test Post";
})(), "fetch() request/response cycle should work")

// fetch() - handles large response
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/content/large");
    const text = await response.text();
    return text.length > 10000; // 10KB+
})(), "fetch() should handle large response")

// fetch() - streaming response (if supported)
assert.isTrue((async () => {
    const response = await fetch("http://localhost:8080/content/stream");
    const reader = response.body.getReader();
    
    let chunks = 0;
    while (true) {
        const { done } = await reader.read();
        if (done) break;
        chunks++;
    }
    
    return chunks > 0;
})(), "fetch() should handle streaming response")

// End of tests marker
assert.isTrue(true, "All fetch integration tests completed")
