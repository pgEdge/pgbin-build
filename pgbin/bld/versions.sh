#!/bin/bash

lolorV=1.0
lolorBldV=1

spock40V=4.0.131
spockBld40V=1

spock33V=3.3.3
spockBld33V=1

pg17V=17devel
pg17BuildV=1

pg16V=16.3
pg16BuildV=1

pg15V=15.7
pg15BuildV=1

pg14V=14.12
pg14BuildV=1

pg13V=13.15
pg13BuildV=1

pg12V=12.19
pg12BuildV=1

foslotsV=1a
foslotsBldV=1

snwflkV=2.0
snwflkBldV=1

wal2jV=2.6.0
wal2jBldV=1

decoderbufsFullV=1.7.0
decoderbufsShortV=
decoderbufsBuildV=1

curlFullV=2.2.2
curlShortV=
curlBuildV=1

odbcFullV=13.01
odbcShortV=
odbcBuildV=1

backrestFullV=2.51
backrestShortV=
backrestBuildV=1

multicorn2FullV=2.4
multicorn2ShortV=
multicorn2BuildV=1

citusFullV=12.1.3
citusShortV=
citusBuildV=1

vectorFullV=0.7.0
vectorShortV=
vectorBuildV=1

hypopgFullV=1.4.1
hypopgShortV=
hypopgBuildV=1

postgisFullV=3.4.2
postgisShortV=
postgisBuildV=1

orafceFullV=4.9.2
orafceShortV=
orafceBuildV=1

oraclefdwFullV=2.6.0
oraclefdwShortV=
oraclefdwBuildV=1

logfdwFullV=1.4
logfdwShortV=
logfdwBuildV=1

tdsfdwFullV=2.0.3
tdsfdwShortV=
tdsfdwBuildV=1

mysqlfdwFullV=2.8.0
mysqlfdwShortV=
mysqlfdwBuildV=1

mongofdwFullV=5.4.0
mongofdwShortV=
mongofdwBuildV=1

plProfilerFullVersion=4.2.4
plProfilerShortVersion=
plprofilerBuildV=1

plv8FullV=3.2.2
plv8ShortV=
plv8BuildV=1

debugFullV=1.6
debugShortV=
debugBuildV=1

anonFullV=1.1.0
anonShortV=
anonBuildV=1

ddlxFullV=0.17
ddlxShortV=
ddlxBuildV=1

auditFull15V=1.7.0
auditFull16V=16.0
auditShortV=
auditBuildV=1

pljavaFullV=1.6.6
pljavaShortV=
pljavaBuildV=1

pgLogicalFullV=2.4.4
pgLogicalShortV=
pgLogicalBuildV=1

partmanFullV=5.0.1
partmanShortV=
partmanBuildV=1

hintplan16V=1.6.0
hintplan15V=1.5.1
hintplanShortV=
hintplanBuildV=1

timescaledbFullV=2.14.2
timescaledbShortV=
timescaledbBuildV=1

cronFullV=1.6.2
cronShortV=
cronBuildV=1

isEL=no
isEL8=no
isEL9=no

if [ -f /etc/os-release ]; then
  PLATFORM=`cat /etc/os-release | grep PLATFORM_ID | cut -d: -f2 | tr -d '\"'`
  if [ "$PLATFORM" == "el8" ]; then
    isEL=yes
    isEL8=yes
    isEL9=no
  elif [ "$PLATFORM" == "el9" ]; then
    isEL=yes
    isEL8=no
    isEL9=yes
  fi
fi

ARCH=`arch`
OS=`uname -s`
OS=${OS:0:7}
if [[ "$OS" == "Linux" ]]; then
  CORES=`egrep -c 'processor([[:space:]]+):.*' /proc/cpuinfo`
  if [ "$CORES" -gt "16" ]; then
    CORES=16
  fi
  if [[ "$ARCH" == "aarch64" ]]; then
    OS=arm
    if [[ "$isEL9" == "yes" ]]; then
      OS=arm9
    fi
  else
    if [[ "$isEL8" == "yes" ]]; then
      OS=el8
    elif [[ "$isEL9" == "yes" ]]; then
      OS=el9
    else
      OS=amd
    fi
  fi
elif [[ "$OS" == "Darwin" ]]; then
  CORES=`/usr/sbin/sysctl hw.physicalcpu | awk '{print $2}'`
  OS="osx"
else
  echo "Think again. :-)"
  exit 1
fi

