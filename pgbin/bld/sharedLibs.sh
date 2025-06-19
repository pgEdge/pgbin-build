

function osxCopySharedLibs {
  lib=/usr/local/lib
  cp -Pv $lib/liblz4*.dylib   $shared_lib/.
  cp -Pv $lib/libzstd*.dylib  $shared_lib/.
  cp -Pv $lib/libssl*.dylib   $shared_lib/.
  cp -Pv $lib/libpq*.dylib    $shared_lib/.
}



function linuxCopySharedLibs {
  lib=/lib64

  cp -Pv $lib/libcrypt*.so*     $shared_lib/.
  cp -Pv $lib/libbz2.so.*       $shared_lib/.
  cp -Pv $lib/libz.so.*         $shared_lib/.
  cp -Pv $lib/libssl*           $shared_lib/.
  cp -Pv $lib/libkrb5*          $shared_lib/.
  cp -Pv $lib/libgssapi*        $shared_lib/.
  cp -Pv $lib/libldap*          $shared_lib/.
  cp -Pv $lib/libedit*          $shared_lib/.
  cp -Pv $lib/libxml2.so.*      $shared_lib/.
  cp -Pv $lib/libxslt.so*       $shared_lib/.
  cp -Pv $lib/liblber*          $shared_lib/.
  cp -Pv $lib/libsasl2*         $shared_lib/.
  cp -Pv $lib/libevent*         $shared_lib/.
  cp -Pv $lib/libk5crypto.so.*  $shared_lib/.
  cp -Pv $lib/libpam.so.*       $shared_lib/.
  cp -Pv $lib/libpython3.so     $shared_lib/.
  cp -Pv $lib/libpython3.9*     $shared_lib/.
  cp -Pv $lib/libnss3*          $shared_lib/.
  cp -Pv $lib/libnspr4*         $shared_lib/.
  cp -Pv $lib/libnssutil3*      $shared_lib/.
  cp -Pv $lib/libsmime*         $shared_lib/.
  cp -Pv $lib/libplds4*         $shared_lib/.
  cp -Pv $lib/libplc4*          $shared_lib/.
  cp -Pv $lib/libpcre.so.*      $shared_lib/.
  cp -Pv $lib/libfreebl3.so     $shared_lib/.
  cp -Pv $lib/libcap*           $shared_lib/.
  cp -Pv $lib/libaudit*         $shared_lib/.
  cp -Pv $lib/libicu*.so.*      $shared_lib/.
  ##cp -Pv $lib/libeconf*         $shared_lib/.
  cp -Pv $lib/liblzma.so.*      $shared_lib/.
  cp -Pv $lib/libcom_err.so.*   $shared_lib/.
  cp -Pv $lib/libkeyutils.so.*  $shared_lib/.
  cp -Pv $lib/libjson-c*        $shared_lib/.
  cp -Pv $lib/libsystemd.so.*   $shared_lib/.
  cp -Pv $lib/libjansson.so*    $shared_lib/.

  cp -Pv $lib/libLLVM*.so*      $shared_lib/.
  cp -Pv $lib/libffi*.so*       $shared_lib/.
  cp -Pv $lib/libossp-uuid.so.16* $shared_lib/.
  cp -Pv /$lib/libcares*        $shared_lib/.

  cp -Pv $lib/libresolv*        $shared_lib/.

  cp -Pv $lib/libzstd*.so*      $shared_lib/.
  cp -Pv $lib/liblz4*.so*       $shared_lib/.
  cp -Pv $lib/libuuid*.so*      $shared_lib/.
  cp -Pv $lib/libblkid*.so*     $shared_lib/.
  cp -Pv $lib/libgcrypt*.so*    $shared_lib/.
  cp -Pv $lib/libmount*.so*     $shared_lib/.

  ##cp -Pv $lib/libdl*.so*      $shared_lib/.
  ##cp -Pv $lib/libtinfo*         $shared_lib/.
  ##cp -Pv $lib/libpcre2-8*.so*   $shared_lib/.

  ## cleanups at the end #################
  cd $shared_lib
  rm libresolv.so
  ln -s libresolv.so.2 libresolv.so
  ##rm libdl.so
  ##ln -s libdl.so.2 libdl.so

  sl="$shared_lib/."
  rm -f $sl/*.a
  rm -f $sl/*.la
  rm -f $sl/*libboost*test*

  cd $sl
  patchelf --set-rpath '$ORIGIN/../lib' *
}

########################################################
##                MAINLINE                            ##
########################################################

shared_lib=/opt/pgbin-build/pgbin/shared/lib/
mkdir -p $shared_lib
rm -f $shared_lib/*

if [ `uname` == "Linux" ]; then
  linuxCopySharedLibs
else
  osxCopySharedLibs
fi

