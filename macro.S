# Push a register to the stack...
# Note: Clobbers t6
.macro push reg
	sd \reg, 0(sp)
	li t6, 8
	add sp, sp, t6
.endm

# And to pop it off again...
# Note: Clobbers t6
.macro pop reg
	li t6, -8
	add sp, sp, t6
	ld \reg, 0(sp)
.endm
