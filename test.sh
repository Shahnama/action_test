#!/usr/bin/env bash

branch_name="VALUE BRANCH"
echo "Branch name: $branch_name"
echo "::set-output name=VERSION::$branch_name"
