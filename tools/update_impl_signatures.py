#!/usr/bin/env python3
"""
Update function signatures in src/webidl/impls/ to match src/webidl/impls_tmp/

This script:
1. Scans impls_tmp/ for function signatures
2. For each function found in impls/, updates just the signature if it differs
3. Preserves the function body from impls/
"""

import os
import re
import sys

IMPLS_DIR = "src/webidl/impls"
IMPLS_TMP_DIR = "src/webidl/impls_tmp"

# Regex to match function signature (pub fn name(params) return_type {)
FN_PATTERN = re.compile(
    r'^(pub fn (\w+)\([^)]*\)\s*[^{]*)\s*\{',
    re.MULTILINE
)

def extract_signatures(content):
    """Extract function signatures from file content."""
    signatures = {}
    for match in FN_PATTERN.finditer(content):
        full_sig = match.group(1).strip()
        fn_name = match.group(2)
        signatures[fn_name] = full_sig
    return signatures

def update_signatures(impl_content, tmp_signatures):
    """Update signatures in impl content to match tmp signatures."""
    updated = impl_content
    changes = []
    
    for match in FN_PATTERN.finditer(impl_content):
        old_sig = match.group(1).strip()
        fn_name = match.group(2)
        
        if fn_name in tmp_signatures:
            new_sig = tmp_signatures[fn_name]
            if old_sig != new_sig:
                # Replace just this signature
                updated = updated.replace(old_sig + " {", new_sig + " {", 1)
                changes.append(fn_name)
    
    return updated, changes

def process_file(impl_file, tmp_file):
    """Process a single impl file."""
    if not os.path.exists(tmp_file):
        return None, []
    
    with open(impl_file, 'r') as f:
        impl_content = f.read()
    
    with open(tmp_file, 'r') as f:
        tmp_content = f.read()
    
    tmp_signatures = extract_signatures(tmp_content)
    updated_content, changes = update_signatures(impl_content, tmp_signatures)
    
    if changes:
        with open(impl_file, 'w') as f:
            f.write(updated_content)
    
    return updated_content, changes

def main():
    if not os.path.exists(IMPLS_DIR) or not os.path.exists(IMPLS_TMP_DIR):
        print(f"Error: {IMPLS_DIR} or {IMPLS_TMP_DIR} not found")
        sys.exit(1)
    
    total_changes = 0
    files_changed = 0
    
    for filename in os.listdir(IMPLS_DIR):
        if not filename.endswith('.zig') or filename == 'root.zig':
            continue
        
        impl_file = os.path.join(IMPLS_DIR, filename)
        tmp_file = os.path.join(IMPLS_TMP_DIR, filename)
        
        _, changes = process_file(impl_file, tmp_file)
        
        if changes:
            print(f"{filename}: updated {len(changes)} signatures")
            for fn in changes:
                print(f"  - {fn}")
            total_changes += len(changes)
            files_changed += 1
    
    print(f"\nTotal: {total_changes} signatures updated in {files_changed} files")

if __name__ == "__main__":
    main()
