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
typeof fetch === "function"

// fetch() returns Promise
(() => {
    const promise = fetch("http://localhost:8080/api/test");
    return promise instanceof Promise;
})()

// fetch() - simple GET request
(async () => {
    const response = await fetch("http://localhost:8080/api/test");
    return response instanceof Response;
})()

// fetch() - response has correct status
(async () => {
    const response = await fetch("http://localhost:8080/api/test");
    return response.status === 200;
})()

// fetch() - response is ok
(async () => {
    const response = await fetch("http://localhost:8080/api/test");
    return response.ok === true;
})()

// fetch() - can read response body
(async () => {
    const response = await fetch("http://localhost:8080/api/test");
    const text = await response.text();
    return typeof text === "string" && text.length > 0;
})()

// ============================================================================
// JSON API TESTS
// ============================================================================

// fetch() - GET JSON data
(async () => {
    const response = await fetch("http://localhost:8080/api/users");
    const data = await response.json();
    return Array.isArray(data) && data.length > 0;
})()

// fetch() - POST JSON data
(async () => {
    const response = await fetch("http://localhost:8080/api/users", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify({ name: "John Doe", email: "john@example.com" })
    });
    return response.status === 201;
})()

// fetch() - response includes correct headers
(async () => {
    const response = await fetch("http://localhost:8080/api/users");
    return response.headers.get("content-type") === "application/json";
})()

// fetch() - complex JSON response
(async () => {
    const response = await fetch("http://localhost:8080/api/users/123");
    const user = await response.json();
    return user.id === 123 && 
           user.name && 
           user.email;
})()

// ============================================================================
// HTTP METHODS TESTS
// ============================================================================

// fetch() - GET method (default)
(async () => {
    const response = await fetch("http://localhost:8080/api/test");
    return response.status === 200;
})()

// fetch() - POST method
(async () => {
    const response = await fetch("http://localhost:8080/api/posts", {
        method: "POST",
        body: "test data"
    });
    return response.status === 201;
})()

// fetch() - PUT method
(async () => {
    const response = await fetch("http://localhost:8080/api/posts/1", {
        method: "PUT",
        body: JSON.stringify({ title: "Updated" })
    });
    return response.status === 200;
})()

// fetch() - PATCH method
(async () => {
    const response = await fetch("http://localhost:8080/api/posts/1", {
        method: "PATCH",
        body: JSON.stringify({ title: "Patched" })
    });
    return response.status === 200;
})()

// fetch() - DELETE method
(async () => {
    const response = await fetch("http://localhost:8080/api/posts/1", {
        method: "DELETE"
    });
    return response.status === 204;
})()

// fetch() - HEAD method
(async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        method: "HEAD"
    });
    return response.status === 200 && !response.body;
})()

// ============================================================================
// REQUEST HEADERS TESTS
// ============================================================================

// fetch() - custom headers sent
(async () => {
    const response = await fetch("http://localhost:8080/echo/headers", {
        headers: {
            "X-Custom-Header": "test-value",
            "Authorization": "Bearer token123"
        }
    });
    const echoed = await response.json();
    return echoed["x-custom-header"] === "test-value" &&
           echoed["authorization"] === "Bearer token123";
})()

// fetch() - Content-Type header
(async () => {
    const response = await fetch("http://localhost:8080/echo/headers", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify({ key: "value" })
    });
    const echoed = await response.json();
    return echoed["content-type"] === "application/json";
})()

// fetch() - User-Agent header
(async () => {
    const response = await fetch("http://localhost:8080/echo/headers", {
        headers: {
            "User-Agent": "CustomAgent/1.0"
        }
    });
    const echoed = await response.json();
    return echoed["user-agent"] === "CustomAgent/1.0";
})()

// ============================================================================
// RESPONSE STATUS TESTS
// ============================================================================

// fetch() - 200 OK
(async () => {
    const response = await fetch("http://localhost:8080/status/200");
    return response.status === 200 && response.ok === true;
})()

// fetch() - 201 Created
(async () => {
    const response = await fetch("http://localhost:8080/status/201");
    return response.status === 201 && response.ok === true;
})()

// fetch() - 204 No Content
(async () => {
    const response = await fetch("http://localhost:8080/status/204");
    return response.status === 204 && response.ok === true;
})()

// fetch() - 400 Bad Request
(async () => {
    const response = await fetch("http://localhost:8080/status/400");
    return response.status === 400 && response.ok === false;
})()

// fetch() - 401 Unauthorized
(async () => {
    const response = await fetch("http://localhost:8080/status/401");
    return response.status === 401 && response.ok === false;
})()

// fetch() - 403 Forbidden
(async () => {
    const response = await fetch("http://localhost:8080/status/403");
    return response.status === 403 && response.ok === false;
})()

// fetch() - 404 Not Found
(async () => {
    const response = await fetch("http://localhost:8080/status/404");
    return response.status === 404 && response.ok === false;
})()

// fetch() - 500 Internal Server Error
(async () => {
    const response = await fetch("http://localhost:8080/status/500");
    return response.status === 500 && response.ok === false;
})()

// fetch() - 503 Service Unavailable
(async () => {
    const response = await fetch("http://localhost:8080/status/503");
    return response.status === 503 && response.ok === false;
})()

// ============================================================================
// REDIRECT TESTS
// ============================================================================

// fetch() - follows redirects by default
(async () => {
    const response = await fetch("http://localhost:8080/redirect/permanent");
    return response.status === 200 && response.redirected === true;
})()

// fetch() - redirect sets final URL
(async () => {
    const response = await fetch("http://localhost:8080/redirect/permanent");
    return response.url === "http://localhost:8080/redirect/target";
})()

// fetch() - 301 Moved Permanently
(async () => {
    const response = await fetch("http://localhost:8080/redirect/301");
    return response.redirected === true;
})()

// fetch() - 302 Found
(async () => {
    const response = await fetch("http://localhost:8080/redirect/302");
    return response.redirected === true;
})()

// fetch() - 307 Temporary Redirect
(async () => {
    const response = await fetch("http://localhost:8080/redirect/307");
    return response.redirected === true;
})()

// fetch() - redirect: "manual" doesn't follow
(async () => {
    const response = await fetch("http://localhost:8080/redirect/permanent", {
        redirect: "manual"
    });
    return response.status === 301 && response.redirected === false;
})()

// fetch() - redirect: "error" throws on redirect
(async () => {
    try {
        await fetch("http://localhost:8080/redirect/permanent", {
            redirect: "error"
        });
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})()

// ============================================================================
// BODY FORMATS TESTS
// ============================================================================

// fetch() - text/plain response
(async () => {
    const response = await fetch("http://localhost:8080/content/text");
    const text = await response.text();
    return text === "Hello, World!";
})()

// fetch() - application/json response
(async () => {
    const response = await fetch("http://localhost:8080/content/json");
    const data = await response.json();
    return data.message === "success";
})()

// fetch() - binary data response
(async () => {
    const response = await fetch("http://localhost:8080/content/binary");
    const buffer = await response.arrayBuffer();
    return buffer.byteLength > 0;
})()

// fetch() - POST with text body
(async () => {
    const response = await fetch("http://localhost:8080/echo/body", {
        method: "POST",
        body: "plain text data"
    });
    const echoed = await response.text();
    return echoed === "plain text data";
})()

// fetch() - POST with JSON body
(async () => {
    const response = await fetch("http://localhost:8080/echo/body", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ key: "value", number: 42 })
    });
    const echoed = await response.json();
    return echoed.key === "value" && echoed.number === 42;
})()

// fetch() - POST with FormData
(async () => {
    const formData = new FormData();
    formData.append("username", "johndoe");
    formData.append("email", "john@example.com");
    
    const response = await fetch("http://localhost:8080/echo/formdata", {
        method: "POST",
        body: formData
    });
    return response.status === 200;
})()

// fetch() - POST with URLSearchParams
(async () => {
    const params = new URLSearchParams();
    params.append("key1", "value1");
    params.append("key2", "value2");
    
    const response = await fetch("http://localhost:8080/echo/body", {
        method: "POST",
        body: params
    });
    const echoed = await response.text();
    return echoed === "key1=value1&key2=value2";
})()

// ============================================================================
// RESPONSE HEADERS TESTS
// ============================================================================

// fetch() - response has headers
(async () => {
    const response = await fetch("http://localhost:8080/headers/custom");
    return response.headers.get("x-custom-header") === "custom-value";
})()

// fetch() - response Content-Type header
(async () => {
    const response = await fetch("http://localhost:8080/content/json");
    return response.headers.get("content-type") === "application/json";
})()

// fetch() - response Content-Length header
(async () => {
    const response = await fetch("http://localhost:8080/content/text");
    const length = response.headers.get("content-length");
    return length && parseInt(length) > 0;
})()

// fetch() - multiple values for same header
(async () => {
    const response = await fetch("http://localhost:8080/headers/multiple");
    const values = response.headers.get("set-cookie");
    return values && values.includes(",");
})()

// ============================================================================
// CACHE CONTROL TESTS
// ============================================================================

// fetch() - cache: "default"
(async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        cache: "default"
    });
    return response.status === 200;
})()

// fetch() - cache: "no-cache"
(async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        cache: "no-cache"
    });
    return response.status === 200;
})()

// fetch() - cache: "no-store"
(async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        cache: "no-store"
    });
    return response.status === 200;
})()

// fetch() - cache: "reload"
(async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        cache: "reload"
    });
    return response.status === 200;
})()

// ============================================================================
// CORS TESTS
// ============================================================================

// fetch() - same-origin request succeeds
(async () => {
    const response = await fetch("http://localhost:8080/api/test");
    return response.ok === true;
})()

// fetch() - CORS preflight for cross-origin
(async () => {
    const response = await fetch("http://localhost:8080/cors/allowed", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        }
    });
    return response.ok === true;
})()

// fetch() - CORS headers in response
(async () => {
    const response = await fetch("http://localhost:8080/cors/allowed");
    return response.headers.has("access-control-allow-origin");
})()

// fetch() - mode: "cors" allows CORS
(async () => {
    const response = await fetch("http://localhost:8080/cors/allowed", {
        mode: "cors"
    });
    return response.ok === true;
})()

// fetch() - mode: "no-cors" for opaque responses
(async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        mode: "no-cors"
    });
    return response.type === "opaque";
})()

// ============================================================================
// CREDENTIALS TESTS
// ============================================================================

// fetch() - credentials: "omit"
(async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        credentials: "omit"
    });
    return response.ok === true;
})()

// fetch() - credentials: "same-origin"
(async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        credentials: "same-origin"
    });
    return response.ok === true;
})()

// fetch() - credentials: "include"
(async () => {
    const response = await fetch("http://localhost:8080/api/test", {
        credentials: "include"
    });
    return response.ok === true;
})()

// ============================================================================
// ERROR HANDLING TESTS
// ============================================================================

// fetch() - network error rejects Promise
(async () => {
    try {
        await fetch("http://localhost:9999/nonexistent");
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})()

// fetch() - invalid URL rejects
(async () => {
    try {
        await fetch("not a valid url");
        return false; // Should have thrown
    } catch (e) {
        return e.name === "TypeError";
    }
})()

// fetch() - timeout (if supported)
(async () => {
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
})()

// ============================================================================
// ABORT SIGNAL TESTS
// ============================================================================

// AbortController exists
typeof AbortController === "function"

// fetch() - can be aborted
(async () => {
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
})()

// fetch() - abort before request
(async () => {
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
})()

// ============================================================================
// COMPLEX SCENARIOS
// ============================================================================

// fetch() - multiple requests in parallel
(async () => {
    const promises = [
        fetch("http://localhost:8080/api/users"),
        fetch("http://localhost:8080/api/posts"),
        fetch("http://localhost:8080/api/comments")
    ];
    
    const responses = await Promise.all(promises);
    return responses.every(r => r.ok === true);
})()

// fetch() - sequential requests
(async () => {
    const r1 = await fetch("http://localhost:8080/api/users");
    const users = await r1.json();
    
    const r2 = await fetch(`http://localhost:8080/api/users/${users[0].id}`);
    const user = await r2.json();
    
    return user.id === users[0].id;
})()

// fetch() - request/response cycle
(async () => {
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
})()

// fetch() - handles large response
(async () => {
    const response = await fetch("http://localhost:8080/content/large");
    const text = await response.text();
    return text.length > 10000; // 10KB+
})()

// fetch() - streaming response (if supported)
(async () => {
    const response = await fetch("http://localhost:8080/content/stream");
    const reader = response.body.getReader();
    
    let chunks = 0;
    while (true) {
        const { done } = await reader.read();
        if (done) break;
        chunks++;
    }
    
    return chunks > 0;
})()

// End of tests marker
true
