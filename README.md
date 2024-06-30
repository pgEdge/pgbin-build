# PGBIN-BUILD 


## Creating a posix build environment

### 1.) First setup a CLI environment to be able to test
   see https://github.com/pgEdge/cli

### 2.) Change the owernship of `/opt` directory to so you (a non-root user) can write there
`sudo chown $USER:$USER /opt`

### 3.) From /opt directory, run 
`git clone https://github.com/pgedge/pgbin-build`

### 4.) cd $BLD 
        a) run `./sharedlibs.sh` the first time and each time you do incremental pg releases (after `dnf update`)
        b) run `./build-all-pgbin.sh 16`   & `build-all-components.sh spock33 16' to confirm build environment
        c) execute build-scripts as necessary and maintain IN directory binaries via push & pull scripts

