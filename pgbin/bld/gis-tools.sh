
## we are only using this build script on the EL8 AMD build box because
## postgis 3.5.0 needs 3.9.x of GEOS along with a newer version of PROJ.
## (In EL9 the default version of these compnents is new enough)
## These components do NOT allow to be built with gcc-toolset-13, so 
## make sure it is not enabled when running this build script.

sudo mkdir -p /opt/gis-tools
sudo chown $USER:$USER /opt/gis-tools

sudo yum install jasper-devel libtiff-devel

function buildGDAL {
  cd /opt/gis-tools
  rm -rf gdal*
  VER=3.2.3
  wget https://github.com/OSGeo/gdal/releases/download/v$VER/gdal-$VER.tar.gz
  tar -xf gdal-$VER.tar.gz
  cd gdal-$VER
  ./configure
  sudo make -j8
  sudo make install
  return
}

function buildGeos {
  cd /opt/gis-tools
  rm -rf geos*
  VER=3.9.1
  wget http://download.osgeo.org/geos/geos-$VER.tar.bz2
  tar -xf geos-$VER.tar.bz2
  cd geos-$VER
  ./configure
  sudo make -j8
  sudo make install
  return
}

function buildProj {
  cd /opt/gis-tools
  rm -rf proj*
  VER=8.2.0
  wget http://download.osgeo.org/proj/proj-$VER.tar.gz
  tar -xf proj-$VER.tar.gz
  cd proj-$VER
  ./configure
  sudo make -j8
  sudo make install
  return
}

function buildProto {
  cd /opt/gis-tools
  VER=2.6.1
  rm -rf protobuf-$VER
  wget https://github.com/google/protobuf/releases/download/v$VER/protobuf-$VER.tar.gz
  tar -xf protobuf-$VER.tar.gz
  cd protobuf-$VER
  ./configure
  sudo make -j8
  sudo make install
  return
}

function buildProtoC {
  cd /opt/gis-tools
  VER=1.3.3
  rm -rf protobuf-c*
  rm -f v$VER*
  wget https://github.com/protobuf-c/protobuf-c/archive/refs/tags/v$VER.tar.gz
  tar -xf v$VER.tar.gz
  cd protobuf-c-$VER
  export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
  ./autogen.sh
  ./configure
  sudo make -j8
  sudo make install
  return
}


############# MAINLINE ###################

buildGeos
buildProj
buildGDAL
