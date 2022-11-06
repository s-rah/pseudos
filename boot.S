.option norvc

# To save some space, a macro to push the return address
# to the local stack
.macro push reg
	sd \reg, 0(sp)
	li t0, 8
	add sp, sp, t0
.endm

# And to pop it off again...
.macro pop reg
	li t0, -8
	add sp, sp, t0
	ld \reg, 0(sp)
.endm

# Here is our data section which for now
# contains some useful strings for outputting our OS status
.section .data
welcome: .ascii  "Welcome to PseudOS\n\0"
iamhart: .ascii  "I am HART \0"
givingupcontrol: .ascii "Giving Up Control\0"
newline: .ascii  "\n\0"
trapwarning: .ascii "WARNING!\0"
twisset: .ascii "TW bit is set!\0"

smode_trapwarning: .ascii "S-Mode Trap!"
supervisormodeentry: .ascii "Entering Supervisor Mode\0"

mpp_mmode: .ascii  "MPP Mode: Machine \0"
mpp_smode: .ascii  "MPP Mode: Supervisor \0"
interrupts_status: .ascii  "Interrupts:\0"

hextable: .ascii  "0123456789ABCDEF"

# We use co-operative scheduling for our HARTs, for now we
# serialize them through this HART lock, later we will *only* use
# this for access to shared resources.
_hartlock:
	.skip 8,0

# Some small memory that we can use as a scratchpad for useful
# temp values etc.
_scratchpad:
	.skip 1024,0

# Allocate some stack space..
_stacks:
	.skip 8192,0

.section .text.init
.global _start

# Our kernel starts here...s
_start:
	# Setup a Stack for Hart 0-4
	csrr t0, mhartid
	la t1, _stacks
	li t2, 1024
	mul t3, t2, t0
	add sp, t3, t1

	# make all HARTS except 0 wait..
	bnez t0, _announce

	# Setup UART + Print Welcome Message
	call _setup_uart
	la a0, welcome
	call _write_uart

	# Dump MISA Extensions to Serial...
	call _debug_misa

	# Read some machine mode registers and check
	# that they are the values we expect
	call _sanity_check

	# Set a Machine Mode Trap Vector
	la t0, _machine_trap
	csrw mtvec, t0

	la t0, _supervisor_trap
	csrw stvec,t0

	# Set pmpcfg0 to allow read/write/exec of a physical memory region
	# containing _supervisor_mode_entry and uart read/write..
	# Also, it will need access to data section read
	li t0, 0xFFFFFFFF
	csrw pmpaddr0,t0
	li t0, 0x1F
	csrw pmpcfg0,t0

	# Jump into Supervisor Mode
	csrr t0, mstatus
	# Clear MPP
	li t1, 0xFFFFFFFFFFFFE7FF
	and t1, t0, t1
	# Set MPP to Supervisor
	li t2, 0x0800
	or t1, t1, t2
	csrw mstatus, t1

	# Read some machine mode registers and check
	# that they are the values we expect
	call _sanity_check

	call _setup_satp

	csrr a0, satp
	call _print_hex

	la a0, _example_page
	call _print_hex

	li a0, 0x00
	la a1, _example_page
	li a2, 0x0F
	call _map_to_virtual

	la a0, _page_table_start
	ld a0, 0(a0)
	call _print_hex

	li t0, 0x00
	csrw mepc,t0
	mret

	# Show off that we can announce ourselves
	j _announce
	wfi

_setup_satp:
	# Setting our satp mode to Sv39 (39-bit virtual addressing)
	li t0, 8
	slli t0,t0, 60
	# Gets the Physical Page Number of the Page Table
	la t1, _page_table_start
	# divide the physical address of the page table by 4096
	srai t1, t1, 12
	# Set 44 bits of t0 to the physical page number of the root page table...
	or t0, t0, t1
	csrw satp, t0
	ret


# For Sv39 LEVELS=3 and PTESIZE = 8
# PAGE_SIZE = 2^12
# va -> pa
# va = VPN[2].VPN[1].VPN[0].Offset
# a = physical address of the page table
# a = satp[ppn] * PAGE_SIZE
# for va = 0x00_0000_0000
# pte = a + va.vpn[2]*PTESIZE i.e. just a because va.vpn[2] == 0
# pte = first entry in the page table...
# Add An Entry to our Page Table
# Usage:
# a0: Virtual Page
# a1: Physical Page
# a2: X/W/R Bits
_map_to_virtual:
	push ra
	# given a physical page map it to a virtual page
	# Calculate the PTE of the Virtual Address
	# va.vpn[2]
	srli a0, a0, 30
	li t0, 8
	mul a0, a0, t0
	# a0 is now va.vpn[2] * 8

	# _page_table_start = satp.ppn * 4096
	la t0, _page_table_start
	add a0, t0, a0

	# a0 now contains the physical address of the PTE for level 2 of the page tree
	push a0
	push a1
	push a2
	call _zalloc
	mv a4, a0
	pop a2
	pop a1
	pop a0

	srli a5, a4, 2
	li t0, 1
	or a5, a5, t0
	sd a5, 0(a0)

	push a0
	push a1
	push a2
	push a4
	call _zalloc
	mv a5, a0
	pop a4
	pop a2
	pop a1
	pop a0

	srli a6, a5, 2
	li t0, 1
	or a6, a6, t0
	sd a6, 0(a4)

	srli a1, a1, 2
	or a1, a1, a2
	sd a1, 0(a5)
	pop ra
	ret

_supervisor_trap:
	la a0, smode_trapwarning
	call _write_uart

	csrr t0, mcause
	li t1, 0x30
	add t0, t0, t1
	# Loading our Scratchpad RAM into a0
	la a0, _scratchpad
	# Store ASCII Hart ID into scratchpad
	sb t0, 0(a0)
	call _writeln
	wfi

_machine_trap:
	la a0, trapwarning
	call _write_uart

	csrr a0, mcause
	call _print_hex
	wfi





# A function to check mstatus to check the MPP and MIE bits
# and print them to UART
_sanity_check:
	push ra
	csrr t0, mstatus
	srai t0, t0, 11
	li t1, 0x3
	and t2, t0, t1
	bne t1,t2, _sanity_check_smode
	la a0, mpp_mmode
	call _writeln

_sanity_check_smode:
	csrr t0, mstatus
	srai t0, t0, 11
	li t1, 0x3
	and t2, t0, t1
	li t1, 0x1
	bne t1,t2, _sanity_check_tw
	la a0, mpp_smode
	call _writeln

_sanity_check_tw:
	csrr t0, mstatus
	li t1, 0x100000
	and t2, t0, t1
	bne t1,t2, _sanity_check_interrupts
	la a0, twisset
	call _writeln

_sanity_check_interrupts:
	csrr t0, mstatus
	li t1, 0x8
	and t0, t1, t2
	la a0, interrupts_status
	call _write_uart

	li t3, 0x30
	srai t2, t2, 3
	add t1, t2, t3
	# Loading our Scratchpad RAM into a0
	la a0, _scratchpad
	# Store ASCII Hart ID into scratchpad
	sb t1, 0(a0)
	call _writeln
_sanity_check_end:
	pop ra
	ret

# writeln is a function that will print out something followed
# by a new line...
# a0 should contain the address of a string to print
# writeln will then write this string to the serial UART device
# followed by a newline
_writeln:
	push ra
	call _write_uart
	la a0, newline
	call _write_uart
	pop ra
	ret

# Ensure that UART is a good state accepting 8bit values..
_setup_uart:
	# Diable Interupts on the UART
	li t1, 0x10000001
	sb x0, 0(t1)
	# Write out to the UART Line Control Register at UART+3
	li t1, 0x10000003
	li t2, 0x03 # Set the output to 8 bits
	ret

_write_uart_char:
	push ra
	li t1, 0x10000000
	lb t2, 0(a0)
	sb t2, 0(t1)
	pop ra
	ret

# Write a string to UART
# a0 should contain a pointer to the string we want to print...
_write_uart:
	push ra
_write_uart_loop:
	# check that UART is free...
	li t1, 0x10000005
	lb t2, 0(t1)
	li t3, 0x20
	and t2, t3, t1
	beqz t1, _write_uart_loop
	li t1, 0x10000000
	lb t2, 0(a0)
	beqz t2, _write_uart_end
	sb t2, 0(t1)
	li t2, 1
	add a0,t2,a0
	# loop until null...
	j _write_uart_loop

_write_uart_end:
	pop ra
	ret

_debug_misa:
	push ra
	csrr t0, misa
	# Number of Extensions to Check
	li t1, 26
	# Counter
	li t2, 0
	# Mask
	li t3, 1
	_debug_misa_extension_start:
	and t4, t0, t3
	beqz t4, _debug_misa_extension_inc

	# Load ASCII 'A' into T4
	li t4, 0x41
	add t4, t4, t2

	# Loading our Scratchpad RAM into a0
	la a0, _scratchpad
	# Store ASCII Extension Value
	sb t4, 0(a0)
	push t0
	push t1
	push t2
	push t3
	call _write_uart
	pop t3
	pop t2
	pop t1
	pop t0

	_debug_misa_extension_inc:
	# Shift the value of MISA right by 1
	# and increment our counter
	srai t0, t0, 1
	add t2, t2, t3

	# Continue if there are more extensions to check
	# if counter != target, then loop
	bne t1, t2, _debug_misa_extension_start

	la a0, newline
	call _write_uart
	pop ra
	ret

# Test function to ensure that HARTs can co-exist. Each HART
# will announce itself in turn and then give control to the next
# HART
# Eventually, we will use this to configure any HART specific
# structures...
_announce:
	fence
	la t0, _hartlock
	lw t0, 0(t0)
	csrr t1, mhartid
	bne t0, t1, _announce

	# Write I am HART...
	la a0, iamhart
	call _write_uart

	# Add 0x30 to the HART ID to get ASCII Number
	csrr t1, mhartid
	li t2, 0x30
	add t1, t2, t1
	# Loading our Scratchpad RAM into a0
	la a0, _scratchpad
	# Store ASCII Hart ID into scratchpad
	sb t1, 0(a0)
	call _writeln

	# Increment the HART lock
	csrr t0, mhartid
	li t1, 0x01
	add t1, t0, t1
	la t2, _hartlock
	sw t1, 0(t2)

	la t0, _hartlock
	lw t1, 0(t0)

	fence

	j _wait

# Wait for interrupts (that will never come, because they are turned off)
_wait:
	wfi

_supervisor_mode_entry:
	#csrr t0, sstatus
	#li t0, 0x00
	#jalr t0
	#la a0, supervisormodeentry
	#call _writeln
	wfi
	j _supervisor_mode_entry

# given a0 = some 64 bit value, print it in hex
# a1 = len?
_print_hex:
	push ra
	# 64 bit value  = 8 bytes = 16 nibbles
	li a1, 15
_print_hex_loop:
	# Load Mask into T1
	li t4, 4
	mul t4, a1, t4
	sra a2, a0, t4
	li t1, 0x0F
	# t1 = Value & 0x0F
	and t1, a2, t1
	# load hextable and add the offset..
	la t2, hextable
	push a0
	push a1
	add a0, t1, t2
	call _write_uart_char
	pop a1
	pop a0
	li t1, -1
	add a1, a1, t1
	bgez a1, _print_hex_loop
	# End with a New Line
	la a0, newline
	call _write_uart
	pop ra
	ret

# a0 = pages to alloc
_zalloc:
	la a1, _heap_counter
	ld t0, 0(a1)

	li t1, 1
	add t0, t0, t1
	sd t0, 0(a1)

	la t1, _heap_end
	li t2, 4096
	mul t2, t0, t2
	sub a0, t1, t2
	ret


.align 12
_example_page:
	ecall
	.skip 4096

.align 12
_page_table_start:
# Sv39 page tables contain 2^9 Page Table Entries
	.skip 4096
