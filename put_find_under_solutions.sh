#!/usr/bin/env bash
set -euo pipefail

# branch
git checkout -B feat/solutions-find >/dev/null 2>&1 || git checkout feat/solutions-find

# collect html
HTMLS="$(git ls-files '*.html' || true)"
[ -z "$HTMLS" ] && { echo "No .html files found."; exit 1; }

# pick FIND (prefer filenames; avoid 'plus')
F=""
# exact/find/index-first
while IFS= read -r f; do
  low="$(printf '%s' "$f" | tr '[:upper:]' '[:lower:]')"
  base="$(basename "$low")"
  if [[ "$base" == "find.html" && "$low" != *"plus"* ]]; then F="$f"; break; fi
  if [[ "$low" == */find/index.html && "$low" != *"plus"* ]]; then F="$f"; break; fi
done <<<"$HTMLS"
# fallback: any */find*.html not plus
if [[ -z "$F" ]]; then
  while IFS= read -r f; do
    low="$(printf '%s' "$f" | tr '[:upper:]' '[:lower:]')"
    if [[ "$low" == *"/find"*".html" && "$low" != *"plus"* ]]; then F="$f"; break; fi
  done <<<"$HTMLS"
fi
# fallback content: contains "Find" but not "Find Plus"
if [[ -z "$F" ]]; then
  while IFS= read -r f; do
    if grep -qi "Find" "$f" && ! grep -qi "Find[[:space:]]*Plus" "$f"; then F="$f"; break; fi
  done <<<"$HTMLS"
fi
[ -z "$F" ] && { echo "Could not detect the main Find page."; exit 1; }

# pick FIND PLUS
PLUS=""
while IFS= read -r f; do
  low="$(printf '%s' "$f" | tr '[:upper:]' '[:lower:]')"
  if [[ "$low" == *"/find-plus.html" || "$low" == *"/find-plus/index.html" || "$low" == *"find-plus.html" ]]; then PLUS="$f"; break; fi
done <<<"$HTMLS"
if [[ -z "$PLUS" ]]; then
  while IFS= read -r f; do
    if grep -qi "Find[[:space:]]*Plus" "$f"; then PLUS="$f"; break; fi
  done <<<"$HTMLS"
fi
[ -z "$PLUS" ] && echo "Note: no standalone Find Plus page detected (maybe already merged)."

echo "Detected Find page: $F"
[ -n "${PLUS:-}" ] && echo "Detected Find Plus: $PLUS"

# backups
cp "$F" "$F.bak" >/dev/null 2>&1 || true
[ -n "${PLUS:-}" ] && cp "$PLUS" "$PLUS.bak" >/dev/null 2>&1 || true

# if PLUS is separate, merge its body as second section
if [[ -n "${PLUS:-}" && "$PLUS" != "$F" ]]; then
  perl -0777 -ne 'if (/<body[^>]*>([\s\S]*?)<\/body>/i){print $1}else{print ""}' "$PLUS" > /tmp/findplus.body.html
  [[ -s /tmp/findplus.body.html ]] || cp "$PLUS" /tmp/findplus.body.html
  {
    echo "<!-- BEGIN: merged from find-plus ($PLUS) -->"
    echo "<section id=\"find-plus\">"
    echo "  <h2 class=\"section-title\">Find Plus</h2>"
    cat /tmp/findplus.body.html
    echo "</section>"
    echo "<!-- END: merged from find-plus -->"
  } > /tmp/findplus.wrap.html
  perl -0777 -pe '
    BEGIN{ local $/; open my $w,"</tmp/findplus.wrap.html" or die $!; our $wrap=<$w>; }
    if    (s{(<body[^>]*>.*?</section>)}{$1\n$wrap\n}is) { }
    elsif (s{<body[^>]*>}{&\n$wrap\n}i)                   { }
    elsif (s{</body>}{$wrap\n</body>}i)                   { }
    elsif (s{</html>}{$wrap\n</html>}i)                   { }
    else  { $_ .= "\n$wrap\n"; }
  ' "$F" > /tmp/find.merged.html && mv /tmp/find.merged.html "$F"
  rm -f "$PLUS" >/dev/null 2>&1 || true
fi

# ensure final destination path
TARGET="cat/solutions/find.html"
mkdir -p "cat/solutions"
# move F into TARGET (preserve if F already there)
if [[ "$F" != "$TARGET" ]]; then
  # update site links from old F path to TARGET before moving (both absolute and relative)
  oldEsc="$(printf '%s' "$F" | sed 's/[.[\*^$(){}+?|/\\]/\\&/g')"
  git ls-files '*.html' | xargs perl -pi -e "s/$oldEsc/cat\\/solutions\\/find.html/gi"
  mv "$F" "$TARGET"
  F="$TARGET"
fi

# update any links that still point to find-plus.html or old locations to the new TARGET
git ls-files '*.html' | xargs perl -pi -e 's/find-plus\.html/solutions\/find.html/gi'
git ls-files '*.html' | xargs perl -pi -e 's/\/cat\/find\.html/\/cat\/solutions\/find.html/gi'
git ls-files '*.html' | xargs perl -pi -e 's/(href=(["'\'']))find\.html/\1solutions\/find.html/gi'

# nav text: "Find Plus" -> "Find"
git ls-files '*.html' | xargs perl -pi -e 's/(>|\b)"?Find Plus"?(\b|<)/\1Find\2/gi'

# remove Ximloc & Urbaniser pages and references
rm -f cat/ximloc.html ximloc.html cat/ximloc/index.html >/dev/null 2>&1 || true
rm -f cat/urbaniser.html urbaniser.html cat/urbaniser/index.html >/dev/null 2>&1 || true
git ls-files '*.html' | xargs perl -pi -e 's/href=(["'\''])(?:\/?cat\/)?(ximloc|urbaniser)(?:\/index)?\.html\1/href=\1#\1/gi'
git ls-files '*.html' | xargs perl -ni -e 'print unless (/Ximloc/i || /Urbaniser/i)'

# clean sitemaps
for f in sitemap.xml cat/sitemap.xml; do
  [ -f "$f" ] && perl -ni -e 'print unless (/find-plus\.html/i || /ximloc\.html/i || /urbaniser\.html/i)' "$f"
done

git add -A
git commit -m "Place Find under /cat/solutions/find.html; merged Find Plus; removed find-plus/Ximloc/Urbaniser; updated links/nav/sitemap" || true
git push -u origin feat/solutions-find || true

echo "Done. Final page at: $TARGET"
