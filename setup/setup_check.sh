#!/usr/bin/env bash

# a quick check if setup.sh worked

odin run hello.odin -file

qbe hello.qbe -o hello.s
cc -o hello hello.s
./hello
