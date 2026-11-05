#!/usr/bin/env bash
#
# Test suite for Posterizer.
# Builds the Docker image, starts a container and runs HTTP tests against it.
#
# Usage:  tests/run.sh
# Env:    PORT   host port for the test container (default 18080)
#         KEEP=1 keep the test image after the run
#
# Requires: docker, curl

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-18080}"
IMAGE="posterizer-test"
CONTAINER="posterizer-test-$$"
BASE="http://localhost:$PORT"
TMP="$(mktemp -d)"

PASS=0
FAIL=0

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1
  [[ "${KEEP:-}" == 1 ]] || docker rmi -f "$IMAGE" >/dev/null 2>&1
  rm -rf "$TMP"
}
trap cleanup EXIT

ok()   { PASS=$((PASS + 1)); printf '  \033[32m✔\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  \033[31m✘\033[0m %s\n    %s\n' "$1" "$2"; }

# make_pdf <bytes> <file>: write a valid one-page A4 PDF with <bytes> of random payload
make_pdf() {
  local size=$1 out=$2 offsets=() i
  local objs=(
    "<< /Type /Catalog /Pages 2 0 R >>"
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R >>"
    "<< /Length 0 >>"$'\nstream\n\nendstream'
  )
  printf '%%PDF-1.4\n' >"$out"
  for i in "${!objs[@]}"; do
    offsets+=("$(wc -c <"$out")")
    printf '%d 0 obj\n%s\nendobj\n' $((i + 1)) "${objs[$i]}" >>"$out"
  done
  offsets+=("$(wc -c <"$out")")
  printf '5 0 obj\n<< /Length %d >>\nstream\n' "$size" >>"$out"
  head -c "$size" /dev/urandom >>"$out"
  printf '\nendstream\nendobj\n' >>"$out"
  local xref; xref=$(wc -c <"$out")
  printf 'xref\n0 6\n0000000000 65535 f \n' >>"$out"
  for i in "${offsets[@]}"; do printf '%010d 00000 n \n' "$i" >>"$out"; done
  printf 'trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n' "$xref" >>"$out"
}

# post <curl args...>: POST to posterize.php, body -> $TMP/body, headers -> $TMP/headers
post() {
  curl -s -o "$TMP/body" -D "$TMP/headers" "$@" "$BASE/posterize.php"
}

# expect_message <name> <expected text> <curl args...>
expect_message() {
  local name=$1 expected=$2; shift 2
  post "$@"
  if grep -qiE 'warning|notice|fatal error|<b>' "$TMP/body"; then
    fail "$name" "PHP error output: $(head -c 200 "$TMP/body")"
  elif [[ "$(cat "$TMP/body")" == "$expected" ]]; then
    ok "$name"
  else
    fail "$name" "expected '$expected', got '$(head -c 200 "$TMP/body")'"
  fi
}

# expect_poster <name> <pdf file> <expected download name>
expect_poster() {
  local name=$1 file=$2 filename=$3
  post -F "if=@$file;type=application/pdf"
  if ! grep -qi '^content-type: application/pdf' "$TMP/headers"; then
    fail "$name" "no PDF returned: $(head -c 200 "$TMP/body")"
  elif ! grep -qi "filename=\"$filename\"" "$TMP/headers"; then
    fail "$name" "wrong download name: $(grep -i disposition "$TMP/headers")"
  elif ! grep -aqx '/Count 4' "$TMP/body"; then
    fail "$name" "poster does not have 4 pages"
  else
    ok "$name"
  fi
}

# ---------------------------------------------------------------------------

echo "Building image ..."
docker build -q -t "$IMAGE" "$ROOT" >/dev/null || { echo "docker build failed"; exit 1; }

echo "Starting container on port $PORT ..."
docker run -d --name "$CONTAINER" -p "$PORT:8080" "$IMAGE" >/dev/null || exit 1
for _ in $(seq 1 50); do
  curl -s -o /dev/null "$BASE/" && break
  sleep 0.2
done

echo "Creating test files ..."
make_pdf 1000      "$TMP/small.pdf"
make_pdf 5242880   "$TMP/5mb.pdf"    #  5 MB: above PHP's default limit of 2 MB
make_pdf 10747904  "$TMP/10_5mb.pdf" # 10.5 MB: above upload_max_filesize
make_pdf 12582912  "$TMP/12mb.pdf"   # 12 MB: above post_max_size
echo "hello" >"$TMP/text.txt"

echo
echo "PHP configuration"
ini() { docker exec "$CONTAINER" php -r "echo ini_get('$1');"; }
[[ "$(ini upload_max_filesize)" == 10M ]] && ok "upload_max_filesize = 10M" || fail "upload_max_filesize = 10M" "got $(ini upload_max_filesize)"
[[ "$(ini post_max_size)" == 11M ]]       && ok "post_max_size = 11M"       || fail "post_max_size = 11M" "got $(ini post_max_size)"
[[ -z "$(ini display_errors)" ]]          && ok "display_errors = Off"      || fail "display_errors = Off" "got $(ini display_errors)"

echo
echo "Start page"
code=$(curl -s -o "$TMP/body" -w '%{http_code}' "$BASE/")
[[ "$code" == 200 ]] && grep -q 'Posterize it' "$TMP/body" \
  && ok "index.html is served" || fail "index.html is served" "HTTP $code"

echo
echo "Posterizing"
expect_poster "small PDF becomes a 2x2 A4 poster" "$TMP/small.pdf" "Poster_small.pdf"
expect_poster "5 MB PDF is accepted"              "$TMP/5mb.pdf"   "Poster_5mb.pdf"

echo
echo "Error handling"
expect_message "POST without data"        "No input file selected!" -X POST
expect_message "form without file field"  "No input file selected!" -F "x=1"
expect_message "empty file field"         "No input file selected!" -F "if=@/dev/null;filename=;type=application/pdf"
expect_message "non-PDF file is rejected" "Sorry, only PDF files are allowed." -F "if=@$TMP/text.txt;type=text/plain"
expect_message "10.5 MB PDF is too large" "Sorry, maximum allowed file size is 10MB." -F "if=@$TMP/10_5mb.pdf;type=application/pdf"
expect_message "12 MB PDF is too large"   "Sorry, maximum allowed file size is 10MB." -F "if=@$TMP/12mb.pdf;type=application/pdf"

echo
echo "Concurrency"
docker exec "$CONTAINER" sh -c 'echo "<?php sleep(2);" > /app/slow.php'
start=$(date +%s)
for i in 1 2 3 4; do curl -s -o /dev/null "$BASE/slow.php" & done
wait
elapsed=$(( $(date +%s) - start ))
# parallel: ~2s, serial (single worker): ~8s
(( elapsed < 6 )) && ok "4 requests run in parallel (${elapsed}s)" \
  || fail "4 requests run in parallel" "took ${elapsed}s, expected about 2s (8s means only one worker)"

echo
echo "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
