#!/usr/bin/env bash
set -euo pipefail

# Use a safe branch name (skip if already exists)
git checkout -B feat/merge-all >/dev/null 2>&1 || git checkout feat/merge-all

# --- gather html files ---
HTMLS=$(git ls-files '*.html' || true)
if [[ -z "$HTMLS" ]]; then
  echo "❌ No .html files found in repo."
  exit 1
fi

# --- find main "Find" page by ID or filename ---
F=""
for f in $HTMLS; do
  if grep -Eiq '<section[^>]*id=["'\'']find["'\'']|<h[12][^>]*>\s*Find(?!\s*Plus)' "$f"; then
    F="$f"
    break
  fi
done
if [[ -z "$F" ]]; then
  F=$(echo "$HTMLS" | grep -iE '/?find[^/]*\.html$|/find/index\.html$' | head -n1 || true)
fi
[[ -z "$F" ]] && { echo "❌ Could not detect the main Find page."; exit 1; }

# --- find "Find Plus" page ---
PLUS=$(echo "$HTMLS" | grep -iE 'find-?plus([^/]*\.html$|/index\.html$)' | head -n1 || true)
if [[ -z "$PLUS" ]]; then
  for f in $HTMLS; do
    if grep -Eiq '\bFind\s*Plus\b' "$f"; then PLUS="$f"; break; fi
  done
fi
[[ -z "$PLUS" ]] && { echo "❌ Could not detect Find Plus page."; exit 1; }

# --- skip if same file ---
if [[ "$PLUS" == "$F" ]]; then
  echo "ℹ️ Find Plus content already inside ${F}, skipping merge."
else
  echo "➡️ Merging Find Plus ($PLUS) into $F ..."
  cp "$F" "$F.bak" >/dev/null 2>&1 || true
  cp "$PLUS" "$PLUS.bak" >/dev/null 2>&1 || true

  # extract <body> content
  perl -0777 -ne 'if (/<body[^>]*>([\s\S]*?)<\/body>/i){print $1}else{print ""}' "$PLUS" > /tmp/findplus.body.html
  [[ -s /tmp/findplus.body.html ]] || cp "$PLUS" /tmp/findplus.body.html

  # wrap
  {
    echo "<!-- BEGIN: merged from find-plus ($PLUS) -->"
    echo "<section id=\"find-plus\">"
    echo "  <h2 class=\"section-title\">Find Plus</h2>"
    cat /tmp/findplus.body.html
    echo "</section>"
    echo "<!-- END: merged from find-plus -->"
  } > /tmp/findplus.wrap.html

  # insert block after first </section> or at end of <body>
  perl -0777 -pe '
    BEGIN{
      local $/;
      open my $w,"</tmp/findplus.wrap.html" or die $!;
      our $wrap = <$w>;
    }
    if    (s{(<body[^>]*>.*?</section>)}{$1\n$wrap\n}is) { }
    elsif (s{<body[^>]*>}{&\n$wrap\n}i)                      { }
    elsif (s{</body>}{$wrap\n</body>}i)                      { }
    elsif (s{</html>}{$wrap\n</html>}i)                      { }
    else  { $_ .= "\n$wrap\n"; }
  ' "$F" > /tmp/find.merged.html && mv /tmp/find.merged.html "$F"

  rm -f "$PLUS" >/dev/null 2>&1 || true
fi

# --- update links ---
git ls-files '*.html' | xargs perl -pi -e 's/find-plus\.html/find.html/gi'
git ls-files '*.html' | xargs perl -pi -e 's/(>|\b)"?Find Plus"?(\b|<)/\1Find\2/gi'

# --- remove Ximloc & Urbaniser ---
rm -f cat/ximloc.html ximloc.html cat/ximloc/index.html >/dev/null 2>&1 || true
rm -f cat/urbaniser.html urbaniser.html cat/urbaniser/index.html >/dev/null 2>&1 || true
git ls-files '*.html' | xargs perl -pi -e 's/href=(["'\''])(?:\/?cat\/)?(ximloc|urbaniser)(?:\/index)?\.html\1/href=\1#\1/gi'
git ls-files '*.html' | xargs perl -ni -e 'print unless (/Ximloc/i || /Urbaniser/i)'

# --- clean sitemap if exists ---
for f in sitemap.xml cat/sitemap.xml; do
  [[ -f "$f" ]] && perl -ni -e 'print unless (/find-plus\.html/i || /ximloc\.html/i || /urbaniser\.html/i)' "$f"
done

git add -A
git commit -m "Smart merge: Find Plus merged into ${F}; removed find-plus/Ximloc/Urbaniser; updated links/nav/sitemap" || true
git push -u origin feat/merge-all || true

echo "✅ Done. Merged Find Plus into ${F} and removed Ximloc/Urbaniser."
