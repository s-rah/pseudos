.option norvc

.section .data

welcome: .ascii  "Welcome to PseudOS\n\0"

.section .text.init
.global _start

_start:
	csrr t0, mhartid
	bnez t0, _wait
	call _setup_uart
	la a0, welcome
	call _write_uart
	la a0, welcome
	call _write_uart
	wfi

_setup_uart:
	# Diable Interupts on the UART
	li t1, 0x10000001
	sb x0, 0(t1)
	# Write out to the UART Line Control Register at UART+3
	li t1, 0x10000003
	li t2, 0x03 # Set the output to 8 bits
	sb t2, 0(t1)
	ret

_write_uart:
	li t1, 0x10000000
	lb t2, 0(a0)
	beqz t2, _write_uart_end
	sb t2, 0(t1)
	li t2, 1
	add a0,t2,a0
	j _write_uart

_write_uart_end:
	ret


_wait:
	wfi
