CROSS_COMPILE ?= riscv64-unknown-elf-
CC      = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump

CFLAGS  = -march=rv32i -mabi=ilp32 -O2 -Wall -nostartfiles -ffreestanding -I../../drivers
LDFLAGS = -T../../common/linker.ld -nostdlib

SRCS = ../../common/crt0.s ../../drivers/uart.c main.c
TARGET = hello_world

all: $(TARGET).hex $(TARGET).dump

$(TARGET).elf: $(SRCS)
	$(CC) $(CFLAGS) $(SRCS) $(LDFLAGS) -o $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).hex: $(TARGET).bin
	hexdump -v -e '1/4 "%08x\n"' $< > $@

$(TARGET).dump: $(TARGET).elf
	$(OBJDUMP) -D $< > $@

clean:
	rm -f *.elf *.bin *.hex *.dump

.PHONY: all clean
