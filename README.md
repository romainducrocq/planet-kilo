```
gcc kilo.c -Wall -Werror -Wextra -Wpedantic -pedantic-errors -lplanet -latexit -lsignal -L../planet/wheelcc/bin/libc -o kilo
wheelcc -O3 -L../planet/wheelcc/bin/libc -lplanet -latexit -lsignal -o kilo kilo.c
```
