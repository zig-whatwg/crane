# Specifications

Moved verbatim from AGENTS.md (2026-11-03). The core keeps each rule as one line and points here.

## Know what kind of work you're doing

**Spec work** (a DOM method, a parser state machine, a WebIDL conversion):
load the complete algorithm section from `specs/` before writing. Never work
from grep fragments — every algorithm has edge cases that live in the
surrounding prose.

**Specs are cached in `specs/`, and kept fresh** (the user, 2026-10-02). A spec
you need that is not there: fetch it and save it (`specs/get <url> <dir>`:
`specs/w3c/` for W3C, WICG and CSSWG drafts, `specs/whatwg/` for WHATWG), as its
own commit. A cached spec six months old or more: compare it with upstream before
relying on it, and update it when a newer version exists, as its own commit.
`specs/whatwg/` is gitignored (local only; worktrees link it). `specs/idl/` is
different: a pinned webref snapshot that codegen depends on, updated only by the
procedure in specs/idl/WEBREF.md.

## WHATWG specifications

| Spec | URL | Local |
|------|-----|-------|
| URL | https://url.spec.whatwg.org/ | `specs/whatwg/url.md` |
| Encoding | https://encoding.spec.whatwg.org/ | `specs/whatwg/encoding.md` |
| Streams | https://streams.spec.whatwg.org/ | `specs/whatwg/streams.md` |
| Infra | https://infra.spec.whatwg.org/ | `specs/whatwg/infra.md` |
| WebIDL | https://webidl.spec.whatwg.org/ | `specs/whatwg/webidl.md` |
| Console | https://console.spec.whatwg.org/ | `specs/whatwg/console.md` |
| MIME Sniff | https://mimesniff.spec.whatwg.org/ | `specs/whatwg/mimesniff.md` |
| Fetch | https://fetch.spec.whatwg.org/ | `specs/whatwg/fetch.md` |
| DOM | https://dom.spec.whatwg.org/ | `specs/whatwg/dom.md` |
| HTML | https://html.spec.whatwg.org/ | `specs/whatwg/html.md` (parsing chapter alone: `specs/whatwg/html/parsing.md`) |

Specs reference each other constantly. Most depend on **Infra**; anything with
a Web API depends on **WebIDL**.
