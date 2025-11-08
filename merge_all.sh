#!/usr/bin/env bash
set -euo pipefail

git checkout -b feat/merge-all || git checkout feat/merge-all

# --- detect paths ---
if   [[ -f cat/find.html ]]; then F="cat/find.html"
elif [[ -f find.html ]]; then F="find.html"
elif [[ -f cat/find/index.html ]]; then F="cat/find/index.html"
else echo "find.html not found"; exit 1; fi

if   [[ -f cat/find-plus.html ]]; then PLUS="cat/find-plus.html"
elif [[ -f find-plus.html ]]; then PLUS="find-plus.html"
elif [[ -f cat/find-plus/index.html ]]; then PLUS="cat/find-plus/index.html"
else echo "find-plus.html not found"; exit 1; fi

# --- backups ---
cp "$F" "$F.bak" >/dev/null 2>&1 || true
cp "$PLUS" "$PLUS.bak" >/dev/null 2>&1 || true

# --- extract <body> of find-plus ---
perl -0777 -ne 'print $1 if /<body[^>]*>([\s\S]*?)<\/body>/i' "$PLUS" > /tmp/findplus.body.html

# --- wrap it ---
{
  echo "<!-- BEGIN: merged from find-plus -->"
  echo "<section id=\"find-plus\">"
  echo "  <h2 class=\"section-title\">Find Plus</h2>"
  cat /tmp/findplus.body.html
  echo "</section>"
  echo "<!-- END: merged from find-plus -->"
} > /tmp/findplus.wrap.html

# --- insert as the 2nd <section> in find.html ---
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

# --- remove find-plus file & update links/labels ---
rm -f "$PLUS" >/dev/null 2>&1 || true
git ls-files '*.html' | xargs perl -pi -e 's/find-plus\.html/find.html/gi'
git ls-files '*.html' | xargs perl -pi -e 's/(>|\b)"?Find Plus"?(\b|<)/\1Find\2/gi'

# --- remove Ximloc & Urbaniser pages & references ---
rm -f cat/ximloc.html ximloc.html cat/ximloc/index.html >/dev/null 2>&1 || true
rm -f cat/urbaniser.html urbaniser.html cat/urbaniser/index.html >/dev/null 2>&1 || true
git ls-files '*.html' | xargs perl -pi -e 's/href=(["'\''])(?:\/?cat\/)?(ximloc|urbaniser)(?:\/index)?\.html\1/href=\1#\1/gi'
git ls-files '*.html' | xargs perl -ni -e 'print unless (/Ximloc/i || /Urbaniser/i)'

# --- clean sitemap if present ---
for f in sitemap.xml cat/sitemap.xml; do
  [[ -f "$f" ]] && perl -ni -e 'print unless (/find-plus\.html/i || /ximloc\.html/i || /urbaniser\.html/i)' "$f"
done

git add -A
git commit -m "Merge-all: Find Plus merged as 2nd section in ${F}; removed find-plus/Ximloc/Urbaniser; updated links/nav/sitemap" || true
git push -u origin feat/merge-all || true

echo "✅ Done. Merged into ${F}. Backups saved as ${F}.bak and ${PLUS}.bak (if created)."



