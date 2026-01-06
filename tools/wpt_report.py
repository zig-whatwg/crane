#!/usr/bin/env python3
"""
Generate an HTML report from WPT results JSON.
Produces a wpt.fyi-style dashboard with subtest breakdown.
Accumulates results across runs - same tests are replaced, new tests are added.

Usage:
    python tools/wpt_report.py wpt-results/wptreport.json wpt-results/dashboard.html
"""

import json
import sys
from pathlib import Path
from html import escape
from datetime import datetime

ACCUMULATED_RESULTS_FILE = 'wpt-results/accumulated.json'

def load_accumulated_results():
    path = Path(ACCUMULATED_RESULTS_FILE)
    if path.exists():
        with open(path) as f:
            return json.load(f)
    return {'run_info': {}, 'results': []}

def save_accumulated_results(data):
    Path(ACCUMULATED_RESULTS_FILE).parent.mkdir(parents=True, exist_ok=True)
    with open(ACCUMULATED_RESULTS_FILE, 'w') as f:
        json.dump(data, f, indent=2)

def merge_results(accumulated, new_data):
    acc_by_test = {r['test']: r for r in accumulated.get('results', [])}
    
    for result in new_data.get('results', []):
        acc_by_test[result['test']] = result
    
    accumulated['results'] = list(acc_by_test.values())
    accumulated['run_info'] = new_data.get('run_info', accumulated.get('run_info', {}))
    accumulated['last_updated'] = datetime.now().isoformat()
    return accumulated

def status_class(status):
    """Return CSS class for status."""
    return {
        'PASS': 'pass',
        'OK': 'pass',
        'FAIL': 'fail',
        'ERROR': 'error',
        'TIMEOUT': 'timeout',
        'CRASH': 'crash',
        'SKIP': 'skip',
    }.get(status, 'unknown')

def status_icon(status):
    """Return emoji for status."""
    return {
        'PASS': '✅',
        'OK': '✅',
        'FAIL': '❌',
        'ERROR': '⚠️',
        'TIMEOUT': '⏱️',
        'CRASH': '💥',
        'SKIP': '⏭️',
    }.get(status, '❓')

def generate_html(data, output_path):
    """Generate HTML report from WPT JSON data."""
    
    run_info = data.get('run_info', {})
    results = data.get('results', [])
    
    # Calculate stats
    total_tests = len(results)
    total_subtests = sum(len(r.get('subtests', [])) for r in results)
    
    passed_tests = sum(1 for r in results if r.get('status') in ('OK', 'PASS'))
    failed_tests = total_tests - passed_tests
    
    passed_subtests = sum(
        sum(1 for s in r.get('subtests', []) if s.get('status') == 'PASS')
        for r in results
    )
    failed_subtests = total_subtests - passed_subtests
    
    pass_rate = (passed_subtests / total_subtests * 100) if total_subtests > 0 else 0
    
    html = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WPT Results - {run_info.get('product', 'Unknown')}</title>
    <style>
        :root {{
            --pass-color: #28a745;
            --fail-color: #dc3545;
            --error-color: #fd7e14;
            --timeout-color: #6f42c1;
            --skip-color: #6c757d;
            --bg-color: #f8f9fa;
            --card-bg: #ffffff;
            --text-color: #212529;
            --border-color: #dee2e6;
        }}
        
        * {{ box-sizing: border-box; }}
        
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: var(--bg-color);
            color: var(--text-color);
            line-height: 1.5;
        }}
        
        .container {{
            max-width: 1200px;
            margin: 0 auto;
        }}
        
        header {{
            background: var(--card-bg);
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }}
        
        h1 {{
            margin: 0 0 10px 0;
            font-size: 1.5rem;
        }}
        
        .meta {{
            color: #666;
            font-size: 0.9rem;
        }}
        
        .stats {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }}
        
        .stat-card {{
            background: var(--card-bg);
            padding: 15px;
            border-radius: 8px;
            text-align: center;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }}
        
        .stat-card .value {{
            font-size: 2rem;
            font-weight: bold;
        }}
        
        .stat-card .label {{
            color: #666;
            font-size: 0.85rem;
        }}
        
        .stat-card.pass .value {{ color: var(--pass-color); }}
        .stat-card.fail .value {{ color: var(--fail-color); }}
        
        .progress-bar {{
            height: 20px;
            background: var(--fail-color);
            border-radius: 10px;
            overflow: hidden;
            margin-bottom: 20px;
        }}
        
        .progress-bar .fill {{
            height: 100%;
            background: var(--pass-color);
            transition: width 0.3s;
        }}
        
        .filter-bar {{
            background: var(--card-bg);
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
            align-items: center;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }}
        
        .filter-bar input {{
            flex: 1;
            min-width: 200px;
            padding: 8px 12px;
            border: 1px solid var(--border-color);
            border-radius: 4px;
            font-size: 1rem;
        }}
        
        .filter-bar button {{
            padding: 8px 16px;
            border: 1px solid var(--border-color);
            background: var(--card-bg);
            border-radius: 4px;
            cursor: pointer;
        }}
        
        .filter-bar button.active {{
            background: var(--text-color);
            color: white;
        }}
        
        .test {{
            background: var(--card-bg);
            border-radius: 8px;
            margin-bottom: 10px;
            overflow: hidden;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }}
        
        .test-header {{
            padding: 12px 15px;
            cursor: pointer;
            display: flex;
            align-items: center;
            gap: 10px;
            border-left: 4px solid transparent;
        }}
        
        .test-header:hover {{
            background: #f0f0f0;
        }}
        
        .test.pass .test-header {{ border-left-color: var(--pass-color); }}
        .test.fail .test-header {{ border-left-color: var(--fail-color); }}
        .test.error .test-header {{ border-left-color: var(--error-color); }}
        .test.timeout .test-header {{ border-left-color: var(--timeout-color); }}
        
        .test-name {{
            flex: 1;
            font-family: monospace;
            font-size: 0.9rem;
            word-break: break-all;
        }}
        
        .test-stats {{
            font-size: 0.85rem;
            color: #666;
            white-space: nowrap;
        }}
        
        .subtests {{
            display: none;
            border-top: 1px solid var(--border-color);
            padding: 10px 15px;
            background: #fafafa;
        }}
        
        .test.expanded .subtests {{
            display: block;
        }}
        
        .subtest {{
            padding: 6px 0;
            display: flex;
            align-items: flex-start;
            gap: 10px;
            border-bottom: 1px solid #eee;
        }}
        
        .subtest:last-child {{
            border-bottom: none;
        }}
        
        .subtest-status {{
            font-size: 1rem;
        }}
        
        .subtest-name {{
            flex: 1;
            font-size: 0.85rem;
        }}
        
        .subtest-message {{
            font-size: 0.8rem;
            color: #666;
            font-family: monospace;
            margin-top: 4px;
            padding: 8px;
            background: #fff;
            border-radius: 4px;
            white-space: pre-wrap;
            word-break: break-all;
        }}
        
        .expand-icon {{
            transition: transform 0.2s;
        }}
        
        .test.expanded .expand-icon {{
            transform: rotate(90deg);
        }}
        
        .hidden {{
            display: none !important;
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>WPT Results: {escape(run_info.get('product', 'Unknown Browser'))}</h1>
            <div class="meta">
                Version: {escape(run_info.get('browser_version', 'N/A'))} |
                OS: {escape(run_info.get('os', 'N/A'))} |
                Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
            </div>
        </header>
        
        <div class="stats">
            <div class="stat-card">
                <div class="value">{total_tests}</div>
                <div class="label">Total Tests</div>
            </div>
            <div class="stat-card pass">
                <div class="value">{passed_subtests}</div>
                <div class="label">Passed Subtests</div>
            </div>
            <div class="stat-card fail">
                <div class="value">{failed_subtests}</div>
                <div class="label">Failed Subtests</div>
            </div>
            <div class="stat-card">
                <div class="value">{pass_rate:.1f}%</div>
                <div class="label">Pass Rate</div>
            </div>
        </div>
        
        <div class="progress-bar">
            <div class="fill" style="width: {pass_rate}%"></div>
        </div>
        
        <div class="filter-bar">
            <input type="text" id="search" placeholder="Filter tests..." onkeyup="filterTests()">
            <button class="active" onclick="showAll()">All</button>
            <button onclick="showFailed()">Failed Only</button>
            <button onclick="expandAll()">Expand All</button>
            <button onclick="collapseAll()">Collapse All</button>
        </div>
        
        <div id="tests">
'''

    # Sort results: failures first, then by name
    sorted_results = sorted(results, key=lambda r: (
        0 if r.get('status') not in ('OK', 'PASS') or any(s.get('status') != 'PASS' for s in r.get('subtests', [])) else 1,
        r.get('test', '')
    ))

    for result in sorted_results:
        test_name = result.get('test', 'Unknown')
        test_status = result.get('status', 'UNKNOWN')
        subtests = result.get('subtests', [])
        message = result.get('message', '')
        
        # Determine overall status class
        has_failures = any(s.get('status') != 'PASS' for s in subtests)
        overall_class = 'fail' if has_failures or test_status not in ('OK', 'PASS') else 'pass'
        
        passed = sum(1 for s in subtests if s.get('status') == 'PASS')
        total = len(subtests)
        
        html += f'''
            <div class="test {overall_class}" data-name="{escape(test_name.lower())}">
                <div class="test-header" onclick="toggleTest(this.parentElement)">
                    <span class="expand-icon">▶</span>
                    <span class="test-name">{escape(test_name)}</span>
                    <span class="test-stats">{passed}/{total} subtests</span>
                    <span>{status_icon(test_status)}</span>
                </div>
                <div class="subtests">
'''
        
        if message:
            html += f'<div class="subtest-message">{escape(message)}</div>'
        
        for subtest in subtests:
            sub_name = subtest.get('name', 'Unknown')
            sub_status = subtest.get('status', 'UNKNOWN')
            sub_message = subtest.get('message', '')
            
            html += f'''
                    <div class="subtest">
                        <span class="subtest-status">{status_icon(sub_status)}</span>
                        <div class="subtest-name">
                            {escape(sub_name)}
                            {f'<div class="subtest-message">{escape(sub_message)}</div>' if sub_message else ''}
                        </div>
                    </div>
'''
        
        html += '''
                </div>
            </div>
'''

    html += '''
        </div>
    </div>
    
    <script>
        function toggleTest(el) {
            el.classList.toggle('expanded');
        }
        
        function filterTests() {
            const query = document.getElementById('search').value.toLowerCase();
            document.querySelectorAll('.test').forEach(test => {
                const name = test.dataset.name;
                test.classList.toggle('hidden', !name.includes(query));
            });
        }
        
        function showAll() {
            document.querySelectorAll('.test').forEach(t => t.classList.remove('hidden'));
            document.querySelectorAll('.filter-bar button').forEach(b => b.classList.remove('active'));
            event.target.classList.add('active');
        }
        
        function showFailed() {
            document.querySelectorAll('.test').forEach(t => {
                t.classList.toggle('hidden', t.classList.contains('pass'));
            });
            document.querySelectorAll('.filter-bar button').forEach(b => b.classList.remove('active'));
            event.target.classList.add('active');
        }
        
        function expandAll() {
            document.querySelectorAll('.test:not(.hidden)').forEach(t => t.classList.add('expanded'));
        }
        
        function collapseAll() {
            document.querySelectorAll('.test').forEach(t => t.classList.remove('expanded'));
        }
    </script>
</body>
</html>
'''

    Path(output_path).write_text(html)
    print(f"Report generated: {output_path}")
    print(f"  Tests: {total_tests} | Subtests: {passed_subtests}/{total_subtests} ({pass_rate:.1f}% pass)")

def main():
    if len(sys.argv) < 3:
        print("Usage: python wpt_report.py <input.json> <output.html>")
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    
    with open(input_path) as f:
        new_data = json.load(f)
    
    accumulated = load_accumulated_results()
    merged = merge_results(accumulated, new_data)
    save_accumulated_results(merged)
    
    generate_html(merged, output_path)
    print(f"  Accumulated {len(merged['results'])} total tests")

if __name__ == '__main__':
    main()
