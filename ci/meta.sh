#!/bin/sh -e

src=$PWD/src
meta=$PWD/meta

cd "$src"
git describe | tr -d '\n' > "$meta/version"

cat "$meta"/*
