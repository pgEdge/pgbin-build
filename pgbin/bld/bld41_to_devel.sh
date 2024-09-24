set -x
set -e

./build-all-components.sh spock41 16 --copy-bin
./build-all-components.sh spock41 17 --copy-bin

rm -f $OUT/spock41*
cd $PGE
./build_all.sh 16
./build_all.sh 17


cd $DEV
h_dir=$HIST/devel-spock41
rm -rf $h_dir
mkdir $h_dir
cp -v $OUT/spock41* $h_dir/.

./copy-to-devel.sh $h_dir

