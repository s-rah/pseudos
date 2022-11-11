# Push a register to the stack...
# Note: Clobbers t6
.macro push reg
	sd \reg, 0(sp)
	li s2, 8
	add sp, sp, s2
.endm

# And to pop it off again...
# Note: Clobbers t6
.macro pop reg
	li s2, -8
	add sp, sp, s2
	ld \reg, 0(sp)
.endm
