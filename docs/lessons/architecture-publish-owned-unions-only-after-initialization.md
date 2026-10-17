# Architecture: Publish owned unions only after initialization

**Date**: 2026-10-17

**Lesson**: Finish a fallible owned payload before assigning it to a union or optional field that error cleanup will inspect.

**Why**: Zig's [result-location semantics](https://ziglang.org/documentation/0.16.0/#Result-Locations) let aggregate initializers write directly into an assignment's destination. A `try` inside an initializer does not guarantee that the destination remains unchanged on error. Its tag can already be active while its payload is undefined.

**What Happened**: InternalRequest.clone leaked its completed allocations when a later copy failed. Adding `errdefer new_request.deinit()` correctly made the request responsible for cleanup, but the exhaustive allocation-failure test then aborted in Body.deinit. The unchanged body assignment initialized an optional union directly in the request while calling the fallible Body.clone. An allocation failure left cleanup reading an invalid body pointer. The policy-container union used the same unsafe publication pattern; earlier failure iterations surviving did not prove its undefined payload was safe.

**Fix**: Clone the policy container into a local, then assign the completed container to the request's union. Build the body switch into a separate typed RequestBody local, then assign it to the optional body field. Neither assignment can fail. Keep plain slice assignments and setters that already allocate before publication unchanged. No change to Body.clone or its ownership contract is needed.

The regression builds every owned request component before enabling failure injection, then fails each successive allocation in clone. It checks both union payloads and uses std.testing.allocator beneath the failing allocator, so an invalid cleanup, incomplete copy or leaked allocation fails the test.

**Takeaway**: **An errdefer destructor is safe only when every field it can observe is fully initialized. Stage fallible union payloads before publishing them.**
