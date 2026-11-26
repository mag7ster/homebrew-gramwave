# Gramwave Homebrew tap

Install [Gramwave](https://github.com/mag7ster/gramwave) on Linux x86_64.

```sh
brew trust --tap mag7ster/gramwave
brew tap mag7ster/gramwave
brew install mag7ster/gramwave/gramwave
```

Homebrew uses the Gramwave bottle on compatible Linux x86_64 systems. New
bottles include Gramwave's Telegram API credentials. Sign in by QR or phone.
The tap builds TDLib 1.8.61 with GCC and ships a separate audio-focused libmpv
bottle. The mpv build retains ALSA, PulseAudio and PipeWire output.

For a source build on x86_64 without a compatible bottle, set
`HOMEBREW_GRAMWAVE_TELEGRAM_CONFIG` to the absolute path of your own credentials
file. [Gramwave build instructions](https://github.com/mag7ster/gramwave#build-and-run)

## Check the bottles locally

With Podman, Python 3.11 or later and the tap checked out, run the local release
check against a Gramwave source tag.

```sh
./release.sh --check v0.2.0
```

The check uses a synthetic Telegram API pair. It builds and tests the packages
in the Homebrew Ubuntu 24.04 x86_64 container, then pours the bottles in a fresh
container. The script prints the directory containing the bottles, checksums,
installed formula list and measured Cellar growth.

## Publish a release

Use the same private credentials file as for a local Gramwave build. By default
the script looks for `${XDG_CONFIG_HOME:-$HOME/.config}/gramwave/telegram.conf`.
`GRAMWAVE_TELEGRAM_CONFIG` can point to a different file. Put the API ID and hash
on separate lines and set the file's permissions to `600`. Keep it outside both
Git repositories. The published binary includes the app's API pair.

Push the Gramwave source tag first. Commit the tap changes locally on a branch
that includes the current tap `main`. Run the script with the new source tag.

```sh
./release.sh v0.2.1
```

The script pushes updated formulae and a new bottle tag atomically. Existing
dependency bottle blocks are reused. When changing one of the dependency
builds, increment its formula revision unless the upstream version changes, and
remove its bottle block so the script builds and publishes a replacement. A
published Gramwave bottle tag is immutable.

To release a packaging fix for an existing upstream tag, increment
`revision` in `Formula/gramwave.rb` and pass the same source tag. For example,
republishing `v0.2.0` with revision 1 creates `bottle-v0.2.0-r1` and Homebrew
offers `0.2.0_1` as an upgrade. Switching to a newer source tag clears the
formula revision.
