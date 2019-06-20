#!/bin/sh -e

src=/var/lib/postgresql
pkg=$PWD/pkg
postgresql=/usr/local/lib/postgresql

cd "$src"
cp ci/Dockerfile "$pkg/"
cp -R "$postgresql" "$pkg/postgresql/"

ls -AlhR "$pkg"
