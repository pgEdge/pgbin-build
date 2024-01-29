# PGBIN-BUILD 


## Creating a build environment on el8 or el9

### 1.) First setup a CLI environment to be able to test (see https://github.com/pgEdge/cli)

### 2.) Change the owernship of `/opt` directory to be $USER:$USER so you can write there

### 3.) From /opt directory, run `git clone https://github.com/pgedge/pgbin-build`

### 4.) The BLD & IN environment variables are setup in your .bashrc from step #1 installing the CLI

### 5.) Configure your ~/.aws/config credentials for access to s3://pgedge-xxxxxxxx/IN

### 6.) in setup directory run `1-pgbin-build.sh` script to setup all compilation tools needed

### 7.) in setup directory run `2-pull-IN.sh` to pull in all the source binaries into the IN directory structure

### 8.) cd $BLD and run the the build-all-pgbin.sh and build-all-components.sh for each pgversion and component that needs to be run

