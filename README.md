MemoryFiller
============

Simple app to fill memory with data from /dev/urandom. It will allocate the specified amount of memory with malloc() and then fill it with data from /dev/urandom in chunks of 128 KB each. The process can be repeated multiple times to allocate more memory.
