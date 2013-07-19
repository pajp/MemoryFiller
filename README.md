MemoryFiller
============

Simple app to fill memory with data from /dev/urandom, /dev/zero or using memset with the value 0. It will allocate the specified amount of memory with malloc() and then fill it with data (or zeroes) in chunks of configurable size. The process can be repeated multiple times to allocate more memory.
