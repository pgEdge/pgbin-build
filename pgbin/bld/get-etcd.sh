#!/bin/bash
cd "$(dirname "$0")"

set -x

ver=3.6.1
minV=1
url=https://github.com/etcd-io/etcd/releases/download/v$ver
tar_pigz="tar -czf"

etc=etcd-v$ver-linux-amd64
rm -rf $etc*
wget -q $url/$etc.tar.gz
tar -xf $etc.tar.gz
dir=etcd-$ver-$minV-amd
mv $etc $dir
$tar_pigz $dir.tgz $dir
rm $etc.tar.gz
rm -r $dir

etc=etcd-v$ver-linux-arm64
rm -rf $etc*
wget -q $url/$etc.tar.gz
tar -xf $etc.tar.gz
dir=etcd-$ver-$minV-arm 
mv $etc $dir
$tar_pigz $dir.tgz $dir
rm -r $dir
rm $etc.tar.gz

exit


