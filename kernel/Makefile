MAKEFLAGS += -rR
.SUFFIXES:


override OUTPUT := kernel

ARCH := x86_64

PREFIX := /usr/local

ifeq ($(filter $(ARCH),aarch64 loongarch64 riscv64 x86_64),)
    $(error Architecture $(ARCH) not supported)
endif

ZIG := zig

ZIGFLAGS := -Doptimize=ReleaseSafe --cache-dir ~/.zig-cache

# Default target.
.PHONY: all
all:
	$(ZIG) build $(ZIGFLAGS) -Darch=$(ARCH) 

# Remove object files and the final executable.
.PHONY: clean
clean:
	rm -rf .zig-cache zig-out

# Remove everything built and generated including downloaded dependencies.
.PHONY: distclean
distclean:
	rm -rf .zig-cache zig-out

# Install the final built executable to its final on-root location.
.PHONY: install
install: all
	install -d "$(DESTDIR)$(PREFIX)/share/$(OUTPUT)"
	install -m 644 bin-$(ARCH)/$(OUTPUT) "$(DESTDIR)$(PREFIX)/share/$(OUTPUT)/$(OUTPUT)-$(ARCH)"

# Try to undo whatever the "install" target did.
.PHONY: uninstall
uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/share/$(OUTPUT)/$(OUTPUT)-$(ARCH)"
	-rmdir "$(DESTDIR)$(PREFIX)/share/$(OUTPUT)"
