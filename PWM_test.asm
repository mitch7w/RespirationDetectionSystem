        list		p=PIC18F45K22
        #include	"p18f45k22.inc"

;========== Configuration bits ==========
;--- Configuration bits ---
    CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
    CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register)

    
    cblock
	Delay1
	Delay2
    endc
    
;========== Reset vector ==========
    org 	00h
    goto 	Setup

;========== Setup ==========
Setup       
    ; Set oscillator speed at 4 MHz
    bsf 	OSCCON,IRCF0
    bcf		OSCCON,IRCF1
    bsf		OSCCON,IRCF2
    
    CLRF    PORTC
    CLRF    LATC
    BCF TRISC,2 ; RC2 is output
    MOVLW B'00101100'
    MOVWF CCP1CON
    clrf	T2CON
    clrf	TMR2
    
    movlw .61 ; PWM period = 20us
    movwf PR2 ; Timer 2 period register
    movlw .30 ; DUTY cycle at 50% : 0.5 * PR2 = 0.5 * 61 = 30.75
    MOVWF CCPR1L ; PWM register 1 low byte
    BSF	CCP1CON,5
    BSF	CCP1CON,4 ; 0.75
    
    ; TODO replace duty cycle above with ADCRESULT
    ;ADCRESULT HIGH = 100% duty cycle and ADCRESULT LOW = 10% duty cycle
    ; Put in capacitor here to slow down response
        
    BSF T2CON,TMR2ON
    
    
    
     
    
Main
    ; Check PWM output in logic analyser
    CALL Delay
    Call ChangeDC
    CALL Delay
    CALL ChangeDC1
    CALL Delay
    goto 	Main

ChangeDC
    movlw .61 ; PWM period = 20us
    movwf PR2 ; Timer 2 period register
    movlw .61 ; DUTY cycle at 100% : 1 * PR2 = 1 * 61 = 61
    MOVWF CCPR1L ; PWM register 1 low byte
    BCF	CCP1CON,5
    BCF	CCP1CON,4 ; .00
    RETURN
    
ChangeDC1
    movlw .61 ; PWM period = 20us
    movwf PR2 ; Timer 2 period register
    movlw .10 ; DUTY cycle at 50% : 0.5 * PR2 = 0.5 * 61 = 30.75
    MOVWF CCPR1L ; PWM register 1 low byte
    BSF	CCP1CON,5
    BSF	CCP1CON,4 ; 0.75
    
Delay
	MOVLW 0xFF
	MOVWF Delay1
Loop	MOVLW	0xFF		
	MOVWF	Delay2
Decrement
	DECFSZ	Delay2,f
	GOTO	Decrement
	DECFSZ	Delay1,f
	GOTO	Loop
	RETURN
    end