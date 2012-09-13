      SUBROUTINE MORTALTY (STEMMASS, ROOTMASS,    AILCG, GLEAFMAS,
     1                     BLEAFMAS,      ICC,      ILG,      IL1, 
     2                          IL2,     IDAY,   ICHECK,     SORT,
C    3 ------------------ INPUTS ABOVE THIS LINE ----------------------   
     4                     LYSTMMAS, LYROTMAS, TYMAXLAI, GRWTHEFF,
C    5 -------------- INPUTS UPDATED ABOVE THIS LINE ------------------
     6                     STEMLTRM, ROOTLTRM, GLEALTRM, GEREMORT,
     7                     INTRMORT)
C    8 ------------------OUTPUTS ABOVE THIS LINE ----------------------
C
C               CANADIAN TERRESTRIAL ECOSYSTEM MODEL (CTEM) V1.0
C                             MORTALITY SUBROUTINE
C
C     07  MAY 2003  - THIS SUBROUTINE CALCULATES THE LITTER GENERATED
C     V. ARORA        FROM LEAVES, STEM, AND ROOT COMPONENTS AFTER
C                     VEGETATION DIES DUE TO REDUCED GROWTH EFFICIENCY
C                     OR DUE TO AGING (THE INTRINSIC MORTALITY)  

C     INPUTS 
C
C     STEMMASS  - STEM MASS FOR EACH OF THE 9 CTEM PFTs, Kg C/M2
C     ROOTMASS  - ROOT MASS FOR EACH OF THE 9 CTEM PFTs, Kg C/M2
C     AILCG     - GREEN OR LIVE LAI
C     GLEAFMAS  - GREEN LEAF MASS FOR EACH OF THE 9 CTEM PFTs, Kg C/M2
C     BLEAFMAS  - BROWN LEAF MASS FOR EACH OF THE 9 CTEM PFTs, Kg C/M2
C     LYSTMMAS  - STEM MASS AT THE END OF LAST YEAR
C     LYROTMAS  - ROOT MASS AT THE END OF LAST YEAR
C     TYMAXLAI  - THIS YEAR's MAXIMUM LAI
C     GRWTHEFF  - GROWTH EFFICIENCY. CHANGE IN BIOMASS PER YEAR PER
C                 UNIT MAX. LAI (g C/M2)/(M2/M2)
C     ICC       - NO. OF CTEM PLANT FUNCTION TYPES, CURRENTLY 8
C     ILG       - NO. OF GRID CELLS IN LATITUDE CIRCLE
C     IL1,IL2   - IL1=1, IL2=ILG
C     IDAY      - DAY OF THE YEAR
C     ICHECK    - SWITCH TO TURNOFF MORTALITY BY SETTING ITS VALUE TO 1.
C     SORT      - INDEX FOR CORRESPONDENCE BETWEEN CTEM 9 PFTs AND SIZE
C                 12 OF PARAMETERS VECTORS
C
C     OUTPUTS
C
C     STEMLTRM  - STEM LITTER GENERATED DUE TO MORTALITY (Kg C/M2)
C     ROOTLTRM  - ROOT LITTER GENERATED DUE TO MORTALITY (Kg C/M2)
C     GLEALTRM  - GREEN LEAF LITTER GENERATED DUE TO MORTALITY (Kg C/M2)
C     GEREMORT  - GROWTH EFFICIENCY RELATED MORTALITY (1/DAY)
C     INTRMORT  - INTRINSIC MORTALITY (1/DAY)
C
      IMPLICIT NONE
C
      INTEGER ILG, ICC, IL1, IL2, I, J, K, IDAY, ICHECK, KK, N
C
      PARAMETER (KK=12)  ! PRODUCT OF CLASS PFTs AND L2MAX
C
      INTEGER       SORT(ICC)
C
      REAL  STEMMASS(ILG,ICC), ROOTMASS(ILG,ICC), GLEAFMAS(ILG,ICC),
     1         AILCG(ILG,ICC), GRWTHEFF(ILG,ICC), LYSTMMAS(ILG,ICC),
     2      LYROTMAS(ILG,ICC), TYMAXLAI(ILG,ICC), BLEAFMAS(ILG,ICC)
C
      REAL  STEMLTRM(ILG,ICC), ROOTLTRM(ILG,ICC), GLEALTRM(ILG,ICC),
     1      GEREMORT(ILG,ICC), INTRMORT(ILG,ICC)
C
      REAL       MXMORTGE(KK),            KMORT1,             ZERO,
     1             MAXAGE(KK)
C
C     ------------------------------------------------------------------
C                     PARAMETER USED IN THE MODEL
C
C     ALSO NOTE THE STRUCTURE OF PARAMETER VECTORS WHICH CLEARLY SHOWS
C     THE CLASS PFTs (ALONG ROWS) AND CTEM SUB-PFTs (ALONG COLUMNS)
C
C     NEEDLE LEAF |  EVG       DCD       ---
C     BROAD LEAF  |  EVG   DCD-CLD   DCD-DRY
C     CROPS       |   C3        C4       ---
C     GRASSES     |   C3        C4       ---
C
C     KMORT1, PARAMETER USED IN GROWTH EFFICIENCY MORTALITY FORMULATION
      DATA  KMORT1/0.3/
C
C     MAXIMUM PLANT AGE. USED TO CALCULATE INTRINSIC MORTALITY RATE.
C     MAXIMUM AGE FOR CROPS IS SET TO ZERO SINCE THEY WILL BE HARVESTED
C     ANYWAY. GRASSES ARE TREATED THE SAME WAY SINCE THE TURNOVER TIME
C     FOR GRASS LEAVES IS ~1 YEAR AND FOR ROOTS IS ~2 YEAR. 
      DATA MAXAGE/250.0, 250.0,   0.0,
     &            250.0, 250.0, 250.0,
     &              0.0,   0.0,   0.0,
     &              0.0,   0.0,   0.0/
C
C     MAXIMUM MORTALITY WHEN GROWTH EFFICIENCY IS ZERO (1/YEAR)
      DATA  MXMORTGE/0.01, 0.01, 0.00,
     &               0.01, 0.01, 0.01,
     &               0.00, 0.00, 0.00,
     &               0.00, 0.00, 0.00/
C
C     ZERO
      DATA ZERO/1E-20/
C
C     ---------------------------------------------------------------
C
      IF(ICC.NE.9)                            CALL XIT('MORTALTY',-1)
C
C     INITIALIZE REQUIRED ARRAYS TO ZERO
C
      DO 140 J = 1,ICC
        DO 150 I = IL1, IL2
          STEMLTRM(I,J)=0.0     !STEM LITTER DUE TO MORTALITY
          ROOTLTRM(I,J)=0.0     !ROOT LITTER DUE TO MORTALITY
          GLEALTRM(I,J)=0.0     !GREEN LEAF LITTER DUE TO MORTALITY
          GEREMORT(I,J)=0.0     !GROWTH EFFICIENCY RELATED MORTALITY RATE 
          INTRMORT(I,J)=0.0     !INTRINSIC MORTALITY RATE 
150     CONTINUE                  
140   CONTINUE
C
C     INITIALIZATION ENDS    
C
C     ------------------------------------------------------------------
C
C     AT THE END OF EVERY YEAR, I.E. WHEN IDAY EQUALS 365, WE CALCULATE
C     GROWTH RELATED MORTALITY. RATHER THAN USING THIS NUMBER TO KILL
C     PLANTS AT THE END OF EVERY YEAR, THIS MORTALITY RATE IS APPLIED
C     GRADUALLY OVER THE NEXT YEAR.
C
      DO 200 J = 1, ICC
        N = SORT(J)
        DO 210 I = IL1, IL2
C
          IF(IDAY.EQ.1)THEN
            TYMAXLAI(I,J) =0.0
          ENDIF
C
          IF(AILCG(I,J).GT.TYMAXLAI(I,J))THEN
            TYMAXLAI(I,J)=AILCG(I,J)
          ENDIF
C
          IF(IDAY.EQ.365)THEN
            IF(TYMAXLAI(I,J).GT.ZERO)THEN
              GRWTHEFF(I,J)= ( (STEMMASS(I,J)+ROOTMASS(I,J))-
     &         (LYSTMMAS(I,J)+LYROTMAS(I,J)) )/TYMAXLAI(I,J) 
            ELSE
              GRWTHEFF(I,J)= 0.0
            ENDIF
            GRWTHEFF(I,J)=MAX(0.0,GRWTHEFF(I,J))*1000.0
            LYSTMMAS(I,J)=STEMMASS(I,J)
            LYROTMAS(I,J)=ROOTMASS(I,J)
          ENDIF
C
C         CALCULATE GROWTH RELATED MORTALITY USING LAST YEAR'S GROWTH
C         EFFICIENCY OR THE NEW GROWTH EFFICIENCY IF DAY IS 365 AND
C         GROWTH EFFICIENCY ESTIMATE HAS BEEN UPDATED ABOVE.
C
          GEREMORT(I,J)=MXMORTGE(N)/(1.0+KMORT1*GRWTHEFF(I,J))
C
C         CONVERT (1/YEAR) RATE INTO (1/DAY) RATE   
          GEREMORT(I,J)=GEREMORT(I,J)/365.0
C
210     CONTINUE
200   CONTINUE
C
C     CALCULATE INTRINSIC MORTALITY RATE DUE TO AGING WHICH IMPLICITY
C     INCLUDES EFFECTS OF FROST, HAIL, WIND THROW ETC. IT IS ASSUMED 
C     THAT ONLY 1% OF THE PLANTS EXCEED MAXIMUM AGE (WHICH IS A PFT-
C     DEPENDENT PARAMETER). TO ACHIEVE THIS SOME FRACTION OF THE PLANTS
C     NEED TO BE KILLED EVERY YEAR. 
C
      DO 250 J = 1, ICC
        N = SORT(J)
        DO 260 I = IL1, IL2
          IF(MAXAGE(N).GT.ZERO)THEN
            INTRMORT(I,J)=1.0-EXP(-4.605/MAXAGE(N))
          ELSE
            INTRMORT(I,J)=0.0
          ENDIF
C         CONVERT (1/YEAR) RATE INTO (1/DAY) RATE   
          INTRMORT(I,J)=INTRMORT(I,J)/365.0
260     CONTINUE
250   CONTINUE 
C
      DO 270 J = 1,ICC
        DO 280 I = IL1, IL2
          IF(ICHECK.EQ.1)THEN
            GEREMORT(I,J)=0.0
            INTRMORT(I,J)=0.0
          ENDIF
280     CONTINUE
270   CONTINUE
C
C     NOW THAT WE HAVE BOTH GROWTH RELATED AND INTRINSIC MORTALITY RATES,
C     LETS COMBINE THESE RATES FOR EVERY PFT AND ESTIMATE LITTER GENERATED
C
      DO 300 J = 1, ICC
        DO 310 I = IL1, IL2
          STEMLTRM(I,J)=STEMMASS(I,J)*
     &    ( 1.0-EXP(-1.0*(GEREMORT(I,J)+INTRMORT(I,J))) )
          ROOTLTRM(I,J)=ROOTMASS(I,J)*
     &    ( 1.0-EXP(-1.0*(GEREMORT(I,J)+INTRMORT(I,J))) )
          GLEALTRM(I,J)=GLEAFMAS(I,J)*
     &    ( 1.0-EXP(-1.0*(GEREMORT(I,J)+INTRMORT(I,J))) )
310     CONTINUE
300   CONTINUE
C
      RETURN
      END

