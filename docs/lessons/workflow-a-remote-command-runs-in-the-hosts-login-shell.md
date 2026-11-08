# Workflow: A remote command runs in the host's login shell - zsh on the Macs, bash on server1

**Date**: 2026-11-08
**Lesson**: A command string given to ssh is run by the host's login shell, so the same string behaves differently on chat.local and chat2 (zsh) and on server1 (bash); send anything longer than one command as a script to `bash -s`, and brace a variable before a colon on the Mac's own zsh command line.

**Why**: zsh does not word-split an unquoted parameter (`set -- $p` with p="a b" sets one argument), and in zsh `$h:c` is a history modifier, not "$h" followed by ":c". bash does neither. The pool scripts already wrap their remote commands in `exec bash -c` for this reason (crane-pool.sh on/wpt); an ad-hoc ssh does not.

**What Happened**: Deploying the portable host scripts to chat.local and chat2 (lane linux1 b2), `scp f "bcardarella@$h:crane-deploy/"` on the Mac's zsh copied to a local path `bcardarella@chat.localrane-deploy/` (the `:c` modifier) - the same trap left `bcardarella@chat.localrane-measure.sh.new` files in tmp/remote/ earlier. Then a remote loop `for p in 'a b' ...; do set -- $p; cp ~/$2 ...` ran under the hosts' zsh, `$2` was empty, and `cp ~/ ...` stopped the script (set -e, nothing changed). The same loop works on server1.

**Fix**: `"bcardarella@${h}:path"`, and the remote part as a file piped to `ssh host bash -s < script.sh`.

**Takeaway**: **Never assume the remote shell: pipe a multi-line remote step to `bash -s` (or `exec bash -c`), and write `${host}:` - not `$host:` - on the Mac's zsh.**
