#!/bin/bash

clang -lc++ -framework IOKit -framework CoreFoundation -lAstrisAPI probeenterdfu.c -o probeenterdfu
