# Source the common SBOM generator
source "$(dirname "$0")/generate_sbom.sh"
source "$(dirname "$0")/generate_debug_symbols.sh"

set -e
# set -x

source versions.sh

archiveDir="/opt/builds/"
baseDir="`pwd`/.."
workDir=`date +%Y%m%d_%H%M`
buildLocation=""

osArch=`getconf LONG_BIT`
 
sharedLibs=/opt/pgbin-build/pgbin/shared/lib/
sharedBins=/opt/pgbin-build/pgbin/shared/bin/
includePath="$baseDir/shared/include"

pgTarLocation=""
pgSrcDir=""
pgSrcV=""
pgShortV=""
pgBldV=1
pgOPT=""

sourceTarPassed=0
archiveLocationPassed=0
buildVersionPassed=0

scriptName=`basename $0`


function printUsage {
echo "
Usage:

$scriptName [OPTIONS]

Required Options:
	-a      Target build location, the final tarball is placed here
	-t      PostgreSQL Source tar ball.

Optional:
	-n      Build number, defaults to 1.
	-c      Copy tarFile to \$IN/postgres/pgXX
	-h      Print Usage/help.

";
}


function checkPostgres {
	
	if [[ ! -e $pgTarLocation ]]; then
		echo "File $pgTarLocation not found .... "
		printUsage
		exit 1
	fi	

	cd $baseDir	
	mkdir -p $workDir
	cd $workDir
	mkdir -p logs
	
	tarFileName=`basename $pgTarLocation`
	pgSrcDir=`tar -tf $pgTarLocation | grep HISTORY`
	pgSrcDir=`dirname $pgSrcDir`
	
	tar -xzf $pgTarLocation
		
	isPgConfigure=`$pgSrcDir/configure --version | head -1 | grep "PostgreSQL configure" | wc -l`
	
	if [[ $isPgConfigure -ne 1 ]]; then
		echo "$tarFileName is not a valid postgresql source tarball .... "
		exit 1
	else
		pgSrcV=`$pgSrcDir/configure --version | head -1 | awk '{print $3}'`
		echo "pgSrcV=$pgSrcV/rc"
		if [[ "${pgSrcV/rc}" =~ ^17.* ]]; then
			pgShortV="17"
			bndlPrfx=pg17
			if [ "$OS" == "osx" ]; then
				pgOPT="--without-icu"
			else
				pgOPT="--with-zstd --with-lz4 --with-icu"
			fi

		elif [[ "${pgSrcV/rc}" =~ ^16.* ]]; then
			pgShortV="16"
			bndlPrfx=pg16
			if [ "$OS" == "osx" ]; then
				pgOPT="--without-icu"
			else
				pgOPT="--with-zstd --with-lz4 --with-icu"
			fi

		elif [[ "${pgSrcV/rc}" =~ ^15.* ]]; then
			pgShortV="15"
			bndlPrfx=pg15
			if [ "$OS" == "osx" ]; then
				pgOPT="--without-icu"
			else
				pgOPT="--with-zstd --with-lz4 --with-icu"
			fi
                        
		else
			echo "ERROR: Could not determine Postgres Version for '$pgSrcV'"
			exit 1
		fi
		
	fi
}


function patcher {
  if [ "$1" == "" ]; then
    return
  fi

  echo "# Applying $1"
  patch -p1 -i $1
  rc=$?
  if [ "$rc" == "0" ]; then
    echo "# patch succesfully applied"
  else
    echo "# FATAL ERROR: applying patch"
    exit 1
  fi
}

function buildPostgres {
	echo "# buildPOSTGRES"	
	cd $baseDir/$workDir/$pgSrcDir

        pgS="$pgShortV"

	if [ $pgS == "15" ] || [ $pgS == "16" ] || [ $pgS == "17" ]; then
		patcher "$DIFF1"
		patcher "$DIFF2"
		patcher "$DIFF3"
		patcher "$DIFF4"
		patcher "$DIFF5"
		patcher "$DIFF6"
	fi

	mkdir -p $baseDir/$workDir/logs
	buildLocation="$baseDir/$workDir/build/$bndlPrfx-$pgSrcV-$pgBldV-$OS"
	echo "# buildLocation = $buildLocation"
	arch=`arch`

	if [ $OS == "osx" ]; then
		conf="--disable-rpath $pgOPT"
		conf="$conf --without-python --without-perl"
        else
		conf="--enable-rpath $pgOPT --with-libedit"
		conf="$conf  --with-libxslt --with-libxml --with-perl --with-python PYTHON=/usr/bin/python3.9"
		conf="$conf --with-uuid=ossp --with-gssapi --with-ldap --with-pam --enable-debug --enable-dtrace"
		conf="$conf --with-llvm LLVM_CONFIG=/usr/bin/llvm-config-64 --with-openssl --with-systemd --enable-tap-tests"
        fi

	which gcc
	echo "#  @`date`  $conf"
	configCmnd="./configure --prefix=$buildLocation $conf" 

	export LD_LIBRARY_PATH=$sharedLibs
	export LDFLAGS="$LDFLAGS -Wl,-rpath,'$sharedLibs' -L$sharedLibs"
	export CPPFLAGS="$CPPFLAGS -I$includePath"

	log=$baseDir/$workDir/logs/configure.log
	$configCmnd > $log 2>&1
	if [[ $? -ne 0 ]]; then
		echo "# configure failed, cat $log"
		exit 1
	fi

	echo "#  @`date`  make -j $CORES" 
	log=$baseDir/$workDir/logs/make.log
	make -j $CORES > $log 2>&1
	if [[ $? -ne 0 ]]; then
		echo "# make failed, check $log"
		exit 1
	fi

	echo "#  @`date`  make install"
	log=$baseDir/$workDir/logs/make_install.log
	make install > $log 2>&1
	if [[ $? -ne 0 ]]; then
		echo "# make install failed, cat $log"
		exit 1
 	fi

	cd $baseDir/$workDir/$pgSrcDir/contrib
	echo "#  @`date`  make -j $CORES contrib"
	make -j $CORES > $baseDir/$workDir/logs/contrib_make.log 2>&1
	if [[ $? -eq 0 ]]; then
		echo "#  @`date`  make install contrib"
		make install > $baseDir/$workDir/logs/contrib_install.log 2>&1
		if [[ $? -ne 0 ]]; then
			echo "Failed to install contrib modules ...."
		fi
	fi

	oldPath=$PATH
	PATH="$PATH:$buildLocation/bin"

	return

	cd $baseDir/$workDir/$pgSrcDir/doc
	echo "#  @`date`  make docs"
	make > $baseDir/$workDir/logs/docs_make.log 2>&1
	if [[ $? -eq 0 ]]; then
		make install > $baseDir/$workDir/logs/docs_install.log 2>&1
		if [[ $? -ne 0 ]]; then
			echo "Failed to install docs .... "
		fi
	else
		echo "Make failed for docs ...."
		return 1
	fi
}


function copySharedLibs {
	echo "# copySharedLibs()"
	cp -Pp $sharedLibs/* $buildLocation/lib/
	return
}

function updateSharedLibPathsForLinux {
  libPathLog=$baseDir/$workDir/logs/libPath.log
  echo "# updateSharedLibPathsForLinux()"

  cd $buildLocation/bin
  ##echo "#     looping thru executables"
  for file in `ls -d *` ; do
    ##echo "### $file"
    patchelf --set-rpath '${ORIGIN}/../lib' "$file"
  done

  libSuffix="*so*"

  cd $buildLocation/lib
  ##echo "#     looping thru shared objects"
  for file in `ls -d $libSuffix 2>/dev/null` ; do
    ##echo "### $file"
    patchelf --set-rpath '${ORIGIN}/../lib' "$file"
  done

  ##echo "#     looping thru lib/postgresql "
  if [[ -d "$buildLocation/lib/postgresql" ]]; then
    cd $buildLocation/lib/postgresql
    ##echo "### $file"
    for file in `ls -d $libSuffix 2>/dev/null` ; do
        patchelf --set-rpath '${ORIGIN}/../../lib' "$file"
    done
  fi

}

function fixMacOSBinary {
  binary="$1"
  libPathPrefix="$2"
  rpath="$3"
  libPathLog="$4"

  otool -L "$binary" |
	awk '/^[[:space:]]+'"$libPathPrefix"'/ {print $1}' |
	while read lib; do
	  install_name_tool -change "$lib" '@rpath/'$(basename "$lib") "$binary" >> $libPathLog 2>&1
	done

  if otool -l "$binary" | grep -A3 RPATH | grep -q "$sharedLibs"; then
	install_name_tool -rpath "$sharedLibs" "$rpath" "$binary" >> $libPathLog 2>&1
  fi
}

function updateSharedLibPathsForMacOS {
  libPathLog=$baseDir/$workDir/logs/libPath.log
  escapedBaseDir="$(echo "$baseDir" | sed 's@/@\\/@g')"
  echo "#  updateSharedLibPathsForMacOS()"

  cd $buildLocation/bin
  ##echo "#     looping thru executables"
  for file in `ls -d *` ; do
	##echo "### $file"
	fixMacOSBinary "$file" "$escapedBaseDir" '@executable_path/../lib' "$libPathLog"
  done

  libSuffix="*.dylib*"
  cd $buildLocation/lib
  ##echo "#     looping thru shared objects"
  for file in `ls -d $libSuffix 2>/dev/null` ; do
	##echo "### $file"
	fixMacOSBinary "$file" "$escapedBaseDir" '@loader_path/../lib' "$libPathLog"
  done

  libSuffix="*.so*"
  ##echo "#     looping thru lib/postgresql"
  if [[ -d "$buildLocation/lib/postgresql" ]]; then
	cd $buildLocation/lib/postgresql
	##echo "### $file"
    for file in `ls -d $libSuffix 2>/dev/null` ; do
	  fixMacOSBinary "$file" "$escapedBaseDir" '@loader_path/../../lib' "$libPathLog"
    done
  fi

}


function updateSharedLibPaths {
	if [ `uname` == "Linux" ]; then
		updateSharedLibPathsForLinux
	else
		updateSharedLibPathsForMacOS
	fi
}

function createBundle {
	echo "# createBundle()"

	cd $baseDir/$workDir/build

	Tar="$bndlPrfx-$pgSrcV-$pgBldV-$OS"

	# Generate SBOM for the server before packaging
	generate_sbom "$Tar" "$baseDir/$workDir/build/$Tar"
	#generate_grype_sbom "$Tar" "$baseDir/$workDir/build/$Tar"
	generateDebugSymbols "$baseDir/$workDir/build/$Tar"

	Cmd="tar -czf $Tar.tgz $Tar $bndlPrfx-$pgSrcV-$pgBldV-$OS"

	tar_log=$baseDir/$workDir/logs/tar.log
	$Cmd >> $tar_log 2>&1
	if [[ $? -ne 0 ]]; then
		echo "Unable to create tar for $buildLocation, check logs .... "
		echo "tar_log=$tar_log"
		cat $tar_log
		return 1
	else
		mkdir -p $archiveDir/$workDir
		mv "$Tar.tgz" $archiveDir/$workDir/

                scan_tarball_with_grype "$archiveDir/$workDir/$Tar.tgz"

                pgcomp=/opt/pgcomponent
		if [ ! -d $pgcomp ]; then
			sudo mkdir -p $pgcomp
			sudo chown -R $USER:$USER $pgcomp
		fi
		cd $pgcomp
		pgCompDir="pg$pgShortV"
		rm -rf $pgCompDir
		mkdir $pgCompDir 
		tar -xf "$archiveDir/$workDir/$Tar.tgz" --strip-components=1 -C $pgCompDir
	fi
	tarFile="$archiveDir/$workDir/$Tar.tgz"
	if [ "$optional" == "-c" ]; then
		##cmd="cp -p $tarFile $IN/postgres/pg$pgShortV/."
		cmd="cp -p $tarFile $IN/postgres/$bndlPrfx/."
		echo $cmd
		$cmd
	else
		echo "#    tarFile=$tarFile"
	fi
	return 0
}

function checkCmd {
	$1
	rc=$?
	if [ "$rc" == "0" ]; then
		return 0
	else
		echo "FATAL ERROR in $1"
		echo ""
		exit 1
	fi
}


function buildApp {
	checkFunc=$1
	buildFunc=$2

	echo "#"	
	$checkFunc
	if [[ $? -eq 0 ]]; then
		$buildFunc
		if [[ $? -ne 0 ]]; then
			echo "FATAL ERROR: in $buildFunc ()"
			exit 1
		fi
	else
		echo "FATAL ERROR: in $checkFunc ()"
		exit 1
	fi
}


function isPassed { 
	if [ "$1" == "0" ]; then
		echo "FATAL ERROR: $2 is required"
		printUsage
		exit 1
	fi
}

###########################################################
#                  MAINLINE                               #
###########################################################

if [[ $# -lt 1 ]]; then
	printUsage
	exit 1
fi

optional=""
while getopts "t:a:n:hc" opt; do
	case $opt in
		t)
			if [[ $OPTARG = -* ]]; then
				((OPTIND--))
				continue
			fi
			pgTarLocation=$OPTARG
			sourceTarPassed=1
			##echo "# -t $pgTarLocation"
		;;
		a)
			if [[ $OPTARG = -* ]]; then
				((OPTIND--))
			fi
			archiveDir=$OPTARG
			archiveLocationPassed=1
			##echo "# -a $archiveDir"
		;;
		n)	
			pgBldV=$OPTARG
			##echo "# -n $pgBldV"
		;;
		c)
			optional="-c"
		;;
		h)
			printUsage
			exit 0
		;;
		esac
done
if [ ! "$optional" == "" ]; then
	echo "# $optional"
fi
echo "###"

isPassed "$archiveLocationPassed" "Target build location (-a)"
isPassed "$sourceTarPassed" "Postgres source tarball (-t)"

checkCmd "checkPostgres"
checkCmd "buildPostgres"

copySharedLibs
checkCmd "updateSharedLibPaths"
checkCmd "createBundle"
rc=$?
echo "# rc=$rc"
echo "#"

exit 0
