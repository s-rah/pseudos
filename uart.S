# writeln is a function that will print out something followed
# by a new line...
# a0 should contain the address of a string to print
# writeln will then write this string to the serial UART device
# followed by a newline
_writeln:
	push t0
	push t1
	push t2
	push t3
	push t4
	push t5
	push t6
	push a0
	push a1
	push a2
	push a3
	push a4
	push ra
	call _write_uart
	la a0, newline
	call _write_uart
	pop ra
	pop a4
	pop a3
	pop a2
	pop a1
	pop a0
	pop t6
	pop t5
	pop t4
	pop t3
	pop t2
	pop t1
	pop t0
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
	addi a0,1,a0
	# loop until null...
	j _write_uart_loop
_write_uart_end:
	pop ra
	ret
