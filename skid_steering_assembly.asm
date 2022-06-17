PROCESSOR 16F877A
    #include <xc.inc>
    ; CONFIG
  CONFIG  FOSC = XT             ; Oscillator Selection bits (XT oscillator)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  BOREN = OFF           ; Brown-out Reset Enable bit (BOR disabled)
  CONFIG  LVP = OFF             ; Low-Voltage (Single-Supply) In-Circuit Serial Programming Enable bit (RB3 is digital I/O, HV on MCLR must be used for programming)
  CONFIG  CPD = OFF             ; Data EEPROM Memory Code Protection bit (Data EEPROM code protection off)
  CONFIG  WRT = OFF             ; Flash Program Memory Write Enable bits (Write protection off; all program memory may be written to by EECON control)
  CONFIG  CP = OFF              ; Flash Program Memory Code Protection bit (Code protection off)
  
  PSECT resetVect, class=CODE, delta=2
  resetVect:
    pagesel main
    goto main
    
 DELAY0 equ 0x20       ;delay0 is used for storing the linear velocity commanded
 DELAY1 equ 0x21       ;delay1 is used for storing the angular velocity commanded
 DELAY2 equ 0x22       ;delay2 is used for storing the signs of commanded velocities and the direction of rotation of wheels
 DELAY3 equ 0x23       ;delay3 stores the magnitude of velocity of left wheel
 DELAY4 equ 0x24       ;delay4 stores the magnitude of velocity of right wheel
 
  PSECT code, delta=2
  main:
    CLRF DELAY0        
    CLRF DELAY1
    CLRF DELAY2
    CLRF DELAY3
    bcf STATUS, 6
    bsf STATUS, 5      ;setting RP0 bit of STATUS register
    MOVLW 0b00111111
    MOVWF TRISA        ;Porta is used for input commands
    MOVLW 0x00
    MOVWF TRISB        ;debugging purpose
    MOVLW 0x00
    MOVWF TRISD        ;debugging purpose
    MOVLW 0x00
    MOVWF TRISC        ;Output Port
    MOVLW 0x8D
    MOVWF ADCON1       ;It is initialiazed in such a way that 0th and 1st bit of PORTA are analog inputs and 2nd and 3rd bits are reference voltages.
    MOVLW 0B10100000
    MOVWF PR2          ;time period of output PWM signals
    BCF STATUS, 5
    MOVLW 0B00001100   
    MOVWF CCP1CON      ;CCP configuration for PWM tasks
    MOVLW 0B00001100
    MOVWF CCP2CON      ;CCP configuration for PWM tasks
    MOVLW 0B00000001    
    MOVWF T2CON        ;Initially Timer 2 is off.
    MOVLW 0xC1
    MOVWF ADCON0      ;Initially it is initialized for channel 0(0th bit of PORTA)
    
    LoopHead:       ;using a loop ADC is taking place
    BCF ADCON0, 3
    BSF ADCON0, 2
    ADCLOOP:
    BTFSC ADCON0, 2  ;checking if ADC has completed
    GOTO ADCLOOP
    
    BSF STATUS, 5    ;normalizing the data into 8 bits and storing the result in delay0
    MOVF ADRESL, 0
    BCF STATUS, 5
    MOVWF DELAY0
    BCF STATUS, 0
    rrf DELAY0
    BCF STATUS, 0
    rrf DELAY0
    btfsc ADRESH, 0
    BSF DELAY0, 6
    btfsc ADRESH, 1
    BSF DELAY0, 7
    
    BSF ADCON0, 3     ;channel 1 (1st bit of PORTA) selection
    BSF ADCON0, 2 
    ADCLOOP2:
    BTFSC ADCON0, 2   ;checking if ADC has completed
    GOTO ADCLOOP2
    
    BSF STATUS, 5    ;normalizing the data into 8 bits and storing the result in delay1
    MOVF ADRESL, 0
    BCF STATUS, 5
    MOVWF DELAY1
    BCF STATUS, 0
    rrf DELAY1
    BCF STATUS, 0
    rrf DELAY1
    btfsc ADRESH, 0
    BSF DELAY1, 6
    btfsc ADRESH, 1
    BSF DELAY1, 7
    
    
    MOVLW 0b10000000    ;initially the range of data is from 0-255
    SUBWF DELAY0, 1     ; to accomodate negative velocities, we have subtracted 128 
    MOVLW 0b10000000    ; now the range will be from -127 to +127
    SUBWF DELAY1, 1
    
    
    btfsc DELAY0, 7    ;checking if the commanded velocity is positive or negative
    bsf DELAY2, 0      ; if it is negative then setting bit 0 of delay 2 as 1
    btfsc DELAY0, 7
    comf DELAY0
    btfsc DELAY2, 0
    INCF DELAY0
    
    btfsc DELAY1, 7
    bsf DELAY2, 1
    btfsc DELAY1, 7
    comf DELAY1
    btfsc DELAY2, 1
    INCF DELAY1
    
    
    BCF STATUS, 0    ;zt/2
    rrf DELAY1
    BCF STATUS, 0
    rrf DELAY1
    
;    MOVF DELAY0, 0
;    MOVWF PORTB
;    MOVF DELAY1, 0
;    MOVWF PORTD
    
    btfss DELAY2, 0   ;calaculation of speed for left wheel
    goto case1        ;according to sign, we have made different cases
    btfsc DELAY2, 0
    GOTO case2
    
    case1:
    btfss DELAY2, 1
    GOTO case3
    btfsc DELAY2, 1
    GOTO case4
    
    case2:
    btfss DELAY2, 1
    GOTO case5
    btfsc DELAY2, 1
    GOTO case6
    
    case3:               ;when both linear and angular velocities are positive
    movf DELAY1, 0
    SUBWF DELAY0, 0
    MOVWF DELAY3
    btfsc DELAY3, 7
    BSF DELAY2, 2
    ;direction depends
    btfsc DELAY2, 2
    COMF DELAY3
    BTFSC DELAY2, 2
    INCF DELAY3
    goto right
    
    case4:               ;when linear is +ve and angular is negative
    movf DELAY1, 0
    ADDWF DELAY0, 0
    MOVWF DELAY3
    ;direction positive
    goto right
    
    case5:               ;when linear is -ve and angular is +ve
    movf DELAY1, 0
    ADDWF DELAY0, 0
    MOVWF DELAY3
    ;direction negative
    BSF DELAY2, 2
    goto right
    
    case6:               ;when both are negative
    movf DELAY0, 0
    SUBWF DELAY1, 0
    MOVWF DELAY3
    ;direction depends
    btfsc DELAY3, 7
    BSF DELAY2, 2
    btfsc DELAY2, 2
    COMF DELAY3
    BTFSC DELAY2, 2
    INCF DELAY3
    goto right
    
    right:                  ;calculation of right wheel velocity
    
    btfss DELAY2, 0
    goto case7
    btfsc DELAY2, 0
    GOTO case8
    
    case7:
    btfss DELAY2, 1
    GOTO case9
    btfsc DELAY2, 1
    GOTO case10
    
    case8:
    btfss DELAY2, 1
    GOTO case11
    btfsc DELAY2, 1
    GOTO case12
    
    case9:
    movf DELAY1, 0
    ADDWF DELAY0, 0
    MOVWF DELAY4
    ;direction positive
    goto finish
    
    case10:
    movf DELAY1, 0
    SUBWF DELAY0, 0
    MOVWF DELAY4
    ;direction depends
    btfsc DELAY4, 7
    BSF DELAY2, 3
    btfsc DELAY2, 3
    COMF DELAY4
    BTFSC DELAY2, 3
    INCF DELAY4
    goto finish
    
    case11:
    movf DELAY0, 0
    SUBWF DELAY1, 0
    MOVWF DELAY4
    ;direction depends
    btfsc DELAY4, 7
    BSF DELAY2, 3
    btfsc DELAY2, 3
    COMF DELAY4
    BTFSC DELAY2, 3
    INCF DELAY4
    goto finish
    
    case12:
    movf DELAY0, 0
    ADDWF DELAY1, 0
    MOVWF DELAY4
    ;direction negative
    BSF DELAY2, 3
    goto finish
    
    finish:
    
    btfss DELAY2, 2      ;depending on the sign , direction is commanded(for left wheel)
    GOTO dir1
    btfsc DELAY2, 2
    GOTO dir2
    
    dir1:
    BSF PORTC, 3
    BCF PORTC, 4
    goto motor
    
    dir2:
    BCF PORTC, 3
    BSF PORTC, 4
    goto motor
    
    
    motor:             ;depending on the sign , direction is commanded(for right wheel)
    
    btfss DELAY2, 3
    GOTO dir3
    btfsc DELAY2, 3
    GOTO dir4
    
    dir3:
    BSF PORTC, 5
    BCF PORTC, 6
    goto motor1
    
    dir4:
    BCF PORTC, 5
    BSF PORTC, 6
    goto motor1
    
    motor1:
    
    MOVF DELAY3, 0     ;PWM also supports 10bit resolution, but we are using 8bit(left wheel)
    MOVWF CCPR1L
    btfsc CCPR1L, 0
    BSF CCP1CON, 4
    btfsc CCPR1L, 1
    BSF CCP1CON, 5
    BCF STATUS, 0
    rrf CCPR1L
    BCF STATUS, 0
    rrf CCPR1L
    
    
    MOVF DELAY4, 0      ;right wheel
    MOVWF CCPR2L
    btfsc CCPR2L, 0
    BSF CCP2CON, 4
    btfsc CCPR2L, 1
    BSF CCP2CON, 5
    BCF STATUS, 0
    rrf CCPR2L
    BCF STATUS, 0
    rrf CCPR2L
    
    count:
    
    BCF PIR1, 1
    CLRF TMR2
    BSF T2CON, 2     ;starting the timer 2
    
    counterLoop:
    btfss PIR1, 1    ;checking if PR2 = Timer 2
    GOTO counterLoop
    btfsc PIR1, 1
    goto count
    
    
    
    goto LoopHead
    
    
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    
  END resetVect


