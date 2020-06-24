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
    SM ;0x0	Stores current state enable bits
    OPENSWITCH ;0x1	voltage value for when capacitor switch not pressed
    CTMUVOLTAGE ;0x2	voltage result from ADC
    FiveCounter ;0x3	counter for FiveDelay
    CapDelay ;0x4	value for 250us cap switch delay
    FiveDelay1 ;0x5	value for 5s delay
    FiveDelay2 ;0x6	value for 5s delay
    LOWTHRESHOLD ;0x7	Voltage for LOW
    HIGHTHRESHOLD ;0x8	Voltage for HIGH
    ADCRESULT ;0x9	Current voltage of switch
    TOTALROLLSLOW ;0xA	total interrupts of timer (8 breaths)
    TOTALROLLSHIGH ;0xB	total interrupts of timer (8 breaths)
    TIMERROLLOVERS ;0xC	total interrupts of timer (1 breath)
    ROLLSPERBREATH ;0xD	Number of itnerrupts per 1 breath
    REACHEDHIGH; 0xE
    NUMBREATHSCOUNTED ; 0xF
    TABLECOUNT; 0x10
    endc

; Bit Definitions
Func0 		equ .0
Func1 		equ .1
Func2 		equ .2

    org 00h ; Reset vector
	GOTO START
		
    org 08h ; Interrupt vector
	GOTO ISR
	
; ----- PIC starts up here -----
START
	;Oscillator set at 4 MHz
	BSF 	OSCCON,IRCF0
	BCF	OSCCON,IRCF1
	BSF	OSCCON,IRCF2
	
; ------ Set up all variables -------
    

    
; Setup state machine variables
    CLRF	SM ; All states disabled
    BSF		SM, Func0 ; Startup state enabled
    
    ; LED Setup
	; PORT A
	MOVLB		0xF
	CLRF 		PORTA 		; Initialize PORTA by clearing output data latches
	CLRF 		LATA 		; Alternate method to clear output data latches
	CLRF		ANSELA 		; Configure I/O
	CLRF 		TRISA		; All digital outputs
	; PORT C
	CLRF 		PORTC 		; Initialize PORTC by clearing output data latches
	CLRF 		LATC 		; Alternate method to clear output data latches
	CLRF		ANSELC 		; Configure I/O
	CLRF 		TRISC		; All digital outputs
	
	; PORT B
	CLRF 		PORTB 		; Initialize PORTB by clearing output data latches
	CLRF 		LATB 		; Alternate method to clear output data latches
	CLRF		ANSELB 		; Configure I/O
	CLRF 		TRISB		; All digital outputs
	MOVLB		0x00
	
 ;====================================================================================================
    
; --------- STARTUP STATE (SM State #1) --------------------------------------- 
    ;Empty waiting state when system turned on
    
    
STARTUP
    BTFSS SM, Func0 ; check if this state is enabled
	GOTO CALIBRATION ;This state is not enabled (fall through)
    ;State is enabled
    ; -------- Startup state code --------
	BSF	PORTB,0 ; LED state indicator
	MOVLW	0x02
	MOVWF	OPENSWITCH ; Set what the voltage value for the open switch is
	
	
	
	
	;---------- ADC for CTMU setup ----------
	MOVLB	0xF
	MOVLW	B'10111110' ; Right Justified, 20TAD, FOSC/64
	MOVWF	ADCON2
	MOVLW	B'10000000' ; Trigger from CTMU, AVdd and AVss reference voltages
	MOVWF	ADCON1
	MOVLW	B'0001000'
	MOVWF	ADCON0
	BSF TRISA,2 ; Channel 2 is input (RA2)
	BSF ANSELA,2 ; is ADC input
	BSF ADCON0,ADON ; enable ADC
		
	
;---------- CTMU Setup -------------
	MOVLB 0x0F; BSR change
	MOVLW	B'00000000'
	MOVWF	CTMUCONH
	MOVLW	B'10010000' ; Edge 2 positive edge response, EECP2 special event trigger, positive edge response,
	MOVWF	CTMUCONL
	MOVLW	B'00000001'
	MOVWF	CTMUICON ; Current source is nominal base current level (0.55uA)

;--------- CMTU operation -------------
CAPDETECT
	
	MOVLB	0x0F
	BSF CTMUCONH,CTMUEN ; enable CTMU
	BCF CTMUCONL,EDG1STAT ; edge status bits = zero
	BCF CTMUCONL,EDG2STAT
	BSF CTMUCONH,IDISSEN ; drain charge on circuit
	CALL Delay ;delay 125us
	BCF CTMUCONH,IDISSEN ; End draining of circuit
	BSF CTMUCONL,EDG1STAT ; Begin charging of cicuit using CTMU current source (0.55uA)
	CALL Delay ;delay 125us
	BCF CTMUCONL,EDG1STAT ; Finish circuit charging
	
	MOVLB	0x00
	BCF PIR1,ADIF; Make sure ADC not currently converting
	BSF ADCON0,GO ; start ADC conversion
	BTFSC 	ADCON0,GO ; finished yet?
	BRA 	$-2 ; not finished
	; conversion now finished
	MOVFF	ADRESH,CTMUVOLTAGE
	MOVF	OPENSWITCH,0 ; W = open switch value
	CPFSEQ	CTMUVOLTAGE ; skip next line if CTMUVOLTAGE < open switch voltage
	GOTO	TransitionStartup
	; switch has been pressed
	BSF PORTC,1
	CALL FiveDelay
	CALL FiveDelay
	CALL FiveDelay
	CALL FiveDelay
	CALL FiveDelay
	CALL FiveDelay
	BCF PORTC,1
	BCF SM,Func0 ; leave this state
TransitionStartup
    BTFSC   SM,Func0 ; startup state still enabled
    GOTO    CAPDETECT ; hang in startup state
    BCF	PORTB,0
    BCF SM, Func0 ; Leave Startup state
    BSF SM, Func1 ; enable Calibration state
    
        
 ;====================================================================================================

    ; --------- Calibration STATE (SM State #2) -------------------------------
    ;Calibrate the system for different users
    
CALIBRATION
    BTFSS SM, Func1 ; Check if this state enabled
    GOTO BREATHDETECT ; this state is disabled (fall through)
    ; State is enabled
    ; -------- Calibration state code --------
    BSF	PORTB,1 ; LED state indicator
    ; Read in HIGH + LOW values for ADC and put them in high and low thresholds
    ;------- Setup PORTA for ADC LED output ----------
	    CLRF PORTA
	    CLRF TRISA
	    MOVLW   B'00000000'
	    MOVWF PORTA ; All LEDs on PORTD off
	    
;---- Setup ADC ----
	    MOVLB 0xF ; ADC bank
	    CLRF ADRESH
	    MOVLW B'00001100'; ADC settings: left justified, Fosc/4 and 2TAD
	    MOVWF ADCON2
	    MOVLW B'00000000'; ADC settings: ADC refs are Vdd and Vss
	    MOVWF ADCON1
	    CLRF ADCON0
	    BSF ANSELA,0 ; RA0 used for ADC (not IO)
	    BSF TRISA,0 ; RA0 is an input
	    BSF ADCON0,ADON ; ADC's ANO enabled
	    MOVLB 0x0 ; Back to main bank
	    
;---------- Setup PWM on Port RC2----------
	    CLRF    PORTC
	    CLRF    LATC
	    BCF TRISC,2 ; RC2 is output
	    MOVLW B'00101100'
	    MOVWF CCP1CON
	    CLRF	T2CON
	    CLRF	TMR2
	    BSF T2CON,TMR2ON
    
	    BSF ADCON0,GO ; Start ADC conversion
	    BTFSC ADCON0,GO ; If conversion done skip the next line
	    BRA $-2 ; Loop until conversion is done
	    MOVLW   0x1E ; 100 repetitions
	    MOVWF   FiveCounter
FiveLoop1    CALL FiveDelay
	    DECFSZ  FiveCounter
	    GOTO FiveLoop1
	    ; repeat as first conversion often junk
	    BSF ADCON0,GO ; Start ADC conversion
	    BTFSC ADCON0,GO ; If conversion done skip the next line
	    BRA $-2 ; Loop until conversion is done
	    ; Conversion now done	    
	    Call FiveDelay; Let register settle
	    MOVFF ADRESH,HIGHTHRESHOLD ; Read upper eight bytes of ADC (8bit conversion)
	    MOVLW   0x19; -25 from the adc value
	    SUBWF   HIGHTHRESHOLD,1 ; becomes the highthreshold
	    ; indicate to user they must press button in
	    BSF PORTC,3
	    ; now wait 5s
	    CALL FiveDelay
	    CALL FiveDelay
	    CALL FiveDelay
	    CALL FiveDelay
	    CALL FiveDelay
	    CALL FiveDelay
	    MOVLW   0x1E ; 100 repetitions
	    MOVWF   FiveCounter
FiveLoop    CALL FiveDelay
	    DECFSZ  FiveCounter
	    GOTO FiveLoop
	    ; have now waited 5s now take low threshold
	    BSF ADCON0,GO ; Start ADC conversion
	    BTFSC ADCON0,GO ; If conversion done skip the next line
	    BRA $-2 ; Loop until conversion is donne
	    ; Conversion now done
	    Call FiveDelay ; Let register settle
	    MOVFF ADRESH,LOWTHRESHOLD ; Read upper eight bytes of ADC (8bit conversion)
	    MOVLW   0x19 ; +25 from the adc value
	    ADDWF   LOWTHRESHOLD,1
	    BCF PORTC,3
	    ; calibration now complete
	    
TransitionCalibration
	    BCF	PORTB,1
	    BCF SM, Func1 ; Leave Calibration state
	    BSF SM, Func2 ; enable BreathDetect state
    
 ;====================================================================================================
 
 ; --------- Breath Detection STATE (SM State #3) ---------------------------------
    ;Read in the sensor data and perform averaging/breath rate calculations
    
BREATHDETECT
    BTFSS SM, Func2 ; Check if this state enabled
    GOTO STARTUP ; this state is disabled (fall through back to start)
    ; State is enabled
    ; -------- Breath detect state code --------
    BSF	PORTB,2 ; LED state indicator
    ;;------- Setup PORTA for ADC LED output ----------
    
	    CLRF PORTA
	    CLRF TRISA
	    MOVLW   B'00000000'
	    MOVWF PORTA ; All LEDs on PORTD off
	    
;---- Setup ADC ----
	    MOVLB 0xF ; ADC bank
	    CLRF ADRESH
	    MOVLW B'00001100'; ADC settings: left justified, Fosc/4 and 2TAD
	    MOVWF ADCON2
	    MOVLW B'00000000'; ADC settings: ADC refs are Vdd and Vss
	    MOVWF ADCON1
	    CLRF ADCON0
	    BSF ANSELA,0 ; RA0 used for ADC (not IO)
	    BSF TRISA,0 ; RA0 is an input
	    BSF ADCON0,ADON ; ADC's ANO enabled
	    MOVLB 0x0 ; Back to main bank
	    
	    ; initialize ADC interrupt
		BSF	PIE1,ADIE ; ADC interrupt enable
		BSF	INTCON,PEIE ; peripheral interrupt enable
		BSF	INTCON,GIE	; global interrupt enable
	    
;---------- Setup PWM on Port RC2----------
	    CLRF    PORTC
	    CLRF    LATC
	    BCF TRISC,2 ; RC2 is output
	    MOVLW B'00101100'
	    MOVWF CCP1CON
	    CLRF	T2CON
	    CLRF	TMR2
	    BSF T2CON,TMR2ON
    
	    ; now actually run ADC
	    
Convert	
		BSF 	ADCON0,GO; Start ADC conversion
		BTFSC 	ADCON0,GO; finished yet?
		BRA 	$-2 ; no
		; All ADC handling occurs in interrupt
		GOTO	Convert	; convert again
	    
    ;
TransitionBreathDetect
    BCF	PORTB,2 ; LED state indicator
    BCF SM, Func2 ; Leave Calibration state
    BSF SM, Func0 ; enable BreathDetect state
    
    GOTO STARTUP ; go back to beginning and cycle through again
    
    ;====================================================================================================
    
;----------- END of State machine ----------------------
    
    ;====================================================================================================
    
;----------- All subroutines ---------------------------
Delay ; 125us delay for cap touch
	MOVLW	0xFF		
	MOVWF	CapDelay
Decrement
	DECFSZ	CapDelay,f
	GOTO	Decrement
	RETURN 
	
FiveDelay ; 0.04s
	MOVLW 0xFF
	MOVWF	FiveDelay2
	
Five2	MOVLW	0xFF		
	MOVWF	FiveDelay1
Five1
	DECFSZ	FiveDelay1,f
	GOTO	Five1
	DECFSZ	FiveDelay2,f
	GOTO Five2
	RETURN 
	
ADCSR ; Conversion now done
	MOVFF ADRESH,ADCRESULT ; Read upper eight bytes of ADC (8bit conversion)
EvaluateL   
	CPFSLT ADCRESULT; if ADCRESULT lower than lowThreshold call LOW subroutine
	BRA EvaluateH ; Not lower than low threshold
        CALL SRLOW ; Calls LOW subroutine
	BRA ADCEND ; Makes surehigh isn't evaluated
EvaluateH
	MOVF HIGHTHRESHOLD,0 ; Put high threshold in W for comparison
	CPFSGT ADCRESULT ; if ADCRESULT higher than high threshold call high subroutine
	BRA ADCEND; not higher than high threshold - not low or high
	CALL SRHIGH
ADCEND	    RETURN
	
SRLOW	    CALL PWMLOW ; PWM LED driving
	    BTFSS REACHEDHIGH,0 ; skip next line if reachedHigh = true
	    GOTO TIMERCHECK ; reachedHigh not = true, go to timerCheck
	    ; reachedHigh is = true
	    MOVLB   0x0F
	    BCF T4CON,TMR4ON ; switch off timer
	    MOVLB   0x00
	    BCF REACHEDHIGH,0 ; reachedHigh = false
	    ; One full breath has now occured
TableWrite
	    ; now write timerrollovers to table
	    MOVF    TIMERROLLOVERS,0 ; W = Timerrolls
	    MOVWF   TABLAT
	    TBLWT*+ ; write TABLAT to that point in table with post increment
	    ; check if have gone through 8 breaths now
	    INCF NUMBREATHSCOUNTED; numBreathsCounted++
	    MOVLW 0x08
	    CPFSLT NUMBREATHSCOUNTED ; if numBreathsCounted < 8 skip next line
	    CALL SRAVERAGEBREATHS; numBreathsCounted = 8
	    BRA LOWRETURN
TIMERCHECK  
	    MOVLB   0x0F
	    BTFSC T4CON,TMR4ON ; Skip next line if timer not started
	    BRA LOWRETURN ; timer has started
	    CLRF TMR4 ; if timer not started start it
	    BSF T4CON,TMR4ON    
LOWRETURN   MOVLB   0x00
	    RETURN
	    
	    ;-------- SRHIGH called when user exhaling------
SRHIGH	    CALL PWMHIGH ; PWM LED driving
	    MOVLB   0x0F
	    BTFSC T4CON,TMR4ON ; Skip next line if timer not started
	    BRA	SETHIGH
	    BRA HIGHRETURN
SETHIGH	    MOVLB   0x00
	    BSF REACHEDHIGH,0 ; reachedHigh = true
HIGHRETURN  MOVLB   0x00
	    RETURN
	    
SRAVERAGEBREATHS    ; Average last 8 breaths to get respiration rate
	    ; Do long write for table
	    CLRF 	TBLPTRU	; Upper byte of table address 00
	    MOVLW 	0x10	
	    MOVWF 	TBLPTRH 	; High byte of table address 01
	    MOVLW 	0x00
	    MOVWF 	TBLPTRL	; Low byte of table address 00
	    BSF	EECON1,EEPGD ; point to flash memory
	    BCF	EECON1,CFGS ; access program memory
	    BSF	EECON1,WREN ; enable memory writing
	    BCF	INTCON,GIE ; disable interrupts to not disturb write process
	    MOVLW   0x55
	    MOVWF   EECON2 ; write 55h to control register 2
	    MOVLW   0xAA
	    MOVWF   EECON2 ; write AAh to control register 2
	    BSF	EECON1,WR ; begin writing
	    BSF	INTCON,GIE; enable interrupts again
	    BCF	EECON1,WREN ; disable writes when writing complete
;	    ; data table has 8 sets of rollovers - add all together and divide by 8 to get rollovers per breath
	    ;Initalize Table pointer at 0x1000
	    CLRF    TBLPTRU
	    MOVLW   0x10
	    MOVWF   TBLPTRH
	    MOVLW   0x00
	    MOVWF   TBLPTRL
TableLoop   
	    MOVLB   0x00
	    TBLRD*+ ; TABLAT now has value in it
	    MOVF    TABLAT,0 ; W = TABLAT value
	    ADDWF   TOTALROLLSLOW ; adding value to totalRollsLow
	    BNC	    DecrementTC ; there is no carry
	    INCF    TOTALROLLSHIGH; there is a carry
DecrementTC 
	    DECF    TABLECOUNT,1
	    MOVLW   0x0
	    CPFSEQ  TABLECOUNT ; skip next instruction if tableCount = 0
	    GOTO    TableLoop
	    MOVLW   0x8 ; tablecount =8
	    MOVWF   TABLECOUNT
	    
	    ; erase tableCounter for next averaging
	    CLRF 	TBLPTRU 	; Upper byte of table address 00
	    MOVLW 	0x01		
	    MOVWF 	TBLPTRH 	; High byte of table address 01
	    MOVLW 	0x00
	    MOVWF 	TBLPTRL	; Low byte of table address 00
	    BSF	EECON1,EEPGD ; point to flash memory
	    BCF	EECON1,CFGS ; access program memory
	    BSF	EECON1,WREN
	    BSF	EECON1,FREE ; enable row erasing
	    BCF	INTCON,GIE ; disable interrupts
	    MOVLW	55h
	    MOVWF	EECON2 ; write 55h to control register 2
	    MOVLW	0AAh
	    MOVWF	EECON2 ; write AAh to control register 2
	    BSF	EECON1,WR ; begin erasing
	    NOP ; wait for operation to complete
	    BSF	INTCON,GIE ; enable interrupts again
	    BCF	EECON1, WREN ; disable memory writing
	    
	    CLRF 	TBLPTRU 	; Upper byte of table address 00
	    MOVLW 	0x01		
	    MOVWF 	TBLPTRH 	; High byte of table address 01
	    MOVLW 	0x00
	    MOVWF 	TBLPTRL	; Low byte of table address 00
	    
Averaging
	    ; TOTALROLLSLOW and TOTALROLLSHIGH have all the rolls in them now
	    ; Multiply timer count by pre and postcaler value to get time in seconds
	    ; Each timer rollover worth 0.065536s
	    ; divide TotalRolls by 8 in order to get rolls for one breath
	    RRNCF TOTALROLLSLOW
	    RRNCF TOTALROLLSLOW
	    RRNCF TOTALROLLSLOW
	    MOVLW B'00011111'
	    ANDWF TOTALROLLSLOW
	    RRNCF TOTALROLLSHIGH
	    RRNCF TOTALROLLSHIGH
	    RRNCF TOTALROLLSHIGH
	    BTFSC TOTALROLLSHIGH,7
	    BSF TOTALROLLSLOW,7
	    BTFSC TOTALROLLSHIGH,6
	    BSF TOTALROLLSLOW,6
	    BTFSC TOTALROLLSHIGH,5
	    BSF TOTALROLLSLOW,5 
	    MOVLW B'00011111'
	    ANDWF TOTALROLLSHIGH
	    ; successfuly divided whole of totalRolls by 8
	    ; totalRolls now represents rollovers taken for one breath
	    ; only have to work with TOTALROLLSLOW in PICLEDS cause if value above a certain threshold the person is dead anyway
	    MOVFF TOTALROLLSLOW,ROLLSPERBREATH; timer rollovers per breath (average)
	    CALL PICLEDS
	    ; clear all values again
	    CLRF REACHEDHIGH ; REACHEDHIGH = 0
	    CLRF NUMBREATHSCOUNTED ; numBreaths = 0
	    CLRF TIMERROLLOVERS
	    CLRF TOTALROLLSHIGH
	    CLRF TOTALROLLSLOW
	    CLRF ADCRESULT
	    CLRF    ROLLSPERBREATH
	    MOVLW   0x8; tablecount =8
	    MOVWF   TABLECOUNT
	    
	    ; set up data table
	    CLRF    TBLPTRU 	; Upper byte of table address 00
	    MOVLW   0x10		
	    MOVWF   TBLPTRH 	; High byte of table address 10
	    MOVLW   0x00
	    MOVWF   TBLPTRL	; Low byte of table address 00
	    RETURN 
	    
; -------- Subroutine to SET PIC LEDs ----------
PICLEDS
	; Check value of BREATHPM and set various PIC LEDs accordingly		
Greater76
	    
	    MOVLW 0x4C ; 76 rolls
	    CPFSGT ROLLSPERBREATH ; skip next line if ROLLSPERBREATH > 76
	    GOTO Greater57 ; ROLLSPERBREATH < 76
	    MOVLW   b'00000000' ; ROLLSPERBREATH > 76
	    MOVWF PORTA ; All LEDs on PORTA off
	    GOTO RETURNLEDS
Greater57
	    MOVLW 0x39 ; 57 rolls
	    CPFSGT ROLLSPERBREATH ; skip next line if ROLLSPERBREATH > 57
	    GOTO Greater46 ; ROLLSPERBREATH < 57
	    MOVLW   b'10000000' ; ROLLSPERBREATH > 57
	    MOVWF PORTA ; 1 LEDs on PORTA on
	    GOTO RETURNLEDS
	    
Greater46
	    MOVLW 0x2E ; 46 rolls
	    CPFSGT ROLLSPERBREATH ; skip next line if ROLLSPERBREATH > 46
	    GOTO Greater30 ; ROLLSPERBREATH < 46
	    MOVLW   b'11000000' ; ROLLSPERBREATH > 46
	    MOVWF PORTA ; 2 LEDs on PORTA on
	    GOTO RETURNLEDS
Greater30
	    MOVLW 0x1E ; 30 rolls
	    CPFSGT ROLLSPERBREATH ; skip next line if ROLLSPERBREATH > 30
	    GOTO Less30 ; ROLLSPERBREATH < 30
	    MOVLW   b'11100000' ; ROLLSPERBREATH > 30
	    MOVWF PORTA ; 3 LEDs on PORTA on
	    GOTO RETURNLEDS
Less30
	    MOVLW   b'11110000' ; ROLLSPERBREATH < 30
	    MOVWF PORTA ; 4 LEDs on PORTA on
RETURNLEDS  RETURN ; PICLEDS Subroutine returns
    
PWMLOW
	    MOVLW .61
	    MOVWF PR2
	    MOVLW .61 ; duty cycle at 100% : 1 * PR2 = 1 * 61 = 61
	    MOVWF CCPR1L
	    BCF	CCP1CON,5
	    BCF	CCP1CON,4 ; 0.00
	    RETURN    
PWMHIGH
	    MOVLW .61
	    MOVWF PR2
	    MOVLW .6 ; duty cycle at 20% : 0.2 * PR2 = 0.2 * 61 = 12.2
	    MOVWF CCPR1L
	    BCF	CCP1CON,5
	    BSF	CCP1CON,4 ; 0.25
	    RETURN
    
;----------- Interrupt ---------------------------------
    
ISR
	; determine whether it is timer interrupt or adc interrupt
	BTFSC	PIR1,ADIF ; skip line if not the adc interrupt
	GOTO	ADCInterrupt
	BTFSC	PIR5,TMR4IF ; skip line if not the timer4 interrupt
	GOTO	Timer4Interrupt
ADCInterrupt
	BCF	PIR1,ADIF ; clear the ADC interrupt
	CALL	ADCSR
	GOTO	InterruptReturn
Timer4Interrupt
    ; 0.065536s have elapsed (Timer gone through whole 16 rollovers)
	INCF TIMERROLLOVERS ; Add one rollover count
	BCF	PIR5,TMR4IF
InterruptReturn
	RETFIE
	    
    end