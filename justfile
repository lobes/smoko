default:
    zig build run

install:
    zig build -Doptimize=ReleaseSmall
    mv zig-out/bin/smoko ~/.local/bin
