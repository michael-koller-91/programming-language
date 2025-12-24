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

# download and unpack Odin
wget https://github.com/odin-lang/Odin/releases/download/dev-2025-12a/odin-linux-amd64-dev-2025-12a.tar.gz
tar -xf odin-linux-amd64-dev-2025-12a.tar.gz
rm odin-linux-amd64-dev-2025-12a.tar.gz
# move to downloads
mv odin-linux-amd64-dev-2025-12a downloads
