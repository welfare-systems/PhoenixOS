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

ifeq ($(OS),Windows_NT)
define RM_RF
powershell -NoProfile -Command "if (Test-Path '$(1)') { Remove-Item -Recurse -Force '$(1)' }"
endef
define RM_F
powershell -NoProfile -Command "Remove-Item -Force -ErrorAction SilentlyContinue '$(1)'"
endef
else
define RM_RF
rm -rf $(1)
endef
define RM_F
rm -f $(1)
endef
endif

# Default target.
.PHONY: all
all:
	$(ZIG) build $(ZIGFLAGS) -Darch=$(ARCH) 

.PHONY: test
test:
	$(ZIG) test src/arch/x86_64/trap_layout_test.zig --cache-dir ~/.zig-cache

# Remove object files and the final executable.
.PHONY: clean
clean:
	$(call RM_RF,.zig-cache)
	$(call RM_RF,zig-out)

# Remove everything built and generated including downloaded dependencies.
.PHONY: distclean
distclean:
	$(call RM_RF,.zig-cache)
	$(call RM_RF,zig-out)

# Install the final built executable to its final on-root location.
.PHONY: install
install: all
	install -d "$(DESTDIR)$(PREFIX)/share/$(OUTPUT)"
	install -m 644 bin-$(ARCH)/$(OUTPUT) "$(DESTDIR)$(PREFIX)/share/$(OUTPUT)/$(OUTPUT)-$(ARCH)"

# Try to undo whatever the "install" target did.
.PHONY: uninstall
uninstall:
	$(call RM_F,"$(DESTDIR)$(PREFIX)/share/$(OUTPUT)/$(OUTPUT)-$(ARCH)")
	-rmdir "$(DESTDIR)$(PREFIX)/share/$(OUTPUT)"
