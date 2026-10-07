.global brainfuck
.data
format_str: .asciz "%c"
.bss
# INSTR: .skip 64 * 1024
DATA: .skip 64 * 1024
# 3 bits opcode, 16 bits operand (count or jump target instruction pointer) = 19 bits => 3 bytes per instruction
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

# Arguments: RDI - pointer to null terminated instruction string
# Writes bytecode to BYTECODE label
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
	
	xor %ax, %ax # Last
	xor %r9, %r9 # Count
	xor %r10, %r10 # Loop index
	xor %r11, %r11 # Bytecode top pointer
	# For char in string
	gen_bytecode_loop:
		# Check if reached end of string
		cmpb $0, (%rdi, %r10)
		je gen_bytecode_loop_done

		# check that last is set (edge case on first iteration)
		cmpb $0, %ax
		je gen_bytecode_loop_continue

		# Check if last char is compressible (+-><)
		cmpb $'+', %ax
		je compressible
		cmpb $'-', %ax
		je compressible
		cmpb $'>', %ax
		je compressible
		cmpb $'<', %ax
		je compressible

		# Not compressible

		# Add to bytecode
			
			inc %r11 # Move to next bytecode location

		jmp gen_bytecode_loop_continue

		compressible:


		gen_bytecode_loop_continue:
			inc %r9 # count++
			movb (%rdi, %r10), %ax # last = current
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

			xor %rax, %rax
			movb DATA(%r9), %al
			movq %rax, %rsi

			movq $format_str, %rdi
			call printf
			movq $0, %rax

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

	# ================

	movq %rbp, %rsp
	popq %rbp
	ret
