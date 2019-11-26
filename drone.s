




section .data

    currNum: dq 0.0
     xSub: dq 0.0
    ySub: dq 0.0
    numOfMoves: dd 0
    gamma: dq 0.0
    currDrone: dd 0
    one_eighty:	dd 	180.0
    hundred: dd 100.0
    radiansAngle: dq 0.0
    addAngle: dq 360.0
    subAngle: dq 60.0
    zeroAngle: dq 0.0
     random_angle: dq 0.0
    random_distance: dq 0.0
    canDestroy: dd 0
    num: dd 0
    scalePar: dd 65535.0
    printWinner: db "Drone id %d: I am a winner",10,0


section .text

global droneFunc
extern scheduler
extern resume
extern do_shift
extern target
extern dis
extern dronesArray
extern seed
extern CURR
extern Beta
extern endCo
extern printf
extern T
extern resu
%macro scaleDrone 1 
            mov eax, dword[seed]
            mov ebx, %1
            mov edx, 0
            mov ecx, scalePar
            mul ebx             ;eax <- seed*wanted range
            mov dword[num], eax
            fild dword[num]     ; result in st(0)
            fld dword[scalePar]
            fdivp
            fstp qword[resu]

 %endmacro

droneFunc:


        ; inc dword[numOfMoves]
        ; cmp dword[numOfMoves], 20
        ; je endCo



        mov ebx, dword[CURR]                                   ;index of the current drone
        mov esi, dword[ebx + 8]
        mov eax, esi
        mov edx, 28
        mul edx                                 ; eax <- droneSize*index
        mov edx, eax
        mov ecx, dword[dronesArray]        ; score
        fld qword[ecx + edx + 16]
        fstp qword[currNum]
        finit

            ; get angle of current drone
            ; calculate random angle ∆α     
            ; generate a random number in range [-60,60] degrees, with 16 bit resolution
            ; generate number betweeen [0,120], sub 60 
            call do_shift
            scaleDrone 120
            fld qword[resu]     ; result in st(0)
            fld qword[subAngle] ; 60.0 in ST(0)
            fsubp               ; resule - 60 into ST(0)
            fstp qword[random_angle]

            ; calculate random distance ∆d
            ; generate random number in range [0,50], with 16 bit resolution

            call do_shift
            scaleDrone 50
            fld qword[resu]     ; result in st(0)
            fstp qword[random_distance]
aa:
            ; change the current angle to be α + ∆α
            fld qword[random_angle]
            fld qword[currNum]
            faddp
            fstp qword[currNum]
            fld qword[currNum]

            ;chack if the new angle is between 0 to 360 
            
            fld qword[addAngle]
            fld qword[currNum]
            fcomip
            jb check_zero           ; if angle < 360
            finit
            fld qword[currNum]
            fld qword[addAngle]
            fsubp
            fstp qword[currNum]
            jmp continue

            check_zero: 
                        
            fld qword[currNum]
            fld qword[zeroAngle]
            fcomip
            jb continue           ; if 0 < angle
            ;finit
            fld qword[currNum]
            fld qword[addAngle]
            faddp
            fstp qword[currNum]
            
            continue:
            ;move ∆d at the direction defined by the current angle

            ; update the angle of the drone
            mov ebx, dword[CURR]                                   ;index of the current drone
            mov esi, dword[ebx + 8]
            mov eax, esi
            mov edx, 28
            mul edx                                 ; eax <- droneSize*index
            mov edx, eax
            mov ecx, dword[dronesArray]        ; score
            fld qword[currNum]
            fstp qword[ecx + edx + 16]

            fld	qword [currNum]
            fldpi                    ; Convert angle into radians
            fmulp                  ; multiply by pi
            fld	dword [one_eighty]
            fdivp	      ; and divide by 180.0
            fstp qword[radiansAngle]
            
            fld qword[radiansAngle]
            fcos
            fld qword[random_distance]
            fmulp
            mov ecx, dword[dronesArray]        
            fld qword[ecx + edx]                        
            faddp                              ; st(0) < - x0 + distance*cos(angle)        
            fstp qword[ecx+edx]              

            finit
            fld qword[radiansAngle]
            fsin
            fld qword[random_distance]
            fmulp
            mov ecx, dword[dronesArray]       
            fld qword[ecx + edx +8]                   
            faddp                               ;st(0) <- y0 + distance*sin(angle)
            fstp qword[ecx+edx+8]               

            ; check new distances 
            checkX:
            ; if newX<0 -> x=x+100
            fld qword[ecx + edx]
            fldz                                ; load zero
            fcomip
            jb contCheck                        ; if 0 < x
            ; x < 0
            fld dword[hundred]
            faddp
            fstp qword[ecx + edx]
            jmp checkY
            contCheck:
            ;if newX >100 -> x=x-100
            fld dword[hundred]
            fcomip
            ja checkY                           ; if 100 < x             
            fld dword[hundred]
            fsubp
            fstp qword[ecx + edx]
            
            checkY: 
            ; if newY<0 -> y=y+100
            fld qword[ecx + edx +8]
            fldz                                ; load zero
            fcomip
            jb contCheckY                        ; if 0 < x
            ; x < 0
            fld dword[hundred]
            faddp
            fstp qword[ecx + edx + 8]
            jmp toDestroy
            contCheckY:
            ;if newY >100 -> y=y-100
            fld dword[hundred]
            fcomip
            ja toDestroy                       ; if 100 < x             
            fld dword[hundred]
            fsubp
            fstp qword[ecx + edx + 8]

            toDestroy:
            call mayDestroy
            cmp dword[canDestroy], 1        ; if the drone can destroy the target 
            jne dontDestroy
            
            destroy:
            ; destroy the terget
            mov ecx, dword[dronesArray]        ; score
            mov ebx, dword[ecx+edx + 24]                   ; ebx now holds the score of the drone       
            inc ebx                                         ; the drone destroyed the target
            mov dword[ecx+edx + 24], ebx
            
            cmp ebx, dword[T]                                        ; if the drone destroyed T targets 
            jge printBeforeEnd
            jmp dontEnd

            printBeforeEnd: 
            ;;;;;;;;;; need to print that the current drone is the winner
            mov ebx, dword[CURR]
            mov ebx, [ebx+8]
            inc ebx
            push ebx                      ; drone id
            push dword printWinner        ; string 
            call printf
            add esp, 8
            jmp endCo                   ; end the game


            dontEnd: 
            ; resume target co-rountin 
            mov ebx, target
            call resume
            jmp droneFunc


            dontDestroy: 
            ; if the drone can't destroy the target we should call resume(scheduler) 
            mov ebx, scheduler
            call resume  
            jmp droneFunc


        ; this function will check if the drone can destroy the target
        ; if it is possible - canDestroy var will be 1 
        mayDestroy:
            mov ecx, dword[dronesArray]

            fld qword[target+8]
            fld qword[ecx+edx]
            fsubp 
            fstp qword[xSub]

            fld qword[target+16]
            mov ecx, dword[dronesArray]       
            fld qword[ecx+edx + 8]
            fsubp 
            fstp qword[ySub]
            fld  qword[ySub]
            fld  qword[xSub]
            fpatan
            fldpi                                   ; Convert gamma into degrees
            fdivp                                   ; multiply by pi
            fld	dword [one_eighty]
            fmulp	                                ; and divide by 180.0    
            
            contCompute:
            ; degrees gamma is in st(0)
            mov ecx, dword[dronesArray]        
            fld qword[ecx+edx + 16]                 ; alpha
            fsubp                                   ; alpha - gamma
            fabs                                    ; |alpha - gamma|

            ; check if is smaller than pi (180 degrees)
            fld	dword [one_eighty]
            fcomip
            ja checkBeta            ; pi > |alpha - gamma|
            fld	qword [addAngle]    ; sub 360
            fsubp
            fabs

            checkBeta:
            fld qword[Beta]         ; st(0)
            fcomip
            jb dontChangeFlag

            fld qword[xSub]
            fld qword[xSub]
            fmulp
            fstp qword[xSub]

            fld qword[ySub]
            fld qword[ySub]
            fmulp
            fstp qword[ySub]

            fld qword[xSub]
            fld qword[ySub]
            faddp
            fsqrt
            fld qword[dis]
            fcomip
            jb dontChangeFlag

            mov dword[canDestroy], 1
            ret
            dontChangeFlag:
            mov dword[canDestroy], 0
            ret
