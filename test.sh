#!/bin/bash

API_ENDPOINT=`tofu output -raw api_gateway_endpoint`

ROUTE_KEY_CUSTOM="presigned-custom-url"
ROUTE_KEY_S3="presigned-s3-url"

S3_ENDPOINT=`tofu output -raw s3_endpoint_name`

FILENAME="hello.zip"


COLOR='\033[1;33m'
RESET='\033[0m'



echo -e "${COLOR}Use unsigned S3 URL (should fail) from:${RESET}"
echo "https://${S3_ENDPOINT}/${FILENAME}"
echo

curl -s -G "https://${S3_ENDPOINT}/${FILENAME}" | tidy -xml -q -i
echo
echo 

echo -e "${COLOR}Getting presigned S3 URL from:${RESET}"
echo "${API_ENDPOINT}/${ROUTE_KEY_S3} for $FILENAME"
echo

response=$(curl -s -G "${API_ENDPOINT}/${ROUTE_KEY_S3}" --data-urlencode "filename=${FILENAME}")
presigned_url=$(echo "$response" | jq -r '.url')

echo -e "${COLOR}Presigned S3 URL:${RESET}"
echo "${presigned_url:0:100}..."
echo

echo -e "${COLOR}Downloading $FILENAME${RESET}"
echo

curl -s -o "$FILENAME" "$presigned_url"

echo -e "${COLOR}Unzipping $FILENAME${RESET}"
echo

unzip -l hello.zip

rm -f hello.zip




echo 
echo -e "${COLOR}Getting presigned CloudFront URL from:${RESET}"
echo "${API_ENDPOINT}/${ROUTE_KEY_CUSTOM} for $FILENAME"
echo

response=$(curl -s -G "${API_ENDPOINT}/${ROUTE_KEY_CUSTOM}" --data-urlencode "filename=${FILENAME}")
presigned_url=$(echo "$response" | jq -r '.url')

echo -e "${COLOR}Presigned CloudFront URL:${RESET}"
echo "${presigned_url:0:100}..."
echo

echo -e "${COLOR}Downloading $FILENAME${RESET}"
echo

curl -s -o "$FILENAME" "$presigned_url"

echo -e "${COLOR}Unzipping $FILENAME${RESET}"
echo

unzip -l hello.zip

rm -f hello.zip

