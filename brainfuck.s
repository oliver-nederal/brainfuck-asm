.global brainfuck
.data
format_str: .asciz "%c"
.bss
# INSTR: .skip 64 * 1024
DATA: .skip 64 * 1024
BRACKETS: .skip 64 * 1024 * 2 * 2
.text

# Arguments: RDI - pointer to null terminated instruction string
create_bracket_table:
	pushq %rbp
	movq %rsp, %rbp

	# When open bracket, push its IP to stack
	# When close bracket, pop off stack and add both pairs (open, close) and (close, open)

	xor %ax, %ax # i = 0
	create_bracket_table_loop:
		cmp $0, (%rdi, %ax)
		je create_bracket_table_loop_done
		
		cmp $'[', (%rdi, %ax)
		je create_bracket_table_open
		cmp $']', (%rdi, %ax)
		je create_bracket_table_close
		jmp create_bracket_table_loop_continue

		create_bracket_table_open:
			pushw %ax
			jmp create_bracket_table_loop_continue
		create_bracket_table_close:
			popw %cx
			movq %cx, (BRACKETS, 2, %ax)
			movq %ax, (BRACKETS, 2, %cx)
			jmp create_bracket_table_loop_continue

		create_bracket_table_loop_continue:
		inc %ax

	create_bracket_table_loop_done:

	movq %rbp, %rsp
	popq %rbp
	ret

brainfuck:
	pushq %rbp
	movq %rsp, %rbp

	# === OUR CODE === 

	

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
			jmp continue

		# [
		loop_start:
			# Check if current cell is zero
			cmpb $0, DATA(%r9)
			jne continue

			xor %r10, %r10 # Counter = 0
			# Scan ahead to find closing bracket
			lookahead_loop:
				inc %r8
				cmpb $']', (%rdi, %r8)
				je closing1
				cmpb $'[', (%rdi, %r8)
				je opening1
				jmp lookahead_loop

				# If ] && counter == 0 : found closing
				# If ] : counter-- 
				# If [ : counter++
				closing1:
					cmp $0, %r10
					je continue
					dec %r10
					jmp lookahead_loop

				opening1:
					inc %r10
					jmp lookahead_loop

			jmp continue

		# ]
		loop_end:
			# Check if current cell is nonzero
			cmpb $0, DATA(%r9)
			je continue

			xor %r10, %r10 # Counter = 0
			# Scan behind to find opening bracket
			lookbehind_loop:
				inc %r8
				cmpb $']', (%rdi, %r8)
				je closing2
				cmpb $'[', (%rdi, %r8)
				je opening2
				jmp lookahead_loop

				# If ] && counter == 0 : found closing
				# If ] : counter-- 
				# If [ : counter++
				closing2:
					cmp $0, %r10
					je continue
					dec %r10
					jmp lookahead_loop

				opening2:
					inc %r10
					jmp lookahead_loop

			jmp continue

		continue:

		inc %r8

		jmp instruction_loop
	done:

	# ================

	movq %rbp, %rsp
	popq %rbp
	ret
