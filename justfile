default:
    zig build run

install:
    zig build -Doptimize=ReleaseSmall
    mv zig-out/bin/smoko ~/.local/bin

# Build with optimizations for release
release:
    zig build -Doptimize=ReleaseSafe

# Build and run tests
test:
    zig build test

# Run with extra debug info
debug:
    zig build run -Doptimize=Debug

# Format all Zig files
fmt:
    find . -name "*.zig" -type f -exec zig fmt {} \;

# Check formatting without modifying files
fmt-check:
    find . -name "*.zig" -type f -exec zig fmt --check {} \;

# Clean build artifacts
clean:
    rm -rf zig-cache zig-out

# Watch for changes and rebuild (requires watchexec: brew install watchexec)
watch:
    watchexec -w src -e zig "zig build run"

# Run with debug logging
debug-log:
    zig build run -Doptimize=Debug --verbose-cimport --verbose-link

# Show build help
help:
    zig build -h

# Create wads directory and show instructions
setup-wads:
    mkdir -p src/wads
    @echo "Please copy DOOM.WAD to src/wads/doom.wad to run the game"

# List contents of WAD file
list-wads:
    hexdump -C src/wads/doom.wad | head -n 20

# Dump WAD lumps
dump-wads:
    strings src/wads/doom.wad | grep -i e1m1
