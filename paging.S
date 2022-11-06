
# Setup SATP sets up sv39 paging for our OS
_setup_satp:
	# Setting our satp mode to Sv39 (8) (39-bit virtual addressing)
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

# given a physical page map it to a virtual page
# Usage:
# a0: Virtual Page
# a1: Physical Page
# a2: X/W/R Bits
_map_to_virtual:
	push ra



	# Calculate the first PTE of the Virtual Address
	# a0 contains the Virtual Address
	# Virtual Address: VPN[2]-VPN[1]-VPN[0] (Offset)

	# Calculate the offset va.vpn[0] * 8
	srli t0, a0, 12
	li t1, 0x1FF
	and t2, t0, t1
	li t1, 8
	mul t2, t1, t2
	push t2

	# va.vpn[1]
	srli t0, a0, 21
	li t1, 0x1FF
	and t2, t0, t1
	li t1, 8
	mul t2, t1, t2
	push t2

	# va.vpn[2]
	srli t0, a0, 30
	li t1, 0x1FF
	and t2, t0, t1
	li t1, 8
	mul a0, t1, t2

	# _page_table_start = satp.ppn * 4096
	la t0, _page_table_start
	add a0, t0, a0

	# a0 now contains the physical address of the 2nd level-PTE

	# Create the 2nd-level PTE
	# This is going to be a non-leaf node
	# Which means the only 2 elements it needs to contain are
	# The PPN of the *next* PTE entry
	# And the Valid Bit Set to 1
	# Check the currrent entry...
	ld t0, 0(a0)
	li t1, 0x01
	# t2 contains the Current Valid bit (either 0 or 1)
	and t2, t0, t1

	# The current PPN mapped to this PTE (should only be valid if V=1)
	srli a4, t0, 10 # get the PPN
	slli a4, a4, 12 # get the physical address ( we know it is 4K aligned)

	# Either A4 contains the physical address of the next PTE
	# or we need to allocate space if v=0
	bnez t2, _map_level_1

	# Otherwise allocate space for a sub-page table...
	push a0
	push a1
	push a2
	call _kalloc
	mv a4, a0
	pop a2
	pop a1
	pop a0

	# Contruct the PTE Entry
	# kalloc(1) >> 2 to get the PPN
	srli a5, a4, 2
	li t0, 1
	# OR PPN | V
	or a5, a5, t0
	sd a5, 0(a0)


_map_level_1:

	# a4 contains the physcial address of the top of
	# the next page table...
	# Pop off vpn[1] offset into a0
	pop a0

	# a4 contains the physical address of the level 1 page...
	# Calculate the physical address of the next page table entry
	# store in a0
	add a0, a4, a0

	# 1nd-level PTE
	# This is also going to be a non-leaf node
	# Which means the only 2 elements it needs to contain are
	# The PPN of the *next* PTE entry
	# And the Valid Bit Set to 1
	ld t0, 0(a0)
	li t1, 0x01
	# t2 contains the Valid bit (either 0 or 1)
	and t2, t0, t1
	# The current PPN mapped to this PTE (should only be valid if V=1)
	srli a4, t0, 10
	slli a4, a4, 12 # get the physical address ( we know it is 4K aligned)

	# Either A4 contains the physical address of the next PTE
	# or we need to allocate space if v=0
	bnez t2, _map_level_0

	# if it is *not valid* we allocate memory for another sub-page table
	push a0
	push a1
	push a2
	call _kalloc
	mv a4, a0
	pop a2
	pop a1
	pop a0

	# Contruct the PTE Entry
	# kalloc(1) >> 2 to get the PPN
	srli a5, a4, 2
	li t0, 1
	# OR PPN | V
	or a5, a5, t0
	sd a5, 0(a0)


_map_level_0:

	# Pop off vpn[0] offset into a4
	pop a0
	# Calculate the physical address of the next page table entry
	add a0, a4, a0

	# a1 contains the physical address we want to actually map
	# because we assume we align pages to 4KB (at least for now)
	# we can just shift this down by 2
	# and we will have a valid PPN in the PTE format
	srli a1, a1, 2
	# OR PPN | Permission Bits
	or a1, a1, a2
	# Write to the physical address allocated by V1
	sd a1, 0(a0)
	pop ra
	ret


# a0 = page table start...(_page_table_start)
# a1 = level of the page table...(2)
_walk_page_tables:
	push ra
	# t0 = PTE Pointer
	mv t0, a0
	li t1, 8 # size of a single PTE in bytes
_walk_page_tables_inner:

	# if pte > _page_table_start+504 end
	li t6, 4088
	add t5, a0, t6 # Find the end of the Page Table...
	bgt t0, t5, _walk_page_tables_end


 	# Load the PTE and Put the Valid Bit into t4
	ld t2, 0(t0)
	li t3, 0x01
	and t4, t2, t3

	# Add 8 to our current PTE Pointer
	add t0, t0, t1

	# if the valid bit is not set...continue...
	beqz t4, _walk_page_tables_inner


	# print the address out
	push t0
	push t1
	push t2
	push a1
	push a0
	mv a0, t2
	call _print_hex
	pop a0
	pop a1
	pop t2
	pop t1
	pop t0

	# Otherwise get the physical address of the
	# next page table level...
	srli t2, t2, 10
	slli t2, t2, 12 # 4K aligned so << 12 gives us the physical address



	# if this is the final level of the page table
	# do not recurse
	beqz a1, _walk_page_tables_inner

	# Otherwise...
	# Walk the Sub Page Table
	push t0
	push t1
	push a1
	push a0
	mv a0, t2
	li t2, 0x1
	sub a1, a1, t2
	call _walk_page_tables
	pop a0
	pop a1
	pop t1
	pop t0

	j _walk_page_tables_inner

_walk_page_tables_end:
	pop ra
	ret
