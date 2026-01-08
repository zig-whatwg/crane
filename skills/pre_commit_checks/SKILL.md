# Pre-Commit Checks Skill

## Overview

This skill ensures code quality by running automated checks before every commit. It prevents commits with formatting issues, build errors, or test failures.

## Core Principle

**Never commit unformatted, broken, or untested code.**

Every commit must pass:
1. ✅ Formatting check (`zig fmt --check`)
2. ✅ Build check (`zig build`)
3. ✅ Test check (`zig build test`)

## Pre-Commit Hook

The repository includes a git pre-commit hook that automatically runs these checks.

### Location

`.git/hooks/pre-commit`

### What It Does

```bash
#!/bin/bash
set -e

echo "Running pre-commit checks..."

# 1. Format check
echo "→ Checking code formatting..."
zig fmt --check src/ tests/ || {
    echo "❌ Formatting check failed!"
    echo "Run: zig fmt src/ tests/"
    exit 1
}

# 2. Build check
echo "→ Building project..."
zig build || {
    echo "❌ Build failed!"
    exit 1
}

# 3. Test check
echo "→ Running tests..."
zig build test --summary all || {
    echo "❌ Tests failed!"
    exit 1
}

echo "✅ All pre-commit checks passed!"
```

## Installation

### Automatic Setup

Run the setup script:

```bash
./scripts/setup-git-hooks.sh
```

### Manual Setup

Copy the pre-commit hook:

```bash
cp scripts/pre-commit.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

## Usage

Once installed, the hook runs automatically on `git commit`:

```bash
# Make changes
vim src/io_queue.zig

# Stage changes
git add src/io_queue.zig

# Commit (hook runs automatically)
git commit -m "Add feature"

# Output:
# Running pre-commit checks...
# → Checking code formatting...
# → Building project...
# → Running tests...
# ✅ All pre-commit checks passed!
# [main abc123] Add feature
```

## Handling Failures

### Formatting Failure

```bash
git commit -m "Add feature"
# → Checking code formatting...
# src/io_queue.zig
# ❌ Formatting check failed!
# Run: zig fmt src/ tests/

# Fix:
zig fmt src/ tests/
git add src/io_queue.zig
git commit -m "Add feature"
```

### Build Failure

```bash
git commit -m "Add feature"
# → Building project...
# error: ...
# ❌ Build failed!

# Fix the build error first
vim src/io_queue.zig
git add src/io_queue.zig
git commit -m "Add feature"
```

### Test Failure

```bash
git commit -m "Add feature"
# → Running tests...
# test "feature" failed
# ❌ Tests failed!

# Fix the test
vim src/io_queue.zig
git add src/io_queue.zig
git commit -m "Add feature"
```

## Bypassing the Hook (Emergency Only)

**⚠️ Use with extreme caution!**

```bash
# Skip pre-commit checks (NOT recommended)
git commit --no-verify -m "Emergency fix"
```

**Only bypass when:**
- Working on a known-broken branch
- Committing work-in-progress for backup
- Time-critical emergency situation

**Never bypass for:**
- Regular development
- Pull requests
- Main branch commits

## Agent Workflow

### Before Every Commit

When an AI agent (or developer) is about to commit:

1. **Format all modified files:**
   ```bash
   zig fmt src/ tests/
   git add -u
   ```

2. **Run build:**
   ```bash
   zig build
   ```

3. **Run tests:**
   ```bash
   zig build test --summary all
   ```

4. **Verify formatting:**
   ```bash
   zig fmt --check src/ tests/
   ```

5. **Then commit:**
   ```bash
   git commit -m "Your message"
   # Hook will verify everything again
   ```

### Automated Check Pattern

```zig
// Pseudo-code for agent workflow
fn beforeCommit() !void {
    // 1. Format
    try runCommand("zig fmt src/ tests/");
    
    // 2. Stage formatting changes
    try runCommand("git add -u");
    
    // 3. Verify formatting
    const fmt_result = try runCommand("zig fmt --check src/ tests/");
    if (fmt_result.exit_code != 0) return error.FormattingFailed;
    
    // 4. Build
    const build_result = try runCommand("zig build");
    if (build_result.exit_code != 0) return error.BuildFailed;
    
    // 5. Test
    const test_result = try runCommand("zig build test");
    if (test_result.exit_code != 0) return error.TestsFailed;
    
    // 6. Now safe to commit
    try runCommand("git commit -m \"...\"");
}
```

## CI/CD Integration

The pre-commit hook mirrors the CI checks:

| Check | Pre-Commit Hook | GitHub Actions CI |
|-------|----------------|-------------------|
| Formatting | `zig fmt --check` | `zig fmt --check` |
| Build | `zig build` | `zig build` |
| Tests | `zig build test` | `zig build test` |

**Benefit**: If pre-commit passes, CI will pass.

## Best Practices

### DO ✅

- Run pre-commit checks before committing
- Format files immediately after editing
- Fix failures before committing
- Keep commits small and focused
- Test changes locally before pushing

### DON'T ❌

- Bypass pre-commit hooks regularly
- Commit unformatted code
- Commit broken builds
- Commit failing tests
- Push without running checks locally

## Troubleshooting

### Hook Not Running

```bash
# Check if hook exists
ls -l .git/hooks/pre-commit

# If missing, reinstall:
./scripts/setup-git-hooks.sh
```

### Hook Not Executable

```bash
# Make executable
chmod +x .git/hooks/pre-commit
```

### Hook Runs But Fails

```bash
# Debug mode
bash -x .git/hooks/pre-commit
```

### Zig Not Found

```bash
# Ensure Zig is in PATH
which zig

# Or update hook to use absolute path
# Change: zig fmt
# To: /path/to/zig fmt
```

## Performance

### Typical Times

- Format check: ~100ms
- Build: ~2s
- Tests: ~300ms
- **Total**: ~2.5s per commit

### Optimization Tips

If pre-commit checks are slow:

1. **Skip tests for WIP commits:**
   ```bash
   # Edit .git/hooks/pre-commit
   # Comment out test section for development
   ```

2. **Use faster build:**
   ```bash
   # Use cached build
   zig build --help | grep cache
   ```

3. **Format only changed files:**
   ```bash
   # Instead of: zig fmt src/ tests/
   # Use: zig fmt $(git diff --cached --name-only --diff-filter=ACM | grep '.zig$')
   ```

## Integration with Development Tools

### VS Code

Add to `.vscode/settings.json`:

```json
{
    "[zig]": {
        "editor.formatOnSave": true,
        "editor.defaultFormatter": "ziglang.vscode-zig"
    }
}
```

### Vim/Neovim

Add to `.vimrc`:

```vim
autocmd BufWritePre *.zig !zig fmt %
```

### Emacs

Add to `init.el`:

```elisp
(add-hook 'zig-mode-hook
  (lambda ()
    (add-hook 'before-save-hook 'zig-format-buffer nil t)))
```

## Summary

**Pre-commit checks ensure:**
- ✅ All code is properly formatted
- ✅ All code builds successfully
- ✅ All tests pass
- ✅ CI will pass when pushed
- ✅ Consistent code quality

**Result**: No more "oops, forgot to format" commits!

## Related

- See `skills/zig_standards/` for formatting rules
- See `skills/testing_requirements/` for test requirements
- See `.github/workflows/ci.yml` for CI checks
