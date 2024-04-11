
set -x

now=`date +%m%d%H%M`

repo=spock-private
branch=main
comp=spock40
ver=4.0dev5
zipd=$comp-$ver

hdir=$DEV/history/up-$now
if [ -d $hdir ]; then
  echo "ERROR: $hdir already exists"
  exit 1
else
  mkdir $hdir
fi

## clone if needed ###########
if [ ! -d "$repo" ]; then
  git clone https://github.com/pgedge/spock-private
fi

## get current repo version ##
cd $repo
git checkout $main
git pull

## build a tar file ########
cd ..
rm -rf $zipd
cp -pr $repo $zipd
rm -rf $zipd/.git
tar czf $zipd.tar.gz $zipd

## copy to src directory ####
rm -f $SOURCE/$zipd.tar.gz
cp $zipd.tar.gz $SOURCE/.
mv $zipd.tar.gz $SOURCE/$zipd-$now.tar.gz

## build from src ############
cd $BLD
git checkout $branch
git pull
./build-all-components.sh $comp 15 --copy-bin
./build-all-components.sh $comp 16 --copy-bin

## assemble the extension ####
cd $PGE
rm $OUT/$comp*
./build_all.sh 15
./build_all.sh 16


