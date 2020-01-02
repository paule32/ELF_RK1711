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

section .data

; -----------------------------------------------------------------------------
; error message's ...
; -----------------------------------------------------------------------------
%macro error_msg 2-*
%1:
%rotate 1
%rep %0-1
           db %1
%rotate 1
%endrep
%1_length  equ $-%1
%endmacro

; -----------------------------------------------------------------------------
; Linux 32-bit kernel syscall
; -----------------------------------------------------------------------------
%macro sys_call 1-2 nop
        mov     eax, %1     ; syscall function
        int     0x80        ; Linux kernel syscall
        %2
%endmacro
; -----------------------------------------------------------------------------
%macro sys_prolog 0
        push    ebp         ; prolog
        mov     ebp, esp    ; get cmd line stack pointer
%endmacro
; -----------------------------------------------------------------------------
%macro sys_getcmdline_args 0
    mov eax, [ebp]          ; argc => store argument count into EAX
%endmacro
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
; -----------------------------------------------------------------------------
; compare character in %1 at buffer %2
; -----------------------------------------------------------------------------
%macro sys_cmphdr 2
        xor     edx, edx        ; make sure, edx is 0 at start
        mov     esi, %1         ; buffer 1
        mov     edi, %2         ; buffer 2
%%loop1:
        mov     al, [esi + edx] ; buffer 1
        mov     bl, [edi + edx] ; buffer 2
        inc     edx             ; prepare for next char
        cmp     al, bl          ; compare char
        jne     %%differs       ; not equal, get out
        test    al, al          ; eof ?
        jz      %%done1         ; m_nagic -> ok; go next (version)
        jmp     %%loop1         ; compare next char
%%differs:
        sys_strlen sys_cmp_error_str
        sys_write  stderr,sys_cmp_error_str,sys_cmp_error_str_length
%%done1:
%endmacro

; -----------------------------------------------------------------------------
; sys_exit:     exit the program with return code in EBX
;
; Example:
;       mov     ebx, <return-code>
;       call    sys_exit
; -----------------------------------------------------------------------------
%macro sys_exit 1
        mov     ebx, %1         ; sys_exit: error code
        sys_call SYS_EXIT       ; exit()
%endmacro

; -----------------------------------------------------------------------------
; sys_open:     open a given file by name in EBX.
;               the argument in ECX tells the kenrel in which file mode.
;               On success, EAX contains a file descriptor value assoc
;               to the file that was opened.
; Example:
;       mov     ecx, <flags>        ; O_RDONLY, ...
;       mov     ebx, <file name>
;       call    sys_open
; or:
;       sys_open filedesc, "foo.txt", flags
; -----------------------------------------------------------------------------
%macro sys_open 4
        mov     ebx, %2             ; file name
        mov     ecx, %3             ; flags
        mov     edx, %4             ; mode
        sys_call SYS_OPEN           ; open()
        mov     [%1], eax           ; save result file descriptor
        ;
        test    ax, ax              ; lets make sure it
        jns     %%file_ok           ; if the file desc. have the sign flag
%%error:
        sys_strlen sys_open_error_str
        sys_write  stderr,sys_open_error_str,sys_open_error_str_length
        jmp     .done
%%file_ok:
%endmacro

; -----------------------------------------------------------------------------
; sys_read:     read buffer from fiven file descriptor. fd 0, 1, 2 are reserved
;               under Linux.
; Example:
;       mov     edx, <count>        ; edx := read buffer size
;       mov     ecx, <buffer>       ; ecx := read buffer
;       mov     ebx, <file desc>    ; ebx := file descriptor (e.g.: stdin)
;       call    sys_read            ; sys_read: syscall
; -----------------------------------------------------------------------------
%macro sys_read 3
        mov     ebx, %1
        mov     ecx, %2
        mov     edx, %3
        sys_call SYS_READ
%endmacro

; -----------------------------------------------------------------------------
; sys_write:    write buffer to given file descripor. fd 0, 1, 2 are reserved
;               under Linux.
; Example:
;       mov     edx, <length>       ; edx := string length
;       mov     ecx, <message>      ; ecx := string
;       mov     ebx, <file desc>    ; ebx := file descriptor (e.g.: stdout)
;       call    sys_write           ; sys_write: syscall
; -----------------------------------------------------------------------------
%macro sys_write 3
        mov     ebx, %1             ; ebx := file descriptor (e.g.: stdout)
        mov     ecx, %2             ; ecx := string
        mov     edx, %3             ; edx := length of string
        sys_call SYS_WRITE          ; sys_write: syscall
%endmacro

; -----------------------------------------------------------------------------
; sys_creat:    create a file name in EBX with given permissions
;               in ECX.
; Example:
;       mov     ebx, <file name>    : ebx := the name of file to create
;       mov     ecx, <permissions>  ; ecx := (e.g.: 755)
;       call    sys_creat           ; sys_creat: syscall
; -----------------------------------------------------------------------------
%macro sys_creat 2
        mov     ebx, %1             ; file name
        mov     ecx, %2             ; permission (e.g.: 750)
        sys_call SYS_CREAT
%endmacro

; -----------------------------------------------------------------------------
; sys_lseek:    Perform a long seek to offset in ECX on file (desc.) in EBX
;               from position in EDX.
;               EBX := 0 (default) is file begin
;               EDX := 0 (default) is the origin position in file
; Example:
;       mov     ebx, <file desc.>   ; the file descriptor
;       mov     ecx, <offset>       ; the begin
;       mov     edx, <origin>       ; the current position
;       call    sys_lseek           ; sys_lseek: syscall
; -----------------------------------------------------------------------------
%macro sys_lseek 3
        mov     ebx, [%1]           ; file desc. for sys_lseek
        mov     ecx, %2             ; the end of file, because the attached file
        mov     edx, %3             ; start is position 0 - the first byte of file
        sys_call SYS_LSEEK
%endmacro

; -----------------------------------------------------------------------------
; sys_close:    Close a file (descriptor) in EBX
;
; Example:
;       mov     ebx, <file desc.>   ; the file descriptor
;       call    sys_close           ; sys_close: syscall
; -----------------------------------------------------------------------------
%macro sys_close 1
        mov     ebx, [%1]           ; [file descriptor]
        sys_call SYS_CLOSE
%endmacro
