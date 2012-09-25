      SUBROUTINE ALLOCATE(LFSTATUS,    THLIQ,    AILCG,     AILCB, 
     1                         ICC,       IG,      ILG,       IL1,     
     2                         IL2,     SAND,     CLAY,  RMATCTEM,    
     3                    GLEAFMAS, STEMMASS, ROOTMASS,      SORT,
     4                       L2MAX, NOL2PFTS,       IC,   FCANCMX,
C    5 ------------------ INPUTS ABOVE THIS LINE ----------------------   
     6                     AFRLEAF,  AFRSTEM,  AFRROOT,  WILTSM,
     7                     FIELDSM, WTSTATUS, LTSTATUS)
C    8 ------------------OUTPUTS  ABOVE THIS LINE ---------------------
C
C               CANADIAN TERRESTRIAL ECOSYSTEM MODEL (CTEM) V1.0
C                            ALLOCATION SUBROUTINE
C
C     24  SEP 2012  - ADD IN CHECKS TO PREVENT CALCULATION OF NON-PRESENT
C     J. MELTON       PFTS
C
C     05  MAY 2003  - THIS SUBROUTINE CALCULATES THE ALLOCATION FRACTIONS
C     V. ARORA        FOR LEAF, STEM, AND ROOT COMPONENTS FOR CTEM's PFTs 
C
C     INPUTS 
C
C     LFSTATUS  - LEAF STATUS. AN INTEGER INDICATING IF LEAVES ARE  
C                 IN "MAX. GROWTH", "NORMAL GROWTH", "FALL/HARVEST",
C                 OR "NO LEAVES" MODE. SEE PHENOLGY SUBROUTINE FOR 
C                 MORE DETAILS.
C     THLIQ     - LIQUID SOIL MOISTURE CONTENT IN 3 SOIL LAYERS
C     AILCG     - GREEN OR LIVE LEAF AREA INDEX
C     AILCB     - BROWN OR DEAD LEAF AREA INDEX
C     ICC       - NO. OF CTEM PLANT FUNCTION TYPES, CURRENTLY 9
C     IG        - NO. OF SOIL LAYERS (CURRENTLY 3)
C     ILG       - NO. OF GRID CELLS IN LATITUDE CIRCLE
C     IL1,IL2   - IL1=1, IL2=ILG
C     SAND      - PERCENTAGE SAND
C     CLAY      - PERCENTAGE CLAY
C     RMATCTEM  - FRACTION OF ROOTS IN EACH SOIL LAYER FOR EACH PFT
C     GLEAFMAS  - GREEN OR LIVE LEAF MASS IN KG C/M2, FOR THE 9 PFTs
C     STEMMASS  - STEM MASS FOR EACH OF THE 9 CTEM PFTs, Kg C/M2
C     ROOTMASS  - ROOT MASS FOR EACH OF THE 9 CTEM PFTs, Kg C/M2
C     SORT      - INDEX FOR CORRESPONDENCE BETWEEN 9 PFTs AND THE
C                 12 VALUES IN PARAMETERS VECTORS
C     L2MAX     - MAXIMUM NUMBER OF LEVEL 2 CTEM PFTs
C     NOL2PFTS  - NUMBER OF LEVEL 2 CTEM PFTs
C     IC        - NUMBER OF CLASS PFTs
C     FCANCMX   - MAX. FRACTIONAL COVERAGE OF CTEM's 9 PFTs, BUT THIS CAN BE
C                MODIFIED BY LAND-USE CHANGE, AND COMPETITION BETWEEN PFTs
C
C     OUTPUTS
C
C     AFRLEAF   - ALLOCATION FRACTION FOR LEAVES
C     AFRSTEM   - ALLOCATION FRACTION FOR STEM
C     AFRROOT   - ALLOCATION FRACTION FOR ROOT
C     WILTSM    - WILTING POINT SOIL MOISTURE CONTENT
C     FIELDSM   - FIELD CAPACITY SOIL MOISTURE CONTENT
C     WTSTATUS  - SOIL WATER STATUS (0 DRY -> 1 WET)
C     LTSTATUS  - LIGHT STATUS
C
      IMPLICIT NONE
C
      INTEGER ILG, ICC, IG, IL1, IL2, I, J, K,  LFSTATUS(ILG,ICC), KK,
     1         IC,   N, K1,  K2,   M
C
      PARAMETER (KK=12) ! PRODUCT OF CLASS PFTs AND L2MAX (4 x 3 = 12)
C
      LOGICAL CONSALLO
C
      INTEGER       SORT(ICC),             L2MAX,         NOL2PFTS(IC)
C
      REAL     AILCG(ILG,ICC),    AILCB(ILG,ICC),        THLIQ(ILG,IG), 
     1         WILTSM(ILG,IG),   FIELDSM(ILG,IG),    ROOTMASS(ILG,ICC),
     2   RMATCTEM(ILG,ICC,IG), GLEAFMAS(ILG,ICC),    STEMMASS(ILG,ICC),
     3           SAND(ILG,IG),      CLAY(ILG,IG),        THPOR(ILG,IG),
     4         PSISAT(ILG,IG),         B(ILG,IG),       GRKSAT(ILG,IG)
C
      REAL   AFRLEAF(ILG,ICC),  AFRSTEM(ILG,ICC),     AFRROOT(ILG,ICC),
     1       FCANCMX(ILG,ICC)
C
      REAL          OMEGA(KK),      EPSILONL(KK),         EPSILONS(KK),
     1           EPSILONR(KK),            KN(KK),                 ZERO,
     2                ETA(KK),         KAPPA(KK),           CALEAF(KK),
     3             CASTEM(KK),        CAROOT(KK),          RTSRMIN(KK),
     4           ALDRLFON(KK)
C
      REAL  AVWILTSM(ILG,ICC),  AFIELDSM(ILG,ICC),    AVTHLIQ(ILG,ICC),
     1      WTSTATUS(ILG,ICC),  LTSTATUS(ILG,ICC),    NSTATUS(ILG,ICC),
     2      WNSTATUS(ILG,ICC),              DENOM,   MNSTRTMS(ILG,ICC),
     3                   DIFF,              TERM1,               TERM2,
     4         ALEAF(ILG,ICC),     ASTEM(ILG,ICC),      AROOT(ILG,ICC)
C
C
      COMMON /CTEM1/ ETA, KAPPA, KN
C     ------------------------------------------------------------------
C                     CONSTANTS AND PARAMETERS
C
C     NOTE THE STRUCTURE OF VECTORS WHICH CLEARLY SHOWS THE CLASS
C     PFTs (ALONG ROWS) AND CTEM SUB-PFTs (ALONG COLUMNS)
C
C     NEEDLE LEAF |  EVG       DCD       ---
C     BROAD LEAF  |  EVG   DCD-CLD   DCD-DRY
C     CROPS       |   C3        C4       ---
C     GRASSES     |   C3        C4       ---
C
C     ------------------------------------------------------------------
C
C     OMEGA, PARAMETER USED IN ALLOCATION FORMULAE
      DATA  OMEGA/0.80, 0.50, 0.00,
     &            0.80, 0.80, 0.80,
     &            0.05, 0.05, 0.00,
     &            1.00, 1.00, 0.00/
C
C     EPSILON LEAF, PARAMETER USED IN ALLOCATION FORMULAE
      DATA EPSILONL/0.20, 0.06, 0.00,
     &              0.35, 0.35, 0.25,
     &              0.80, 0.80, 0.00,
     &              0.01, 0.01, 0.00/
C
C     EPSILON STEM, PARAMETER USED IN ALLOCATION FORMULAE
      DATA EPSILONS/0.15, 0.05, 0.00,
     &              0.05, 0.10, 0.10,
     &              0.15, 0.15, 0.00,
     &              0.00, 0.00, 0.00/
C
C     EPSILON ROOT, PARAMETER USED IN ALLOCATION FORMULAE
      DATA EPSILONR/0.65, 0.89, 0.00,
     &              0.60, 0.55, 0.65,
     &              0.05, 0.05, 0.00,
     &              0.99, 0.99, 0.00/
C
C     CONSTANT ALLOCATION FRACTIONS IF NOT USING DYNAMIC ALLOCATION.
C     THE FOLLOWING VALUES HAVEN'T BEEN THOROUGHLY TESTED, AND USING
C     DYNAMIC ALLOCATION IS PREFERABLE.
      DATA CALEAF/0.275, 0.300, 0.000,
     &            0.200, 0.250, 0.250,
     &            0.400, 0.400, 0.000,
     &            0.450, 0.450, 0.000/
C
      DATA CASTEM/0.475, 0.450, 0.000,
     &            0.370, 0.400, 0.400,
     &            0.150, 0.150, 0.000,
     &            0.000, 0.000, 0.000/
C
      DATA CAROOT/0.250, 0.250, 0.000,
     &            0.430, 0.350, 0.350,
     &            0.450, 0.450, 0.000,
     &            0.550, 0.550, 0.000/
C
C     LOGICAL SWITCH FOR USING CONSTANT ALLOCATION FACTORS         
      DATA CONSALLO /.FALSE./     ! DEFAULT VALUE IS FALSE
C
C     MINIMUM ROOT:SHOOT RATIO MOSTLY FOR SUPPORT AND STABILITY
      DATA RTSRMIN /0.16, 0.16, 0.00,
     &              0.16, 0.16, 0.32,
     &              0.16, 0.16, 0.00,
     &              0.50, 0.50, 0.00/
C
C     ALLOCATION TO LEAVES DURING LEAF ONSET
      DATA ALDRLFON/1.00, 1.00, 0.00,
     &              1.00, 1.00, 0.50,
     &              1.00, 1.00, 0.00,
     &              1.00, 1.00, 0.00/
C
C     ZERO
      DATA ZERO/1E-12/
C
C     ---------------------------------------------------------------
C
      IF(ICC.NE.9)                            CALL XIT('ALLOCATE',-1)
C
C     INITIALIZE REQUIRED ARRAYS TO ZERO
C
      DO 140 J = 1,ICC
        DO 150 I = IL1, IL2
          AFRLEAF(ILG,ICC)=0.0    !ALLOCATION FRACTION FOR LEAVES
          AFRSTEM(ILG,ICC)=0.0    !ALLOCATION FRACTION FOR STEM
          AFRROOT(ILG,ICC)=0.0    !ALLOCATION FRACTION FOR ROOT
C
            ALEAF(ILG,ICC)=0.0    !TEMPORARY VARIABLE
            ASTEM(ILG,ICC)=0.0    !TEMPORARY VARIABLE
            AROOT(ILG,ICC)=0.0    !TEMPORARY VARIABLE
C
C                                 !AVERAGED OVER THE ROOT ZONE
          AVWILTSM(ILG,ICC)=0.0   !WILTING POINT SOIL MOISTURE
          AFIELDSM(ILG,ICC)=0.0   !FIELD CAPACITY SOIL MOISTURE
           AVTHLIQ(ILG,ICC)=0.0   !LIQUID SOIL MOISTURE CONTENT
C
          WTSTATUS(ILG,ICC)=0.0   !WATER STATUS
          LTSTATUS(ILG,ICC)=0.0   !LIGHT STATUS
           NSTATUS(ILG,ICC)=0.0   !NITROGEN STATUS, IF AND WHEN WE
C                                 !WILL HAVE N CYCLE IN THE MODEL
          WNSTATUS(ILG,ICC)=0.0   !MIN. OF WATER & N STATUS
C
          MNSTRTMS(ILG,ICC)=0.0   !MIN. (STEM+ROOT) BIOMASS NEEDED TO
C                                 !SUPPORT LEAVES
150     CONTINUE                  
140   CONTINUE
C
C     INITIALIZATION ENDS    
C
C     ------------------------------------------------------------------
C     ESTIMATE FIELD CAPACITY AND WILTING POINT SOIL MOISTURE CONTENTS
C
C     WILTING POINT CORRESPONDS TO MATRIC POTENTIAL OF 150 M
C     FIELD CAPACITY CORRESPONDS TO HYDARULIC CONDUCTIVITY OF
C     0.10 MM/DAY -> 1.157x1E-09 M/S
C
      DO 160 J = 1, IG
        DO 170 I = IL1, IL2
C
          PSISAT(I,J)= (10.0**(-0.0131*SAND(I,J)+1.88))/100.0
          GRKSAT(I,J)= (10.0**(0.0153*SAND(I,J)-0.884))*7.0556E-6
          THPOR(I,J) = (-0.126*SAND(I,J)+48.9)/100.0
          B(I,J)     = 0.159*CLAY(I,J)+2.91
C
          WILTSM(I,J) = (150./PSISAT(I,J))**(-1.0/B(I,J))
          WILTSM(I,J) = THPOR(I,J) * WILTSM(I,J)
C
          FIELDSM(I,J) = (1.157E-09/GRKSAT(I,J))**
     &      (1./(2.*B(I,J)+3.))
          FIELDSM(I,J) = THPOR(I,J) *  FIELDSM(I,J)
C
170     CONTINUE
160   CONTINUE
C
C
C     CALCULATE LIQUID SOIL MOISTURE CONTENT, AND WILTING AND FIELD CAPACITY 
C     SOIL MOISTURE CONTENTS AVERAGED OVER THE ROOT ZONE. NOTE THAT WHILE
C     THE SOIL MOISTURE CONTENT IS SAME UNDER THE ENTIRE GCM GRID CELL,
C     SOIL MOISTURE AVERAGED OVER THE ROOTING DEPTH IS DIFFERENT FOR EACH
C     PFT BECAUSE OF DIFFERENT FRACTION OF ROOTS PRESENT IN EACH SOIL LAYER.
C
      DO 200 J = 1, ICC
        DO 210 I = IL1, IL2
         IF (FCANCMX(I,J).GT.0.0) THEN 
         AVWILTSM(I,J) =  WILTSM(I,1)*RMATCTEM(I,J,1) +
     &                    WILTSM(I,2)*RMATCTEM(I,J,2) +
     &                    WILTSM(I,3)*RMATCTEM(I,J,3)
         AVWILTSM(I,J) = AVWILTSM(I,J) /
     &    (RMATCTEM(I,J,1)+RMATCTEM(I,J,2)+RMATCTEM(I,J,3))
C
         AFIELDSM(I,J) =  FIELDSM(I,1)*RMATCTEM(I,J,1) +
     &                    FIELDSM(I,2)*RMATCTEM(I,J,2) +
     &                    FIELDSM(I,3)*RMATCTEM(I,J,3)
         AFIELDSM(I,J) = AFIELDSM(I,J) /
     &    (RMATCTEM(I,J,1)+RMATCTEM(I,J,2)+RMATCTEM(I,J,3))
C
         AVTHLIQ(I,J)  =  THLIQ(I,1)*RMATCTEM(I,J,1) +
     &                    THLIQ(I,2)*RMATCTEM(I,J,2) +
     &                    THLIQ(I,3)*RMATCTEM(I,J,3)
         AVTHLIQ(I,J)  = AVTHLIQ(I,J) /
     &    (RMATCTEM(I,J,1)+RMATCTEM(I,J,2)+RMATCTEM(I,J,3))
         ENDIF
210     CONTINUE
200   CONTINUE
C
C     USING LIQUID SOIL MOISTURE CONTENT TOGETHER WITH WILTING AND FIELD 
C     CAPACITY SOIL MOISTURE CONTENTS AVERAGED OVER THE ROOT ZONE, FIND
C     SOIL WATER STATUS.
C
      DO 230 J = 1, ICC
        DO 240 I = IL1, IL2
         IF (FCANCMX(I,J).GT.0.0) THEN 
          IF(AVTHLIQ(I,J).LE.AVWILTSM(I,J))THEN
            WTSTATUS(I,J)=0.0
          ELSE IF(AVTHLIQ(I,J).GT.AVWILTSM(I,J).AND.
     &    AVTHLIQ(I,J).LT.AFIELDSM(I,J))THEN
            WTSTATUS(I,J)=(AVTHLIQ(I,J)-AVWILTSM(I,J))/
     &      (AFIELDSM(I,J)-AVWILTSM(I,J))
          ELSE
            WTSTATUS(I,J)=1.0
          ENDIF
         ENDIF
240     CONTINUE
230   CONTINUE
C
C     CALCULATE LIGHT STATUS AS A FUNCTION OF LAI AND LIGHT EXTINCTION
C     PARAMETER. FOR NOW SET NITROGEN STATUS EQUAL TO 1, WHICH MEANS 
C     NITROGEN IS NON-LIMITING.
C
      K1=0
      DO 250 J = 1, IC
       IF(J.EQ.1) THEN
         K1 = K1 + 1
       ELSE
         K1 = K1 + NOL2PFTS(J-1)
       ENDIF
       K2 = K1 + NOL2PFTS(J) - 1
       DO 255 M = K1, K2
        DO 260 I = IL1, IL2
          IF(J.EQ.4) THEN  ! GRASSES
            LTSTATUS(I,M)=MAX(0.0, (1.0-(AILCG(I,M)/4.0)) )
          ELSE             ! TREES AND CROPS
            LTSTATUS(I,M)=EXP(-KN(SORT(M))*AILCG(I,M))
          ENDIF
          NSTATUS(I,M) =1.0
260     CONTINUE 
255    CONTINUE
250   CONTINUE
C
C     ALLOCATION TO ROOTS IS DETERMINED BY MIN. OF WATER AND NITROGEN
C     STATUS
C
      DO 380 J = 1,ICC
        DO 390 I = IL1, IL2
         IF (FCANCMX(I,J).GT.0.0) THEN 
          WNSTATUS(I,J)=MIN(NSTATUS(I,J),WTSTATUS(I,J))
         ENDIF
390     CONTINUE
380   CONTINUE
C
C     NOW THAT WE KNOW WATER, LIGHT, AND NITROGEN STATUS WE CAN FIND
C     ALLOCATION FRACTIONS FOR LEAVES, STEM, AND ROOT COMPONENTS. NOTE
C     THAT ALLOCATION FORMULAE FOR GRASSES ARE DIFFERENT FROM THOSE
C     FOR TREES AND CROPS, SINCE THERE IS NO STEM COMPONENT IN GRASSES. 
C
      K1=0
      DO 400 J = 1, IC
       IF(J.EQ.1) THEN
         K1 = K1 + 1
       ELSE
         K1 = K1 + NOL2PFTS(J-1)
       ENDIF
       K2 = K1 + NOL2PFTS(J) - 1
       DO 405 M = K1, K2
        DO 410 I = IL1, IL2
          N = SORT(M)
          IF(J.LE.3)THEN           !TREES AND CROPS
            DENOM = 1.0 + (OMEGA(N)*( 2.0-LTSTATUS(I,M)-WNSTATUS(I,M) ))    
            AFRSTEM(I,M)=( EPSILONS(N)+OMEGA(N)*(1.0-LTSTATUS(I,M)) )/
     &                     DENOM  
            AFRROOT(I,M)=( EPSILONR(N)+OMEGA(N)*(1.0-WNSTATUS(I,M)) )/
     &                     DENOM  
            AFRLEAF(I,M)=  EPSILONL(N)/DENOM 
          ELSE IF (J.EQ.4) THEN     !GRASSES
            DENOM = 1.0 + (OMEGA(N)*( 1.0+LTSTATUS(I,M)-WNSTATUS(I,M) ))
            AFRLEAF(I,M)=( EPSILONL(N) + OMEGA(N)*LTSTATUS(I,M) ) /DENOM  
            AFRROOT(I,M)=( EPSILONR(N)+OMEGA(N)*(1.0-WNSTATUS(I,M)) )/
     &                     DENOM  
            AFRSTEM(I,M)= 0.0
          ENDIF
410     CONTINUE
405    CONTINUE
400   CONTINUE
C
C     IF USING CONSTANT ALLOCATION FACTORS THEN REPLACE THE DYNAMICALLY
C     CALCULATED ALLOCATION FRACTIONS.
C
      IF(CONSALLO)THEN
        DO 420 J = 1, ICC
          DO 421 I = IL1, IL2
           IF (FCANCMX(I,J).GT.0.0) THEN 
            AFRLEAF(I,J)=CALEAF(SORT(J))
            AFRSTEM(I,J)=CASTEM(SORT(J))
            AFRROOT(I,J)=CAROOT(SORT(J))
           ENDIF
421       CONTINUE
420     CONTINUE
      ENDIF
C
C     MAKE SURE ALLOCATION FRACTIONS ADD TO ONE
C
      DO 430 J = 1, ICC
        DO 440 I = IL1, IL2
         IF (FCANCMX(I,J).GT.0.0) THEN 
          IF( ABS(AFRSTEM(I,J)+AFRROOT(I,J)+AFRLEAF(I,J)-1.0).GT.ZERO ) 
     &    THEN  
           WRITE(6,2000) I,J,(AFRSTEM(I,J)+AFRROOT(I,J)+AFRLEAF(I,J))
2000       FORMAT(' AT (I) = (',I3,'), PFT=',I2,'  ALLOCATION FRACTIONS
     &NOT ADDING TO ONE. SUM  = ',F12.7)
          CALL XIT('ALLOCATE',-2)
          ENDIF
         ENDIF
440     CONTINUE
430   CONTINUE
C
C     THE ALLOCATION FRACTIONS CALCULATED ABOVE ARE OVERRIDDEN BY TWO
C     RULES. 
C
C     RULE 1 WHICH STATES THAT AT THE TIME OF LEAF ONSET WHICH CORRESPONDS 
C     TO LEAF STATUS EQUAL TO 1, MORE C IS ALLOCATED TO LEAVES SO 
C     THAT THEY CAN GROW ASAP. IN ADDITION WHEN LEAF STATUS IS 
C     "FALL/HARVEST" THEN NOTHING IS ALLOCATED TO LEAVES.
C
      K1=0
      DO 500 J = 1, IC
       IF(J.EQ.1) THEN
         K1 = K1 + 1
       ELSE
         K1 = K1 + NOL2PFTS(J-1)
       ENDIF
       K2 = K1 + NOL2PFTS(J) - 1
       DO 505 M = K1, K2
        DO 510 I = IL1, IL2
         IF (FCANCMX(I,M).GT.0.0) THEN 
          IF(LFSTATUS(I,M).EQ.1) THEN
            ALEAF(I,M)=ALDRLFON(SORT(M))
C
C           FOR GRASSES WE USE THE USUAL ALLOCATION EVEN AT LEAF ONSET
C
            IF(J.EQ.4)THEN
              ALEAF(I,M)=AFRLEAF(I,M)
            ENDIF
C
            DIFF  = AFRLEAF(I,M)-ALEAF(I,M)
            IF((AFRSTEM(I,M)+AFRROOT(I,M)).GT.ZERO)THEN 
              TERM1 = AFRSTEM(I,M)/(AFRSTEM(I,M)+AFRROOT(I,M))
              TERM2 = AFRROOT(I,M)/(AFRSTEM(I,M)+AFRROOT(I,M))
            ELSE
              TERM1 = 0.0
              TERM2 = 0.0
            ENDIF 
            ASTEM(I,M) = AFRSTEM(I,M) + DIFF*TERM1
            AROOT(I,M) = AFRROOT(I,M) + DIFF*TERM2
            AFRLEAF(I,M)=ALEAF(I,M)
            AFRSTEM(I,M)=MAX(0.0,ASTEM(I,M))
            AFRROOT(I,M)=MAX(0.0,AROOT(I,M))
          ELSE IF(LFSTATUS(I,M).EQ.3)THEN
            ALEAF(I,M)=0.0
            DIFF  = AFRLEAF(I,M)-ALEAF(I,M)
            IF((AFRSTEM(I,M)+AFRROOT(I,M)).GT.ZERO)THEN 
              TERM1 = AFRSTEM(I,M)/(AFRSTEM(I,M)+AFRROOT(I,M))
              TERM2 = AFRROOT(I,M)/(AFRSTEM(I,M)+AFRROOT(I,M))
            ELSE
              TERM1 = 0.0
              TERM2 = 0.0
            ENDIF 
            ASTEM(I,M) = AFRSTEM(I,M) + DIFF*TERM1
            AROOT(I,M) = AFRROOT(I,M) + DIFF*TERM2
            AFRLEAF(I,M)=ALEAF(I,M)
            AFRSTEM(I,M)=ASTEM(I,M)
            AFRROOT(I,M)=AROOT(I,M)
          ENDIF
         ENDIF
510     CONTINUE
505    CONTINUE
500   CONTINUE
C
C
C     RULE 2 OVERRIDES RULE 1 ABOVE AND MAKES SURE THAT WE DO NOT ALLOW THE 
C     AMOUNT OF LEAVES ON TREES AND CROPS (I.E. PFTs 1 TO 7) TO EXCEED 
C     AN AMOUNT SUCH THAT THE REMAINING WOODY BIOMASS CANNOT SUPPORT. 
C     IF THIS HAPPENS, ALLOCATION TO LEAVES IS REDUCED AND MOST NPP 
C     IS ALLOCATED TO STEM AND ROOTS, IN A PROPORTION BASED ON CALCULATED 
C     AFRSTEM AND AFRROOT. FOR GRASSES THIS RULE ESSENTIALLY CONSTRAINS 
C     THE ROOT:SHOOT RATIO, MEANING THAT THE MODEL GRASSES CAN'T HAVE 
C     LOTS OF LEAVES WITHOUT HAVING A REASONABLE AMOUNT OF ROOTS.
C
      DO 530 J = 1, ICC
        N=SORT(J)
        DO 540 I = IL1, IL2
         IF (FCANCMX(I,J).GT.0.0) THEN 
C         FIND MIN. STEM+ROOT BIOMASS NEEDED TO SUPPORT THE GREEN LEAF 
C         BIOMASS.
          MNSTRTMS(I,J)=ETA(N)*(GLEAFMAS(I,J)**KAPPA(N))
C
          IF( (STEMMASS(I,J)+ROOTMASS(I,J)).LT.MNSTRTMS(I,J)) THEN   
            IF( (AFRSTEM(I,J)+AFRROOT(I,J)).GT.ZERO ) THEN
              ALEAF(I,J)=MIN(0.05,AFRLEAF(I,J))
              DIFF  = AFRLEAF(I,J)-ALEAF(I,J)
              TERM1 = AFRSTEM(I,J)/(AFRSTEM(I,J)+AFRROOT(I,J))
              TERM2 = AFRROOT(I,J)/(AFRSTEM(I,J)+AFRROOT(I,J))
              ASTEM(I,J) = AFRSTEM(I,J) + DIFF*TERM1
              AROOT(I,J) = AFRROOT(I,J) + DIFF*TERM2
              AFRLEAF(I,J)=ALEAF(I,J)
              AFRSTEM(I,J)=ASTEM(I,J)
              AFRROOT(I,J)=AROOT(I,J)
            ELSE
              ALEAF(I,J)=MIN(0.05,AFRLEAF(I,J))
              DIFF  = AFRLEAF(I,J)-ALEAF(I,J)
              AFRLEAF(I,J)=ALEAF(I,J)
              AFRSTEM(I,J)=DIFF*0.5 + AFRSTEM(I,J)
              AFRROOT(I,J)=DIFF*0.5 + AFRROOT(I,J)
            ENDIF
          ENDIF
         ENDIF
540     CONTINUE
530   CONTINUE
C
C     MAKE SURE THAT ROOT:SHOOT RATIO IS AT LEAST EQUAL TO RTSRMIN. IF NOT
C     ALLOCATE MORE TO ROOT AND DECREASE ALLOCATION TO STEM.
C
      DO 541 J = 1, ICC
        N=SORT(J)
        DO 542 I = IL1, IL2
         IF (FCANCMX(I,J).GT.0.0) THEN 
          IF( (STEMMASS(I,J)+GLEAFMAS(I,J)).GT.0.05)THEN
            IF( (ROOTMASS(I,J)/(STEMMASS(I,J)+GLEAFMAS(I,J))).
     &      LT.RTSRMIN(N) ) THEN  
              ASTEM(I,J)=MIN(0.05,AFRSTEM(I,J))
              DIFF = AFRSTEM(I,J)-ASTEM(I,J)
              AFRSTEM(I,J)=AFRSTEM(I,J)-DIFF
              AFRROOT(I,J)=AFRROOT(I,J)+DIFF
            ENDIF
          ENDIF
         ENDIF
542     CONTINUE
541   CONTINUE
C
C     FINALLY CHECK IF ALL ALLOCATION FRACTIONS ARE POSITIVE AND CHECK
C     AGAIN THEY ALL ADD TO ONE.
C
      DO 550 J = 1, ICC
        DO 560 I = IL1, IL2
         IF (FCANCMX(I,J).GT.0.0) THEN 
          IF( (AFRLEAF(I,J).LT.0.0).OR.(AFRSTEM(I,J).LT.0.0).OR.
     &    (AFRROOT(I,J).LT.0.0))THEN
           WRITE(6,2200) I,J
2200       FORMAT(' AT (I) = (',I3,'), PFT=',I2,'  ALLOCATION FRACTIONS 
     & NEGATIVE') 
           WRITE(6,2100)AFRLEAF(I,J),AFRSTEM(I,J),AFRROOT(I,J)
2100       FORMAT(' ALEAF = ',F12.9,' ASTEM = ',F12.9,' AROOT = ',F12.9)
           CALL XIT('ALLOCATE',-3)
          ENDIF
         ENDIF
560     CONTINUE
550   CONTINUE
C
      DO 580 J = 1, ICC
        DO 590 I = IL1, IL2
         IF (FCANCMX(I,J).GT.0.0) THEN 
          IF( ABS(AFRSTEM(I,J)+AFRROOT(I,J)+AFRLEAF(I,J)-1.0).GT.ZERO ) 
     &    THEN  
           WRITE(6,2300) I,J,(AFRSTEM(I,J)+AFRROOT(I,J)+AFRLEAF(I,J))
2300       FORMAT(' AT (I) = (',I3,'), PFT=',I2,'  ALLOCATION FRACTIONS
     &NOT ADDING TO ONE. SUM  = ',F12.7)
           CALL XIT('ALLOCATE',-4)
          ENDIF
         ENDIF
590     CONTINUE
580   CONTINUE
C
      RETURN
      END

