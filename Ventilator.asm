; Mitchell Williams u18013555
; EMK Home Practical Am I Breathing?

    list	 p=PIC18F45K22
    #include	"p18f45k22.inc"

;--- Configuration bits ---
    CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
    CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register
    CONFIG  LVP = ON              ; ***Single-Supply ICSP Enable bit (Single-Supply ICSP enabled if MCLRE is also 1)
    
; Define variables
    cblock 0x00
    BREATHPM ; Breaths per minute (Breathing rate)
    SM ; Stores current state enable bits
    endc

; Bit Definitions
Func0 		equ .0
Func1 		equ .1
Func2 		equ .2

		
    ;org 08h ; Interrupt vector ************************************************************** TODO FIX MEMORY ALLOCATION ONCE INTERRUPT CODED **************************
	;	GOTO ISR
		
    org 00h ; Reset vector
; ----- PIC starts up here -----

; ------ Set up all variables -------

; Setup LEDs for illumination
    MOVLB	0xF
    CLRF 	PORTA 		; Initialize PORTA
    CLRF 	LATA 		; Initialize PORTA
    CLRF	ANSELA 		; PORTA is going to be IO
    CLRF 	TRISA		; PORTA is an output
    MOVLB	0x00
    
; Setup state machine variables
    CLRF	SM ; All states disabled
    BSF		SM, Func0 ; Startup state enabled
    
; Setup ADC values
    
MAIN_LOOP
    
; --------- STARTUP STATE (SM State #1) --------- 
    ;Empty waiting state when system turned on
STARTUP
    BTFSS SM, Func0 ; check if this state is enabled
	GOTO CALIBRATION ;This state is not enabled (fall through)
    ;State is enabled
    ; -------- Startup state code --------
    ;    
    ;
TransitionStartup
    BCF SM, Func0 ; Leave Startup state
    BSF SM, Func1 ; enable Calibration state

    ; --------- Calibration STATE (SM State #2) --------- 
    ;Calibrate the system for different users
CALIBRATION
    BTFSS SM, Func1 ; Check if this state enabled
    GOTO BREATHDETECT ; this state is disabled (fall through)
    ; State is enabled
    ; -------- Calibration state code --------
    ;
    ;
    ;
TransitionCalibration
    BCF SM, Func1 ; Leave Calibration state
    BSF SM, Func2 ; enable BreathDetect state
    
 ; --------- Breath Detection STATE (SM State #3) --------- 
    ;Read in the sensor data and perform averaging/breath rate calculations
BREATHDETECT
    BTFSS SM, Func2 ; Check if this state enabled
    GOTO STARTUP ; this state is disabled (fall through back to start)
    ; State is enabled
    ; -------- Breath detect state code --------
    ;
    ;
    ;
TransitionBreathDirect
    BCF SM, Func2 ; Leave Calibration state
    BSF SM, Func0 ; enable BreathDetect state
    
    
ISR ; interrupt code
    ; handle capacitive touch button in here
	RETFIE
    
    end

    ; ISR for switching off ADC and returning to Startup state when capacitive touch
    ;button pressed
    
    ;; ISR for switching on ADC and going to main state OR switch on ADC in main