.code16  ;tells GAS to output 16-bit code
    mov $msg, %si 
    mov $0x0e, %ah
loop:
    lodsb
    or %al, %al
    jz halt
    int $0x10 ;does a BIOS call. This is what prints the characters one by one.
    jmp loop
halt:
    hlt
msg:
    .asciz "hello world"
