#!/usr/bin/env bash
set -euo pipefail

tap_repo=git@github.com:mag7ster/homebrew-gramwave.git
source_root=https://github.com/mag7ster/gramwave/archive/refs/tags
bottle_root=https://raw.githubusercontent.com/mag7ster/homebrew-gramwave
export GIT_TERMINAL_PROMPT=0

build_bottle() {
  local output=$1 root_url=$2 credentials=$3
  podman run --rm --platform linux/amd64 --userns=keep-id -v "$output:/work:Z" \
    -v "$credentials:/run/gramwave-telegram.conf:ro,Z" \
    ghcr.io/homebrew/brew:7.0.16 /bin/bash -euo pipefail -c '
      test "$(getconf GNU_LIBC_VERSION)" = "glibc 2.39"
      export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_MAKE_JOBS=4
      brew trust --tap mag7ster/gramwave
      brew tap mag7ster/gramwave
      cp /work/gramwave.rb "$(brew --repository mag7ster/gramwave)/Formula/gramwave.rb"
      brew install mag7ster/gramwave/gramwave-tdlib
      HOMEBREW_GRAMWAVE_TELEGRAM_CONFIG=/run/gramwave-telegram.conf \
        brew install --build-bottle mag7ster/gramwave/gramwave
      brew test mag7ster/gramwave/gramwave
      brew linkage --test mag7ster/gramwave/gramwave
      cd /work
      brew bottle --no-rebuild --root-url="$1" mag7ster/gramwave/gramwave | tee bottle.log
    ' bash "$root_url"
}

publish_bottle() {
  local tap=$1 output=$2 tag=$3
  local version=${tag#v} name block digest blob tree artifact_commit
  name="gramwave-$version.x86_64_linux.bottle.tar.gz"
  block=$(sed -n '/^  bottle do$/,/^  end$/p' "$output/bottle.log")
  digest=$(sed -nE 's/^    sha256 .*x86_64_linux: "([a-f0-9]{64})"$/\1/p' <<<"$block")
  if [[ -z $digest || $block != *"root_url \"$bottle_root/bottle-$tag\""* ]]; then
    printf 'Unexpected Homebrew bottle metadata\n' >&2
    return 1
  fi
  local archive="$output/gramwave--$version.x86_64_linux.bottle.tar.gz"
  printf '%s  %s\n' "$digest" "$archive" | sha256sum --check
  awk -v block="$block" '{ print } /^  license "MIT"$/ { print ""; print block }' \
    "$output/gramwave.rb" > "$tap/Formula/gramwave.rb"
  test "$(grep -c '^  bottle do$' "$tap/Formula/gramwave.rb")" -eq 1

  git -C "$tap" add Formula/gramwave.rb
  git -C "$tap" commit -m "Publish Gramwave $version bottle"
  blob=$(git -C "$tap" hash-object -w "$archive")
  tree=$(printf '100644 blob %s\t%s\n' "$blob" "$name" | git -C "$tap" mktree)
  artifact_commit=$(git -C "$tap" commit-tree "$tree" -m "Gramwave $version Linux x86_64 bottle")
  git -C "$tap" push --atomic origin HEAD:refs/heads/main "$artifact_commit:refs/tags/bottle-$tag"
}

main() {
  if [[ $# != 1 || ! $1 =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Usage: %s vMAJOR.MINOR.PATCH\n' "$0" >&2
    return 2
  fi
  local tag=$1 version=${1#v} work current source_url digest
  work=$(mktemp -d)
  trap "$(printf 'rm -rf -- %q' "$work")" EXIT
  git clone --quiet --branch main "$tap_repo" "$work/tap"
  local formula="$work/tap/Formula/gramwave.rb" output="$work/output"
  current=$(sed -nE 's@^  url "https://github.com/mag7ster/gramwave/archive/refs/tags/v([0-9.]+)\.tar\.gz"$@\1@p' "$formula")
  if [[ -z $current ]] || ! printf '%s\n' "$current" "$version" | sort -V -C; then
    printf 'Refusing to replace the current formula version %s with %s\n' "$current" "$version" >&2
    return 1
  fi
  if grep -Fq "root_url \"$bottle_root/bottle-$tag\"" "$formula"; then
    printf 'Bottle %s is already published.\n' "$tag"
    return
  fi

  local config=${GRAMWAVE_TELEGRAM_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/gramwave/telegram.conf}
  if [[ ! -f $config || ! -r $config || ! -s $config ]]; then
    printf 'Telegram credentials file is missing, empty, or unreadable at %s\n' "$config" >&2
    return 1
  fi
  install -m 600 -- "$config" "$work/telegram.conf"

  source_url="$source_root/$tag.tar.gz"
  curl -fLsS --retry 3 "$source_url" -o "$work/source.tar.gz"
  digest=$(sha256sum "$work/source.tar.gz" | cut -d' ' -f1)
  mkdir "$output"
  sed -E -e '/^  bottle do$/,/^  end$/d' \
    -e "s@^  url \".*\"@  url \"$source_url\"@" \
    -e "s/^  sha256 \"[a-f0-9]{64}\"$/  sha256 \"$digest\"/" \
    "$formula" > "$output/gramwave.rb"
  build_bottle "$output" "$bottle_root/bottle-$tag" "$work/telegram.conf"
  publish_bottle "$work/tap" "$output" "$tag"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
