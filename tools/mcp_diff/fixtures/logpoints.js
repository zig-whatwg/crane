// Logpoint fixture: line numbers matter (tools/mcp_diff cases "logpoints: ...").
function add(x, y) {
  const sum = x + y;
  return sum;
}

// a comment line
window.run = n => {
  const doubled = add(n, n);
  return doubled;
};
