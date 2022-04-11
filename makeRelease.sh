#!/bin/bash

version=$1
text=$2
token=$3

branch=$(git rev-parse --abbrev-ref HEAD)
repo_full_name=$(git config --get remote.origin.url | sed 's/.*:\/\/github.com\///;s/.git$//')


generate_post_data()
{
  cat <<EOF
{
  "tag_name": "$version",
  "target_commitish": "$branch",
  "name": "$version",
  "body": "$text",
  "draft": false,
  "prerelease": false,
  "generate_release_notes": true
}
EOF
}

echo "Create release $version for repo: $repo_full_name branch: $branch"

    curl --data "$(generate_post_data)" \
        --header "Accept:  application/vnd.github.v3+json" \
        --header "Authorization: token $token" \
        "https://api.github.com/repos/$repo_full_name/releases"
