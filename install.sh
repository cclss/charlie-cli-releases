#!/bin/sh
set -eu

# charlie-cli installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/cclss/charlie-cli-releases/master/install.sh | sh
#   CHANNEL=dev curl -fsSL ... | sh
#   VERSION=dev-latest curl -fsSL ... | sh
#   VERSION=2.3.0 curl -fsSL ... | sh

REPO="cclss/charlie-cli-releases"
BINARY="charlie"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

main() {
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m)"

    case "$ARCH" in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) err "unsupported architecture: $ARCH" ;;
    esac

    case "$OS" in
        linux|darwin) ;;
        *) err "unsupported OS: $OS" ;;
    esac

    VERSION="${VERSION:-}"
    CHANNEL="${CHANNEL:-}"

    # Most direct form: the caller already knows exactly which release and which
    # file it wants, so nothing has to be looked up. With ASSET_NAME the whole
    # download URL is known up front and no API call is made at all -- which also
    # makes this the only form that keeps working when a release's asset names
    # do not follow the usual pattern. Without it the asset still has to be
    # discovered from the release.
    if [ -n "${RELEASE_TAG:-}" ]; then
        if [ -n "${ASSET_NAME:-}" ]; then
            URL="https://github.com/${REPO}/releases/download/${RELEASE_TAG}/${ASSET_NAME}"
            do_install "$URL" "$RELEASE_TAG"
        else
            download_from_release "$RELEASE_TAG"
        fi
        return
    fi

    # VERSION=dev-latest, staging-latest, frontier-latest → resolve via release tag
    if echo "$VERSION" | grep -qE '^(dev|staging|frontier|prod)-latest$'; then
        RELEASE_TAG="$VERSION"
        download_from_release "$RELEASE_TAG"
        return
    fi

    # VERSION=latest → resolve via GitHub latest release
    if [ "$VERSION" = "latest" ]; then
        RELEASE_TAG="latest"
        download_from_release "$RELEASE_TAG"
        return
    fi

    # Explicit version number (e.g. VERSION=2.3.0)
    if [ -n "$VERSION" ]; then
        # Stable releases are tagged with a leading `v` (`v2.3.0`) while channel
        # builds are tagged with the version verbatim
        # (`dev.0ebe295.20260730-051458`). Prefixing unconditionally sent every
        # channel build to a tag that does not exist, so the only way to install
        # one was through an alias -- and that costs an API call per attempt.
        case "$VERSION" in
            [0-9]*) RELEASE_TAG="v${VERSION}" ;;
            *) RELEASE_TAG="${VERSION}" ;;
        esac
        FILENAME="charlie_${VERSION}_${OS}_${ARCH}.tar.gz"
        URL="https://github.com/${REPO}/releases/download/${RELEASE_TAG}/${FILENAME}"
        do_install "$URL" "$VERSION"
        return
    fi

    # CHANNEL-based resolution
    case "${CHANNEL:-stable}" in
        stable)
            VERSION="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
                | grep '"tag_name"' \
                | sed -E 's/.*"v([^"]+)".*/\1/')"
            if [ -z "$VERSION" ]; then
                err "could not determine latest version"
            fi
            FILENAME="charlie_${VERSION}_${OS}_${ARCH}.tar.gz"
            URL="https://github.com/${REPO}/releases/download/v${VERSION}/${FILENAME}"
            do_install "$URL" "$VERSION"
            ;;
        dev|staging|frontier|prod)
            download_from_release "${CHANNEL}-latest"
            ;;
        *)
            err "unknown channel: ${CHANNEL} (use stable, dev, staging, frontier, or prod)"
            ;;
    esac
}

download_from_release() {
    RELEASE_TAG="$1"
    ASSET_PATTERN="charlie_.*_${OS}_${ARCH}\\.tar\\.gz"

    RELEASE_JSON="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/tags/${RELEASE_TAG}")" \
        || err "release '${RELEASE_TAG}' not found"

    ASSET_URL="$(echo "$RELEASE_JSON" \
        | grep -o '"browser_download_url":[^,]*' \
        | grep -E "$ASSET_PATTERN" \
        | head -1 \
        | sed -E 's/"browser_download_url": *"(.*)"/\1/')"

    if [ -z "$ASSET_URL" ]; then
        err "no matching asset for ${OS}/${ARCH} in release '${RELEASE_TAG}'"
    fi

    DISPLAY_VERSION="$(echo "$RELEASE_JSON" \
        | grep '"body"' \
        | sed -E 's/.*Latest [a-z]+ build: ([^"\\]+).*/\1/' \
        | head -1)"
    [ -z "$DISPLAY_VERSION" ] && DISPLAY_VERSION="$RELEASE_TAG"

    do_install "$ASSET_URL" "$DISPLAY_VERSION"
}

do_install() {
    URL="$1"
    DISPLAY_VERSION="$2"

    echo "Installing charlie ${DISPLAY_VERSION} (${OS}/${ARCH})..."

    TMPDIR="$(mktemp -d)"
    trap 'rm -rf "$TMPDIR"' EXIT

    if ! curl -fsSL "$URL" -o "${TMPDIR}/archive.tar.gz"; then
        err "failed to download ${URL}"
    fi

    tar -xzf "${TMPDIR}/archive.tar.gz" -C "$TMPDIR"

    if [ -w "$INSTALL_DIR" ]; then
        mv "${TMPDIR}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
    else
        echo "Need sudo to install to ${INSTALL_DIR}"
        sudo mv "${TMPDIR}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
    fi

    chmod +x "${INSTALL_DIR}/${BINARY}"

    echo ""
    echo "charlie ${DISPLAY_VERSION} installed to ${INSTALL_DIR}/${BINARY}"

    case ":${PATH}:" in
        *":${INSTALL_DIR}:"*) ;;
        *)
            echo ""
            echo "WARNING: ${INSTALL_DIR} is not in your PATH."
            echo "Add it with:"
            echo "  echo 'export PATH=\"${INSTALL_DIR}:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
            ;;
    esac

    echo ""
    echo "Run 'charlie --version' to verify."
}

err() {
    echo "Error: $1" >&2
    exit 1
}

main "$@"
