set -x

ver=4.0.6
minor_ver=1

in_file=v$ver.tar.gz
out_dir=patroni-$ver-$minor_ver

rm -rf $in_file*

wget https://github.com/patroni/patroni/archive/refs/tags/$in_file
tar -xf $in_file
mv patroni-$ver $out_dir
tar czf $out_dir.tgz $out_dir

rm -r $out_dir
rm $in_file
