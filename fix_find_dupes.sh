#!/usr/bin/env bash
set -e

echo "🔧 Cleaning duplicates..."

# 1. Ensure we're on main and up to date
git checkout main
git pull --ff-only

# 2. Remove duplicate nav items (FIND or Find Plus)
for f in $(git ls-files '*.html'); do
  perl -0777 -pi -e 's!\s*<li[^>]*>\s*<a[^>]*>\s*(?:FIND|Find\s*Plus)\s*</a>\s*</li>\s*!!gi' "$f"
done

# 3. De-duplicate multiple “Find” links in nav
for f in $(git ls-files '*.html'); do
  perl -0777 -pi -e '
    my $seen = 0;
    s{
      \s*<li[^>]*>\s*<a[^>]*href=(["'\''])[^\1]*?/solutions/find\.html\1[^>]*>.*?</a>\s*</li>\s*
    }{
      ($seen++ ? q{} : $&)
    }igesx;
  ' "$f"
done

# 4. Remove duplicate “Find”/“Find Plus” cards on home and solutions landing pages
for f in index.html solutions/index.html; do
  [ -f "$f" ] || continue
  perl -0777 -pi -e '
    s{
      \s*<div[^>]*?(?:card|feature|tile)[^>]*>
      (?:(?!<div[^>]*>).)*?
      <h[1-6][^>]*>\s*(?:FIND|Find\s*Plus)\s*</h[1-6]>
      .*?</div>\s*
    }{}igsx;
  ' "$f"
done

# 5. Normalize “Find” link path everywhere
for f in $(git ls-files '*.html'); do
  perl -pi -e 's{href=(["'\''])(?:/?cat/)?solutions/find\.html\1}{href=\1/cat/solutions/find.html\1}gi' "$f"
done

# 6. Commit and push
git add -A
git commit -m "Cleanup: remove duplicate Find/Find Plus from nav & cards; normalize link to /cat/solutions/find.html" || true
git push origin main

# 7. Trigger rebuild
git commit --allow-empty -m "chore: trigger GitHub Pages rebuild"
git push origin main

echo "✅ Done! Reload https://m-stacking.github.io/cat/solutions/index.html and https://m-stacking.github.io/cat/index.html (hard refresh ⌘⇧R)."
