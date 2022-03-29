#!/bin/bash
while IFS='=' read -r k v; do
    key="$k"
    

    if [[ "$k" == "ANDROID_VERSION_CODE" ]]; then
        version="$v"
        if [ -z "${version}" ]; then
            version=0
        fi
        version=$(echo $version + 1 | bc)
        echo "new version: ${version}"
        sed -i.bak "s/^[#]*\s*ANDROID_VERSION_CODE=.*/ANDROID_VERSION_CODE=$version/" version.properties
    elif [[ "$k" == "ANDROID_VERSION_NAME" ]]; then
        major=0
        minor=0
        patch=0
        version="$v"
        # break down the version number into it's components
        regex="([0-9]+).([0-9]+).([0-9]+)"
        if [[ $version =~ $regex ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
        patch="${BASH_REMATCH[3]}"
        fi

        # check paramater to see which number to increment
        if [[ "$1" == "major" ]]; then
            major=$(echo $major + 1 | bc)
            minor=0
            patch=0
        elif [[ "$1" == "minor" ]]; then
            minor=$(echo $minor + 1 | bc)
            patch=0
        elif [[ "$1" == "patch" ]]; then
            patch=$(echo $patch+1 | bc)
        else
        echo "usage: ./version.sh version_number [major/minor/patch]"
        exit -1
        fi

        # echo the new version number
        echo "new version: ${major}.${minor}.${patch}"
        sed -i.bak "s/^[#]*\s*ANDROID_VERSION_NAME=.*/ANDROID_VERSION_NAME=${major}.${minor}.${patch}/" version.properties
    fi
done < version.properties
rm   ./version.properties.bak