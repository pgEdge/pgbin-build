# PGBIN-BUILD 


## Creating an AMD64 or ARM64 build environment on EL8

### 1.) Setup a CLI environment (see https://github.com/pgEdge/cli for more info)
```
cd ~
mkdir dev
cd dev
git clone https://github.com/pgEdge/cli
```

### 2.) Setup a BUILD (BLD) environment
```
cd /opt
sudo git clone https://github.com/pgedge/pgbin-build
sudo chown -R $USER:$USER pgbin-build
```

### 3.) cd $BLD 
        a) run `./sharedlibs.sh` the first time and each time you do incremental pg releases (after `dnf update`)
        b) run `./build-all-pgbin.sh 17`   & `build-all-components.sh spock40 17' to confirm build environment
        c) execute build-scripts as necessary and maintain IN directory binaries via push & pull scripts

