# Testing: Headless Chrome May Never Exit, and a Reused Profile Caches a Regenerated Page

**Date**: 2026-09-30
**Lesson**: Headless Chrome's `--screenshot` and `--dump-dom` can write their output and never exit, and a capture round that reuses its profile can serve a regenerated page from cache.

**Why**: Chrome 151's one-shot headless modes finish their work and then keep the browser process alive; nothing in the flag says "exit after". A persistent `--user-data-dir` keeps the HTTP and file caches between rounds, so a page regenerated at the same URL can come back stale.

**What Happened**: While the wptsite2 lane verified the static results site, `--dump-dom` and `--screenshot` calls hung after writing their files, holding the shell until killed. Later a CDP capture round that reused its profile showed the old subtitle while `index.html` on disk already had the new one - evidence of a fix that was not in the capture.

**Fix**:
1. Bound every headless call: `perl -e 'alarm 30; exec @ARGV' chrome --headless ...`.
2. Kill leftovers by their profile path (`pkill -f <profile-dir>`), never by name.
3. Give each capture round a fresh `--user-data-dir`, or send `Network.setCacheDisabled` over CDP.
4. Serve pages over a local http server when they load fonts: Chrome refuses fonts from `file://` (CORS).

**Takeaway**: **Bound every headless call, and never reuse a profile across a regeneration.**
