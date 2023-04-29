VIDEO_MEMORY equ 0xb8000 + 160
WHITE_ON_BLACK equ 0x0f

; Offsets de los segmentos en la GDT
CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

;Inicio de sector de booteo
[org 0x7c00]
    ;Setea el modo de video a 80 columnas y 25 lineas
    mov ah, 0
    mov al, 0x03
    int 0x10

    ;Imprimo un mensaje en modo real haciendo uso de la interrupcion 0x10
    mov si, msg_mr
    mov ah, 0x0e  ;Seleccionamos la funcion Teletype Output
loop:
    lodsb
    or al, al ;Cuando al es cero (termina el string), setea el flag para el jz
    jz goto_protected
    int 0x10
    jmp loop
goto_protected:
    call change_to_pm
   
;GDT
gdt_start:
    gdt_null:          ; El descriptor nulo
    dd 0x0             
    dd 0x0
        
gdt_code:                  ; El  segmento descriptor de codigo
                           ; base=0x0, limit=0xfffff ,
                           ; 1st flags: (present)1 (privilege)00 
                           ;(descriptor type)1 -> 1001b
                           ; tipo flags: (code)1 (conforming)0 
                           ;(readable)1 (accessed)0 -> 1010b
                           ; 2nd flags: (granularity)1 (32 -bit )1
                           ; (64 -bit seg)0 (AVL)0 -> 1100b
    dw 0xFFFF              ; Limite (bits 0 -15)
    dw 0x0                 ; Base (bits 0 -15)
    db 0x0                 ; Base (bits 16 -23)
    db 10011010b           ; 1001(P DPL S) 1010(type codigo no 
                           ;accedido)
    db 11001111b           ; 1100 ( G D/B 0 AVL)  ,1111  Limite
                           ; (bits 16 -19)
    db 0x0                 ; Base (bits 24 -31)

gdt_data:                  ; El  segmento descriptor de datos
                           ; Igual que el segmento de código 
                           ;excepto por los flags.
                           ; type flags: (code)0 (expand down)0 
                           ;(writable)1 (accessed)0 -> 0010b
    dw 0xFFFF              ; Limite (bits 0 -15)
    dw 0x0                 ; Base (bits 0 -15)
    db 0x0                 ; Base (bits 16 -23)
    db 10010010b           ;  1001(P DPL S) 0010(type codigo no 
                           ;accedido)
    db 11001111b           ; 1100 ( G D/B 0 AVL)  ,1111  Limite 
                           ;(bits 16 -19)
    db 0x0                 ; Base (bits 24 -31)
gdt_end:                   ; Tag para poder calcular el tamaño de la GDT
                             
;GDT descriptor
gdt_descriptor:
        dw gdt_end - gdt_start - 1 ; -1 por aritmetica
        dd gdt_start        

[bits 16]
change_to_pm:
    cli                     ; Interrupciones apagadas porque este proceso no debe ser interrumpido
    lgdt [gdt_descriptor]   ; Cargamos la dirección y tamaño de la tabla GDT
    mov eax, cr0            ; Seteamos el bit 0 de cr0 en 1 para pasar a PM
    or eax, 0x1
    mov cr0, eax
    jmp CODE_SEG : initialize_seg_regs  ; Saltamos al segmento de codigo en PM

[bits 32]
; Inicializamos los registros de segmento y el stack.
initialize_seg_regs:
    mov ax, DATA_SEG 
    mov ds, ax 
    mov ss, ax 
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ebp, 0x7000        ; Seteamos el stack en 0x7000
    mov esp, ebp
 
    ; Estamos en PM, podemos imprimir el mensaje
    mov ebx, msg_mp
    call print_string_pm

    ;mov ebx, data_only_read
    ;call print_string_pm ; Usamos  nuestra rutina para imprimir en PM.
   
    jmp $ ; Loop infinito


; Imprime una cadena de caracteres terminadas en null apuntada por  EBX
print_string_pm:
           pusha
           mov edx, VIDEO_MEMORY    ;Se inicializa EDX a la segunda
                                    ;linea de la memoria de video.
print_string_pm_loop:
           mov al, [ebx]            ;El caracter apuntado por  EBX 
                                    ;se mueve a  AL
           mov ah, WHITE_ON_BLACK   ;Carga AH con el atributo de
                                    ;video
           cmp al, 0                ;si (al = 0) fin de la cadena
           je print_string_pm_done  ;si no salta a done
           mov [edx] , ax           ;Almacena el caracter en la
                                    ;memoria de video
           add ebx, 1               ;Incremento EBX al proximo
                                    ;caracter.
           add edx, 2               ;Apunto al proximo caracter
                                    ;en la memoria de video.
           jmp print_string_pm_loop ;loop a proximo caracter.
print_string_pm_done:
           popa
           ret  

; Mensajes a imprimir
msg_mr db "Modo real" , 0
msg_mp db "Modo protegido", 0

; Rellenamos el espacio restante del bootsector con 0s y definimos el magic number 
times 510 -( $ - $$ ) db 0
dw 0xaa55