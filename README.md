# charlie-cli-releases

Release binaries for [charlie-cli](https://github.com/cclss/charlie-cli).

## Install

```bash
# macOS (Homebrew)
brew tap cclss/tap
brew install charlie

# Linux / macOS (curl)
curl -fsSL https://raw.githubusercontent.com/cclss/charlie-cli-releases/master/install.sh | sh

# Specific version
VERSION=0.1.0 curl -fsSL https://raw.githubusercontent.com/cclss/charlie-cli-releases/master/install.sh | sh

# Custom install location
INSTALL_DIR=~/.local/bin curl -fsSL https://raw.githubusercontent.com/cclss/charlie-cli-releases/master/install.sh | sh
```

## About

This repository hosts release binaries built by GoReleaser from the private `charlie-cli` source repository. Releases are created automatically when a version tag is pushed to the source repo.
