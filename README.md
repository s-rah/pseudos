

## Getting Started

You will need a risc-v toolchain which you can aquire using the instruction at (https://github.com/riscv-collab/riscv-gnu-toolchain).

`riscv64-unknown-elf-as`
`riscv64-unknown-elf-ld`

You will also want to consult the risc-v specifications: https://riscv.org/technical/specifications/

You will also need qemu risc-v the instructions for compiling/installing
can be found https://www.qemu.org/docs/master/system/riscv/virt.html

You will also want to reference the virt.c implementation for qemu's risc-v emulator: https://github.com/qemu/qemu/blob/master/hw/riscv/virt.c

`qemu-system-riscv64 -machine virt -cpu rv64 -smp 4 -m 128M -nographic -serial mon:stdio -bios none -kernel kernel.elf`

# Running with a VGA graphics card (accessible via PCIe)

`qemu-system-riscv64 -machine virt -cpu rv64 -smp 4 -m 8192M  -serial mon:stdio -device VGA -nographic -bios none -kernel kernel.elf`

# Compiling our bootloader


Compilation Step: `riscv64-unknown-elf-as boot.S -o boot.o`

Linking Step: `riscv64-unknown-elf-ld -T kernel.lds boot.o -o kernel.elf`

