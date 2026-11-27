#!/usr/bin/env bash
set -euo pipefail

tap_repo=git@github.com:mag7ster/homebrew-gramwave.git
source_root=https://github.com/mag7ster/gramwave/archive/refs/tags
bottle_root=https://raw.githubusercontent.com/mag7ster/homebrew-gramwave
image=ghcr.io/homebrew/brew:7.0.16
export GIT_TERMINAL_PROMPT=0

build_bottles() {
  podman run --rm --platform linux/amd64 --userns=keep-id -v "$1:/work:Z" \
    "$image" /bin/bash -euo pipefail -c '
      test "$(getconf GNU_LIBC_VERSION)" = "glibc 2.39"
      export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_MAKE_JOBS=4
      brew tap mag7ster/gramwave /work/tap
      brew trust --tap mag7ster/gramwave
      tap=$(brew --repository mag7ster/gramwave)
      cd /work/bottles

      for name in gramwave-tdlib gramwave; do
        formula=mag7ster/gramwave/$name
        if grep -q "^  bottle do$" "$tap/Formula/$name.rb"; then
          brew install "$formula"
        else
          HOMEBREW_GRAMWAVE_TELEGRAM_CONFIG=/work/telegram.conf brew install --build-bottle "$formula"
          brew bottle --no-rebuild --json --root-url="$1" "$formula"
          brew bottle --merge --write --no-commit "$name"--*.bottle.json
          cp "$tap/Formula/$name.rb" /work/tap/Formula/
        fi
        brew test "$formula"
        brew linkage --test "$formula"
      done

      if [[ "$2" == check ]]; then
        mkdir /work/source
        tar -xf "/work/$3" -C /work/source --strip-components=1
        cd /work/source
        tdlib=$(brew --prefix mag7ster/gramwave/gramwave-tdlib)
        alsa=$(brew --prefix alsa-lib)
        wayland=$(brew --prefix wayland)
        export GRAMWAVE_TDLIB_DIR="$tdlib"
        export PKG_CONFIG_PATH="$alsa/lib/pkgconfig:$wayland/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
        export LD_LIBRARY_PATH="$tdlib/lib:$alsa/lib:$wayland/lib"
        export CARGO_PROFILE_TEST_DEBUG=0 CARGO_INCREMENTAL=0
        cargo test --workspace --locked --no-default-features \
          --features telegram,vulkan,native-tests --lib --jobs 4 -- --test-threads=1
        rm -rf /work/source/target
      fi
    ' bash "$2" "$3" "$4"
}

stage_bottles() {
  python3 - "$1/bottles" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

directory = Path(sys.argv[1])
for metadata in sorted(directory.glob("*.bottle.json")):
    (entry,) = json.loads(metadata.read_text()).values()
    bottle = entry["bottle"]["tags"]["x86_64_linux"]
    source = directory / bottle["local_filename"]
    with source.open("rb") as archive:
        if hashlib.file_digest(archive, "sha256").hexdigest() != bottle["sha256"]:
            raise SystemExit(f"Checksum mismatch for {source}")
    source.rename(directory / bottle["filename"])
PY
}

check_install() {
  podman run --rm --platform linux/amd64 --userns=keep-id -v "$1:/work:Z" \
    "$image" /bin/bash -euo pipefail -c '
      export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1
      brew tap mag7ster/gramwave /work/tap
      brew trust --tap mag7ster/gramwave
      tap=$(brew --repository mag7ster/gramwave)
      for metadata in /work/bottles/*.bottle.json; do
        name=${metadata##*/}
        sed -i "s|^    root_url .*|    root_url \"file:///work/bottles\"|" "$tap/Formula/${name%%--*}.rb"
      done
      cellar=$(brew --cellar)
      mkdir -p "$cellar"
      baseline=$(du -sB1 "$cellar" | cut -f1)
      brew list --formula | sort > /tmp/gramwave-before

      brew install mag7ster/gramwave/gramwave
      brew list --formula | sort > /tmp/gramwave-after
      comm -13 /tmp/gramwave-before /tmp/gramwave-after | tee /work/installed-formulae.txt
      deps=$(brew deps --full-name mag7ster/gramwave/gramwave)
      if grep -Eq "(^|/)(llvm(@[^/]+)?|mesa|ffmpeg(@[^/]+)?|mpv|gramwave-mpv)$" <<<"$deps"; then
        printf "Unexpected dependency in Gramwave runtime tree\n" >&2
        exit 1
      fi
      bytes=$(( $(du -sB1 "$cellar" | cut -f1) - baseline ))
      printf "Added to Cellar: %s bytes\n" "$bytes" | tee /work/install-size.txt
      test "$bytes" -le 1342177280

      brew ruby -e "
        require \"json\"
        File.foreach(\"/work/installed-formulae.txt\", chomp: true) do |name|
          receipts = Dir.glob(HOMEBREW_CELLAR/name/\"*/INSTALL_RECEIPT.json\")
          abort \"Unexpected receipts for #{name}\" unless receipts.one?
          installed = JSON.parse(File.read(receipts.first))
          abort \"Installed #{name} from source\" unless installed.fetch(\"poured_from_bottle\")
        end
      "
      for name in gramwave-tdlib gramwave; do
        brew linkage --test "mag7ster/gramwave/$name"
      done

      gramwave=$(brew --prefix mag7ster/gramwave/gramwave)/bin/gramwave
      test "$("$gramwave" --version)" = "gramwave $1"
      ldd "$gramwave" | tee /work/gramwave-linkage.txt
      grep -E "libasound[.]so[.]2 => /" /work/gramwave-linkage.txt
      grep -E "libtdjson[.]so[.]1[.]8[.]61 => .*/(opt|Cellar)/gramwave-tdlib/" /work/gramwave-linkage.txt
      if grep -Eq "lib(mpv|avcodec|avformat|avutil|swresample|swscale)[.]so" /work/gramwave-linkage.txt; then
        printf "Unexpected media library in Gramwave linkage\n" >&2
        exit 1
      fi
      test -x "$(brew --prefix glib)/bin/gio"
      brew test mag7ster/gramwave/gramwave
    ' bash "$2"
}

publish_bottles() {
  local tap=$1 bottles=$2 tag=$3 archive blob tree artifact_commit
  shopt -s nullglob
  tree=$(
    for archive in "$bottles"/*.bottle.tar.gz; do
      blob=$(git -C "$tap" hash-object -w "$archive")
      printf '100644 blob %s\t%s\n' "$blob" "${archive##*/}"
    done | git -C "$tap" mktree
  )
  artifact_commit=$(git -C "$tap" commit-tree "$tree" -m "Gramwave ${tag#v} Linux x86_64 bottles")
  git -C "$tap" push --atomic "$tap_repo" HEAD:refs/heads/main "$artifact_commit:refs/tags/bottle-$tag"
}

main() {
  local mode=publish
  if [[ ${1:-} == --check ]]; then
    mode=check
    shift
  fi
  if [[ $# -lt 1 || $# -gt 2 || ! $1 =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ || ( $mode == publish && $# != 1 ) ]]; then
    printf 'Usage: %s vMAJOR.MINOR.PATCH or %s --check vMAJOR.MINOR.PATCH [source-archive]\n' "$0" "$0" >&2
    return 2
  fi

  local tag=$1 version=${1#v} work local_tap current source_url digest formula published revision bottle_tag
  local source_archive="gramwave-${1#v}.tar.gz"
  local_tap=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
  work=$(mktemp -d)
  if [[ $mode == check ]]; then
    printf 'Local bottle build and checks: %s\n' "$work"
    mkdir -p "$work/tap/Formula"
    cp "$local_tap"/Formula/*.rb "$work/tap/Formula/"
    git -C "$work/tap" init -q
    printf '1\n%032d\n' 0 > "$work/telegram.conf"
  else
    trap "$(printf 'rm -rf -- %q' "$work")" EXIT
    if [[ -n $(git -C "$local_tap" status --porcelain) ]]; then
      printf 'Commit the tap changes before publishing.\n' >&2
      return 1
    fi
    git clone --quiet "$local_tap" "$work/tap"
    git -C "$work/tap" fetch --quiet "$tap_repo" main
    if ! git -C "$work/tap" merge-base --is-ancestor FETCH_HEAD HEAD; then
      printf 'Update the local tap branch to include published main.\n' >&2
      return 1
    fi
    local config=${GRAMWAVE_TELEGRAM_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/gramwave/telegram.conf}
    if [[ ! -f $config || ! -r $config || ! -s $config ]]; then
      printf 'Telegram credentials file is missing, empty, or unreadable at %s\n' "$config" >&2
      return 1
    fi
    install -m 600 -- "$config" "$work/telegram.conf"
  fi
  chmod 600 "$work/telegram.conf"

  formula="$work/tap/Formula/gramwave.rb"
  current=$(sed -nE 's@^  url "https://github.com/mag7ster/gramwave/archive/refs/tags/v([0-9.]+)\.tar\.gz"$@\1@p' "$formula")
  if [[ -z $current ]] || ! printf '%s\n' "$current" "$version" | sort -V -C; then
    printf 'Refusing to replace the current formula version %s with %s\n' "$current" "$version" >&2
    return 1
  fi
  bottle_tag=$tag
  if [[ $version == "$current" ]]; then
    revision=$(sed -nE 's/^  revision ([1-9][0-9]*)$/\1/p' "$formula")
    if [[ -n $revision ]]; then
      bottle_tag="$tag-r$revision"
    fi
  else
    sed -i -E '/^  revision [0-9]+$/d' "$formula"
  fi

  if [[ $mode == publish ]]; then
    published=$(git ls-remote "$tap_repo" "refs/tags/bottle-$bottle_tag")
    if [[ -n $published ]]; then
      printf 'Bottle %s is already published.\n' "$bottle_tag"
      return
    fi
  fi
  source_url="$source_root/$tag.tar.gz"
  if [[ $# == 2 ]]; then
    cp -- "$2" "$work/$source_archive"
    source_url="file:///work/$source_archive"
  else
    curl -fLsS --retry 3 "$source_url" -o "$work/$source_archive"
  fi
  digest=$(sha256sum "$work/$source_archive" | cut -d' ' -f1)
  sed -i -E -e '/^  bottle do$/,/^  end$/d' \
    -e "s@^  url \".*\"@  url \"$source_url\"@" \
    -e "s/^  sha256 \"[a-f0-9]{64}\"$/  sha256 \"$digest\"/" "$formula"
  git -C "$work/tap" add Formula
  git -C "$work/tap" -c user.name=Gramwave -c user.email=build@gramwave.invalid \
    commit --allow-empty -qm "Prepare Gramwave $version formulae"

  mkdir "$work/bottles"
  build_bottles "$work" "$bottle_root/bottle-$bottle_tag" "$mode" "$source_archive"
  stage_bottles "$work"
  git -C "$work/tap" add Formula
  git -C "$work/tap" -c user.name=Gramwave -c user.email=build@gramwave.invalid \
    commit -qm "Publish Gramwave ${bottle_tag#v} bottle"
  check_install "$work" "$version"
  if [[ $mode == publish ]]; then
    publish_bottles "$work/tap" "$work/bottles" "$bottle_tag"
  fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
