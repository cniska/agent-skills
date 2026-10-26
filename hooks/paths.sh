path_tokens() {
  { grep -Eo "[^][[:space:]\`'\"():,;<>{}]+" || [ "$?" -eq 1 ]; } | sed -E 's/\.$//'
}

absolute_paths() {
  path_tokens | sed -n '\|^/|p'
}
