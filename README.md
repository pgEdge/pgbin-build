# PGBIN-BUILD 


## Creating a posix build environment

Tested w Rocky Linux 8-amd, 9-arm, 9-amd & OSX arm

### 1.) First setup a CLI environment to be able to test
   see https://github.com/pgEdge/cli

### 2.) Change the owernship of `/opt` directory to so you (a non-root user) can write there
`sudo chown $USER:$USER /opt`

### 3.) From /opt directory, run 
`git clone https://github.com/pgedge/pgbin-build`

### 4.) The BLD & IN & BUCKET environment variables are setup in your profile from step #1 installing the CLI

### 5.) Configure your ~/.aws/config credentials for write access to $BUCKET

### 6.) in setup directory run `1-pgbin-build.sh` script to setup all compilation tools needed

### 7.) in setup directory run `2-pull-IN.sh` to pull in all the source binaries into the IN directory structure

### 8.) cd $BLD 
        a) run `./sharedlibs.sh` the first time and each time you do incremental pg releases (after `dnf update`)
        b) run `./build-all-pgbin.sh 16`   & `build-all-components.sh spock33 16' to confirm build environment
        c) execute build-scripts as necessary and maintain IN directory binaries via push & pull scripts

### 9.) Enjoy.  With great power comes great responsibility.  :-)

