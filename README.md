# notalotofos
Intel 64 bit starter OS

Includes:
* Boots PC into 64 bit mode
* Use C and NASM
* Talks on serial port (better for working over ssh)
* Discovers memory map 
* Sets up page tables
* Discovers PCI devices
* Reads and writes disk sectors
* Setup for qemu debugging
* Setup for bochs, albeit rusty

For debugging, open two terminals and run 'make step' in one and 'make debug' in the other. The latter drops you into gdb so you can do 'hbreak LongMode' then 'cont' or the like.

