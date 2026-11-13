#!/bin/sh
# Big Rocks First — install from the encrypted release (the release password is needed).
#
#   curl -fsSL https://raw.githubusercontent.com/horiag-dev/bigrocks-releases/main/install.sh | sh
#   curl -fsSL …/install.sh | sh -s -- ~/somewhere/else      # a different folder
#
# Installs into ~/big-rocks-first (or the folder you give). After that the app
# updates itself: an "Update to vX" button appears next to the version. Your todo
# file, notes and ~/.config/big-rocks-first are never touched.
#
# Copyright (c) 2026 Big Rocks First. All rights reserved. Proprietary; see LICENSE in the package.
set -eu
REPO=${BIGROCKS_RELEASES_REPO:-horiag-dev/bigrocks-releases}
MANIFEST=${BIGROCKS_UPDATE_MANIFEST:-https://github.com/$REPO/releases/latest/download/latest.json}
DEST=${1:-$HOME/big-rocks-first}

command -v node >/dev/null 2>&1 || { echo "Node.js is needed (20.19+ or 22.12+): https://nodejs.org or 'brew install node'." >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "tar is needed." >&2; exit 1; }
if [ -e "$DEST" ]; then
  echo "$DEST already exists. The app updates itself from inside (the Update button)." >&2
  echo "To reinstall, move that folder away first, or pass another folder: sh -s -- ~/elsewhere" >&2
  exit 1
fi

if [ -n "${BIGROCKS_RELEASE_PASSWORD:-}" ]; then PW=$BIGROCKS_RELEASE_PASSWORD; else
  printf "Release password: " >/dev/tty
  stty -echo </dev/tty; IFS= read -r PW </dev/tty || true; stty echo </dev/tty; printf "\n" >/dev/tty
fi
[ -n "$PW" ] || { echo "No password given." >&2; exit 1; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/bigrocks-install.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM

BRF_PW=$PW BRF_MANIFEST=$MANIFEST BRF_REPO=$REPO BRF_OUT="$TMP/pkg.tar.gz" node --input-type=module -e '
  import { createDecipheriv, createHash, scryptSync } from "node:crypto";
  import { writeFileSync } from "node:fs";
  const { BRF_PW: pw, BRF_MANIFEST: manUrl, BRF_REPO: repo, BRF_OUT: out } = process.env;
  const r = await fetch(manUrl); if (!r.ok) { console.error(`No release found (${r.status}).`); process.exit(1); }
  const m = await r.json();
  if (!/^big-rocks-first-service-\d+\.\d+\.\d+\.tar\.gz\.brf$/.test(m.asset ?? "")) { console.error("The release manifest looks wrong."); process.exit(1); }
  const url = process.env.BIGROCKS_UPDATE_MANIFEST ? new URL(m.asset, manUrl).href : `https://github.com/${repo}/releases/download/v${m.version}/${m.asset}`;
  const a = await fetch(url); if (!a.ok) { console.error(`Download failed (${a.status}).`); process.exit(1); }
  const buf = Buffer.from(await a.arrayBuffer());
  if (buf.length !== m.size || createHash("sha256").update(buf).digest("hex") !== m.sha256) { console.error("The download does not match the release manifest."); process.exit(1); }
  if (buf.subarray(0, 4).toString() !== "BRF1") { console.error("Not a Big Rocks First package."); process.exit(1); }
  const key = scryptSync(pw, buf.subarray(4, 20), 32, { N: 2 ** 17, r: 8, p: 1, maxmem: 512 * 1024 * 1024 });
  const d = createDecipheriv("aes-256-gcm", key, buf.subarray(20, 32));
  d.setAAD(Buffer.from(m.asset.replace(/\.brf$/, ""))); d.setAuthTag(buf.subarray(32, 48));
  let tgz; try { tgz = Buffer.concat([d.update(buf.subarray(48)), d.final()]); } catch { console.error("Wrong password."); process.exit(2); }
  writeFileSync(out, tgz);
  console.log(`v${m.version}`);
' > "$TMP/version"

mkdir -p "$DEST"
tar -xzf "$TMP/pkg.tar.gz" -C "$DEST" --strip-components 1
VERSION=$(cat "$TMP/version")
# Remember the password for the in-app updater (this Mac's Keychain).
if [ "${BIGROCKS_NO_KEYCHAIN:-0}" != "1" ] && command -v security >/dev/null 2>&1; then
  security add-generic-password -U -s big-rocks-first-update -a release -l "Big Rocks First — release password" -w "$PW" >/dev/null 2>&1 || true
fi
unset PW
echo "Installed Big Rocks First $VERSION in $DEST"
echo
echo "Start it:"
echo "  cd \"$DEST\" && sh login-item.sh install     # runs in the background, starts at login"
echo "  (or: cd \"$DEST\" && sh run.sh)"
echo
echo "Already had it running from another folder? 'sh login-item.sh install' here re-points the login item."
echo "Stop any Terminal copy first (Ctrl-C). Your todos and settings carry over."
