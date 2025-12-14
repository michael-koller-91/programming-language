#!/usr/bin/env bash

mkdir downloads

# download and unpack QBE
wget https://c9x.me/compile/release/qbe-1.2.tar.xz
tar -xf qbe-1.2.tar.xz
rm qbe-1.2.tar.xz
# make the binary
cd qbe-1.2
make
cd ..
# copy the binary
cp qbe-1.2/qbe .
# move to downloads
mv qbe-1.2 downloads

# download and unpack Zig
wget https://ziglang.org/builds/zig-x86_64-linux-0.16.0-dev.1484+d0ba6642b.tar.xz
tar -xf zig-x86_64-linux-0.16.0-dev.1484+d0ba6642b.tar.xz
rm zig-x86_64-linux-0.16.0-dev.1484+d0ba6642b.tar.xz
# copy the binary and lib
cp zig-x86_64-linux-0.16.0-dev.1484+d0ba6642b/zig .
cp -r zig-x86_64-linux-0.16.0-dev.1484+d0ba6642b/lib .
# move to downloads
mv zig-x86_64-linux-0.16.0-dev.1484+d0ba6642b downloads
