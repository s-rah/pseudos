# a0 = pointer to the start of an ELF file...
_map_elf:
	push ra
	lw t0, 0(a0)
	li t1, 0x7F454c46
	bne t0, t1, _valid_elf

	la a0, invalid_elf_warning
	call _writeln
	j _end_map_elf

	_valid_elf:

	push a0
	la a0, valid_elf
	call _writeln
	pop a0



	lw t0, 0x20(a0)
	push a0
	mv a0, t0
	call _print_hex
	pop a0

	lw t2, 0x28(a0)
	push a0
	mv a0, t2
	call _print_hex
	pop a0

	# set t3 to the number of program header entries
	lh t3, 0x38(a0)

	push a0
	mv a0, t3
	call _print_hex
	pop a0

	li a2, 0x0
	addi a1, a0, 0x40

	push a0
	la a0, elf_program_headers
	call _writeln
	pop a0

_next_program_header:

	# t4 = offset of segment in file image
	ld t4, 0x08(a1)
	# t5 =  virtual address
	ld t5, 0x10(a1)
	# t6 =  memsize
	ld t6, 0x28(a1)
	# t6 =  filesize
	ld s6, 0x20(a1)


	# t4 = file offset
	# t5 = virtual address
	# t6 = memsize
	push a0
	mv a0, t4
	call _print_hex
	pop a0

	push a0
	mv a0, t5
	call _print_hex
	pop a0

	push a0
	mv a0, t6
	call _print_hex
	pop a0



	push a1
	push a2
	push t5


	# calculate how many pages we need
	# for the program section (+1)
	push t6
	push a0
	srli t6, t6, 12
	addi t6, t6, 1
	mv a0, t6
	call _kalloc
	mv s5, a0
	pop a0
	pop t6


	# t4 = elf offset + start of this section
	# a0 = elf offset
	# a1 = start of the allocated pages
	add s3, a0, t4
	li t5, 0

	bnez t6, _copy_program_section
	pop t5
	pop a2
	pop a1
	j _skip_program_mapping

	_copy_program_section:
	add a3, s3, t5
	lb a2, 0(a3)
	add a3, s5, t5
	sb a2, 0(a3)
	addi t5, t5, 0x1
	bne t5, s6, _copy_program_section

	push a0
	mv a0, a1
	call _print_hex
	pop a0

	pop t5
	pop a2
	pop a1



	push a0
	push a1
	push a2

	# Number of Pages to Map
	srli t6, t6, 12
	addi t6, t6, 1

	li s3, 0
	_vmap_sections:
	mv a0, t5
	mv a1, s5
	li a2, 0xF
	call _map_to_virtual

	li s4, 4096
	add t5, t5, s4
	add s5, s5, s4
	add s3, s3, 0x01
	bne s3, t6, _vmap_sections

	pop a2
	pop a1
	pop a0


	_skip_program_mapping:
	addi a1, a1, 56
	addi a2, a2, 0x1
	bne a2, t3, _next_program_header




	# t0 is incorrect

	# Identity Map Stack
	push a0
	li a0, 0xD0000
	la a1, _user_stacks
	li a2, 0x0F
	call _map_to_virtual
	pop a0

	push a0
	li a0, 0x00000
	la a1, _user_zero
	li a2, 0x0F
	call _map_to_virtual
	pop a0

	push a0
	la a0, _vga_mmio
	la a1, _vga_mmio
	li a2, 0x0F
	call _map_to_virtual
	pop a0

	push a0
	li t0, 0
	li s0, 0x0000000050000000
	_map_frame_buffer:
	mv a0, s0
	mv a1, s0
	li a2, 0x0F
	call _map_to_virtual

	li t1, 4096
	add s0, s0, t1
	li t1, 19
	addi t0, t0, 1
	bne t0, t1, _map_frame_buffer
	pop a0

	la a1, _machine_trap_stack
	sd sp, 0(a1)
	li sp, 0xD1000

	#li t0, 0x0000000087FA27F8
	ld t0, 0x18(a0)
	csrw mepc, t0
	mret

	_end_map_elf:
	pop ra
	ret

.align 12
_user_zero:
	.skip 65536
