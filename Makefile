SGX_SIGNER_KEY ?= ./test-key.pem
SGX ?= 1

ARCH_LIBDIR ?= /lib/$(shell $(CC) -dumpmachine)

CFLAGS = -Wall -Wextra

ifeq ($(DEBUG),1)
GRAMINE_LOG_LEVEL = debug
CFLAGS += -g
else
GRAMINE_LOG_LEVEL = error
CFLAGS += -O3
endif

BIN_NAME ?= mem-test

.PHONY: all
all: ${BIN_NAME} ${BIN_NAME}.manifest
ifeq ($(SGX),1)
all: ${BIN_NAME}.manifest.sgx ${BIN_NAME}.sig ${BIN_NAME}.token
endif

$(BIN_NAME): target/release/$(BIN_NAME)
	cp $< $@

target/release/$(BIN_NAME): Cargo.toml Cargo.lock src/main.rs
	cargo build --release

${BIN_NAME}.manifest: ${BIN_NAME}.manifest.template
	gramine-manifest \
		-Dinstall_dir=$(INSTALL_DIR) \
		-Dlog_level=$(GRAMINE_LOG_LEVEL) \
		-Dname=$(BIN_NAME) \
		$< $@

${BIN_NAME}.manifest.sgx: ${BIN_NAME}.manifest ${BIN_NAME}
	@test -s $(SGX_SIGNER_KEY) || \
	    { echo "SGX signer private key was not found, please specify SGX_SIGNER_KEY!"; exit 1; }
	gramine-sgx-sign \
		--key $(SGX_SIGNER_KEY) \
		--manifest $< \
		--output $@

${BIN_NAME}.sig: ${BIN_NAME}.manifest.sgx

${BIN_NAME}.token: ${BIN_NAME}.sig
	gramine-sgx-get-token \
		--output $@ --sig $<

test: all
ifeq ($(SGX),1)
	gramine-sgx $(BIN_NAME)
else
	gramine-direct $(BIN_NAME)
endif

.PHONY: clean
clean:
	$(RM) *.token *.sig *.manifest.sgx *.manifest
	cargo clean
