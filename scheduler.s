

section .data
printIndex: dd 1        ; each switch, incease value, if k, jump to printer
routineIndex: dd 1
IntegerInput: db "%d",10,0
section .text


global schedFunc
extern printer
extern printf
extern K
extern N
extern resume
extern coSize
extern CORS


schedFunc:
    mov eax, dword[routineIndex]
    sub eax, 1                  ; starts at 1, array starts at 0
    mov edx, 4
    mul edx                     ; eax <- coSize*index
    mov ebx, dword[CORS + eax]
    ;mov ecx, dword[edx + eax]  ; ebx points to new co routine
    ;mov [ebx], ecx 
    call resume                 ; switch to the printIndex’s drone co-routine

    ; check index for printing
    inc dword[printIndex]
    inc dword[routineIndex]
    mov eax, dword[N]
    inc eax
    cmp eax, dword[routineIndex]           ; num of drones
    jne cont
    mov dword[routineIndex], 1  ; init index, end of round robin
    cont:
    mov ecx, dword[printIndex]
    cmp ecx, dword[K]
    jl continueSwitch           
    mov dword[printIndex], 1      ; init printIndex
    mov ebx, printer
    call resume            ; switch to printer co routin and print. return here
    continueSwitch:
    jmp schedFunc