.global brainfuck
.data
format_str: .asciz "%c"
.bss
# INSTR: .skip 64 * 1024
DATA: .skip 64 * 1024
# 3 bits opcode, 16 bits operand (count or jump target instruction pointer) = 19 bits => 3 bytes per instruction
# First byte is opcode, next 2 are operand
BYTECODE: .skip 64 * 1024 * 3
BRACKETS: .skip 64 * 1024 * 2 * 2
.text

# Arguments: RDI - pointer to null terminated instruction string
create_bracket_table:
	pushq %rbp
	movq %rsp, %rbp

	# When open bracket, push its IP to stack
	# When close bracket, pop off stack and add both pairs (open, close) and (close, open)

	xor %rax, %rax # i = 0
	xor %rcx, %rcx
	create_bracket_table_loop:
		cmpb $0, (%rdi, %rax)
		je create_bracket_table_loop_done

		cmpb $'[', (%rdi, %rax)
		je create_bracket_table_open
		cmpb $']', (%rdi, %rax)
		je create_bracket_table_close
		jmp create_bracket_table_loop_continue

		create_bracket_table_open:
			pushw %ax
			jmp create_bracket_table_loop_continue
		create_bracket_table_close:
			popw %cx
			movw %cx, BRACKETS(, %rax, 2)
			movw %ax, BRACKETS(, %rcx, 2)
			jmp create_bracket_table_loop_continue

		create_bracket_table_loop_continue:
		inc %ax
		jmp create_bracket_table_loop

	create_bracket_table_loop_done:

	movq %rbp, %rsp
	popq %rbp
	ret

# RDI - instruction
# Return rax (least significant 3 bits - opcode)
get_opcode:
	pushq %rbp
	movq %rsp, %rbp

	xor %rax, %rax
	movq %rdi, %rax

	cmpb $'>', %al
	je opcode_0
	cmpb $'<', %al
	je opcode_1
	cmpb $'+', %al
	je opcode_2
	cmpb $'-', %al
	je opcode_3
	cmpb $'.', %al
	je opcode_4
	cmpb $',', %al
	je opcode_5
	cmpb $'[', %al
	je opcode_6
	cmpb $']', %al
	je opcode_7

	opcode_0:
	movq $0, %rax
	jmp done2
	opcode_1:
	movq $1,  %rax
	jmp done2
	opcode_2:
	movq $2,  %rax
	jmp done2
	opcode_3:
	movq $3,  %rax
	jmp done2
	opcode_4:
	movq $4,  %rax
	jmp done2
	opcode_5:
	movq $5,  %rax
	jmp done2
	opcode_6:
	movq $6,  %rax
	jmp done2
	opcode_7:
	movq $7,  %rax
	jmp done2

	done2:
	movq %rbp, %rsp
	popq %rbp
	ret


# Arguments: RDI - pointer to null terminated instruction string
# Writes bytecode to BYTECODE label
# NOTE: Bracket table must be generated first
/*
Opcodes:
000 : >(n)
001 : <(n)
010 : +(n)
011 : -(n)
100 : .
101 : ,
110 : [(i)
111 : ](i)
*/
gen_bytecode:
	pushq %rbp
	movq %rsp, %rbp

	# See rle.py for high-level implementation

	xor %rax, %rax # Last (al)
	xor %r9, %r9 # Count
	xor %r10, %r10 # Loop index (and also instruction pointer)
	xor %r11, %r11 # Bytecode top pointer
	# For char in string
	gen_bytecode_loop:
		# Check if reached end of string
		cmpb $0, (%rdi, %r10)
		je gen_bytecode_loop_done

		# check that last is set (edge case on first iteration)
		cmpb $0, %al
		je gen_bytecode_loop_continue

		# Check if last char is compressible (+-><)
		cmpb $'+', %al
		je compressible
		cmpb $'-', %al
		je compressible
		cmpb $'>', %al
		je compressible
		cmpb $'<', %al
		je compressible

		# Not compressible

		# Add to bytecode
			# First, write opcode to first byte

			pushq %rdi
			# Char is in rax
			movq %rax, %rdi
			pushq %rax
			call get_opcode
			movq %rax, %rdx # rdx - opcode (lower 3 bits)
			popq %rax
			popq %rdi

			# dl now stores 00000xxx, so shift 5 to the left
			# First byte is opcode
			movb %dl, BYTECODE(%r11)

			# If [ or ] then operand should be jump target
			cmpb $'[', %al
			je has_operands
			cmpb $']', %al
			je has_operands

			jmp no_operands

			has_operands:
				# Operand is jump target
				# r10 is the instruction pointer
				movq %r10, %rdx
				andq $0xFFFF, %rdx
				movq %r11, %rsi
				addq 8, %rsi
				movw %dx, BYTECODE(%rsi)

			no_operands:
				# Opcode was already written

			inc %r11 # Move to next bytecode location
			xor %r9, %r9 # Reset count to 0

		jmp gen_bytecode_loop_continue

		compressible:
			# Must have current != last
			cmpb %al, (%rdi, %r10)
			je gen_bytecode_loop_continue

			# Write opcode (duplicated code)

			pushq %rdi
			# Char is in rax
			movq %rax, %rdi
			pushq %rax
			call get_opcode
			movq %rax, %rdx # rdx - opcode (lower 3 bits)
			popq %rax
			popq %rdi

			# dl now stores 00000xxx, so shift 5 to the left
			# First byte is opcode
			movb %dl, BYTECODE(%r11)

			# Write operand (count, r9)
			movq %r9, %rsi
			addq 8, %rsi
			movw %dx, BYTECODE(%rsi)

			# Reset count to zero
			xor %r9, %r9


		gen_bytecode_loop_continue:
			inc %r9 # count++
			movb (%rdi, %r10), %al # last = current
			inc %r10 # i++

	gen_bytecode_loop_done:


	movq %rbp, %rsp
	popq %rbp
	ret

brainfuck:
	pushq %rbp
	movq %rsp, %rbp

	# === OUR CODE ===

	pushq %rdi

	# create mmap table for code buffer
	movq    $0, %rdi                        # addr = NULL
	movq    $4*1000000, %rsi                # length fixed here to 4MB
	movq    $(0x1|0x2), %rdx                # prot = PROT_READ | PROT_WRITE
	movq    $(0x02|0x20), %r10              # flags = MAP_PRIVATE | MAP_ANON
	movq    $-1, %r8                        # fd = -1
	movq    $0, %r9                         # offset = 0
	movq    $9, %rax
	syscall
	movq    %rax, %r14                      # move the code buffer space into r14

	popq %rdi

	pushq %rdi
	subq $8, %rsp

	call gen_bytecode

	addq $8, %rsp
	popq %rdi

	pushq %rdi
	subq $8, %rsp
	call create_bracket_table
	addq $8, %rsp
	popq %rdi

	# Instruction pointer: r8, data pointer: r9
	movq $0, %r8
	movq $0, %r9

	# while instruction != 0x00
	instruction_loop:
		cmpb $0, (%rdi, %r8)
		je done

		cmpb $'>', (%rdi, %r8)
		je inc_dp

		cmpb $'<', (%rdi, %r8)
		je dec_dp

		cmpb $'+', (%rdi, %r8)
		je inc_at_dp

		cmpb $'-', (%rdi, %r8)
		je dec_at_dp

		cmpb $'.', (%rdi, %r8)
		je output_at_dp

		cmpb $',', (%rdi, %r8)
		je accept_input

		cmpb $'[', (%rdi, %r8)
		je loop_start

		cmpb $']', (%rdi, %r8)
		je loop_end

		jmp continue

		# Increment DP (>)
		inc_dp:
			inc %r9
			jmp continue

		# Decrement DP (<)
		dec_dp:
			dec %r9
			jmp continue

		# Increment at DP (+)
		inc_at_dp:
			incb DATA(%r9)
			jmp continue

		# Decrement at DP (-)
		dec_at_dp:
			decb DATA(%r9)
			jmp continue

		# Output at DP (.)
		output_at_dp:
			pushq %rdi
			pushq %r8
			pushq %r9
			subq $8, %rsp

			movzxb DATA(%r9), %rsi

			movq $format_str, %rdi
			movq $0, %rax
			call printf

			addq $8, %rsp
			popq %r9
			popq %r8
			popq %rdi

			jmp continue

		# Accept input and write at DP (,)
		accept_input:
		    pushq %rdi
			pushq %r8
			pushq %r9
			subq $8, %rsp

			call getchar

			addq $8, %rsp
			popq %r9
			popq %r8
			popq %rdi

			movb %al, DATA(%r9)
			jmp continue

		# [
		loop_start:
			# Check if current cell is zero
			cmpb $0, DATA(%r9)
			jne continue

			movzwq BRACKETS(, %r8, 2), %r8

			jmp continue

		# ]
		loop_end:
			# Check if current cell is nonzero
			cmpb $0, DATA(%r9)
			je continue

			movzwq BRACKETS(, %r8, 2), %r8

			jmp continue

		continue:

		inc %r8

		jmp instruction_loop
	done:

	# mprotect the code buffer
    movq    %r14, %rdi
    movq    $64*1000000, %rsi
    movq    $(0x1|0x4), %rdx
    movq    $10, %rax
    syscall

	# ================

	movq %rbp, %rsp
	popq %rbp
	ret
