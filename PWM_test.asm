        list		p=PIC18F45K22
        #include	"p18f45k22.inc"

;========== Configuration bits ==========
;--- Configuration bits ---
    CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
    CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register)

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
    
    movlw .2 ; PWM period = 20us
    movwf PR2 ; Timer 2 period register
    movlw .18 ; DUTY cycle at 25% : 0.25 * PR2 = 0.25 * 200 = 5
    ; TODO replace duty cycle above with ADCRESULT
    ;ADCRESULT HIGH = 100% duty cycle and ADCRESULT LOW = 10% duty cycle
    ; Put in capacitor here to slow down response
    MOVWF CCPR1L ; PWM register 1 low byte
    
    BSF T2CON,TMR2ON
    
Main
    ; Check PWM output in logic analyser
    nop
    nop
    nop
    nop
    goto 	Main

    end