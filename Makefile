SHELL := /bin/sh

# Constraints and intended usage:
# - This Makefile targets macOS with Xcode or Command Line Tools already installed.
# - The final runtime tree is installed into $(HOME)/opt/gnupg-<version>.
# - A small $(HOME)/bin/gpg wrapper is installed and points into that final tree.
# - Downloads, extracted source, build directories, and stamp files stay in the
#   current working directory.
# - If the working directory path contains spaces, user-facing build targets use
#   a temporary no-spaces symlink under /tmp while building, then remove it.
# - The final install prefix must not contain spaces.
#
# Typical use:
#   make all
#   $HOME/bin/gpg --version
#
#  (on a circa 2019 MacBook Pro, 'make all' takes about 10 minutes to complete and the installed executable files are about 5MB in size)
#
# Cleanup:
#   make clean             # remove local build output and any temp build symlink
#   make distclean         # remove local downloads/source/build output only
#   make uninstall-prefix  # remove $(HOME)/opt/gnupg-<version> and $HOME/bin/gpg

# Pinned to GnuPG 2.2.44 to mirror the Ubuntu package version you referenced.
# If you move to a different GnuPG release, also update the matching SHA256.
GNUPG_VERSION ?= 2.2.44
LIBGPG_ERROR_VERSION ?= 1.61
LIBGCRYPT_VERSION ?= 1.12.2
LIBASSUAN_VERSION ?= 3.0.2
LIBKSBA_VERSION ?= 1.8.0
NPTH_VERSION ?= 1.8
NTBTLS_VERSION ?= 0.3.2
PINENTRY_VERSION ?= 1.3.3

GNUPG_NAME := gnupg-$(GNUPG_VERSION)
LIBGPG_ERROR_NAME := libgpg-error-$(LIBGPG_ERROR_VERSION)
LIBGCRYPT_NAME := libgcrypt-$(LIBGCRYPT_VERSION)
LIBASSUAN_NAME := libassuan-$(LIBASSUAN_VERSION)
LIBKSBA_NAME := libksba-$(LIBKSBA_VERSION)
NPTH_NAME := npth-$(NPTH_VERSION)
NTBTLS_NAME := ntbtls-$(NTBTLS_VERSION)
PINENTRY_NAME := pinentry-$(PINENTRY_VERSION)

GNUPG_SHA256 ?= 735b8b3e6d2330f66ab98336b060d5852a1a67cb2bc47ec7d1e5411577a8cadd
LIBGPG_ERROR_SHA256 ?= 7a85413f2bc354f4f8aa832b718af122e48965e9e0eb9012ee659c13c6385c93
LIBGCRYPT_SHA256 ?= 7ce33c2492221a0436f96a8500215e9f3e3dcb5fd26a757cd415e7a843babd5e
LIBASSUAN_SHA256 ?= d2931cdad266e633510f9970e1a2f346055e351bb19f9b78912475b8074c36f6
LIBKSBA_SHA256 ?= 296b9db9095749f2aa104202d7ab7fd09ad10710e00780a709c9754b1a1d9292
NPTH_SHA256 ?= 8bd24b4f23a3065d6e5b26e98aba9ce783ea4fd781069c1b35d149694e90ca3e
NTBTLS_SHA256 ?= bdfcb99024acec9c6c4b998ad63bb3921df4cfee4a772ad6c0ca324dbbf2b07c
PINENTRY_SHA256 ?= c2970f16d6afb66ecddfca767d743936c86239bff936eed7fd7597a678414b63

DOWNLOAD_DIR ?= downloads
SRC_DIR ?= src
BUILD_DIR ?= build
STAMP_DIR ?= .stamps
LEGACY_PREFIX_DIR ?= prefix
INSTALL_PREFIX ?= $(HOME)/opt/$(GNUPG_NAME)
HOME_BIN ?= $(HOME)/bin
JOBS ?= $(shell sysctl -n hw.ncpu 2>/dev/null || echo 4)
BUILD_LINK_DIR ?= /tmp
BUILD_LINK_NAME ?= gnupg-build-$(shell printf '%s\n' "$(CURDIR)" | shasum -a 256 | awk '{print substr($$1,1,12)}')

WORKROOT_REAL_ABS := $(CURDIR)
INSTALL_PREFIX_ABS := $(abspath $(INSTALL_PREFIX))
WORKROOT_LINK := $(BUILD_LINK_DIR)/$(BUILD_LINK_NAME)
HAS_SPACE_IN_WORKROOT := $(if $(filter 1,$(words $(WORKROOT_REAL_ABS))),,yes)
WORKROOT_BUILD_ABS := $(if $(HAS_SPACE_IN_WORKROOT),$(WORKROOT_LINK),$(WORKROOT_REAL_ABS))

DOWNLOAD_REAL_ABS := $(WORKROOT_REAL_ABS)/$(DOWNLOAD_DIR)
SRC_REAL_ABS := $(WORKROOT_REAL_ABS)/$(SRC_DIR)
BUILD_REAL_ABS := $(WORKROOT_REAL_ABS)/$(BUILD_DIR)
STAMP_REAL_ABS := $(WORKROOT_REAL_ABS)/$(STAMP_DIR)

DOWNLOAD_ABS := $(WORKROOT_BUILD_ABS)/$(DOWNLOAD_DIR)
SRC_ABS := $(WORKROOT_BUILD_ABS)/$(SRC_DIR)
BUILD_ABS := $(WORKROOT_BUILD_ABS)/$(BUILD_DIR)

BUILD_ENV = env PATH="$(INSTALL_PREFIX_ABS)/bin:$$PATH" CPPFLAGS="-I$(INSTALL_PREFIX_ABS)/include" LDFLAGS="-L$(INSTALL_PREFIX_ABS)/lib" PKG_CONFIG_PATH="$(INSTALL_PREFIX_ABS)/lib/pkgconfig:$(INSTALL_PREFIX_ABS)/share/pkgconfig"
COMMON_CONFIGURE_FLAGS = --prefix="$(INSTALL_PREFIX_ABS)" --disable-nls
MAKE_BUILD_FLAGS = MAKEINFO=true

GNUPG_ARCHIVE := $(DOWNLOAD_DIR)/$(GNUPG_NAME).tar.bz2
LIBGPG_ERROR_ARCHIVE := $(DOWNLOAD_DIR)/$(LIBGPG_ERROR_NAME).tar.bz2
LIBGCRYPT_ARCHIVE := $(DOWNLOAD_DIR)/$(LIBGCRYPT_NAME).tar.bz2
LIBASSUAN_ARCHIVE := $(DOWNLOAD_DIR)/$(LIBASSUAN_NAME).tar.bz2
LIBKSBA_ARCHIVE := $(DOWNLOAD_DIR)/$(LIBKSBA_NAME).tar.bz2
NPTH_ARCHIVE := $(DOWNLOAD_DIR)/$(NPTH_NAME).tar.bz2
NTBTLS_ARCHIVE := $(DOWNLOAD_DIR)/$(NTBTLS_NAME).tar.bz2
PINENTRY_ARCHIVE := $(DOWNLOAD_DIR)/$(PINENTRY_NAME).tar.bz2

GNUPG_URL := https://gnupg.org/ftp/gcrypt/gnupg/$(GNUPG_NAME).tar.bz2
LIBGPG_ERROR_URL := https://gnupg.org/ftp/gcrypt/libgpg-error/$(LIBGPG_ERROR_NAME).tar.bz2
LIBGCRYPT_URL := https://gnupg.org/ftp/gcrypt/libgcrypt/$(LIBGCRYPT_NAME).tar.bz2
LIBASSUAN_URL := https://gnupg.org/ftp/gcrypt/libassuan/$(LIBASSUAN_NAME).tar.bz2
LIBKSBA_URL := https://gnupg.org/ftp/gcrypt/libksba/$(LIBKSBA_NAME).tar.bz2
NPTH_URL := https://gnupg.org/ftp/gcrypt/npth/$(NPTH_NAME).tar.bz2
NTBTLS_URL := https://gnupg.org/ftp/gcrypt/ntbtls/$(NTBTLS_NAME).tar.bz2
PINENTRY_URL := https://gnupg.org/ftp/gcrypt/pinentry/$(PINENTRY_NAME).tar.bz2

ALL_ARCHIVES := \
	$(GNUPG_ARCHIVE) \
	$(LIBGPG_ERROR_ARCHIVE) \
	$(LIBGCRYPT_ARCHIVE) \
	$(LIBASSUAN_ARCHIVE) \
	$(LIBKSBA_ARCHIVE) \
	$(NPTH_ARCHIVE) \
	$(NTBTLS_ARCHIVE) \
	$(PINENTRY_ARCHIVE)

ALL_EXTRACT_STAMPS := \
	$(STAMP_DIR)/gnupg-extract \
	$(STAMP_DIR)/libgpg-error-extract \
	$(STAMP_DIR)/libgcrypt-extract \
	$(STAMP_DIR)/libassuan-extract \
	$(STAMP_DIR)/libksba-extract \
	$(STAMP_DIR)/npth-extract \
	$(STAMP_DIR)/ntbtls-extract \
	$(STAMP_DIR)/pinentry-extract

LIB_INSTALL_STAMPS := \
	$(STAMP_DIR)/libgpg-error-install \
	$(STAMP_DIR)/libgcrypt-install \
	$(STAMP_DIR)/libassuan-install \
	$(STAMP_DIR)/libksba-install \
	$(STAMP_DIR)/npth-install \
	$(STAMP_DIR)/ntbtls-install

.PHONY: all help show-config dirs workroot-link cleanup-build-link require-home-bin doctor fetch checksums extract
.PHONY: libgpg-error libgcrypt libassuan libksba npth ntbtls pinentry build-deps build-gnupg gnupg
.PHONY: smoke-test upstream-check install-home-bin clean distclean uninstall-prefix

all:
	@set -eu; \
	  start_epoch=$$(date +%s); \
	  report_elapsed() { \
	    exit_code=$$?; \
	    end_epoch=$$(date +%s); \
	    elapsed=$$((end_epoch - start_epoch)); \
	    trap - EXIT; \
	    printf 'make all elapsed: %02d:%02d:%02d (exit %d)\n' \
	      $$((elapsed / 3600)) $$(((elapsed % 3600) / 60)) $$((elapsed % 60)) "$$exit_code"; \
	    exit "$$exit_code"; \
	  }; \
	  trap report_elapsed EXIT; \
	  $(MAKE) require-home-bin; \
	  $(MAKE) doctor; \
	  $(MAKE) checksums; \
	  $(MAKE) build-gnupg; \
	  $(MAKE) smoke-test; \
	  $(MAKE) upstream-check; \
	  $(MAKE) install-home-bin

help:
	@printf '%s\n' \
	  'make doctor            # check prerequisites and show paths/constraints' \
	  'make fetch             # download all source tarballs into ./downloads' \
	  'make checksums         # verify the pinned SHA-256 checksums' \
	  'make extract           # unpack tarballs into ./src and seed ./build' \
	  'make libgpg-error      # build/install libgpg-error into $(HOME)/opt/...' \
	  'make libgcrypt         # build/install libgcrypt into $(HOME)/opt/...' \
	  'make libassuan         # build/install libassuan into $(HOME)/opt/...' \
	  'make libksba           # build/install libksba into $(HOME)/opt/...' \
	  'make npth              # build/install npth into $(HOME)/opt/...' \
	  'make ntbtls            # build/install ntbtls into $(HOME)/opt/...' \
	  'make pinentry          # build/install pinentry-tty into $(HOME)/opt/...' \
	  'make build-deps        # build/install every dependency into $(HOME)/opt/...' \
	  'make build-gnupg       # build/install GnuPG into $(HOME)/opt/...' \
	  'make smoke-test        # run the installed GnuPG binary version check' \
	  'make upstream-check    # run the upstream GnuPG test suite via make check' \
	  'make install-home-bin  # install a $$HOME/bin/gpg wrapper for the final tree' \
	  'make clean             # remove local build output and any temp build symlink' \
	  'make distclean         # remove local downloads/source/build output only' \
	  'make uninstall-prefix  # remove the final install tree and $$HOME/bin/gpg' \
	  'make all               # full flow: verify, build, smoke-test, upstream tests, wrapper, timed' \
	  '' \
	  'Notes:' \
	  '  - $$HOME/bin must already exist and be on your PATH before running build targets.' \
	  '  - The final install prefix must not contain spaces.' \
	  '  - If the working directory path contains spaces, build targets use a temporary' \
	  '    symlink under /tmp and remove it afterward.' \
	  '  - Override versions/checksums on the command line if needed.' \
	  'Example: make GNUPG_VERSION=2.5.21 GNUPG_SHA256=e3af2c8caa46a66a9329fa7c6880af260451914d819595beabc2c26597b31352 all'

show-config:
	@printf '%s\n' \
	  'GNUPG_VERSION=$(GNUPG_VERSION)' \
	  'LIBGPG_ERROR_VERSION=$(LIBGPG_ERROR_VERSION)' \
	  'LIBGCRYPT_VERSION=$(LIBGCRYPT_VERSION)' \
	  'LIBASSUAN_VERSION=$(LIBASSUAN_VERSION)' \
	  'LIBKSBA_VERSION=$(LIBKSBA_VERSION)' \
	  'NPTH_VERSION=$(NPTH_VERSION)' \
	  'NTBTLS_VERSION=$(NTBTLS_VERSION)' \
	  'PINENTRY_VERSION=$(PINENTRY_VERSION)' \
	  'WORKROOT_REAL=$(WORKROOT_REAL_ABS)' \
	  'WORKROOT_BUILD=$(WORKROOT_BUILD_ABS)' \
	  'TEMP_BUILD_LINK=$(WORKROOT_LINK)' \
	  'INSTALLED_TEST_BIN_PREFIX=$(INSTALL_PREFIX_ABS)/bin' \
	  'INSTALL_PREFIX=$(INSTALL_PREFIX_ABS)' \
	  'HOME_BIN=$(HOME_BIN)' \
	  'JOBS=$(JOBS)'

dirs:
	mkdir -p "$(DOWNLOAD_REAL_ABS)" "$(SRC_REAL_ABS)" "$(BUILD_REAL_ABS)" "$(STAMP_REAL_ABS)"
	mkdir -p "$(INSTALL_PREFIX_ABS)" "$(INSTALL_PREFIX_ABS)/bin" "$(INSTALL_PREFIX_ABS)/include" "$(INSTALL_PREFIX_ABS)/lib" "$(INSTALL_PREFIX_ABS)/lib/pkgconfig" "$(INSTALL_PREFIX_ABS)/share/pkgconfig"

workroot-link:
	@set -eu; \
	  if [ "$(WORKROOT_BUILD_ABS)" = "$(WORKROOT_REAL_ABS)" ]; then \
	    exit 0; \
	  fi; \
	  case "$(WORKROOT_LINK)" in \
	    *" "*) \
	      echo "Temporary build symlink path contains spaces: $(WORKROOT_LINK)"; \
	      exit 1; \
	      ;; \
	  esac; \
	  mkdir -p "$(BUILD_LINK_DIR)"; \
	  if [ -L "$(WORKROOT_LINK)" ]; then \
	    current_target="$$(readlink "$(WORKROOT_LINK)")"; \
	    if [ "$$current_target" != "$(WORKROOT_REAL_ABS)" ]; then \
	      rm -f "$(WORKROOT_LINK)"; \
	      ln -s "$(WORKROOT_REAL_ABS)" "$(WORKROOT_LINK)"; \
	    fi; \
	  elif [ -e "$(WORKROOT_LINK)" ]; then \
	    echo "Temporary build symlink path exists and is not a symlink: $(WORKROOT_LINK)"; \
	    exit 1; \
	  else \
	    ln -s "$(WORKROOT_REAL_ABS)" "$(WORKROOT_LINK)"; \
	  fi

cleanup-build-link:
	@set -eu; \
	  if [ "$(WORKROOT_BUILD_ABS)" != "$(WORKROOT_REAL_ABS)" ]; then \
	    rm -f "$(WORKROOT_LINK)"; \
	  fi

require-home-bin:
	@set -eu; \
	  if [ ! -d "$(HOME_BIN)" ]; then \
	    echo "Required directory is missing: $(HOME_BIN)"; \
	    echo "Create it with:"; \
	    echo "  mkdir -p \"$(HOME_BIN)\""; \
	    echo "Then add it to your PATH, for example in ~/.zshrc:"; \
	    echo "  export PATH=\"$(HOME_BIN):\$$PATH\""; \
	    exit 1; \
	  fi; \
	  case ":$$PATH:" in \
	    *":$(HOME_BIN):"*) \
	      ;; \
	    *) \
	      echo "Required directory is not on PATH: $(HOME_BIN)"; \
	      echo "Add it to your PATH, for example in ~/.zshrc:"; \
	      echo "  export PATH=\"$(HOME_BIN):\$$PATH\""; \
	      exit 1; \
	      ;; \
	  esac

doctor:
	@set -eu; \
	  echo "Host OS      : $$(uname -s)"; \
	  echo "Host arch    : $$(uname -m)"; \
	  if [ "$$(uname -s)" != "Darwin" ]; then \
	    echo "This Makefile targets macOS/Darwin."; \
	    exit 1; \
	  fi; \
	  case "$(INSTALL_PREFIX_ABS)" in \
	    *" "*) \
	      echo "INSTALL_PREFIX must not contain spaces: $(INSTALL_PREFIX_ABS)"; \
	      exit 1; \
	      ;; \
	  esac; \
	  case "$(BUILD_LINK_DIR)" in \
	    *" "*) \
	      echo "BUILD_LINK_DIR must not contain spaces: $(BUILD_LINK_DIR)"; \
	      exit 1; \
	      ;; \
	  esac; \
	  for cmd in curl tar make clang xcode-select shasum install; do \
	    if ! command -v "$$cmd" >/dev/null 2>&1; then \
	      echo "Missing required command: $$cmd"; \
	      exit 1; \
	    fi; \
	  done; \
	  if ! xcode-select -p >/dev/null 2>&1; then \
	    echo "Xcode or Command Line Tools are not configured."; \
	    exit 1; \
	  fi; \
	  mkdir -p "$(DOWNLOAD_REAL_ABS)" "$(SRC_REAL_ABS)" "$(BUILD_REAL_ABS)" "$(STAMP_REAL_ABS)"; \
	  echo "Working dir   : $(WORKROOT_REAL_ABS)"; \
	  if [ "$(WORKROOT_BUILD_ABS)" != "$(WORKROOT_REAL_ABS)" ]; then \
	    echo "Temp build link: $(WORKROOT_LINK)"; \
	  else \
	    echo "Temp build link: not needed"; \
	  fi; \
	  echo "Install prefix: $(INSTALL_PREFIX_ABS)"; \
	  echo "Wrapper path  : $(HOME_BIN)/gpg"; \
	  if [ "$$(uname -m)" != "arm64" ]; then \
	    echo "Note: current host is not arm64; the target M4 Mac should still build natively as arm64."; \
	  fi

fetch: $(ALL_ARCHIVES)

checksums: fetch
	@set -eu; \
	  cd "$(DOWNLOAD_REAL_ABS)"; \
	  printf '%s  %s\n' \
	    "$(GNUPG_SHA256)" "$(GNUPG_NAME).tar.bz2" \
	    "$(LIBGPG_ERROR_SHA256)" "$(LIBGPG_ERROR_NAME).tar.bz2" \
	    "$(LIBGCRYPT_SHA256)" "$(LIBGCRYPT_NAME).tar.bz2" \
	    "$(LIBASSUAN_SHA256)" "$(LIBASSUAN_NAME).tar.bz2" \
	    "$(LIBKSBA_SHA256)" "$(LIBKSBA_NAME).tar.bz2" \
	    "$(NPTH_SHA256)" "$(NPTH_NAME).tar.bz2" \
	    "$(NTBTLS_SHA256)" "$(NTBTLS_NAME).tar.bz2" \
	    "$(PINENTRY_SHA256)" "$(PINENTRY_NAME).tar.bz2" \
	  | shasum -a 256 -c -

extract: $(ALL_EXTRACT_STAMPS)

libgpg-error:
	@set -eu; \
	  cleanup() { rm -f "$(WORKROOT_LINK)"; }; \
	  trap cleanup EXIT HUP INT TERM; \
	  $(MAKE) require-home-bin; \
	  $(MAKE) $(STAMP_DIR)/libgpg-error-install; \
	  trap - EXIT HUP INT TERM; \
	  cleanup

libgcrypt:
	@set -eu; \
	  cleanup() { rm -f "$(WORKROOT_LINK)"; }; \
	  trap cleanup EXIT HUP INT TERM; \
	  $(MAKE) require-home-bin; \
	  $(MAKE) $(STAMP_DIR)/libgcrypt-install; \
	  trap - EXIT HUP INT TERM; \
	  cleanup

libassuan:
	@set -eu; \
	  cleanup() { rm -f "$(WORKROOT_LINK)"; }; \
	  trap cleanup EXIT HUP INT TERM; \
	  $(MAKE) require-home-bin; \
	  $(MAKE) $(STAMP_DIR)/libassuan-install; \
	  trap - EXIT HUP INT TERM; \
	  cleanup

libksba:
	@set -eu; \
	  cleanup() { rm -f "$(WORKROOT_LINK)"; }; \
	  trap cleanup EXIT HUP INT TERM; \
	  $(MAKE) require-home-bin; \
	  $(MAKE) $(STAMP_DIR)/libksba-install; \
	  trap - EXIT HUP INT TERM; \
	  cleanup

npth:
	@set -eu; \
	  cleanup() { rm -f "$(WORKROOT_LINK)"; }; \
	  trap cleanup EXIT HUP INT TERM; \
	  $(MAKE) require-home-bin; \
	  $(MAKE) $(STAMP_DIR)/npth-install; \
	  trap - EXIT HUP INT TERM; \
	  cleanup

ntbtls:
	@set -eu; \
	  cleanup() { rm -f "$(WORKROOT_LINK)"; }; \
	  trap cleanup EXIT HUP INT TERM; \
	  $(MAKE) require-home-bin; \
	  $(MAKE) $(STAMP_DIR)/ntbtls-install; \
	  trap - EXIT HUP INT TERM; \
	  cleanup

pinentry:
	@set -eu; \
	  cleanup() { rm -f "$(WORKROOT_LINK)"; }; \
	  trap cleanup EXIT HUP INT TERM; \
	  $(MAKE) require-home-bin; \
	  $(MAKE) $(STAMP_DIR)/pinentry-install; \
	  trap - EXIT HUP INT TERM; \
	  cleanup

build-deps:
	@set -eu; \
	  cleanup() { rm -f "$(WORKROOT_LINK)"; }; \
	  trap cleanup EXIT HUP INT TERM; \
	  $(MAKE) require-home-bin; \
	  $(MAKE) $(STAMP_DIR)/pinentry-install; \
	  trap - EXIT HUP INT TERM; \
	  cleanup

build-gnupg:
	@set -eu; \
	  cleanup() { rm -f "$(WORKROOT_LINK)"; }; \
	  trap cleanup EXIT HUP INT TERM; \
	  $(MAKE) require-home-bin; \
	  $(MAKE) $(STAMP_DIR)/gnupg-install; \
	  trap - EXIT HUP INT TERM; \
	  cleanup

gnupg: build-gnupg

smoke-test:
	@set -eu; \
	  cleanup() { rm -f "$(WORKROOT_LINK)"; }; \
	  trap cleanup EXIT HUP INT TERM; \
	  $(MAKE) require-home-bin; \
	  $(MAKE) $(STAMP_DIR)/gnupg-install; \
	  "$(INSTALL_PREFIX_ABS)/bin/gpg" --version; \
	  trap - EXIT HUP INT TERM; \
	  cleanup

upstream-check:
	@set -eu; \
	  cleanup() { rm -f "$(WORKROOT_LINK)"; }; \
	  trap cleanup EXIT HUP INT TERM; \
	  $(MAKE) require-home-bin; \
	  $(MAKE) $(STAMP_DIR)/gnupg-test-helper-install; \
	  cd "$(BUILD_ABS)/$(GNUPG_NAME)" && $(BUILD_ENV) BIN_PREFIX="$(INSTALL_PREFIX_ABS)/bin" GPG_PRESET_PASSPHRASE="$(INSTALL_PREFIX_ABS)/libexec/gpg-preset-passphrase" PINENTRY="$(INSTALL_PREFIX_ABS)/libexec/fake-pinentry" $(MAKE) $(MAKE_BUILD_FLAGS) check; \
	  trap - EXIT HUP INT TERM; \
	  cleanup

install-home-bin:
	@set -eu; \
	  cleanup() { rm -f "$(WORKROOT_LINK)"; }; \
	  trap cleanup EXIT HUP INT TERM; \
	  $(MAKE) require-home-bin; \
	  $(MAKE) $(STAMP_DIR)/install-home-bin; \
	  trap - EXIT HUP INT TERM; \
	  cleanup

clean:
	rm -rf "$(BUILD_DIR)" "$(STAMP_DIR)"
	rm -f "$(WORKROOT_LINK)"

distclean: clean
	rm -rf "$(DOWNLOAD_DIR)" "$(SRC_DIR)" "$(LEGACY_PREFIX_DIR)"

uninstall-prefix:
	rm -rf "$(INSTALL_PREFIX_ABS)"
	rm -f "$(HOME_BIN)/gpg"

$(GNUPG_ARCHIVE): | dirs
	curl -fL --retry 3 --retry-delay 2 -o "$(DOWNLOAD_REAL_ABS)/$(GNUPG_NAME).tar.bz2" "$(GNUPG_URL)"

$(LIBGPG_ERROR_ARCHIVE): | dirs
	curl -fL --retry 3 --retry-delay 2 -o "$(DOWNLOAD_REAL_ABS)/$(LIBGPG_ERROR_NAME).tar.bz2" "$(LIBGPG_ERROR_URL)"

$(LIBGCRYPT_ARCHIVE): | dirs
	curl -fL --retry 3 --retry-delay 2 -o "$(DOWNLOAD_REAL_ABS)/$(LIBGCRYPT_NAME).tar.bz2" "$(LIBGCRYPT_URL)"

$(LIBASSUAN_ARCHIVE): | dirs
	curl -fL --retry 3 --retry-delay 2 -o "$(DOWNLOAD_REAL_ABS)/$(LIBASSUAN_NAME).tar.bz2" "$(LIBASSUAN_URL)"

$(LIBKSBA_ARCHIVE): | dirs
	curl -fL --retry 3 --retry-delay 2 -o "$(DOWNLOAD_REAL_ABS)/$(LIBKSBA_NAME).tar.bz2" "$(LIBKSBA_URL)"

$(NPTH_ARCHIVE): | dirs
	curl -fL --retry 3 --retry-delay 2 -o "$(DOWNLOAD_REAL_ABS)/$(NPTH_NAME).tar.bz2" "$(NPTH_URL)"

$(NTBTLS_ARCHIVE): | dirs
	curl -fL --retry 3 --retry-delay 2 -o "$(DOWNLOAD_REAL_ABS)/$(NTBTLS_NAME).tar.bz2" "$(NTBTLS_URL)"

$(PINENTRY_ARCHIVE): | dirs
	curl -fL --retry 3 --retry-delay 2 -o "$(DOWNLOAD_REAL_ABS)/$(PINENTRY_NAME).tar.bz2" "$(PINENTRY_URL)"

$(STAMP_DIR)/gnupg-extract: $(GNUPG_ARCHIVE) | dirs
	rm -rf "$(SRC_REAL_ABS)/$(GNUPG_NAME)" "$(BUILD_REAL_ABS)/$(GNUPG_NAME)"
	tar -C "$(SRC_REAL_ABS)" -xjf "$(DOWNLOAD_REAL_ABS)/$(GNUPG_NAME).tar.bz2"
	mkdir -p "$(BUILD_REAL_ABS)/$(GNUPG_NAME)"
	touch "$@"

$(STAMP_DIR)/libgpg-error-extract: $(LIBGPG_ERROR_ARCHIVE) | dirs
	rm -rf "$(SRC_REAL_ABS)/$(LIBGPG_ERROR_NAME)" "$(BUILD_REAL_ABS)/$(LIBGPG_ERROR_NAME)"
	tar -C "$(SRC_REAL_ABS)" -xjf "$(DOWNLOAD_REAL_ABS)/$(LIBGPG_ERROR_NAME).tar.bz2"
	mkdir -p "$(BUILD_REAL_ABS)/$(LIBGPG_ERROR_NAME)"
	touch "$@"

$(STAMP_DIR)/libgcrypt-extract: $(LIBGCRYPT_ARCHIVE) | dirs
	rm -rf "$(SRC_REAL_ABS)/$(LIBGCRYPT_NAME)" "$(BUILD_REAL_ABS)/$(LIBGCRYPT_NAME)"
	tar -C "$(SRC_REAL_ABS)" -xjf "$(DOWNLOAD_REAL_ABS)/$(LIBGCRYPT_NAME).tar.bz2"
	mkdir -p "$(BUILD_REAL_ABS)/$(LIBGCRYPT_NAME)"
	touch "$@"

$(STAMP_DIR)/libassuan-extract: $(LIBASSUAN_ARCHIVE) | dirs
	rm -rf "$(SRC_REAL_ABS)/$(LIBASSUAN_NAME)" "$(BUILD_REAL_ABS)/$(LIBASSUAN_NAME)"
	tar -C "$(SRC_REAL_ABS)" -xjf "$(DOWNLOAD_REAL_ABS)/$(LIBASSUAN_NAME).tar.bz2"
	mkdir -p "$(BUILD_REAL_ABS)/$(LIBASSUAN_NAME)"
	touch "$@"

$(STAMP_DIR)/libksba-extract: $(LIBKSBA_ARCHIVE) | dirs
	rm -rf "$(SRC_REAL_ABS)/$(LIBKSBA_NAME)" "$(BUILD_REAL_ABS)/$(LIBKSBA_NAME)"
	tar -C "$(SRC_REAL_ABS)" -xjf "$(DOWNLOAD_REAL_ABS)/$(LIBKSBA_NAME).tar.bz2"
	mkdir -p "$(BUILD_REAL_ABS)/$(LIBKSBA_NAME)"
	touch "$@"

$(STAMP_DIR)/npth-extract: $(NPTH_ARCHIVE) | dirs
	rm -rf "$(SRC_REAL_ABS)/$(NPTH_NAME)" "$(BUILD_REAL_ABS)/$(NPTH_NAME)"
	tar -C "$(SRC_REAL_ABS)" -xjf "$(DOWNLOAD_REAL_ABS)/$(NPTH_NAME).tar.bz2"
	mkdir -p "$(BUILD_REAL_ABS)/$(NPTH_NAME)"
	touch "$@"

$(STAMP_DIR)/ntbtls-extract: $(NTBTLS_ARCHIVE) | dirs
	rm -rf "$(SRC_REAL_ABS)/$(NTBTLS_NAME)" "$(BUILD_REAL_ABS)/$(NTBTLS_NAME)"
	tar -C "$(SRC_REAL_ABS)" -xjf "$(DOWNLOAD_REAL_ABS)/$(NTBTLS_NAME).tar.bz2"
	mkdir -p "$(BUILD_REAL_ABS)/$(NTBTLS_NAME)"
	touch "$@"

$(STAMP_DIR)/pinentry-extract: $(PINENTRY_ARCHIVE) | dirs
	rm -rf "$(SRC_REAL_ABS)/$(PINENTRY_NAME)" "$(BUILD_REAL_ABS)/$(PINENTRY_NAME)"
	tar -C "$(SRC_REAL_ABS)" -xjf "$(DOWNLOAD_REAL_ABS)/$(PINENTRY_NAME).tar.bz2"
	mkdir -p "$(BUILD_REAL_ABS)/$(PINENTRY_NAME)"
	touch "$@"

$(STAMP_DIR)/libgpg-error-install: $(STAMP_DIR)/libgpg-error-extract | workroot-link
	cd "$(BUILD_ABS)/$(LIBGPG_ERROR_NAME)" && $(BUILD_ENV) "../../$(SRC_DIR)/$(LIBGPG_ERROR_NAME)/configure" $(COMMON_CONFIGURE_FLAGS)
	cd "$(BUILD_ABS)/$(LIBGPG_ERROR_NAME)" && $(BUILD_ENV) $(MAKE) $(MAKE_BUILD_FLAGS) -j"$(JOBS)"
	cd "$(BUILD_ABS)/$(LIBGPG_ERROR_NAME)" && $(BUILD_ENV) $(MAKE) $(MAKE_BUILD_FLAGS) install
	touch "$@"

$(STAMP_DIR)/libgcrypt-install: $(STAMP_DIR)/libgcrypt-extract $(STAMP_DIR)/libgpg-error-install | workroot-link
	cd "$(BUILD_ABS)/$(LIBGCRYPT_NAME)" && $(BUILD_ENV) "../../$(SRC_DIR)/$(LIBGCRYPT_NAME)/configure" $(COMMON_CONFIGURE_FLAGS)
	cd "$(BUILD_ABS)/$(LIBGCRYPT_NAME)" && $(BUILD_ENV) $(MAKE) $(MAKE_BUILD_FLAGS) -j"$(JOBS)"
	cd "$(BUILD_ABS)/$(LIBGCRYPT_NAME)" && $(BUILD_ENV) $(MAKE) $(MAKE_BUILD_FLAGS) install
	touch "$@"

$(STAMP_DIR)/libassuan-install: $(STAMP_DIR)/libassuan-extract $(STAMP_DIR)/libgpg-error-install | workroot-link
	cd "$(BUILD_ABS)/$(LIBASSUAN_NAME)" && $(BUILD_ENV) "../../$(SRC_DIR)/$(LIBASSUAN_NAME)/configure" $(COMMON_CONFIGURE_FLAGS)
	cd "$(BUILD_ABS)/$(LIBASSUAN_NAME)" && $(BUILD_ENV) $(MAKE) $(MAKE_BUILD_FLAGS) -j"$(JOBS)"
	cd "$(BUILD_ABS)/$(LIBASSUAN_NAME)" && $(BUILD_ENV) $(MAKE) $(MAKE_BUILD_FLAGS) install
	touch "$@"

$(STAMP_DIR)/libksba-install: $(STAMP_DIR)/libksba-extract $(STAMP_DIR)/libgpg-error-install | workroot-link
	cd "$(BUILD_ABS)/$(LIBKSBA_NAME)" && $(BUILD_ENV) "../../$(SRC_DIR)/$(LIBKSBA_NAME)/configure" $(COMMON_CONFIGURE_FLAGS)
	cd "$(BUILD_ABS)/$(LIBKSBA_NAME)" && $(BUILD_ENV) $(MAKE) $(MAKE_BUILD_FLAGS) -j"$(JOBS)"
	cd "$(BUILD_ABS)/$(LIBKSBA_NAME)" && $(BUILD_ENV) $(MAKE) $(MAKE_BUILD_FLAGS) install
	touch "$@"

$(STAMP_DIR)/npth-install: $(STAMP_DIR)/npth-extract | workroot-link
	cd "$(BUILD_ABS)/$(NPTH_NAME)" && $(BUILD_ENV) "../../$(SRC_DIR)/$(NPTH_NAME)/configure" $(COMMON_CONFIGURE_FLAGS)
	cd "$(BUILD_ABS)/$(NPTH_NAME)" && $(BUILD_ENV) $(MAKE) $(MAKE_BUILD_FLAGS) -j"$(JOBS)"
	cd "$(BUILD_ABS)/$(NPTH_NAME)" && $(BUILD_ENV) $(MAKE) $(MAKE_BUILD_FLAGS) install
	touch "$@"

$(STAMP_DIR)/ntbtls-install: $(STAMP_DIR)/ntbtls-extract $(STAMP_DIR)/libgpg-error-install $(STAMP_DIR)/libgcrypt-install $(STAMP_DIR)/libksba-install | workroot-link
	cd "$(BUILD_ABS)/$(NTBTLS_NAME)" && $(BUILD_ENV) "../../$(SRC_DIR)/$(NTBTLS_NAME)/configure" $(COMMON_CONFIGURE_FLAGS)
	cd "$(BUILD_ABS)/$(NTBTLS_NAME)" && $(BUILD_ENV) $(MAKE) $(MAKE_BUILD_FLAGS) -j"$(JOBS)"
	cd "$(BUILD_ABS)/$(NTBTLS_NAME)" && $(BUILD_ENV) $(MAKE) $(MAKE_BUILD_FLAGS) install
	touch "$@"

$(STAMP_DIR)/pinentry-install: $(STAMP_DIR)/pinentry-extract $(STAMP_DIR)/libgpg-error-install $(STAMP_DIR)/libassuan-install | workroot-link
	cd "$(BUILD_ABS)/$(PINENTRY_NAME)" && $(BUILD_ENV) "../../$(SRC_DIR)/$(PINENTRY_NAME)/configure" $(COMMON_CONFIGURE_FLAGS) --disable-pinentry-curses --enable-pinentry-tty --disable-fallback-curses --disable-pinentry-gtk2 --disable-pinentry-gnome3 --disable-pinentry-qt5 --disable-pinentry-qt --disable-pinentry-qt4 --disable-pinentry-efl --disable-pinentry-fltk --disable-pinentry-emacs
	cd "$(BUILD_ABS)/$(PINENTRY_NAME)" && $(BUILD_ENV) $(MAKE) $(MAKE_BUILD_FLAGS) -j"$(JOBS)"
	cd "$(BUILD_ABS)/$(PINENTRY_NAME)" && $(BUILD_ENV) $(MAKE) $(MAKE_BUILD_FLAGS) install
	touch "$@"

$(STAMP_DIR)/gnupg-install: $(STAMP_DIR)/gnupg-extract $(LIB_INSTALL_STAMPS) $(STAMP_DIR)/pinentry-install | workroot-link
	cd "$(BUILD_ABS)/$(GNUPG_NAME)" && $(BUILD_ENV) "../../$(SRC_DIR)/$(GNUPG_NAME)/configure" $(COMMON_CONFIGURE_FLAGS) --with-pinentry-pgm="$(INSTALL_PREFIX_ABS)/bin/pinentry-tty"
	cd "$(BUILD_ABS)/$(GNUPG_NAME)" && $(BUILD_ENV) $(MAKE) $(MAKE_BUILD_FLAGS) -j"$(JOBS)"
	cd "$(BUILD_ABS)/$(GNUPG_NAME)" && $(BUILD_ENV) $(MAKE) $(MAKE_BUILD_FLAGS) install
	touch "$@"

$(STAMP_DIR)/gnupg-test-helper-install: $(STAMP_DIR)/gnupg-install | workroot-link
	install -m 755 "$(BUILD_ABS)/$(GNUPG_NAME)/tests/openpgp/fake-pinentry" "$(INSTALL_PREFIX_ABS)/libexec/fake-pinentry"
	touch "$@"

$(STAMP_DIR)/install-home-bin: $(STAMP_DIR)/gnupg-install
	@set -eu; \
	  mkdir -p "$(HOME_BIN)"; \
	  wrapper="$(BUILD_REAL_ABS)/gpg-home-bin-wrapper"; \
	  printf '%s\n' \
	    '#!/bin/sh' \
	    'PREFIX="$(INSTALL_PREFIX_ABS)"' \
	    'if [ -t 0 ] && [ -z "$$GPG_TTY" ]; then' \
	    '  GPG_TTY=$$(tty 2>/dev/null || true)' \
	    '  export GPG_TTY' \
	    'fi' \
	    'exec "$$PREFIX/bin/gpg" "$$@"' \
	    > "$$wrapper"; \
	  chmod 755 "$$wrapper"; \
	  install -m 755 "$$wrapper" "$(HOME_BIN)/gpg"; \
	  echo "Installed $(HOME_BIN)/gpg"
