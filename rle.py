s = "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."
output = ""

last = None
count = 0
for c in s:
    if last is not None:
        if last not in ['+', '-', '>', '<']:
            output += last +"\n"
            count = 0
        elif c != last:
            output += last + f"({count})\n"
            count = 0

    count += 1
    last = c

if last is not None:
    if last not in ['+', '-', '>', '<']:
        output += last + "\n"
    else:
        output += last + f"({count})\n"
    

print(output)