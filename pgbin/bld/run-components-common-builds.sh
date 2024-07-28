
bac="./build-all-components.sh"

## build common components
function bcc {
  $bac $1 15 --copy-bin
  rc1=$?
  $bac $1 16 --copy-bin
  rc2=$?

  if [ "$rc1" == "0" ] && [ "$rc2" == "0" ]; then
    return
  fi

  echo "### ERROR: compiling $bac"
  exit 1
}


bcc setuser
bcc permissions
bcc hypopg
bcc orafce
bcc curl
bcc cron
bcc partman
bcc postgis
bcc vector
bcc audit
bcc hintplan
bcc timescale
bcc plprofiler
bcc pldebugger
bcc citus
bcc timescaledb
bcc wal2json
bcc plv8
## bcc pljava

exit 0
