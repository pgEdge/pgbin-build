#!/bin/bash
cd "$(dirname "$0")"

outD=lab-0129

rm -rf history/$outD
mkdir history/$outD

cp -p $OUT/* history/$outD/.

./copy-to-s3.sh $outD
