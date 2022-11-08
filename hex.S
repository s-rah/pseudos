# a0 is the value to format
# a1 address of 16 byte block of memory for return value
_format_hex:
	push ra
	mv t5, a1
	# 64 bit value  = 8 bytes = 16 nibbles
	li a1, 15
_format_hex_loop:
	# Get the Current Hex Nibble..
	li t4, 4
	mul t4, a1, t4
	sra a2, a0, t4

	# Load Mask into T1
	li t1, 0x0F
	# t1 = Value & 0x0F
	and t1, a2, t1
	# load hextable and add the offset..
	la t2, hextable

	# ASCII Value of Hex Digit
	add t6, t2, t1
	lb t6, 0(t6)

	# Store the ASCII HEX Value into (t5)
	sb t6, 0(t5)
	addi t5, t5, 1

	# Loop until we have formatted the whole value..
	li t1, -1
	add a1, a1, t1
	bgez a1, _format_hex_loop
	pop ra
	ret
