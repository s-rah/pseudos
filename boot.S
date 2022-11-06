.option norvc

.include "macro.S"

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

data_section_address: .ascii "Data: \0"
write_uart_address: .ascii "Uart: \0"

walkingpagetables: .ascii "Walking Page Tables...\0"
endwalkingpagetables: .ascii "Walking Page Tables Complete\0"

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
.align 12
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

	#csrr a0, satp
	#call _print_hex

	#la a0, _example_page
	#call _print_hex

	# print out data page address
	#la a0, data_section_address
	#call _write_uart
	#la a0, _data_start
	#call _print_hex

	# print out supervisor string address
	la a0, _data_start
	call _print_hex

	# print out _write_uart address
	#la a0, write_uart_address
	#call _write_uart
	#la a0, _write_uart
	#call _print_hex

	# Identity Map Data
	la a0, _data_start
	la a1, _data_start
	li a2, 0x07
	call _map_to_virtual

	# Identity Map Data (F)
	la a0, _stacks
	la a1, _stacks
	li a2, 0x0F
	call _map_to_virtual

	# Identity Map the Uart Ports
	li a0, 0x10000000
	li a1, 0x10000000
	li a2, 0x0F
	call _map_to_virtual

	# Identity Map the Uart Functions  (F)
	la a0, _write_uart
	la a1, _write_uart
	li a2, 0x0F
	call _map_to_virtual

	# Virtual Map the Example Page (F)
	la a0, _example_page
	la a1, _example_page
	li a2, 0x0F
	call _map_to_virtual

	la a0, walkingpagetables
	call _writeln

	# Print out All Page Tables
	la a0, _page_table_start
	li a1, 2
	call _walk_page_tables

	la a0, endwalkingpagetables
	call _writeln

	li t0, 0
	_iterate_pci:
	li a0, 0x30000000
	add a0, a0, t0
	ld a0, 0(a0)
	push t0
	call _print_hex
	pop t0
	li t1, 4096
	add t0, t0, t1
	li t1, 0x10000
	bne t0,t1, _iterate_pci
	#call _list_pci_devices

	la t0, _example_page
	csrw mepc,t0
	mret

	# Show off that we can announce ourselves
	j _announce
	wfi

# Inlcude all of our Paging Code...
.include "paging.S"
.include "uart.S"
.include "pci.S"

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

# TODO: a0 = pages to alloc
_kalloc:
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
	la a0, supervisormodeentry
	call _write_uart
	la a0, _page_table_start
	ld a0, 0(a0)
	wfi
	.skip 4096

.align 12
_page_table_start:
# Sv39 page tables contain 2^9 Page Table Entries
	.skip 4096
