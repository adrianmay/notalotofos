ENTRY(start)
SECTIONS
{
	.text 0x8000 :
	{
		made/cold.o (.text)
		made/serial.o (.text)
		made/pci.o (.text)
		made/disk.o (.text)
		made/play.o (.text)
	}
	. = ALIGN(16);
	KERNEL_CODE_END = .;
	KERNEL_DATA_BEGIN = .;
	. = ALIGN(4096);
	Pml4 = .;
	. += 0x1000;
	Pdpt = .;
	. += 0x1000;
	Pd = .;
	. += 0x1000;
	Pt = .;
	. += 0x1000;
	. += 0x8000;
	Stack = .;
	.data :
	{
		made/cold.o (.data)
		made/serial.o (.data)
		made/pci.o (.data)
		made/disk.o (.data)
		made/play.o (.data)
	}
	.bss :  
	{ 
		made/cold.o (.bss)  
		made/serial.o (.bss)
		made/pci.o (.bss)
		made/disk.o (.bss)
		made/play.o (.bss)
	}
	. = ALIGN(512);
	KERNEL_END = .;
	KERNEL_DATA_SIZE = KERNEL_END - KERNEL_DATA_BEGIN;
}
