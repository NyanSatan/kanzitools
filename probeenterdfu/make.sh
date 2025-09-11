#!/bin/bash

clang -arch x86_64 -arch arm64 -mmacosx-version-min=10.7 -lc++ -framework IOKit -framework CoreFoundation -lAstrisAPI probeenterdfu.c -o probeenterdfu
