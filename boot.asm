format binary 

use16

org 0x7c00

    jmp near EntryBoot

GDT:

  rq 1 ; null descriptor
  DCODE db 0xff,0xff,0x00,0x00,0x00,10011010b,11001111b,0x00
  DDATA db 0xff,0xff,0x00,0x00,0x00,10010010b,11001111b,0x00
  UCODE db 0xff,0xff,0x00,0x00,0x00,11111010b,11001111b,0x00
  UDATA db 0xff,0xff,0x00,0x00,0x00,11110010b,11001111b,0x00 
  DVIDEO db 0xff,0xff,0x00,0x80,0x0b,10010010b,01001111b,0x00  
  gdtlen equ $ - GDT          

GDTR:

    dw gdtlen - 1
    dd GDT

EntryBoot:

    mov ah,0x0e
    xor bh,bh
    mov al,' '
    mov cx,1024

.lp:   
    int 0x10  
    loop .lp
    
    mov ah,0x02
    xor bh,bh
    movzx dx,bh
    int 0x10
    
    mov ah,0x01
    mov cx,0x2607
    int 0x10
    
    cli
    
    in al,0x70
    bts ax,7
    out 0x70,al
    
    in al,0x92
    or al,0x02
    out 0x92,al
    
    mov ax,0x0205
    mov cx,0x0002
    xor dx,dx
    mov bx,EntryProtected
    int 0x13
    
    lgdt fword ptr GDTR
    
    mov eax,cr0
    inc al
    mov cr0,eax
    
    jmp far 0x0008:EntryProtected

times 510 - ($ -$$) db 0x00
dw 0xaa55

use32

EntryProtected:

    mov dx,0x0010
    mov ds,dx
    mov es,dx
    mov gs,dx
    mov ss,dx
    mov dx,0x0028
    mov fs,dx
    mov esp,0x01000000
    xor ebp,ebp

    mov ecx,0x174
    xor edx,edx
    mov eax,0x00000008
    wrmsr
    
    add cl,2
    mov eax,syscall_handle
    wrmsr
    
    dec cl
    mov eax,0x00100000
    wrmsr
    
    mov edx,prog3
    mov ecx,0x00001000
    sysexit



syscall_handle:

     cmp word [0x00001000-2],0x01 ; sys_exit
     jz .sys_exit
     
     cmp word [0x00001000-2],0x02 ; sys_print
     jz .sys_print
     
     mov dword [0x0001000-18],0xffffffff ; error
     
     jmp short .return

.sys_print:

     mov esi,dword [0x0001000-6]
     mov ecx,dword [0x0001000-10] 
     call PrintString

.return:

     mov dword [0x0001000-18],0
     mov edx,dword [0x0001000-14]
     mov ecx,0x0001000-18
     sysexit          
     

.sys_exit:

    cli
    hlt   
         
; ==========<ring3>=========== 


prog3:

    jmp short _start
    
    msg db '[*] prog3',0x0a
    lenm equ $ - msg
    
_start:
    push word 0x02
    push dword msg
    push dword lenm
    push dword .exit_process 
    sysenter

.exit_process:
    
    mov word [esp+4],0x01
    sysenter
    

; ==========<ring0>=========== 
            
                    
locate:
    
    push edx
    push ebx
    
    xchg eax,ebx
    mov edx,160
    
    mul edx
    add eax,ebx ; eax return located string
      
    pop ebx
    pop edx
   
                  
    retn
    
PrintString:
    
    push edi
    push esi
    push ecx
    push ebx
    
    movzx eax,byte ptr x
    movzx ebx,byte ptr y
    
    call locate
    
    mov edi,eax
    mov ah,0x0f

.lp:
    
    lodsb
    cmp al,0x0a
    jz .newline
    mov [fs:edi],ax
    
    add edi,2
    loop .lp
    jmp near .return
    
.newline:
    push eax
    
    xor eax,eax
    movzx ebx,byte [y]
    inc bl
    
    call locate
    
    mov edi,eax
    
    mov byte [x],0x00
    mov byte [y],bl
    
    pop eax
    
    jmp short .lp              
                                        
.return:

    pop ax

    mov byte ptr x,ah
    mov byte ptr y,al
    
    pop ebx
    pop ecx
    pop esi
    pop edi

    xor eax,eax
    
    retn            

PutChar:
    
    cmp byte ptr x,160
    jz .newline
    inc byte ptr x
.newline:

    inc byte ptr y
    
    push ebx
    push eax
    
    movzx eax,byte ptr x
    movzx ebx,byte ptr y
    
    call locate
    
    mov ebx,eax
    pop eax
    mov ah,0x0f
    
    mov [fs:ebx],ax
    
    pop ebx
    
    retn

x db 0x00
y db 0x00                                         