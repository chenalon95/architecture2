
section .data
    printTarget: db "%.2f,%.2f",10,0
    printDrone: db "%d,%.2f,%.2f,%.2f,%d",10,0


section .text

global printerF
extern N
extern printf
extern scheduler
extern resume
extern droneSize
extern target
extern dronesArray
extern droneSize


printerF:               ; print game board and switch to routin number indexOfNextCo

    ; print the target
    mov ebx, dword[target+16]        ;push y
    mov edx, dword[target+20]
    push edx
    push ebx
    mov eax, dword[target+8]          ;push x
    mov ecx, dword[target+12]
    push ecx
    push eax
    push printTarget
    call printf
    add esp, 20


    mov esi, 0
    printDrones: 
        cmp esi, dword[N]
        je labelToJump
        mov eax, esi
        mov edx, 28
        mul edx                                 ; eax <- droneSize*index
        mov edx, eax
        mov ecx, dword[dronesArray]
        push dword[ecx+edx + 24]        ; score
        push dword[ecx+edx + 20]        ; angle
        push dword[ecx+edx + 16]        
        push dword[ecx+edx + 12]        ; y
        push dword[ecx+edx + 8]        
        push dword[ecx+edx + 4]         ; x
        push dword[ecx+edx] 
        inc esi       
        mov ebx, esi
        push ebx
        push printDrone
        call printf
        add esp, 36
        jmp printDrones

    labelToJump:
    mov ebx, scheduler   ; ebx holds next routin's address    ???????????????????????????
    call resume
    jmp printerF         ; return to the beggining of the function, satrting point of next printing

