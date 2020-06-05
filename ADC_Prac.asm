; Mitchell Williams u18013555
; EMK Home Practical Am I Breathing?

    list	 p=PIC18F45K22
    #include	"p18f45k22.inc"

;--- Configuration bits ---
    CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
    CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register
    CONFIG  LVP = ON              ; ***Single-Supply ICSP Enable bit (Single-Supply ICSP enabled if MCLRE is also 1)
    
    cblock
	ADCRESULT
	LOWTHRESHOLD
	HIGHTHRESHOLD
	REACHEDHIGH
	BREATHPM
	NUMBREATHSCOUNTED
	AVGCALC
	NUMERATOR
	DENOMINATOR
	QUOTIENT
    endc
    ;org 08h ISR Vector
	;GOTO ADCISR
    org 00h ; Reset Vector
    
    ;------- Setup PORTD for ADC LED output ----------
    
	    CLRF PORTA
	    CLRF TRISA
	    MOVLW   B'00000000'
	    MOVWF PORTA ; All LEDs on PORTD off
	    
    ;---- Setup ADC ----
	    MOVLB 0xF ; ADC bank
	    clrf ADRESH
	    clrf ADCRESULT
	    MOVLW B'00101111'; ADC settings: left justified,internal oscillator and 12TAD
	    MOVWF ADCON2
	    MOVLW B'00000000'; ADC settings: ADC refs are Vdd and Vss
	    MOVWF ADCON1
	    BSF ANSELA,0 ; RA0 used for ADC (not IO)
	    BSF TRISA,0 ; RA0 is an input
	    BSF ADCON0, ADON ; ADC's ANO enabled
	    MOVLB 0x0 ; Back to main bank
	    
    ;------Initialize variables-------------
    
	    CLRF REACHEDHIGH ; REACHEDHIGH = 0
	    CLRF BREATHPM ; BREATHPM = 0
	    CLRF NUMBREATHSCOUNTED ; numBreaths = 0
	    CLRF AVGCALC ; avgCalc = 0
	    MOVLW 0x64
	    MOVWF LOWTHRESHOLD
	    MOVLW 0x6A
	    MOVWF HIGHTHRESHOLD
	    
;------- Setup Timer2 for counting respiration rate ----------
	    MOVLW b'00000001' ; TODO change this to correct postscalar values and whatnot
	    MOVWF T2CON
	    MOVLW d'200'
	    MOVWF PR2 ; preloading period values or something TODO read datasheet to understand this   
    
    ;---- Conversion polling--------- TODO : CHANGE THIS TO AN INTERRUPT
POLL    BSF ADCON0, GO ; Start ADC conversion
	    BTFSC ADCON0,GO ; If conversion done skip the next line
	    BRA $-2 ; Loop until conversion is donne
	    
	    ; Conversion now done
	    
	    MOVF ADRESH,W ; Read upper eight bytes of ADC (8bit conversion)
	    MOVWF ADCRESULT ;
	    CALL ADCISR ; proper interrupt not set up yet
	    CLRF ADCRESULT
	    GOTO POLL ;
   
	    ; ------ Turn on LED if value is high - exhaling-------
	    ; ------ Turn off LED if value is low - inhaling-------

ADCISR
	    MOVF LOWTHRESHOLD,W ; put low threshold in W for comparison
EvaluateL   CPFSLT ADCRESULT; if ADCRESULT lower than lowThreshold call LOW subroutine
	    BRA EvaluateH ; Not lower than low threshold
	    CALL SRHIGH ; Calls LOW subroutine
	    BRA ADCEND ; Makes surehigh isn't evaluated
EvaluateH   MOVF HIGHTHRESHOLD,W ; Put high threshold in W for comparison
	    CPFSGT ADCRESULT ; if ADCRESULT higher than high threshold call high subroutine
	    BRA ADCEND; not higher than high threshold - not low or high
	    CALL SRLOW
ADCEND	    RETURN
	
	    ;------- SRLOW called when user inhaling ----------
SRLOW	    MOVLW b'11111111' 
	    CPFSEQ REACHEDHIGH ; skip next line if reachedHigh = true
	    GOTO TIMERCHECK ; reachedHigh not = true, go to timerCheck
	    ; reachedHigh is = true
	    BCF T2CON,TMR2ON ; switch off timer
	    CLRF REACHEDHIGH ; reachedHigh = false
	    MOVF TMR2,0; write breath period to W
	    ADDLW AVGCALC ; AVGCALC gets new value of timer added each time
	    MOVWF AVGCALC
	    INCF NUMBREATHSCOUNTED; numBreathsCounted++
	    MOVLW 0x08
	    CPFSLT NUMBREATHSCOUNTED ; if numBreathsCounted < 8 skip next line
	    CALL SRAVERAGEBREATHS; numBreathsCounted = 8
	    BRA LOWRETURN
TIMERCHECK  
	    MOVLW b'0'
	    CPFSEQ TMR2ON,W ; Skip next line if timer not started TODO Check notation
	    BRA LOWRETURN ; timer has started
	    CLRF TMR2 ; if timer not started start it
	    BSF T2CON,TMR2ON    
LOWRETURN   RETURN
	    
	    ;-------- SRHIGH called when user exhaling------
SRHIGH	    MOVLW b'0'
	    CPFSEQ TMR2ON,W ; Skip next line if timer not started TODO Check notation
	    SETF REACHEDHIGH ; reachedHigh = true	    
HIGHRETURN  RETURN
	    
	    
SRAVERAGEBREATHS    ; Average last 8 breaths to get respiration rate
	    ; AVGCALC contains sum of all breath periods
	    MOVFF AVGCALC,NUMERATOR ; Numerator = added sum of all breath periods
	    MOVLW 0x08
	    MOVWF DENOMINATOR; DENOMINATOR = 8;
	    CALL DIVIDE; divide avgcalc by 8 to get avg period
	    ; avg period = QUOTIENT . NUMERATOR
	   
	    ; can't just throw away decimal like this
	    MOVFF DENOMINATOR, QUOTIENT ; DENOMINATOR = QUOTIENT
	   MOVLW 0x1
	   MOVWF NUMERATOR ; numerator = 1
	   CALL DIVIDE ; divide 1 by breath period to get breath per second
	    MOVLW 0x3c ; 60
	    MULWF QUOTIENT; multiply by 60 to get breath pm
	    ; multiplication result stored in PRODH and PRODL
	    
	    MOVF PRODL,0 ; place PRODL in W assuming product never uses prodH
	    MOVWF BREATHPM; write result to BREATHPM
	    CALL PICLEDS
	    CLRF NUMBREATHSCOUNTED ; start counting numBreaths again
	    CLRF AVGCALC ; the average register must be cleared
	    RETURN 

	    ;-------- SR to divide AVG CALC by 8 - yields average respiration period ---------
DIVIDE
	    CLRF QUOTIENT
	    ; Numerator = added sum of all breath periods
	    MOVF DENOMINATOR,0 ; WREG = Denominator = 8
DIVIDECYCLE
	    INCF QUOTIENT ; quotient++ for every 8 subtracted
	    SUBWF NUMERATOR ; subtract 8 each time
	    BC DIVIDECYCLE ; repeat until carry = 0
	    DECF QUOTIENT ; one too many
	    ADDWF NUMERATOR ; so have to add 10 back to get remainder
	    ; quotient = answer , numerator = answer remainder
	    RETURN
	    
; -------- Subroutine to SET PIC LEDs ----------
PICLEDS
	; Check value of BREATHPM and set various PIC LEDs accordingly		
Less12
	    
	    MOVLW 0xC
	    CPFSLT BREATHPM ; skip next line if BREATHPM < 12
	    GOTO Less16 ; BREATHPM > 12
	    MOVLW   b'00000000' ; BREATHPM <12
	    MOVWF PORTA ; All LEDs on PORTA off
	    GOTO RETURNLEDS
Less16
	    MOVLW 0x10
	    CPFSLT BREATHPM ; skip next line if BREATHPM < 16
	    GOTO Less20 ; BREATHPM > 16
	    MOVLW   b'00000001' ; BREATHPM is between 12 and 16
	    MOVWF PORTA ; 1 LED on PORTA on
	    GOTO RETURNLEDS
Less20
	    MOVLW 0x14
	    CPFSLT BREATHPM ; skip next line if BREATHPM < 20
	    GOTO Less30 ; BREATHPM > 20
	    MOVLW   b'00000011' ; BREATHPM is between 16 and 20
	    MOVWF PORTA ; 2 LEDs on PORTA on
	    GOTO RETURNLEDS
Less30
	    MOVLW 0x1E
	    CPFSLT BREATHPM ; skip next line if BREATHPM < 30
	    GOTO Greater30 ; BREATHPM > 30
	    MOVLW   b'00000111' ; BREATHPM is between 20 and 30
	    MOVWF PORTA ; 3 LEDs on PORTA on
	    GOTO RETURNLEDS
Greater30
	    MOVLW   b'00001111' ; BREATHPM is between 16 and 20
	    MOVWF PORTA ; 4 LEDs on PORTA on
RETURNLEDS  RETURN ; PICLEDS Subroutine returns
	    
    end