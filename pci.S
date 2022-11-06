# List PCI Devices
# a0 = PCIE ECAM Address: 0x30000000
_list_pci_devices:
	push ra
	li t0, 0
	_iterate_devices:
	li t1, 0
	li t2, 1

	mv a0, t0
	mv a1, t1
	mv a2, x0
	push t0
	push t1
	push t2
	call _read_pci
	call _print_hex
	pop t2
	pop t1
	pop t0

	pop ra
	ret

# a0: bus
# a1: device
# a2: function
# a3: offset
# returns a0 = address
_build_address:
	li t0, 0x40000000
	slli a0, a0, 16
	slli a1, a1, 11
	slli a2, a2, 8
	add a0, a0, t0
	add a0, a0, a1
	add a0, a0, a2
	add a0, a0, a3
	ret

# a0 bus
# a1 device
# a2 offset
_read_pci:
	push ra
	mv a3, a2
	mv a2, x0
	call _build_address
	# a0 has the address
	li t0, 0xcf8
	sd a0, 0(t0)
	li t0, 0xcfc
	ld a0, 0(t0)
	pop ra
	ret
