## Kilo text editor - port to planet

TODO add description

### Quick install

See the repo of the language for more info, or get started now:  
```
$ git clone --depth 1 --branch master --recurse-submodules --shallow-submodules https://github.com/romainducrocq/planet
$ cd planet/bin/
$ ./configure.sh
$ ./make.sh
$ ./install.sh
$ . ~/.bashrc # or . ~/.zshrc or . ~/.shrc
```

### Build and Run

Build with the planet compiler:  
```
planet -O3 -E -latexit -lsignal kilo.plx
```
and start editing:  
```
./kilo <filename>
```

TODO add demo

****

@romainducrocq
