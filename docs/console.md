# The browser console: Crane as a headless browser

`repl` is a Browser showing a page, and the console that evaluates in it - what Chrome DevTools'
console is to a tab. Crane draws nothing (rendering and layout are its one deliberate exclusion), so
the console is how a person, or a script, drives the page: open URLs, run JavaScript in the page,
watch what the page prints, follow its navigations, its popups and its workers.

## Build and run

```bash
zig build repl-exe -j2 --cache-dir ~/Library/Caches/crane-z16-cache
./zig-out/bin/repl https://example.com
```

`zig build repl-exe` builds the console and its snapshot (`zig-out/bin/whatwg_snapshot.bin`, read
from beside the binary) and nothing else; `zig build repl -- <args>` builds it and runs it. The
snapshot generator is a Debug build whatever the mode (`-Dsnapshot-generator-optimize` for a
diagnosis): its snapshot is the same whatever `-Doptimize` says, and the console's compile does not
wait for it - only its install does.

The console builds **ReleaseSafe by default**, as the WPT runner does: it is a tool people use, and a
Debug console lags (std's Debug allocator captured a stack trace on every allocation and free).
`-Drepl-optimize=Debug` (or an explicit `-Doptimize=Debug`) builds the Debug console, for a diagnosis
in a debugger; Crane's own modules keep `-Doptimize`'s mode either way, so their Debug-only checks stay.
The console allocates with libc malloc; `--check-leaks` gives it a leak-checking allocator instead
(no per-allocation traces; `CRANE_LEAK_TRACES=1` adds a six-frame trace to each leak), and the leaks
are reported when it exits.

How much memory JavaScript's young generation takes is decided when the console is BUILT, not when
it is run: `-Dv8-young-generation-mb=<n>`, megabytes of the WHOLE young generation of each of its
isolates - the page's and every worker's. The default, 24, keeps V8's semispaces at 8 MB: less
memory held between collections, slower on pages that allocate heavily. A desktop build passes
`-Dv8-young-generation-mb=0`, V8's own sizing (32 MB semispaces, as Chrome on desktop).
docs/engine-protocol.md, section 7b, has the table of values and why this is a build option of
the V8 adapter rather than a command-line flag.

```
repl [<url>] [--user-agent=<s>] [--proxy=system|direct|<url>] [--accept-insecure-certs]
     [--ca-bundle=<pem>] [--timeout=<ms>] [--wait-for-navigation]
```

| Flag | What it does |
|---|---|
| `<url>` | The first tab's page (default `about:blank`). The first prompt waits for its load event - the document's readiness "complete", which HTML's "the end" sets in the task that fires `load` - at most `--timeout`. |
| `--user-agent=<s>` | The `User-Agent` header and `navigator.userAgent`, in windows and workers. |
| `--proxy=system` | The environment's `http_proxy`, `https_proxy`, `no_proxy` (the default). |
| `--proxy=direct` | No proxy. |
| `--proxy=<url>` | Every request through this proxy (PAC files and auto-detection are not supported). |
| `--accept-insecure-certs` | TLS certificates are not verified (WebDriver's `acceptInsecureCerts`). |
| `--ca-bundle=<pem>` | Trust this PEM bundle besides the system's (WPT's `tools/certs/cacert.pem`). |
| `--timeout=<ms>` | How long a load, or an evaluation, is waited for (30000). |
| `--wait-for-navigation` | On a terminal too, an input that starts a navigation holds the next prompt until it has loaded (piped input always does). |
| `--check-leaks` | A leak-checking allocator; leaks are reported at exit (`CRANE_LEAK_TRACES=1` for traces). |

`--profile=<dir>` is refused: no store persists yet (cookies, localStorage, IndexedDB, the Cache
API and the HTTP cache are all in memory, and the Browser writes nothing to disk). Persistence is
queued (STORAGE PERSISTENCE).

## Using it

Type JavaScript; Enter evaluates once the input is complete (an open block asks for more with
`...`). Input is evaluated as Chrome's console evaluates it (REPL mode): top-level `await`, and a
`let`, `const` or `class` declared again replaces the earlier one. Tab completes a name, the arrows
walk the history. Ctrl+C stops waiting for an evaluation or a load (and aborts a synchronous script
that runs too long); at a prompt it clears the line, and at an empty prompt it says
"(To exit, press Ctrl+C again or Ctrl+D or type .exit)" - a second Ctrl+C exits, as in Node's REPL.
Ctrl+D or `.exit` exits.

The page is live while the console waits for input: timers fire, fetches complete, workers post,
navigations proceed. What the page prints - `console.log` and the rest, from the page, its frames,
its popups and its workers - and the exceptions and promise rejections nothing handled print as
they happen, above the prompt, marked with where they came from when that is not the one tab's own
document (`[tab 2]`, `[frame <url>]`, `[worker <url>]`).

Navigations print as they start and as their document commits:

```
> location.href = 'https://example.org/'
'https://example.org/'
Navigating to https://example.org/
Navigated to https://example.org/ (200)
```

On a terminal the prompt comes back at once, as in Chrome: a line typed before the commit reads the
old page. Piped input (`repl <url> < script.js`) waits for the navigation an input started, so each
line reads the page the line before it left.

| Command | |
|---|---|
| `.open <url>` | Navigate the tab to `<url>` as its address bar does, and wait for its load. |
| `.reload` | Reload the tab. |
| `.back`, `.forward` | HTML "traverse the history by a delta" on the tab's session history. |
| `.url` | The tab's URL. |
| `.tabs` | The Browser's tabs: its own and every popup a page opened (`window.open`, a link's or form's target), with URL, title and opener. |
| `.tab <n>` | Evaluate in tab `<n>` from now on. |
| `.close [<n>]` | Close a popup (HTML "close": beforeunload, unload, destroy). |
| `.newtab` | Not supported yet (HOST-OPENED TABS: the host page's realm is entered for its life). |
| `.help`, `.exit` | `.exit` ends the console, as Ctrl+D does, and Ctrl+C twice at an empty prompt. |

## Scripted use

Piped input makes the console a headless browser for scripts: each line runs when the one before
it has finished (its promise settled, and any navigation it started loaded).

```bash
printf '%s\n' 'document.title' 'document.querySelector("a").click()' 'location.href' '.exit' \
  | ./zig-out/bin/repl https://example.com
```

## What is excluded, and why

- Rendering and layout: Crane is the web platform; the host supplies pixels. No screenshots, no
  geometry (`getBoundingClientRect` and layout-dependent values are what the layout backend gives:
  none here).
- Automation protocols (CDP, WebDriver BiDi): not the console's - src/webdriver is their home.
- Media decoding beyond WAV: the platform decides what it decodes (protocol `media_decoding`; lane
  wptcfg D4, the user 2026-11-09). Crane's default platforms build in WAV linear PCM
  (kit/media_decoding), so the console's `<audio>` plays a WAV - `canPlayType('audio/wav')` is
  `"maybe"`, `loadedmetadata` and `ended` fire - and answers `""` for WebM, Ogg and MP4, which nothing
  decodes yet.
- Persistence: everything is in memory (above).
