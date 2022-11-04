.option norvc

.section .data

welcome: .ascii  "Welcome to PseudOS\n\0"
iamhart: .ascii  "I am HART \0"
givingupcontrol: .ascii "Giving Up Control\0"
newline: .ascii  "\n\0"

_hartlock:
	.skip 1,0

_scratchpad:
	.skip 1024,0

.section .text.init
.global _start


_start:
	# make all HARTS except 0 wait..
	csrr t0, mhartid
	bnez t0, _announce

	# Setup UART + Print Welcome Message
	call _setup_uart
	la a0, welcome
	call _write_uart
	j _announce
	wfi

# a0 should contain the address of a string to print
# writeln will then write this string to the serial UART device
# followed by a newline
_writeln:
	mv s0, ra
	call _write_uart
	la a0, newline
	call _write_uart
	mv ra, s0
	ret

_setup_uart:
	# Diable Interupts on the UART
	li t1, 0x10000001
	sb x0, 0(t1)
	# Write out to the UART Line Control Register at UART+3
	li t1, 0x10000003
	li t2, 0x03 # Set the output to 8 bits
	ret

_write_uart:
	li t1, 0x10000005
	lb t2, 0(t1)
	li t3, 0x20
	and t2, t3, t1
	beqz t1, _write_uart
	li t1, 0x10000000
	lb t2, 0(a0)
	beqz t2, _write_uart_end
	sb t2, 0(t1)
	li t2, 1
	add a0,t2,a0
	j _write_uart

_write_uart_end:
	ret

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

_wait:
	wfi
