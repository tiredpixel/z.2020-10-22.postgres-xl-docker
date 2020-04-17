#!/bin/bash -eu
set -o pipefail

src=$PWD/src
meta=$PWD/meta

branch_latest=master

test -d "$meta" || meta=$(mktemp -d)
#-------------------------------------------------------------------------------
cd "$src"

version=$(git describe)

echo -n "$version" > "$meta/version"
touch "$meta/tags"

release=$(git describe --abbrev=0)

if [ "$version" == "$release" ]; then
    release_1=$(echo "$release" | cut -d'.' -f1)
    release_2=$(echo "$release" | cut -d'.' -f2)
    
    # release tagged for completeness, but version same
    echo -n "$release $release_1.$release_2 $release_1 " >> "$meta/tags"
fi

commit_latest=$(git rev-parse "$branch_latest")
commit_head=$(git rev-parse HEAD)

if [ "$commit_head" == "$commit_latest" ]; then
    echo -n "latest " >> "$meta/tags"
fi
#-------------------------------------------------------------------------------
echo "version: $(cat "$meta/version")"
echo "tags:    $(cat "$meta/tags")"
