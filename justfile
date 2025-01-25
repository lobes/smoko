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
