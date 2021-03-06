#!/bin/bash

# Name variables
PRIVATE_KEY=$1
PLAYSTORE_KEY=$2
PLAYSTORE_TRACK=$3
APK_PATH=$(find . -name "*.aab")

# Safety checks

if [ -z "$APK_PATH" ]; then
  echo "APK_PATH variable not supplied. Exiting."
  exit 1
fi

AUTH_ISS=$(cat $PLAYSTORE_KEY | jq -r '.client_email')
AUTH_AUD=$(cat $PLAYSTORE_KEY | jq -r '.token_uri')

if [ -z "$AUTH_ISS" ] || [ -z "$AUTH_AUD" ]; then
  echo "PLAYSTORE_SERVICE_KEY not as expected. Exiting."
  exit 1
fi

IFS=- read VERSION_NAME PACKAGE_NAME VERSION_CODE rest<<< "$APK_PATH"

if [ -z "$PACKAGE_NAME" ]; then
  echo "PACKAGE_NAME not determined from apk. Exiting."
  exit 1
fi
if [ -z "$VERSION_CODE" ]; then
  echo "VERSION_CODE not determined from apk. Exiting."
  exit 1
fi

# Get access token
echo "Getting access token..."

JWT_HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | openssl base64 -e)
jwt_claims()
{
  cat <<EOF
{
  "iss": "$AUTH_ISS",
  "scope": "https://www.googleapis.com/auth/androidpublisher",
  "aud": "$AUTH_AUD",
  "iat": $(date +%s),
  "exp": $(($(date +%s)+300))
}
EOF
}
JWT_CLAIMS=$(echo -n "$(jwt_claims)" | openssl base64 -e)
JWT_PART_1=$(echo -n "$JWT_HEADER.$JWT_CLAIMS" | tr -d '\n' | tr -d '=' | tr '/+' '_-')
echo "$PRIVATE_KEY"
JWT_SIGNING=$(echo -n "$JWT_PART_1" | openssl dgst -binary -sha256 -sign $PRIVATE_KEY | openssl base64 -e)
JWT_PART_2=$(echo -n "$JWT_SIGNING" | tr -d '\n' | tr -d '=' | tr '/+' '_-')
echo "test"
HTTP_RESPONSE_TOKEN=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" \
  --header "Content-type: application/x-www-form-urlencoded" \
  --request POST \
  --data "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=$JWT_PART_1.$JWT_PART_2" \
  $AUTH_AUD)
HTTP_BODY_TOKEN=$(echo $HTTP_RESPONSE_TOKEN | sed -e 's/HTTPSTATUS\:.*//g')
HTTP_STATUS_TOKEN=$(echo $HTTP_RESPONSE_TOKEN | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')


if [ $HTTP_STATUS_TOKEN != 200 ]; then
  echo -e "Create access token failed.\nStatus: $HTTP_STATUS_TOKEN\nBody: $HTTP_BODY_TOKEN\nExiting."
  exit 1
fi
ACCESS_TOKEN=$(echo $HTTP_BODY_TOKEN | jq -r '.access_token')

# Create new edit
echo "Creating new edit..."

EXPIRY=$(($(date +%s)+120))
post_data_create_edit()
{
  cat <<EOF
{
  "id": "github-$VERSION_CODE",
  "expiryTimeSeconds": "$EXPIRY"
}
EOF
}

HTTP_RESPONSE_CREATE_EDIT=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  --header "Content-Type: application/json" \
  --request POST \
  --data "$(post_data_create_edit)" \
  https://www.googleapis.com/androidpublisher/v3/applications/$PACKAGE_NAME/edits)
HTTP_BODY_CREATE_EDIT=$(echo $HTTP_RESPONSE_CREATE_EDIT | sed -e 's/HTTPSTATUS\:.*//g')
HTTP_STATUS_CREATE_EDIT=$(echo $HTTP_RESPONSE_CREATE_EDIT | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

 

if [ $HTTP_STATUS_CREATE_EDIT != 200 ]; then
  echo -e "Create edit failed.\nStatus: $HTTP_STATUS_CREATE_EDIT\nBody: $HTTP_BODY_CREATE_EDIT\nExiting."
  exit 1
fi

EDIT_ID=$(echo $HTTP_BODY_CREATE_EDIT | jq -r '.id')
# Upload apk
echo "Uploading apk..."

HTTP_RESPONSE_UPLOAD_APK=$(curl --write-out "HTTPSTATUS:%{http_code}" \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  --header "Content-Type: application/octet-stream" \
  --progress-bar \
  --request POST \
  --upload-file $APK_PATH \
    https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$PACKAGE_NAME/edits/$EDIT_ID/bundles?uploadType=media)
HTTP_BODY_UPLOAD_APK=$(echo $HTTP_RESPONSE_UPLOAD_APK | sed -e 's/HTTPSTATUS\:.*//g')
HTTP_STATUS_UPLOAD_APK=$(echo $HTTP_RESPONSE_UPLOAD_APK | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
#   --header "Content-Type: application/vnd.android.package-archive" \
#  https://www.googleapis.com/upload/androidpublisher/v3/applications/$PACKAGE_NAME/edits/$EDIT_ID/apks?uploadType=media)
if [ $HTTP_STATUS_UPLOAD_APK != 200 ]; then
  echo -e "Upload apk failed\nStatus: $HTTP_STATUS_UPLOAD_APK\nBody: $HTTP_BODY_UPLOAD_APK\nExiting."
  exit 1
fi

# Assign edit to track
echo "Assigning edit to track..."

post_data_assign_track()
{
  cat <<EOF
{
  "track": "$PLAYSTORE_TRACK",
  "releases": [
    {
      "versionCodes": [
        $VERSION_CODE
      ],
      "status": "draft"
    }
  ]
}
EOF
}


HTTP_RESPONSE_ASSIGN_TRACK=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  --header "Content-Type: application/json" \
  --request PUT \
  --data "$(post_data_assign_track)" \
  https://www.googleapis.com/androidpublisher/v3/applications/$PACKAGE_NAME/edits/$EDIT_ID/tracks/$PLAYSTORE_TRACK)
HTTP_BODY_ASSIGN_TRACK=$(echo $HTTP_RESPONSE_ASSIGN_TRACK | sed -e 's/HTTPSTATUS\:.*//g')
HTTP_STATUS_ASSIGN_TRACK=$(echo $HTTP_RESPONSE_ASSIGN_TRACK | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

if [ $HTTP_STATUS_ASSIGN_TRACK != 200 ]; then
  echo -e "Assign track failed\nStatus: $HTTP_STATUS_ASSIGN_TRACK\nBody: $HTTP_BODY_ASSIGN_TRACK\nExiting."
  exit 1
fi

# Commit edit
echo "Committing edit..."

HTTP_RESPONSE_COMMIT=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  --request POST \
  https://www.googleapis.com/androidpublisher/v3/applications/$PACKAGE_NAME/edits/$EDIT_ID:commit)
HTTP_BODY_COMMIT=$(echo $HTTP_RESPONSE_COMMIT | sed -e 's/HTTPSTATUS\:.*//g')
HTTP_STATUS_COMMIT=$(echo $HTTP_RESPONSE_COMMIT | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

if [ $HTTP_STATUS_COMMIT != 200 ]; then
  echo -e "Commit edit failed\nStatus: $HTTP_STATUS_COMMIT\nBody: $HTTP_BODY_COMMIT\nExiting."
  exit 1
fi

echo "Success"