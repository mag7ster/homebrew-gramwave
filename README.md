# Gramwave Homebrew tap

Install [Gramwave](https://github.com/mag7ster/gramwave) on Linux x86_64.

```sh
brew trust --tap mag7ster/gramwave
brew tap mag7ster/gramwave
brew install mag7ster/gramwave/gramwave
```

Homebrew uses the Gramwave bottle on compatible Linux x86_64 systems. New
bottles include Gramwave's Telegram API credentials. Sign in by QR or phone.
TDLib comes from the prebuilt tdlib-rs archive.

For a source build on x86_64 without a compatible bottle, set
`HOMEBREW_GRAMWAVE_TELEGRAM_CONFIG` to the absolute path of your own credentials
file. [Gramwave build instructions](https://github.com/mag7ster/gramwave#build-and-run)

## Publish a bottle

Set up Podman and Git SSH write access to this tap once. Clone the tap.

```sh
git clone git@github.com:mag7ster/homebrew-gramwave.git
cd homebrew-gramwave
```

Use the same private file as for a local Gramwave build. By default the script
looks for `${XDG_CONFIG_HOME:-$HOME/.config}/gramwave/telegram.conf`.
`GRAMWAVE_TELEGRAM_CONFIG` can point to a different file. Put the API ID on the
first line and the API hash on the second, and set the file's permissions to
`600`. Keep it outside both Git repositories. The published binary includes the
app's API pair, which anyone with the binary can extract.

Push the updated formula to the tap first, then push a Gramwave release tag
matching the version in `Cargo.toml`. Run the script from the tap with that tag.

```sh
./release.sh v0.1.1
```

The script builds and tests an x86_64 bottle in Homebrew's Ubuntu 24.04
container. It publishes the archive under a separate Git tag and updates
the formula in the same push. Running it for an already published
version leaves that release intact.
