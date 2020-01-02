; -----------------------------------------------------------------------------
; MIT License
;
; Copyright (c) 2019 Jens Kallup
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; WARNING: Linux use different syscall numbers for each arch !!!
; -----------------------------------------------------------------------------
SYS_EXIT         equ   1     ; "exit"  32-bit x86 kernel ABI
SYS_FORK         equ   2     ; "fork"  ...
SYS_READ         equ   3     ; "read"  ...
SYS_WRITE        equ   4     ; "write" ...
SYS_OPEN         equ   5     ; "open"  ...
SYS_CLOSE        equ   6     ; "close" ...
SYS_CREAT        equ   8     ; "creat" ... (file create with perm.)
SYS_LSEEK        equ  19     ; "lseek" ...
SYS_SYNC         equ  36     ; "sync"  ... write buffers, and clear it

O_RDONLY         equ   0     ; read  only file mode
O_WRONLY         equ   1     ; write ...
O_RDWR           equ   2     ; both - read & write

%assign stdin    0           ; std input
%assign stdout   1           ; std output
%assign stderr   2           ; std error => (stdout)

%assign SEEK_SET 0           ; begin of file position
%assign SEEK_CUR 1           ; current ...
%assign SEEK_END 2           ; end



; -----------------------------------------------------------------------------
; code/text section - helper function's ...
; -----------------------------------------------------------------------------
    section .text
write_kernel_str:
    mov     edx, kernel32_rd_byte_len
    mov     ecx, kernel32_rd_byte_str

sys_write:
    mov     ebx, stdout
    mov     eax, SYS_WRITE
    int     0x80
    ret

sys_newline:
    mov     edx, 2
    mov     ecx, print_newline_char
    call    sys_write
    ret

; -----------------------------------------------------------------------------
; sys_read:     read buffer from fiven file descriptor. fd 0, 1, 2 are reserved
;               under Linux.
; Example:
;       mov     edx, <count>        ; edx := read buffer size
;       mov     ecx, <buffer>       ; ecx := read buffer
;       mov     ebx, <file desc>    ; ebx := file descriptor (e.g.: stdin)
;       call    sys_read            ; sys_read: syscall
; -----------------------------------------------------------------------------
sys_read_dd:
    mov     edx, 4
sys_read:
    mov     eax, SYS_READ
    int     0x80
    ret

sys_write_text_nl:
    call    sys_write
    call    sys_newline
    ret

sys_write_bytes_ok:
    mov     edx, sizs_readkernel_len
    mov     ecx, sizs_readkernel_str
    call    sys_write
    mov     edx, bytes_str_ok_len
    mov     ecx, bytes_str_ok
    call    sys_write_text_nl
    ret
; -----------------------------------------------------------------------------
sys_write_bytes_fail:
    mov     edx, bytes_str_fail_len
    mov     ecx, bytes_str_fail
    call    sys_write
    mov     edx, sizs_readkernel_len
    mov     ecx, sizs_readkernel_str
    call    sys_write_text_nl
    mov     eax, -1
    ret

sys_write_kernel_b_ok:
    call    write_kernel_str
    call    sys_write_bytes_ok
    mov     eax, 0
    ret
sys_write_kernel_b_fail:
    call    write_kernel_str
    call    sys_write_bytes_fail
    mov     eax, -1
    ret

sys_write_text_nl_fail:
    call    write_kernel_str
    mov     edx, fail_openkernel_len
    mov     ecx, fail_openkernel_str
    call    sys_write_bytes_fail
    mov     eax, -1
    ret

; -----------------------------------------------------------------------------
open_read_ok:
    push    ebp
    mov     ebp, esp

    mov     al, byte [ebp + 8]
    cmp     al, 1
    je      .open_ok
    cmp     al, 2
    je      .read_ok

.open_ok:
    call    write_kernel_str
    mov     edx, succ_openkernel_len
    mov     ecx, succ_openkernel_str
    call    sys_write_text_nl
    jmp     .done

.read_ok:
    call    write_kernel_str
    mov     edx, succ_readkernel_len
    mov     ecx, succ_readkernel_str
    call    sys_write_text_nl

.done:
    mov     esp, ebp
    pop     ebp
    ret     1

; -----------------------------------------------------------------------------
; read buffer from loader
; -----------------------------------------------------------------------------
loader_read:
    push    ebp
    mov     ebp, esp

    mov     ebx, dword [ebp + 12]
    mov     ecx, dword [ebp + 16]
    mov     edx, dword [ebp + 20]
    call    sys_read

    cmp eax, -1
    jg  .file_read_ok                ; error at read file ...
        mov     al, byte [ebp + 8]
        cmp     al, 1
        je      .file_read_fail_1
        cmp     al, 2
        je      .file_read_fail_2
        cmp     al, 3
        je      .file_read_fail_3
        cmp     al, 4
        je      .file_read_fail_4
        cmp     al, 5
        je      .file_read_fail_5

        .file_read_fail_5:
        .file_read_fail_4:
        .file_read_fail_3:
            call    sys_write_kernel_b_fail
            mov     eax, -1
            ret
        .file_read_fail_2:
        .file_read_fail_1:
            call    sys_write_text_nl_fail
            mov     eax, -1
            ret
    ; -------------------------------------
    ; file_read_ok:
    ; -------------------------------------
    .file_read_ok:
        mov     al, byte [ebp + 8]
        cmp     al, 1
        je      .file_read_ok_1
        cmp     al, 2
        je      .file_read_ok_2
        cmp     al, 3
        je      .file_read_ok_3
        cmp     al, 4
        je      .file_read_ok_4
        cmp     al, 5
        je      .file_read_ok_5

        .file_read_ok_5:
        .file_read_ok_4:
        .file_read_ok_3:
            call    sys_write_kernel_b_ok
            jmp     .done

        .file_read_ok_2:
            call    write_kernel_str
            mov     edx, vers_readkernel_len
            mov     ecx, vers_readkernel_str
            call    sys_write_text_nl
            jmp     .done

        .file_read_ok_1:
            push    eax             ; save file descriptor in eax
            ;
            push    byte 1
            call    open_read_ok
            ;
            pop     eax
.done:
    mov     eax, 0
    mov     esp, ebp
    pop     ebp
    ret     13          ; sizeof(x) + sizeof(y) + sizeof(z) + sizeof(a)

; -----------------------------------------------------------------------------
; open file from loader ...
; -----------------------------------------------------------------------------
loader_open:
    push    ebp
    mov     ebp, esp

    mov     ebx, dword [ebp + 12]
    mov     ecx, dword [ebp + 16]
    mov     edx, dword [ebp + 20]

    mov     eax, SYS_OPEN
    int     0x80

    mov     [ebp + 8], eax          ; save result from eax (file descriptor)

    cmp     eax, -1
    jg  .file_openok                ; error at open file ...
        call    sys_write_text_nl_fail
        ret
    ; -------------------------------------
    ; file open ok:
    ; -------------------------------------
    .file_openok:
        push    byte 2
        call    open_read_ok
.done:
    mov     esp, ebp
    pop     ebp
    ret     16

section .data

; -----------------------------------------------------------------------------
%macro sys_strlen 1
        mov     esi, %1
        push    esi
        mov     ecx, 0          ; counter; string is in ESI
%%repeat:
        lodsb                   ; load string byte by byte
        test    al, al          ; check if zero (terminator \0
        jz      %%done          ; yes, we done the loop

        inc     ecx             ; increment counter
        jmp     %%repeat        ; loop
%%done:
        mov     edx, ecx
        pop     esi
        mov     eax, esi
        mov     esi, eax        ; the string itself
%endmacro

