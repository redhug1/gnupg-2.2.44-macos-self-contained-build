# Self-Contained GnuPG Build For macOS

This repository builds GnuPG 2.2.44 and its required libraries from official source tarballs and installs the final runtime tree into a fixed prefix under `$HOME/opt`.

The resulting user-facing entrypoint is a small wrapper at `$HOME/bin/gpg` that directly executes the installed binary in the fixed prefix.

Official source tarballs from `gnupg.org` are used deliberately instead of GitHub-generated archives. For GnuPG, the project website is the canonical upstream release channel: the release tarballs are published there, the official SHA-256 checksums are published there, and the signature verification workflow is documented there. GitHub source archives can be repository snapshots rather than the exact release artifacts upstream intends people to build. For a security-sensitive tool like GnuPG, using the official release tarballs avoids that ambiguity and keeps the source artifact aligned with the upstream checksum and signature material.

## Prerequisites

Before running `make all`, ensure all of the following are true:

- You are on macOS.
- Xcode or the Apple Command Line Tools are already installed and configured.
- `$HOME/bin` already exists.
- `$HOME/bin` is on your `PATH`.
- The final install prefix path does not contain spaces.

The Makefile creates the final install tree under `$HOME/opt/gnupg-2.2.44` automatically, so you do not need to pre-create `$HOME/opt` yourself.

If `$HOME/bin` does not exist yet, create it with:

```sh
mkdir -p "$HOME/bin"
```

If `$HOME/bin` is not on your `PATH`, add it in your shell configuration, for example in `~/.zshrc`:

```sh
export PATH="$HOME/bin:$PATH"
```

## What This Does

- Downloads official source tarballs from `gnupg.org`
- Verifies upstream SHA-256 checksums
- Builds the required dependency chain from source
- Builds and installs GnuPG itself
- Runs a smoke test with `gpg --version`
- Runs the upstream `make check` test suite
- Installs a small `$HOME/bin/gpg` wrapper for convenience

## Installed Layout

- Final runtime tree: `$HOME/opt/gnupg-2.2.44`
- User-facing wrapper: `$HOME/bin/gpg`
- Local working directories: `downloads`, `src`, `build`, `.stamps`

The actual binaries, libraries, helper tools, and shared data live under the fixed prefix in `$HOME/opt/gnupg-2.2.44`.

## Typical Use

```sh
make all
$HOME/bin/gpg --version
```

On a circa 2019 Intel MacBook Pro, `make all` took about 10 minutes to complete, and the installed executable files were about 5 MB in size.

On a new M4 Max Arm64, `make all` takes about 5 minutes to complete and the installed executable files are about 5MB in size.

## Full Reset And Rebuild

If you want a full rebuild from scratch in the current directory:

```sh
make distclean
make uninstall-prefix
make all
```

That removes:

- Local downloads, extracted sources, build output, and stamps
- The fixed install tree under `$HOME/opt/gnupg-2.2.44`
- The `$HOME/bin/gpg` wrapper

## Make Targets

| Target | Purpose |
| --- | --- |
| `make doctor` | Check prerequisites and show paths and constraints |
| `make fetch` | Download all source tarballs into `./downloads` |
| `make checksums` | Verify the pinned SHA-256 checksums |
| `make extract` | Unpack tarballs into `./src` and seed `./build` |
| `make libgpg-error` | Build and install `libgpg-error` into `$HOME/opt/...` |
| `make libgcrypt` | Build and install `libgcrypt` into `$HOME/opt/...` |
| `make libassuan` | Build and install `libassuan` into `$HOME/opt/...` |
| `make libksba` | Build and install `libksba` into `$HOME/opt/...` |
| `make npth` | Build and install `npth` into `$HOME/opt/...` |
| `make ntbtls` | Build and install `ntbtls` into `$HOME/opt/...` |
| `make pinentry` | Build and install `pinentry-tty` into `$HOME/opt/...` |
| `make build-deps` | Build and install all dependencies |
| `make build-gnupg` | Build and install GnuPG |
| `make smoke-test` | Run the installed `gpg --version` smoke test |
| `make upstream-check` | Run the upstream GnuPG test suite via `make check` |
| `make install-home-bin` | Install the `$HOME/bin/gpg` wrapper |
| `make clean` | Remove local build output and any temporary build symlink |
| `make distclean` | Remove local downloads, extracted source, and build output |
| `make uninstall-prefix` | Remove the fixed install tree and the `$HOME/bin/gpg` wrapper |
| `make all` | Full flow: verify, build, smoke-test, upstream tests, wrapper, timed |

## Timed Build Output

`make all` prints total elapsed time when it finishes.

Example:

```text
Installed /Users/your-user/bin/gpg
make all elapsed: 00:09:41 (exit 0)
```

## What Gets Tested

`make all` validates the build in two stages:

1. A smoke test that runs the installed binary directly from the fixed prefix.
2. The upstream GnuPG test suite via `make check`.

The tests are run against the actual newly built binaries under `$HOME/opt/gnupg-2.2.44`, not against the `$HOME/bin/gpg` wrapper.

## Wrapper Behavior

The generated `$HOME/bin/gpg` wrapper is intentionally minimal:

- It sets `GPG_TTY` if stdin is a terminal and `GPG_TTY` is not already set.
- It does not modify `PATH`.
- It directly executes the installed binary in the fixed prefix.

## Temporary Build Symlink

If the working directory contains spaces, the Makefile creates a temporary symlink like this while building:

```text
/tmp/gnupg-build-<hash>
```

That temporary alias is only used so the Autoconf and libtool build chain can avoid spaced absolute paths. It is not part of the final installation.

If a build is interrupted, `make clean` removes any leftover temporary build symlink.

## Pinned Versions, Sources, And Checksums

| Component | Version | Source URL | SHA-256 |
| --- | --- | --- | --- |
| GnuPG | `2.2.44` | `https://gnupg.org/ftp/gcrypt/gnupg/gnupg-2.2.44.tar.bz2` | `735b8b3e6d2330f66ab98336b060d5852a1a67cb2bc47ec7d1e5411577a8cadd` |
| libgpg-error | `1.61` | `https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.61.tar.bz2` | `7a85413f2bc354f4f8aa832b718af122e48965e9e0eb9012ee659c13c6385c93` |
| libgcrypt | `1.12.2` | `https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.12.2.tar.bz2` | `7ce33c2492221a0436f96a8500215e9f3e3dcb5fd26a757cd415e7a843babd5e` |
| libassuan | `3.0.2` | `https://gnupg.org/ftp/gcrypt/libassuan/libassuan-3.0.2.tar.bz2` | `d2931cdad266e633510f9970e1a2f346055e351bb19f9b78912475b8074c36f6` |
| libksba | `1.8.0` | `https://gnupg.org/ftp/gcrypt/libksba/libksba-1.8.0.tar.bz2` | `296b9db9095749f2aa104202d7ab7fd09ad10710e00780a709c9754b1a1d9292` |
| npth | `1.8` | `https://gnupg.org/ftp/gcrypt/npth/npth-1.8.tar.bz2` | `8bd24b4f23a3065d6e5b26e98aba9ce783ea4fd781069c1b35d149694e90ca3e` |
| ntbtls | `0.3.2` | `https://gnupg.org/ftp/gcrypt/ntbtls/ntbtls-0.3.2.tar.bz2` | `bdfcb99024acec9c6c4b998ad63bb3921df4cfee4a772ad6c0ca324dbbf2b07c` |
| pinentry | `1.3.3` | `https://gnupg.org/ftp/gcrypt/pinentry/pinentry-1.3.3.tar.bz2` | `c2970f16d6afb66ecddfca767d743936c86239bff936eed7fd7597a678414b63` |

## Notes

- The Makefile is pinned to GnuPG `2.2.44` to mirror the Ubuntu package version this work started from.
- If you change versions, update the corresponding SHA-256 values as well.
- The source and checksum provenance are the official upstream GnuPG release channels on `gnupg.org`.
