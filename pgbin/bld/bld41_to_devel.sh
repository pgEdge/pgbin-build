set -x
set -e

$SOURCE/get41devel.sh

./build-all-components.sh spock41 16 --copy-bin
./build-all-components.sh spock41 17 --copy-bin

rm -f $OUT/spock41*
cd $PGE
./build_all.sh 16
./build_all.sh 17


cd $DEV
h=devel-spock41
h_dir=$HIST/$h
rm -rf $h_dir
mkdir $h_dir
cp -v $OUT/spock41* $h_dir/.

./copy-to-devel.sh $h

