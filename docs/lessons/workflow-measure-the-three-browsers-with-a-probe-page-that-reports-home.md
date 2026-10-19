# Workflow: Measure the three browsers with a probe page that reports home

**Date**: 2026-10-19
**Lesson**: When golden rule 2 needs a value the wpt.fyi results cannot give (a passing subtest prints no value, a mechanism no test isolates), run one probe page in Chrome, Firefox and Safari on the Macs and have it report its JSON to a local HTTP server - minutes, not a source-reading afternoon, and the answer is what the browsers compute, not what a table in their source says.

**Why**: wpt.fyi stores a failure message only for a failing subtest, and its Chrome and Firefox run on Linux. Engine source tables are often not what ships: Chrome on macOS answers ButtonBorder from its ColorProvider (black, light) while Blink's DefaultSystemColor says #767676; Safari's system colors come from AppKit. A three-way palette or a phase question ("does a script inserted before the meta see it?") has to be measured.

**What Happened**: Lane style4 needed each system color under `color-scheme: only dark`, the phase of the color-scheme and default-style meta steps, and how each browser treats `inherit` as meta content. The probe (lane style4 tmp/analysis/probe*.html) wrote its results into a `<pre>` and fetched `/report?<json>`.
- Chrome: `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --no-first-run --user-data-dir=<scratch> --dump-dom file://<probe>` and read the `<pre>`. Over http, --dump-dom can hang: use the report server, under `timeout`.
- Firefox: started from the agent's own shell, its content process never starts (`sandbox_extension_issue_file_to_process failed`; MOZ_DISABLE_CONTENT_SANDBOX does not help). Started through LaunchServices it works: `open -n -a /Applications/Firefox.app --args --headless --no-remote --profile <scratch> http://127.0.0.1:<port>/probe.html` (Bash with dangerouslyDisableSandbox for the local port), then `pkill -f <scratch>`.
- Safari: on chat.local, which has a console session: copy the probe and the server there, `open -g -a Safari http://127.0.0.1:<port>/probe.html`, wait for the report, then `osascript -e 'quit app "Safari"'` (it was not running before).
- The server: a 10-line `http.server.SimpleHTTPRequestHandler` that appends the query of `/report?...` to a file (scratch only, never committed).

**Fix**: Keep the probe, the raw JSON and the browser versions with the lane's evidence, cite them beside the code, and delete the profiles, servers and copies the same hour. Note the appearance: both Macs were in Dark mode, so a `light dark` list resolved to dark in all three - the preference is the host's.

**Takeaway**: **For a value or a phase wpt.fyi cannot show, measure all three browsers with one probe page that reports to a local server - Firefox through `open -n -a`, Safari on chat - and cite the versions and the JSON.**
