#!/bin/sh
set -eu

# charlie-cli installer
# Usage: curl -fsSL https://raw.githubusercontent.com/cclss/charlie-cli-releases/master/install.sh | sh

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
    if [ -z "$VERSION" ]; then
        VERSION="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
            | grep '"tag_name"' \
            | sed -E 's/.*"v([^"]+)".*/\1/')"
    fi

    if [ -z "$VERSION" ]; then
        err "could not determine latest version"
    fi

    FILENAME="charlie_${VERSION}_${OS}_${ARCH}.tar.gz"
    URL="https://github.com/${REPO}/releases/download/v${VERSION}/${FILENAME}"

    echo "Installing charlie v${VERSION} (${OS}/${ARCH})..."

    TMPDIR="$(mktemp -d)"
    trap 'rm -rf "$TMPDIR"' EXIT

    if ! curl -fsSL "$URL" -o "${TMPDIR}/${FILENAME}"; then
        err "failed to download ${URL}"
    fi

    tar -xzf "${TMPDIR}/${FILENAME}" -C "$TMPDIR"

    if [ -w "$INSTALL_DIR" ]; then
        mv "${TMPDIR}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
    else
        echo "Need sudo to install to ${INSTALL_DIR}"
        sudo mv "${TMPDIR}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
    fi

    chmod +x "${INSTALL_DIR}/${BINARY}"

    echo ""
    echo "charlie v${VERSION} installed to ${INSTALL_DIR}/${BINARY}"

    # Check if INSTALL_DIR is in PATH
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
