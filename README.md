# Gramwave Homebrew tap

Install [Gramwave](https://github.com/mag7ster/gramwave) on Linux.

```sh
brew trust --tap mag7ster/gramwave
brew tap mag7ster/gramwave
brew install mag7ster/gramwave/gramwave
```

Homebrew uses the Gramwave bottle on compatible Linux x86_64 systems and
builds from source where the bottle is unavailable. TDLib is installed
from the prebuilt tdlib-rs archive on both x86_64 and ARM64. Enter your own
Telegram API ID and hash in the app.

## Publish a bottle

Set up Podman and Git SSH write access to this tap once. Clone the tap.

```sh
git clone git@github.com:mag7ster/homebrew-gramwave.git
cd homebrew-gramwave
```

After pushing a Gramwave release tag that matches the version in
`Cargo.toml`, run one command from the tap. Replace the example tag with
the tag you published.

```sh
./release.sh v0.1.1
```

The script builds and tests an x86_64 bottle in Homebrew's Ubuntu 24.04
container. It publishes the archive under a separate Git tag and updates
the formula in the same push. Running it for an already published
version leaves that release intact.
