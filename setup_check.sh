#!/usr/bin/env bash

# a quick check if setup.sh worked

./zig run hello.zig

./qbe add.qbe -o add.s
cc -o add add.s
./add
