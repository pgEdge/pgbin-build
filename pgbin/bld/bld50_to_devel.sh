set -x
set -e

#$SOURCE/get41devel.sh

./build-all-components.sh spock50 16 --copy-bin
./build-all-components.sh spock50 17 --copy-bin

rm -f $OUT/spock50*
cd $PGE
./build_all.sh 16
./build_all.sh 17


cd $DEV
h=devel-spock50
h_dir=$HIST/$h
rm -rf $h_dir
mkdir $h_dir
cp -v $OUT/spock50* $h_dir/.

./copy-to-devel.sh $h

