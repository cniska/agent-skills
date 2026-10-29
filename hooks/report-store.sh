report_file() {
  printf '%s/reports/%s.json\n' "$CLAUDE_PLUGIN_DATA" "$1"
}
