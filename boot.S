.option norvc

# Here is our data section which for now
# contains some useful strings for outputting our OS status
.section .data
welcome: .ascii  "Welcome to PseudOS\n\0"
iamhart: .ascii  "I am HART \0"
givingupcontrol: .ascii "Giving Up Control\0"
newline: .ascii  "\n\0"

machinemode: .ascii  "Mode: Machine \0"
interrupts_status: .ascii  "Interrupts: "

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

	# Read some machine mode registers and check
	# that they are the values we expect
	call _sanity_check

	# Show off that we can announce ourselves
	j _announce
	wfi

# To save some space, a macro to push the return address
# to the local stack
.macro push
	sd ra, 0(sp)
	li t0, 8
	add sp, sp, t0
.endm

# And to pop it off again...
.macro pop
	li t0, -8
	add sp, sp, t0
	ld ra, 0(sp)
.endm

# A function to check mstatus to check the MPP and MIE bits
# and print them to UART
_sanity_check:
	push
	csrr t0, mstatus
	li t1, 0xC00
	and t0, t1, t2
	beq t1,t2, _sanity_check_interrupts
	la a0, machinemode
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
	pop
	ret

# writeln is a function that will print out something followed
# by a new line...
# a0 should contain the address of a string to print
# writeln will then write this string to the serial UART device
# followed by a newline
_writeln:
	push
	call _write_uart
	la a0, newline
	call _write_uart
	pop
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

# Write a string to UART
# a0 should contain a pointer to the string we want to print...
_write_uart:
	push
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
	pop
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
