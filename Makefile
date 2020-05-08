# Settings
# --------

BUILD_DIR     := .build
SUBDEFN_DIR   := .
DEFN_BASE_DIR := $(BUILD_DIR)/defn
DEFN_DIR      := $(DEFN_BASE_DIR)/$(SUBDEFN_DIR)

DEPS_DIR      := deps

K_RELEASE ?= /usr/lib/kframework
K_BIN     := $(K_RELEASE)/bin
K_LIB     := $(K_RELEASE)/lib
export K_RELEASE

PATH := $(K_BIN):$(PATH)
export PATH

PANDOC_TANGLE_SUBMODULE := $(DEPS_DIR)/pandoc-tangle
TANGLER                 := $(PANDOC_TANGLE_SUBMODULE)/tangle.lua
LUA_PATH                := $(PANDOC_TANGLE_SUBMODULE)/?.lua;;
export TANGLER
export LUA_PATH

.PHONY: all clean distclean                       \
        deps                                      \
	build-simple                              \
        build build-java build-haskell build-llvm \
        defn java-defn haskell-defn llvm-defn     \
        test
.SECONDARY:

all: build-simple build

clean:
	rm -rf $(DEFN_BASE_DIR)

distclean:
	rm -rf $(BUILD_DIR)
	git clean -dffx -- tests/

# K Dependencies
# --------------

deps: $(TANGLER)

$(TANGLER):
	cd deps && git clone --depth 1 https://github.com/ehildenb/pandoc-tangle

# Simple Build
# ------------

build-simple: CPPFLAGS += -I vm-c -I dummy-version -I plugin -I vm-c/kevm -I plugin-c -I install/include -I deps/cpp-httplib
build-simple: CXX := $(or $(CXX),clang++-8)
build-simple: client-c/json.o client-c/main.o plugin-c/blake2.o plugin-c/blockchain.o plugin-c/crypto.o plugin-c/world.o vm-c/init.o vm-c/main.o vm-c/vm.o vm-c/kevm/semantics.o
plugin-c/blockchain.o: plugin/proto/msg.pb.h
vm-c/kevm/semantics.o: plugin/proto/msg.pb.h
%.pb.h: %.proto
	protoc --cpp_out=. $<

# Krypto Build
# ------------

MAIN_MODULE    := TEST-DRIVER
SYNTAX_MODULE  := $(MAIN_MODULE)

c_files := plugin-c/blake2.cpp plugin-c/crypto.cpp
c_files_flags := $(patsubst %, -ccopt %, $(c_files))

k_files       := plugin/krypto.k tests/src/test-driver.k

haskell_dir := $(DEFN_DIR)/haskell
java_dir    := $(DEFN_DIR)/java
llvm_dir    := $(DEFN_DIR)/llvm

haskell_files := $(patsubst %, $(haskell_dir)/%, $(k_files))
java_files    := $(patsubst %, $(java_dir)/%, $(k_files))
llvm_files    := $(patsubst %, $(llvm_dir)/%, $(k_files))

haskell_kompiled := $(haskell_dir)/$(MAIN_DEFN_FILE)-kompiled/definition.kore
java_kompiled    := $(java_dir)/$(MAIN_DEFN_FILE)-kompiled/timestamp
llvm_kompiled    := $(llvm_dir)/$(MAIN_DEFN_FILE)-kompiled/interpreter

# Tangle definition from *.md files

defn: $(defn_files)
haskell-defn: $(haskell_files)
java-defn:    $(java_files)
llvm-defn:    $(llvm_files)

$(haskell_dir)/%.k: %.md $(TANGLER)
	@mkdir -p $(haskell_dir)
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:"$(haskell_tangle)" $< > $@

$(java_dir)/%.k: %.md $(TANGLER)
	@mkdir -p $(java_dir)
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:"$(java_tangle)" $< > $@

$(llvm_dir)/%.k: %.md $(TANGLER)
	@mkdir -p $(llvm_dir)
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:"$(concrete_tangle)" $< > $@

# Kompiling

build: build-haskell build-java build-llvm
build-haskell: $(haskell_kompiled)
build-java:    $(java_kompiled)
build-llvm:    $(llvm_kompiled)

$(haskell_kompiled): $(haskell_files)
	kompile --debug --main-module $(MAIN_MODULE) --backend haskell --hook-namespaces KRYPTO \
	        --syntax-module $(SYNTAX_MODULE) $(haskell_dir)/$(MAIN_DEFN_FILE).k             \
	        --directory $(haskell_dir) -I $(haskell_dir)                                    \
	        $(KOMPILE_OPTS)

$(java_kompiled): $(java_files)
	kompile --debug --main-module $(MAIN_MODULE) --backend java --hook-namespaces KRYPTO \
	        --syntax-module $(SYNTAX_MODULE) $(java_dir)/$(MAIN_DEFN_FILE).k             \
	        --directory $(java_dir) -I $(java_dir)                                       \
	        $(KOMPILE_OPTS)

# llvm compilation flags
UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Linux)
  LINK_PROCPS=-lprocps
else
  LINK_PROCPS=
endif

$(llvm_kompiled): $(llvm_files) $(c_files)
	kompile --debug --main-module $(MAIN_MODULE) --backend llvm                                  \
	        --syntax-module $(SYNTAX_MODULE) $(llvm_dir)/$(MAIN_DEFN_FILE).k                     \
	        --directory $(llvm_dir) -I $(llvm_dir)                                               \
	        --hook-namespaces KRYPTO                                                             \
	        $(KOMPILE_OPTS)                                                                      \
		$(c_files_flags)                                                                     \
	        -ccopt -g -ccopt -std=c++14                                                          \
		-ccopt -I$(INCLUDE_PATH)                                                             \
	        -ccopt -L$(LIBRARY_PATH)                                                             \
	        -ccopt -lff -ccopt -lcryptopp -ccopt -lsecp256k1 $(addprefix -ccopt ,$(LINK_PROCPS))

# Tests
# -----

