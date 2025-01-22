default:
    zig build run

release:
    zig build -Doptimize=ReleaseSmall
    
install:
    mv zig-out/bin/smoko ~/.local/bin
