
## 1. Introduction

*This section is not normative.*

As the web platform is extended to enable more useful and powerful
applications, it becomes increasingly important to ensure that the
features which enable those applications are enabled only in contexts
which meet a minimum security level. As an extension of the TAG's
recommendations in
[\[SECURING-WEB\]](#biblio-securing-web "Securing the Web"),
this document describes threat models for feature abuse on the web (see
[§ 4.1 Threat Models](#threat-models)) and outlines normative
requirements which should be incorporated into documents specifying new
features (see [§ 7 Implementation
Considerations](#implementation-considerations)).

The most obvious of the requirements discussed here is that application
code with access to sensitive or private data be delivered
confidentially over authenticated channels that guarantee data
integrity. Delivering code securely cannot ensure that an application
will always meet a user's security and privacy requirements, but it is a
necessary precondition.

Less obviously, application code delivered over an authenticated and
confidential channel isn't enough in and of itself to limit the use of
powerful features by non-secure contexts. As [§ 4.2 Ancestral
Risk](#ancestors) explains, cooperative frames can be abused to bypass
otherwise solid restrictions on a feature. The algorithms defined below
ensure that these bypasses are difficult and user-visible.

The following examples summarize the normative text which follows:

### 1.1. Top-level Documents

`http://example.com/` opened in a [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) is not a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context), as it was not delivered over an authenticated and
encrypted channel.

!(data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjIwMCIgd2lkdGg9IjQwMCI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLDEwKSI+CiAgICAgICA8cmVjdCBjbGFzcz0ibm9uLXNlY3VyZSIgaGVpZ2h0PSIxNzUiIHdpZHRoPSIyOTciIHg9IjAiIHk9IjAiIC8+CiAgICAgICA8dGV4dCB0cmFuc2Zvcm09InRyYW5zbGF0ZSgxMCwgMjApIj5odHRwOi8vZXhhbXBsZS5jb20vPC90ZXh0PgogICAgICA8L2c+CiAgICAgPC9zdmc+)

`https://example.com/` opened in a [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) is a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context), as it was delivered over an authenticated and
encrypted channel.

!(data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjIwMCIgd2lkdGg9IjQwMCI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLDEwKSI+CiAgICAgICA8cmVjdCBjbGFzcz0ic2VjdXJlIiBoZWlnaHQ9IjE3NSIgd2lkdGg9IjI5NyIgeD0iMCIgeT0iMCIgLz4KICAgICAgIDx0ZXh0IHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLCAyMCkiPmh0dHBzOi8vZXhhbXBsZS5jb20vPC90ZXh0PgogICAgICA8L2c+CiAgICAgPC9zdmc+)

If a secure context opens `https://example.com/` in a new window, that
new window will be a secure context, as it is secure on its own merits:

!(data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjQwMCIgd2lkdGg9IjQwMCI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLDEwKSI+CiAgICAgICA8cmVjdCBjbGFzcz0ic2VjdXJlIiBoZWlnaHQ9IjE3NSIgd2lkdGg9IjI5NyIgeD0iMCIgeT0iMCIgLz4KICAgICAgIDx0ZXh0IHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLCAyMCkiPmh0dHBzOi8vc2VjdXJlLmV4YW1wbGUuY29tLzwvdGV4dD4KICAgICAgPC9nPgogICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgxMCwyMTApIj4KICAgICAgIDxyZWN0IGNsYXNzPSJzZWN1cmUiIGhlaWdodD0iMTc1IiB3aWR0aD0iMjk3IiB4PSIwIiB5PSIwIiAvPgogICAgICAgPHRleHQgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMTAsIDIwKSI+aHR0cHM6Ly9hbm90aGVyLmV4YW1wbGUuY29tLzwvdGV4dD4KICAgICAgPC9nPgogICAgICA8Zz4KICAgICAgIDxwYXRoIGQ9Ik0xNTAsIDg3IEMgMjAwIDc1LCAzNTAgNzUsIDE1MCAyODciIC8+CiAgICAgIDwvZz4KICAgICA8L3N2Zz4=)

Likewise, if a non-secure context opens `https://example.com/` in a new
window, that new window will be a secure context, even though its opener
was non-secure:

!(data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjQwMCIgd2lkdGg9IjQwMCI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLDEwKSI+CiAgICAgICA8cmVjdCBjbGFzcz0ibm9uLXNlY3VyZSIgaGVpZ2h0PSIxNzUiIHdpZHRoPSIyOTciIHg9IjAiIHk9IjAiIC8+CiAgICAgICA8dGV4dCB0cmFuc2Zvcm09InRyYW5zbGF0ZSgxMCwgMjApIj5odHRwOi8vbm9uLXNlY3VyZS5leGFtcGxlLmNvbS88L3RleHQ+CiAgICAgIDwvZz4KICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMTAsMjEwKSI+CiAgICAgICA8cmVjdCBjbGFzcz0ic2VjdXJlIiBoZWlnaHQ9IjE3NSIgd2lkdGg9IjI5NyIgeD0iMCIgeT0iMCIgLz4KICAgICAgIDx0ZXh0IHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLCAyMCkiPmh0dHBzOi8vYW5vdGhlci5leGFtcGxlLmNvbS88L3RleHQ+CiAgICAgIDwvZz4KICAgICAgPGc+CiAgICAgICA8cGF0aCBkPSJNMTUwLCA4NyBDIDIwMCA3NSwgMzUwIDc1LCAxNTAgMjg3IiAvPgogICAgICA8L2c+CiAgICAgPC9zdmc+)

### 1.2. Framed Documents

Framed documents can be [secure
contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) if they are delivered from [potentially trustworthy
origins](#potentially-trustworthy-origin), *and* if they're embedded in a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context). That is:

If `https://example.com/` opened in a
[top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) opens `https://sub.example.com/` in a frame, then both
are [secure
contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context), as both were delivered over authenticated and
encrypted channels.

!(data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjIwMCIgd2lkdGg9IjQwMCI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLDEwKSI+CiAgICAgICA8cmVjdCBjbGFzcz0ic2VjdXJlIiBoZWlnaHQ9IjE3NSIgd2lkdGg9IjMwMCIgeD0iMCIgeT0iMCIgLz4KICAgICAgIDx0ZXh0IHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLCAyMCkiPmh0dHBzOi8vZXhhbXBsZS5jb20vPC90ZXh0PgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMjAsIDUwKSI+CiAgICAgICAgPHJlY3QgY2xhc3M9InNlY3VyZSIgaGVpZ2h0PSIxMDUiIHdpZHRoPSIyNTAiIHg9IjAiIHk9IjAiIC8+CiAgICAgICAgPHRleHQgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMTAsIDIwKSI+aHR0cHM6Ly9zdWIuZXhhbXBsZS5jb20vPC90ZXh0PgogICAgICAgPC9nPgogICAgICA8L2c+CiAgICAgPC9zdmc+)

If `https://example.com/` was somehow able to frame
`http://non-secure.example.com/` (perhaps the user has overridden mixed
content checking?), the top-level frame would remain secure, but the
framed content is not a secure context.

!(data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjIwMCIgd2lkdGg9IjQwMCI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLDEwKSI+CiAgICAgICA8cmVjdCBjbGFzcz0ic2VjdXJlIiBoZWlnaHQ9IjE3NSIgd2lkdGg9IjMwMCIgeD0iMCIgeT0iMCIgLz4KICAgICAgIDx0ZXh0IHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLCAyMCkiPmh0dHBzOi8vZXhhbXBsZS5jb20vPC90ZXh0PgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMjAsIDUwKSI+CiAgICAgICAgPHJlY3QgY2xhc3M9Im5vbi1zZWN1cmUiIGhlaWdodD0iMTA1IiB3aWR0aD0iMjUwIiB4PSIwIiB5PSIwIiAvPgogICAgICAgIDx0ZXh0IHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLCAyMCkiPmh0dHA6Ly9ub24tc2VjdXJlLmV4YW1wbGUuY29tLzwvdGV4dD4KICAgICAgIDwvZz4KICAgICAgPC9nPgogICAgIDwvc3ZnPg==)

If, on the other hand, `https://example.com/` is framed inside of
`http://non-secure.example.com/`, then it is *not* a secure context, as
its ancestor is not delivered over an authenticated and encrypted
channel.

!(data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjIwMCIgd2lkdGg9IjQwMCI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLDEwKSI+CiAgICAgICA8cmVjdCBjbGFzcz0ibm9uLXNlY3VyZSIgaGVpZ2h0PSIxNzUiIHdpZHRoPSIzMDAiIHg9IjAiIHk9IjAiIC8+CiAgICAgICA8dGV4dCB0cmFuc2Zvcm09InRyYW5zbGF0ZSgxMCwgMjApIj5odHRwOi8vbm9uLXNlY3VyZS5leGFtcGxlLmNvbS88L3RleHQ+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgyMCwgNTApIj4KICAgICAgICA8cmVjdCBjbGFzcz0ibm9uLXNlY3VyZSIgaGVpZ2h0PSIxMDUiIHdpZHRoPSIyNTAiIHg9IjAiIHk9IjAiIC8+CiAgICAgICAgPHRleHQgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMTAsIDIwKSI+aHR0cHM6Ly9leGFtcGxlLmNvbS88L3RleHQ+CiAgICAgICA8L2c+CiAgICAgIDwvZz4KICAgICA8L3N2Zz4=)

### 1.3. Web Workers

Dedicated Workers are similar in nature to framed documents. They're
[secure
contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) when they're delivered from [potentially trustworthy
origins](#potentially-trustworthy-origin), only if their owner is itself a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context):

If `https://example.com/` in a [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) runs `https://example.com/worker.js`, then both the
document and the worker are [secure
contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context).

!(data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjIwMCIgd2lkdGg9IjYwMCI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLDEwKSI+CiAgICAgICA8cmVjdCBjbGFzcz0ic2VjdXJlIiBoZWlnaHQ9IjE3NSIgd2lkdGg9IjMwMCIgeD0iMCIgeT0iMCIgLz4KICAgICAgIDx0ZXh0IHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLCAyMCkiPmh0dHBzOi8vZXhhbXBsZS5jb20vPC90ZXh0PgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoNDAwLCAxMTApIj4KICAgICAgICA8Y2lyY2xlIGNsYXNzPSJzZWN1cmUiIHI9IjUwIj48L2NpcmNsZT4KICAgICAgICA8dGV4dCB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtNzUsIC01NSkiPmh0dHBzOi8vZXhhbXBsZS5jb20vd29ya2VyLmpzPC90ZXh0PgogICAgICAgPC9nPgogICAgICAgPGc+CiAgICAgICAgPHBhdGggZD0iTTE1MCwgODcgQyAyMDAgNzUsIDM1MCA3NSwgNDA1IDExMCIgLz4KICAgICAgIDwvZz4KICAgICAgPC9nPgogICAgIDwvc3ZnPg==)

If `http://non-secure.example.com/` in a [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) frames `https://example.com/`, which runs
`https://example.com/worker.js`, then neither the framed document nor
the worker are [secure
contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context).

!(data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjIwMCIgd2lkdGg9IjYwMCI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLDEwKSI+CiAgICAgICA8cmVjdCBjbGFzcz0ibm9uLXNlY3VyZSIgaGVpZ2h0PSIxNzUiIHdpZHRoPSIyOTciIHg9IjAiIHk9IjAiIC8+CiAgICAgICA8dGV4dCB0cmFuc2Zvcm09InRyYW5zbGF0ZSgxMCwgMjApIj5odHRwOi8vbm9uLXNlY3VyZS5leGFtcGxlLmNvbS88L3RleHQ+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgyMCwgNTApIj4KICAgICAgICA8cmVjdCBjbGFzcz0ibm9uLXNlY3VyZSIgaGVpZ2h0PSIxMDUiIHdpZHRoPSIyNTAiIHg9IjAiIHk9IjAiIC8+CiAgICAgICAgPHRleHQgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMTAsIDIwKSI+aHR0cHM6Ly9leGFtcGxlLmNvbS88L3RleHQ+CiAgICAgICA8L2c+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSg0MDAsIDExMCkiPgogICAgICAgIDxjaXJjbGUgY2xhc3M9Im5vbi1zZWN1cmUiIHI9IjUwIj48L2NpcmNsZT4KICAgICAgICA8dGV4dCB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtNzUsIC01NSkiPmh0dHBzOi8vZXhhbXBsZS5jb20vd29ya2VyLmpzPC90ZXh0PgogICAgICAgPC9nPgogICAgICAgPGc+CiAgICAgICAgPHBhdGggZD0iTTE1MCwgODcgQyAyMDAgNzUsIDM1MCA3NSwgNDA1IDExMCIgLz4KICAgICAgIDwvZz4KICAgICAgPC9nPgogICAgIDwvc3ZnPg==)

### 1.4. Shared Workers

Multiple contexts may attach to a Shared Worker. If a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) creates a Shared Worker, then it is a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context), and may only be attached to by other [secure
contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context). If a non-secure context creates a Shared Worker, then
it is *not* a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context), and may only be attached to by other non-secure
contexts.

If `https://example.com/` in a [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) runs `https://example.com/worker.js` as a Shared
Worker, then both the document and the worker are considered secure
contexts.

!(data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjIwMCIgd2lkdGg9IjYwMCI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLDEwKSI+CiAgICAgICA8cmVjdCBjbGFzcz0ic2VjdXJlIiBoZWlnaHQ9IjE3NSIgd2lkdGg9IjMwMCIgeD0iMCIgeT0iMCIgLz4KICAgICAgIDx0ZXh0IHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLCAyMCkiPmh0dHBzOi8vZXhhbXBsZS5jb20vPC90ZXh0PgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoNDAwLCAxMTApIj4KICAgICAgICA8Y2lyY2xlIGNsYXNzPSJzZWN1cmUiIHI9IjUwIj48L2NpcmNsZT4KICAgICAgICA8dGV4dCB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtNzUsIC01NSkiPmh0dHBzOi8vZXhhbXBsZS5jb20vd29ya2VyLmpzPC90ZXh0PgogICAgICAgPC9nPgogICAgICAgPGc+CiAgICAgICAgPHBhdGggZD0iTTE1MCwgODcgQyAyMDAgNzUsIDM1MCA3NSwgNDA1IDExMCIgLz4KICAgICAgIDwvZz4KICAgICAgPC9nPgogICAgIDwvc3ZnPg==)

`https://example.com/` in a different [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) (e.g. in a new window) is a secure context, so it may
access the secure shared worker:

!(data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjQwMCIgd2lkdGg9IjYwMCI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLDEwKSI+CiAgICAgICA8cmVjdCBjbGFzcz0ic2VjdXJlIiBoZWlnaHQ9IjE3NSIgd2lkdGg9IjMwMCIgeD0iMCIgeT0iMCIgLz4KICAgICAgIDx0ZXh0IHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLCAyMCkiPmh0dHBzOi8vZXhhbXBsZS5jb20vPC90ZXh0PgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoNDAwLCAxMTApIj4KICAgICAgICA8Y2lyY2xlIGNsYXNzPSJzZWN1cmUiIHI9IjUwIj48L2NpcmNsZT4KICAgICAgICA8dGV4dCB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtNzUsIC01NSkiPmh0dHBzOi8vZXhhbXBsZS5jb20vd29ya2VyLmpzPC90ZXh0PgogICAgICAgPC9nPgogICAgICAgPGc+CiAgICAgICAgPHBhdGggZD0iTTE1MCwgODcgQyAyMDAgNzUsIDM1MCA3NSwgNDA1IDExMCIgLz4KICAgICAgIDwvZz4KICAgICAgPC9nPgogICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgxMCwyMDApIj4KICAgICAgIDxyZWN0IGNsYXNzPSJzZWN1cmUiIGhlaWdodD0iMTc1IiB3aWR0aD0iMzAwIiB4PSIwIiB5PSIwIiAvPgogICAgICAgPHRleHQgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMTAsIDIwKSI+aHR0cHM6Ly9leGFtcGxlLmNvbS88L3RleHQ+CiAgICAgICA8Zz4KICAgICAgICA8cGF0aCBkPSJNMTUwLCA4NyBDIDIwMCA3NSwgMzUwIDc1LCA0MDUgLTgwIiAvPgogICAgICAgPC9nPgogICAgICA8L2c+CiAgICAgPC9zdmc+)

`https://example.com/` nested in `http://non-secure.example.com/` may
not connect to the secure worker, as it is not a secure context.

!(data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjQwMCIgd2lkdGg9IjYwMCI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLDEwKSI+CiAgICAgICA8cmVjdCBjbGFzcz0ic2VjdXJlIiBoZWlnaHQ9IjE3NSIgd2lkdGg9IjMwMCIgeD0iMCIgeT0iMCIgLz4KICAgICAgIDx0ZXh0IHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLCAyMCkiPmh0dHBzOi8vZXhhbXBsZS5jb20vPC90ZXh0PgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoNDAwLCAxMTApIj4KICAgICAgICA8Y2lyY2xlIGNsYXNzPSJzZWN1cmUiIHI9IjUwIj48L2NpcmNsZT4KICAgICAgICA8dGV4dCB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtNzUsIC01NSkiPmh0dHBzOi8vZXhhbXBsZS5jb20vd29ya2VyLmpzPC90ZXh0PgogICAgICAgPC9nPgogICAgICAgPGc+CiAgICAgICAgPHBhdGggZD0iTTE1MCwgODcgQyAyMDAgNzUsIDM1MCA3NSwgNDA1IDExMCIgLz4KICAgICAgIDwvZz4KICAgICAgPC9nPgogICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgxMCwyMDApIj4KICAgICAgIDxyZWN0IGNsYXNzPSJub24tc2VjdXJlIiBoZWlnaHQ9IjE3NSIgd2lkdGg9IjMwMCIgeD0iMCIgeT0iMCIgLz4KICAgICAgIDx0ZXh0IHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLCAyMCkiPmh0dHA6Ly9ub24tc2VjdXJlLmV4YW1wbGUuY29tLzwvdGV4dD4KICAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKDIwLCA1MCkiPgogICAgICAgIDxyZWN0IGNsYXNzPSJub24tc2VjdXJlIiBoZWlnaHQ9IjEwNSIgd2lkdGg9IjI1MCIgeD0iMCIgeT0iMCIgLz4KICAgICAgICA8dGV4dCB0cmFuc2Zvcm09InRyYW5zbGF0ZSgxMCwgMjApIj5odHRwczovL2V4YW1wbGUuY29tLzwvdGV4dD4KICAgICAgIDwvZz4KICAgICAgIDxnPgogICAgICAgIDxwYXRoIGQ9Ik0xNTAsIDg3IEMgMjAwIDc1LCAzNTAgNzUsIDQwNSAyMCIgLz4KICAgICAgICA8dGV4dCBjbGFzcz0icmVqZWN0aW9uIiB0cmFuc2Zvcm09InRyYW5zbGF0ZSg0MDUsIDIwKSI+WDwvdGV4dD4KICAgICAgIDwvZz4KICAgICAgPC9nPgogICAgIDwvc3ZnPg==)

Likewise, if `https://example.com/` nested in
`http://non-secure.example.com/` runs `https://example.com/worker.js` as
a Shared Worker, then both the document and the worker are considered
non-secure.

!(data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjQwMCIgd2lkdGg9IjYwMCI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLDEwKSI+CiAgICAgICA8cmVjdCBjbGFzcz0ibm9uLXNlY3VyZSIgaGVpZ2h0PSIxNzUiIHdpZHRoPSIzMDAiIHg9IjAiIHk9IjAiIC8+CiAgICAgICA8dGV4dCB0cmFuc2Zvcm09InRyYW5zbGF0ZSgxMCwgMjApIj5odHRwOi8vbm9uLXNlY3VyZS5leGFtcGxlLmNvbS88L3RleHQ+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgyMCwgNTApIj4KICAgICAgICA8cmVjdCBjbGFzcz0ibm9uLXNlY3VyZSIgaGVpZ2h0PSIxMDUiIHdpZHRoPSIyNTAiIHg9IjAiIHk9IjAiIC8+CiAgICAgICAgPHRleHQgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMTAsIDIwKSI+aHR0cHM6Ly9leGFtcGxlLmNvbS88L3RleHQ+CiAgICAgICA8L2c+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSg0MDAsIDExMCkiPgogICAgICAgIDxjaXJjbGUgY2xhc3M9Im5vbi1zZWN1cmUiIHI9IjUwIj48L2NpcmNsZT4KICAgICAgICA8dGV4dCB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtNzUsIC01NSkiPmh0dHBzOi8vZXhhbXBsZS5jb20vd29ya2VyLmpzPC90ZXh0PgogICAgICAgPC9nPgogICAgICAgPGc+CiAgICAgICAgPHBhdGggZD0iTTE1MCwgODcgQyAyMDAgNzUsIDM1MCA3NSwgNDA1IDExMCIgLz4KICAgICAgIDwvZz4KICAgICAgPC9nPgogICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgxMCwyMDApIj4KICAgICAgIDxyZWN0IGNsYXNzPSJzZWN1cmUiIGhlaWdodD0iMTc1IiB3aWR0aD0iMzAwIiB4PSIwIiB5PSIwIiAvPgogICAgICAgPHRleHQgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMTAsIDIwKSI+aHR0cHM6Ly9leGFtcGxlLmNvbS88L3RleHQ+CiAgICAgICA8Zz4KICAgICAgICA8cGF0aCBkPSJNMTUwLCA4NyBDIDIwMCA3NSwgMzUwIDc1LCA0MDUgMjAiIC8+CiAgICAgICAgPHRleHQgY2xhc3M9InJlamVjdGlvbiIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoNDA1LCAyMCkiPlg8L3RleHQ+CiAgICAgICA8L2c+CiAgICAgIDwvZz4KICAgICA8L3N2Zz4=)

### 1.5. Service Workers

Service Workers are always [secure
contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context). Only [secure
contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) may register them, and they may only have clients which
are [secure
contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context).

If `https://example.com/` in a [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) registers `https://example.com/service.js`, then both
the document and the Service Worker are considered secure contexts.

!(data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjIwMCIgd2lkdGg9IjYwMCI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLDEwKSI+CiAgICAgICA8cmVjdCBjbGFzcz0ic2VjdXJlIiBoZWlnaHQ9IjE3NSIgd2lkdGg9IjMwMCIgeD0iMCIgeT0iMCIgLz4KICAgICAgIDx0ZXh0IHRyYW5zZm9ybT0idHJhbnNsYXRlKDEwLCAyMCkiPmh0dHBzOi8vZXhhbXBsZS5jb20vPC90ZXh0PgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoNDAwLCAxMTApIj4KICAgICAgICA8Y2lyY2xlIGNsYXNzPSJzZWN1cmUiIHI9IjUwIj48L2NpcmNsZT4KICAgICAgICA8dGV4dCB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtNzUsIC01NSkiPmh0dHBzOi8vZXhhbXBsZS5jb20vc2VydmljZS5qczwvdGV4dD4KICAgICAgIDwvZz4KICAgICAgIDxnPgogICAgICAgIDxwYXRoIGQ9Ik0xNTAsIDg3IEMgMjAwIDc1LCAzNTAgNzUsIDQwNSAxMTAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvZz4KICAgICA8L3N2Zz4=)

## 2. Framework

*This section is non-normative.*

### 2.1. Integration with WebIDL

A new
\[[`SecureContext`](https://webidl.spec.whatwg.org/#SecureContext)\] attribute is available for operators, which ensures
that they will only be
[exposed](https://webidl.spec.whatwg.org/#dfn-exposed) into secure contexts. The following example should
help:

```
interface ExampleFeature {
 // This call will succeed in all contexts.
 Promise <double> calculateNotSoSecretResult();

 // This operation will not be exposed to a non-secure context.
 [SecureContext] Promise<double> calculateSecretResult();

 // The same applies here: the operation will not be exposed to a non-secure context.
 [SecureContext] boolean getSecretBoolean();
};

[SecureContext]
interface SecureFeature {
 // This interface will not be exposed to non-secure contexts.
 Promise<any> doAmazingThing();
};
```

Specification authors are encouraged to use this attribute when defining
new features.

### 2.2. Integrations with HTML

#### 2.2.1. Shared Workers

The
[`SharedWorker`](https://html.spec.whatwg.org/multipage/workers.html#sharedworker) constructor will throw a
\"[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) exception if a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) attempts to attach to a Worker which is not a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context), and if a non-secure context attempts to attach to a
Worker which is a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context).

#### 2.2.2. Feature Detection

An application can determine whether it's executing in a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) by checking the
[`isSecureContext`](https://html.spec.whatwg.org/multipage/webappapis.html#dom-issecurecontext) boolean defined on
[`WindowOrWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope).

#### 2.2.3. Secure and non-secure contexts

The HTML Standard defines whether an
[environment](https://html.spec.whatwg.org/multipage/semantics.html#link-options-environment) is a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) or a [non-secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#non-secure-context). This is the primary mechanism used by other
specifications.

Given a [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object), specifications can check whether its [relevant
settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object) (which is an
[environment](https://html.spec.whatwg.org/multipage/semantics.html#link-options-environment)) is a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context).

## 3. Algorithms

### 3.1. Is `origin` potentially trustworthy?

A [potentially trustworthy origin] is one which a user agent can
generally trust as delivering data securely.

This algorithms considers certain hosts, scheme, and origins as
potentially trustworthy, even though they might not be authenticated and
encrypted in the traditional sense. In particular, the user agent SHOULD
treat `file` URLs as potentially trustworthy. In principle the user
agent could treat local files as untrustworthy, but, *given the
information that is available to the user agent at runtime*, the
resources appear to have been transported securely from disk to the user
agent. Additionally, treating such resources as potentially trustworthy
is convenient for developers building an application before deploying it
to the public.

This developer-friendlyness is not without risk, however. User agents
which prioritize security over such niceties MAY choose to more strictly
assign trust in a way which excludes `file`.

On the other hand, the user agent MAY choose to extend this trust to
other, vendor-specific URL schemes like `app:` or `chrome-extension:`
which it can determine *a priori* to be trusted (see [§ 7.1 Packaged
Applications](#packaged-applications) for detail).

Given an
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) (`origin`), the following algorithm returns
\"`Potentially Trustworthy`\" or \"`Not Trustworthy`\" as appropriate.

1. If `origin` is an [opaque
 origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque), return \"`Not Trustworthy`\".

2. Assert: `origin` is a [tuple
 origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-tuple).

3. If `origin`'s
 [scheme](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-scheme) is either \"`https`\" or \"`wss`\", return
 \"`Potentially Trustworthy`\".

 This is meant to be analog to the [*a priori*
 authenticated
 URL](https://w3c.github.io/webappsec-mixed-content/#a-priori-authenticated-url) concept in
 [\[MIX\]](#biblio-mix "Mixed Content").

4. If `origin`'s
 [host](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-host) matches one of the CIDR notations `127.0.0.0/8` or
 `::1/128`
 [\[RFC4632\]](#biblio-rfc4632 "Classless Inter-domain Routing (CIDR): The Internet Address Assignment and Aggregation Plan"),
 return \"`Potentially Trustworthy`\".

5. If the user agent conforms to the name resolution rules in
 [\[let-localhost-be-localhost\]](#biblio-let-localhost-be-localhost "Let 'localhost' be localhost.")
 and one of the following is true:

 - `origin`'s
 [host](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-host) is \"`localhost`\" or \"`localhost.`\"

 - `origin`'s
 [host](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-host) ends with \"`.localhost`\" or \"`.localhost.`\"

 then return \"`Potentially Trustworthy`\".

 See [§ 5.2 localhost](#localhost) for details on
 the requirements here.

6. If `origin`'s
 [scheme](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-scheme) is \"`file`\", return
 \"`Potentially Trustworthy`\".

7. If `origin`'s
 [scheme](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-scheme) component is one which the user agent considers to
 be authenticated, return \"`Potentially Trustworthy`\".

 See [§ 7.1 Packaged
 Applications](#packaged-applications) for detail here.

8. If `origin` has been configured as a trustworthy origin,
 return \"`Potentially Trustworthy`\".

 See [§ 7.2 Development
 Environments](#development-environments) for detail here.

9. Return \"`Not Trustworthy`\".

 Neither `origin`'s
[domain](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-domain) nor
[port](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-port) has any effect on whether or not it is considered to be
a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context).

### 3.2. Is `url` potentially trustworthy?

A [potentially trustworthy
URL(#potentially-trustworthy-url)] is one which either inherits context from
its creator (`about:blank`, `about:srcdoc`, `data`) or one whose
[origin](https://url.spec.whatwg.org/#concept-url-origin) is a [potentially trustworthy
origin](#potentially-trustworthy-origin). Given a [URL
record](https://url.spec.whatwg.org/#concept-url) (`url`), the following algorithm returns
\"`Potentially Trustworthy`\" or \"`Not Trustworthy`\" as appropriate:

1. If `url` is \"`about:blank`\" or \"`about:srcdoc`\",
 return \"`Potentially Trustworthy`\".

2. If `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is \"`data`\", return
 \"`Potentially Trustworthy`\".

3. Return the result of executing [§ 3.1 Is origin potentially
 trustworthy?](#is-origin-trustworthy)
 on `url`'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin).

 The origin of `blob:` URLs is the origin of the
 context in which they were created. Therefore, blobs created in a
 trustworthy origin will themselves be potentially trustworthy.

## 4. Threat models and risks

*This section is non-normative.*

### 4.1. Threat Models

Granting permissions to unauthenticated origins is, in the presence of a
network attacker, equivalent to granting the permissions to any origin.
The state of the Internet is such that we must indeed assume that a
network attacker is present. Generally, network attackers fall into 2
classes: passive and active.

#### 4.1.1. Passive Network Attacker

A \"Passive Network Attacker\" is a party who is able to observe traffic
flows but who lacks the ability or chooses not to modify traffic at the
layers which this specification is concerned with.

Surveillance of networks in this manner \"subverts the intent of
communicating parties without the agreement of these parties\" and one
\"cannot defend against the most nefarious actors while allowing
monitoring by other actors no matter how benevolent some might consider
them to be.\"
[\[RFC7258\]](#biblio-rfc7258 "Pervasive Monitoring Is an Attack")
Therefore, the algorithms defined in this document require mechanisms
that provide for the privacy of data at the application layer, not
simply integrity.

#### 4.1.2. Active Network Attacker

An \"Active Network Attacker\" has all the capabilities of a \"Passive
Network Attacker\" and is additionally able to modify, block or replay
any data transiting the network. These capabilities are available to
potential adversaries at many levels of capability, from compromised
devices offering or simply participating in public wireless networks, to
Internet Service Providers indirectly introducing security and privacy
vulnerabilities while manipulating traffic for financial gain
([\[VERIZON\]](#biblio-verizon "Verizon looks to target its mobile subscribers with ads")
and
[\[COMCAST\]](#biblio-comcast "Comcast Wi-Fi serving self-promotional ads via JavaScript injection")
are recent examples), to parties with direct intent to compromise
security or privacy who are able to target individual users,
organizations or even entire populations.

### 4.2. Ancestral Risk

The [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) algorithm walks through all the ancestors of a
particular context in order to determine whether or not the context
itself is secure. Why wouldn't we consider a securely-delivered document
in an
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) to be secure, in and of itself?

The short answer is that this model would enable abuse. Chrome's
implementation of
[\[WEBCRYPTOAPI\]](#biblio-webcryptoapi "Web Cryptography API")
was an early experiment in locking APIs to secure contexts, and it did
not walk through a context's ancestors. The assumption was that locking
the API to a resource which was itself delivered securely would be
enough to ensure secure usage. The result, however, was that entities
like Netflix built
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)- and `postMessage()`-based shims that exposed the
API to non-secure contexts. The restriction was little more than a
speed-bump, slowing down non-secure access to the API, but completely
ineffective in preventing such access.

While the algorithms in this document do not perfectly isolate
non-secure contexts from [secure
contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) (as discussed in [§ 5.1 Incomplete
Isolation](#isolation)), the ancestor checks provide a fairly robust
protection for the guarantees of authentication, confidentiality, and
integrity that such contexts ought to provide.

### 4.3. Risks associated with non-secure contexts

Certain web platform features that have a distinct impact on a user's
security or privacy should be available for use only in [secure
contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) in order to defend against the threats above. Features
available in non-secure contexts risk exposing these capabilities to
network attackers:

1. The ability to read and modify sensitive data
 (personally-identifying information, credentials, payment
 instruments, and so on).
 [\[CREDENTIAL-MANAGEMENT-1\]](#biblio-credential-management-1 "Credential Management Level 1")
 is an example of an API that handles sensitive data.
2. The ability to read and modify input from sensors on a user's device
 (camera, microphone, and GPS being particularly noteworthy, but
 certainly including less obviously dangerous sensors like the
 accelerometer).
 [\[GEOLOCATION-API\]](#biblio-geolocation-api "Geolocation API Specification 2nd Edition")
 and
 [\[MEDIACAPTURE-STREAMS\]](#biblio-mediacapture-streams "Media Capture and Streams")
 are historical examples of features that use sensor input.
3. The ability to access information about other devices to which a
 user has access.
 [\[DISCOVERY-API\]](#biblio-discovery-api "Network Service Discovery")
 and
 [\[WEB-BLUETOOTH\]](#biblio-web-bluetooth "Web Bluetooth")
 are good examples.
4. The ability to track users using temporary or persistent
 identifiers, including identifiers which reset themselves after some
 period of time (e.g. `window.sessionStorage`), identifiers the user
 can manually reset (e.g.
 [\[ENCRYPTED-MEDIA\]](#biblio-encrypted-media "Encrypted Media Extensions"),
 Cookies
 [\[RFC6265\]](#biblio-rfc6265 "HTTP State Management Mechanism"),
 and
 [\[IndexedDB\]](#biblio-indexeddb "Indexed Database API")),
 as well as identifying hardware features the user can't easily
 reset.
5. The ability to introduce some state for an origin which persists
 across browsing sessions.
 [\[SERVICE-WORKERS\]](#biblio-service-workers "Service Workers")
 is a great example.
6. The ability to manipulate a user agent's native UI in some way which
 removes, obscures, or manipulates details relevant to a user's
 understanding of their context.
 [\[FULLSCREEN\]](#biblio-fullscreen "Fullscreen API Standard")
 is a good example.
7. The ability to introduce some functionality for which user
 permission will be required.

This list is non-exhaustive, but should give you a feel for the types of
risks we should consider when writing or implementing specifications.

 While restricting a feature itself to [secure
contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) is critical, we ought not forget that facilities that
carry such information (such as new network access mechanisms, or other
generic functions with access to network data) are equally sensitive.

## 5. Security Considerations

### 5.1. Incomplete Isolation

The [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) definition in this document does not completely isolate
a \"secure\" view on an origin from a \"non-secure\" view on the same
origin. Exfiltration will still be possible via increasingly esoteric
mechanisms such as the contents of `localStorage`/`sessionStorage`,
`storage` events, `BroadcastChannel`, and others.

### 5.2. `localhost`

Section 6.3 of
[\[RFC6761\]](#biblio-rfc6761 "Special-Use Domain Names")
lays out the resolution of `localhost.` and names falling within
`.localhost.` as special, and suggests that local resolvers SHOULD/MAY
treat them specially. For better or worse, resolvers often ignore these
suggestions, and will send `localhost` to the network for resolution in
a number of circumstances.

Given that uncertainty, user agents MAY treat localhost names as having
[potentially trustworthy
origins](#potentially-trustworthy-origin) if and only if they also adhere to the localhost name
resolution rules spelled out in
[\[let-localhost-be-localhost\]](#biblio-let-localhost-be-localhost "Let 'localhost' be localhost.")
(which boil down to ensuring that `localhost` never resolves to a
non-loopback address).

## 6. Privacy Considerations

The [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) definition in this document does not in itself have any
privacy impact. It does, however, enable other features which do have
interesting privacy implications to lock themselves into contexts which
ensures that specific guarantees can be made regarding integrity,
authenticity, and confidentiality.

From a privacy perspective, specification authors are encouraged to
consider requiring secure contexts for the features they define.

## 7. Implementation Considerations

### 7.1. Packaged Applications

A user agent that support packaged applications MAY consider as
\"secure\" specific URL schemes whose contents are authenticated by the
user agent. For example, FirefoxOS application resources are referred to
by a URL whose
[scheme](https://url.spec.whatwg.org/#concept-url-scheme) component is `app:`. Likewise, Chrome's extensions and
apps live on `chrome-extension:` schemes. These could reasonably be
considered trusted origins.

### 7.2. Development Environments

In order to support developers who run staging servers on non-loopback
hosts, the user agent MAY allow users to configure specific sets of
origins as trustworthy, even though [§ 3.1 Is origin potentially
trustworthy?](#is-origin-trustworthy)
would normally return \"`Not Trustworthy`\".

### 7.3. Restricting New Features

*This section is non-normative.*

When writing a specification for new features, we recommend that authors
and editors guard sensitive APIs with checks against [secure
contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context). For example, something like the following might be a
good approach:

1. If the [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object) is *not* a [secure
 context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context), then:
 1. \[*insert something appropriate here: perhaps a Promise could be
 rejected with a `SecurityError`, an error callback could be
 called, a permission request denied, etc.*\].

Authors could alternatively ensure that sensitive APIs are only exposed
to [secure
contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) by guarding them with the
\[[`SecureContext`](https://webidl.spec.whatwg.org/#SecureContext)\] attribute.

```
[SecureContext]
interface SensitiveFeature {
 Promise<double> getTheSecretDouble();
};

// Or:

interface AnotherSensitiveFeature {
 [SecureContext] void doThatPowerfulThing();
};
```

### 7.4. Restricting Legacy Features

*This section is non-normative.*

The list above clearly includes some existing functionality that is
currently available to the web over non-secure channels. We recommend
that such legacy functionality be modified to begin requiring a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) as quickly as is reasonably possible
[\[W3C-PROCESS\]](#biblio-w3c-process "W3C Process Document").

1. If such a feature is not widely implemented, we recommend that the
 specification be immediately
 [modified](https://www.w3.org/2023/Process-20231103/#revising-rec) to include a restriction to [secure
 contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context).

2. If such a feature is widely implemented, but not yet in wide use, we
 recommend that it be quickly restricted to [secure
 contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) by adding a check as described in [§ 7.3
 Restricting New Features](#new) to existing implementations, and
 [modifying the
 specification](https://www.w3.org/2023/Process-20231103/#revising-rec) accordingly.

3. If such a feature is in wide use, we recommend that the existing
 functionality be deprecated; the specification should be
 [modified](https://www.w3.org/2023/Process-20231103/#revising-rec) to note that it does not conform to the
 restrictions outlined in this document, and a plan should be
 developed to both offer a conformant version of the feature and to
 migrate existing users into that new version.

#### 7.4.1. Example: Geolocation

The
[\[GEOLOCATION-API\]](#biblio-geolocation-api "Geolocation API Specification 2nd Edition")
is a good concrete example of such a feature; it is widely implemented
and used on a large number of non-secure sites. A reasonable path
forward might look like this:

1. [Modify](https://www.w3.org/2023/Process-20231103/#revising-rec) the specification to include checks against [secure
 context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) before executing the algorithms for
 [`getCurrentPosition()`](https://w3c.github.io/geolocation-api/#dom-geolocation-getcurrentposition) and
 [`watchPosition()`](https://w3c.github.io/geolocation-api/#dom-geolocation-watchposition).

 If the [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object) is not a [secure
 context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context), then the algorithm should be aborted, and the
 `errorCallback` invoked with a `code` of `PERMISSION_DENIED`.

2. The user agent should announce clear intentions to disable the API
 for non-secure contexts on a specific date, and warn developers
 accordingly (via console messages, for example).

3. Leading up to the flag day, the user agent should announce a
 deprecation schedule to ensure both that site authors recognize the
 need to modify their code before it simply stops working altogether,
 and to protect users in the meantime. Such a plan might include any
 or all of:

 1. Disallowing persistent permission grants to non-secure origins

 2. Coarsening the accuracy of the API for non-secure origins
 (perhaps consistently returning city-level data rather than
 high-accuracy data)

 3. UI modifications to inform users and site authors of the
 risk

## 8. Acknowledgements

This document is largely based on the Chrome Security team's work on
[\[POWERFUL-NEW-FEATURES\]](#biblio-powerful-new-features "Prefer Secure Origins For Powerful New Features").
Chris Palmer, Ryan Sleevi, and David Dorwin have been particularly
engaged. Anne van Kesteren, Jonathan Watt, Boris Zbarsky, and Henri
Sivonen have also provided very helpful feedback.
