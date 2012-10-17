      SUBROUTINE COMPETITION_UNMAP(NLAT, NMOS, ILG, IL1, IL2, 
     1                           NML, ILMOS, JLMOS, ICC, IC, NOL2PFTS,
     2                          FCANCMX_CMP,  NPPVEG_CMP,GEREMORT_CMP,
     3                         INTRMORT_CMP,GLEAFMAS_CMP,BLEAFMAS_CMP,
     4                         STEMMASS_CMP,ROOTMASS_CMP,LITRMASS_CMP,
     5                         SOILCMAS_CMP,PFTEXIST_CMP,  LAMBDA_CMP,
     6                          BMASVEG_CMP, BURNVEG_CMP,ADD2ALLO_CMP,
     7                               CC_CMP,      MM_CMP,  FCANMX_CMP,
     8                         GRCLAREA_CMP,VGBIOMAS_CMP,
     9                         GAVGLTMS_CMP,GAVGSCMS_CMP,
     1                               TA_CMP,  PRECIP_CMP,  NETRAD_CMP, 
     2                            TCURM_CMP,SRPCURYR_CMP,DFTCURYR_CMP,
     3                           TMONTH_CMP,ANPCPCUR_CMP, ANPECUR_CMP, 
     4                          GDD5CUR_CMP,SURMNCUR_CMP,DEFMNCUR_CMP,
     5                         SRPLSCUR_CMP,DEFCTCUR_CMP,  TWARMM_CMP, 
     6                           TCOLDM_CMP,    GDD5_CMP, ARIDITY_CMP,
     7                         SRPLSMON_CMP,DEFCTMON_CMP,ANNDEFCT_CMP,
     8                         ANNSRPLS_CMP,  ANNPCP_CMP,ANPOTEVP_CMP,
C    ------------------- INPUTS ABOVE THIS LINE ----------------------
     A                            NETRADROW,
C    ------------------- SAVED FOR INTERMEDIATE ABOVE THIS LINE ------
     a                              FAREGAT, FCANCMX,  NPPVEG,GEREMORT,  
     b                             INTRMORT,GLEAFMAS,BLEAFMAS,STEMMASS,
     c                             ROOTMASS,LITRMASS,SOILCMAS,
     d                             PFTEXIST,  LAMBDA, BMASVEG, BURNVEG,
     e                             ADD2ALLO,      CC,      MM,  FCANMX,
     f                             GRCLAREA,VGBIOMAS,GAVGLTMS,GAVGSCMS,
     g                             TA,PRECIP, NETRAD,   TCURM,SRPCURYR,
     h                             DFTCURYR,  TMONTH,ANPCPCUR, ANPECUR, 
     i                              GDD5CUR,SURMNCUR,DEFMNCUR,SRPLSCUR,  
     j                             DEFCTCUR,  TWARMM,  TCOLDM,    GDD5, 
     k                              ARIDITY,SRPLSMON,DEFCTMON,ANNDEFCT,
     l                             ANNSRPLS,  ANNPCP,ANPOTEVP)
C    ------------------- UPDATES ABOVE THIS LINE ---------------------
C
C
C               CANADIAN TERRESTRIAL ECOSYSTEM MODEL (CTEM) V1.1
C                UNMAPPING FOR COMPETITION SUBROUTINES 
C
C    28 AUG 2012 - THIS SUBROUTINE UNMAP THE PFT FRACTIONS IN 
C    Y. PENG       EACH GRID CELL BACK TO THE ONLY PFT IN EACH 
C                  MOSAIC AFTER THE COMPETITION CALCULATION IS DONE
C
C
C                  INPUT:        ARRAY_CMP(NLAT,ICC)
C                    | 
C                    | UNMAPPING      
C                    V
C                  INTERMEDIATE: ARRAYROW(NLAT,NMOS,ICC)
C                    | 
C                    | GATHERING
C                    V
C                  OUTPUT(UPDATES): ARRAY(ILG,ICC)
C
C                  ARRAY_CMP: MAPPED ARRAY USED FOR COMPETITION
C
C    -----------------------------------------------------------------
C
C    INDICES
C
C     NLAT    - MAX. NUMBER OF GRID CELLS IN THE LATITUDE CIRCLE, WHICH
C               IS PRESCRIBED IN RUNCLASS35CTEM.F
C     NMOS    - MAX. NUMBER OF MOSAIC TILES IN EACH LATITUDINAL GRID CELL, 
C               WHICH IS PRESCRIBED IN RUNCLASS35CTEM.F
C     ILG     - ILG=NLAT*NMOS
C     IL1,IL2 - IL1=1, IL2=ILG
C     NML     - TOTAL NUMBER OF MOSAIC TILES WITH PFT FRACTIONS LARGER THAN 1,
C               SEE GATPREP.F
C     ILMOS   - INDICES FOR SCATTERING, SEE GATPREP.F
C     JLMOS   - INDICES FOR SCATTERING, SEE GATPREP.F
C     ICC     - NUMBER OF PFTs FOR USE BY CTEM, CURRENTLY 10
C     IC      - NUMBER OF PFTs FOR USE BY CLASS, CURRENTLY 4
C
C    INPUTS
C
C     FCANCMX_CMP - FRACTIONAL COVERAGE OF CTEM's 10 PFTs IN EACH 
C                   LATITUDINAL GRID CELL
C     NPPVEG_CMP  - NPP FOR EACH PFT TYPE OF VEGETATED AREA IN EACH 
C                   LATITUDINAL GRID CELL
C     GEREMORT_CMP- GROWTH RELATED MORTALITY IN EACH LATITUDINAL GRID CELL
C     INTRMORT_CMP- INTRINSIC (AGE RELATED) MORTALITY IN EACH LATITUDINAL GRID CELL
C     GLEAFMAS_CMP- GREEN LEAF MASS FOR EACH OF THE 10 CTEM PFTs IN EACH 
C                   LATITUDINAL GRID CELL
C     BLEAFMAS_CMP- BROWN LEAF MASS FOR EACH OF THE 10 CTEM PFTs IN EACH 
C                   LATITUDINAL GRID CELL
C     STEMMASS_CMP- STEM MASS FOR EACH OF THE 10 CTEM PFTs IN EACH 
C                   LATITUDINAL GRID CELL
C     ROOTMASS_CMP- ROOT MASS FOR EACH OF THE 10 CTEM PFTs IN EACH 
C                   LATITUDINAL GRID CELL
C     LITRMASS_CMP- LITTER MASS FOR EACH OF THE 10 CTEM PFTs + BARE, IN EACH 
C                   LATITUDINAL GRID CELL
C     SOILCMAS_CMP- SOIL CARBON MASS FOR EACH OF THE 10 CTEM PFTs + BARE, IN EACH 
C                   LATITUDINAL GRID CELL 
C     PFTEXIST_CMP- BINARY ARRAY INDICATING PFTs EXIST (=1) OR NOT (=0) IN EACH 
C                   LATITUDINAL GRID CELL 
C     LAMBDA_CMP  - FRACTION OF NPP THAT IS USED FOR HORIZONTAL EXPANSION IN EACH 
C                   LATITUDINAL GRID CELL 
C     BMASVEG_CMP - TOTAL (GLEAF + STEM + ROOT) BIOMASS FOR EACH CTEM PFT, Kg C/M2 IN EACH 
C                   LATITUDINAL GRID CELL 
C     BURNVEG_CMP - AREAS BURNED, KM^2, FOR 10 CTEM PFTs IN EACH 
C                   LATITUDINAL GRID CELL 
C     ADD2ALLO_CMP- NPP KG C/M2.DAY IN EACH LATITUDINAL GRID CELL THAT IS USED 
C                   FOR EXPANSION AND SUBSEQUENTLY ALLOCATED TO LEAVES, STEM,  
C                   AND ROOT VIA THE ALLOCATION PART OF THE MODEL.
C     CC,MM_CMP   - COLONIZATION RATE & MORTALITY RATE IN EACH 
C                   LATITUDINAL GRID CELL  
C     FCANMX_CMP  - FRACTIONAL COVERAGE OF CLASS' 4 PFTs IN EACH 
C                   LATITUDINAL GRID CELL 
C     GRCLAREA_CMP- AREA OF THE GRID CELL, KM^2
C     VGBIOMAS_CMP- GRID AVERAGED VEGETATION BIOMASS, Kg C/M2
C     GAVGLTMS_CMP- GRID AVERAGED LITTER MASS, Kg C/M2
C     GAVGSCMS_CMP- GRID AVERAGED SOIL C MASS, Kg C/M2
C
C     TA_CMP      - MEAN DAILY TEMPERATURE (K) IN EACH LATITUDINAL GRID CELL 
C     PRECIP_CMP  - DAILY PRECIPITATION (MM/DAY) IN EACH LATITUDINAL GRID CELL 
C     NETRAD_CMP  - DAILY NET RADIATION (W/M2) IN EACH LATITUDINAL GRID CELL 
C     TCURM_CMP   - TEMPERATURE OF THE CURRENT MONTH (C) IN EACH LATITUDINAL GRID CELL 
C     SRPCURYR_CMP- WATER SURPLUS FOR THE CURRENT YEAR IN EACH LATITUDINAL GRID CELL 
C     DFTCURYR_CMP- WATER DEFICIT FOR THE CURRENT YEAR IN EACH LATITUDINAL GRID CELL 
C     TMONTH_CMP  - MONTHLY TEMPERATURES IN EACH LATITUDINAL GRID CELL 
C     ANPCPCUR_CMP- ANNUAL PRECIPITATION FOR CURRENT YEAR (MM) IN EACH LATITUDINAL GRID CELL  
C     ANPECUR_CMP - ANNUAL POTENTIAL EVAPORATION FOR CURRENT YEAR (MM) IN EACH 
C                   LATITUDINAL GRID CELL 
C     GDD5CUR_CMP - GROWING DEGREE DAYS ABOVE 5 C FOR CURRENT YEAR IN EACH 
C                   LATITUDINAL GRID CELL 
C     SURMNCUR_CMP- NUMBER OF MONTHS WITH SURPLUS WATER FOR CURRENT YEAR IN EACH 
C                   LATITUDINAL GRID CELL 
C     DEFMNCUR_CMP- NUMBER OF MONTHS WITH WATER DEFICIT FOR CURRENT YEAR IN EACH 
C                   LATITUDINAL GRID CELL 
C     SRPLSCUR_CMP- WATER SURPLUS FOR THE CURRENT MONTH IN EACH LATITUDINAL GRID CELL  
C     DEFCTCUR_CMP- WATER DEFICIT FOR THE CURRENT MONTH IN EACH LATITUDINAL GRID CELL 
C     TWARMM_CMP  - TEMPERATURE OF THE WARMEST MONTH (C) IN EACH LATITUDINAL GRID CELL 
C     TCOLDM_CMP  - TEMPERATURE OF THE COLDEST MONTH (C) IN EACH LATITUDINAL GRID CELL 
C     GDD5_CMP    - GROWING DEGREE DAYS ABOVE 5 C IN EACH LATITUDINAL GRID CELL 
C     ARIDITY_CMP - ARIDITY INDEX, RATIO OF POTENTIAL EVAPORATION TO
C                   PRECIPITATION IN EACH LATITUDINAL GRID CELL 
C     SRPLSMON_CMP- NUMBER OF MONTHS IN A YEAR WITH SURPLUS WATER I.E.
C                   PRECIPITATION MORE THAN POTENTIAL EVAPORATION IN EACH 
C                   LATITUDINAL GRID CELL 
C     DEFCTMON_CMP- NUMBER OF MONTHS IN A YEAR WITH WATER DEFICIT I.E.
C                   PRECIPITATION LESS THAN POTENTIAL EVAPORATION IN EACH 
C                   LATITUDINAL GRID CELL 
C     ANNDEFCT_CMP- ANNUAL WATER DEFICIT (MM) IN EACH LATITUDINAL GRID CELL   
C     ANNSRPLS_CMP- ANNUAL WATER SURPLUS (MM) IN EACH LATITUDINAL GRID CELL 
C     ANNPCP_CMP  - ANNUAL PRECIPITATION (MM) IN EACH LATITUDINAL GRID CELL 
C     ANPOTEVP_CMP- ANNUAL POTENTIAL EVAPORATION (MM) IN EACH LATITUDINAL GRID CELL 
C
C    UPDATES
C 
C     FAREGAT - FRACTIONAL COVERAGE OF EACH CTEM PFT IN EACH MOSAIC TILE   
C     FCANCMX - FRACTIONAL COVERAGE OF CTEM's 10 PFTs IN EACH MOSAIC 
C     NPPVEG  - NPP FOR EACH PFT TYPE /M2 OF VEGETATED AREA [u-MOL CO2-C/M2.SEC]
C     GEREMORT- GROWTH RELATED MORTALITY (1/DAY)
C     INTRMORT- INTRINSIC (AGE RELATED) MORTALITY (1/DAY)
C     GLEAFMAS- GREEN LEAF MASS FOR EACH OF THE 10 CTEM PFTs, Kg C/M2
C     BLEAFMAS- BROWN LEAF MASS FOR EACH OF THE 10 CTEM PFTs, Kg C/M2
C     STEMMASS- STEM MASS FOR EACH OF THE 10 CTEM PFTs, Kg C/M2
C     ROOTMASS- ROOT MASS FOR EACH OF THE 10 CTEM PFTs, Kg C/M2
C     LITRMASS- LITTER MASS FOR EACH OF THE 10 CTEM PFTs + BARE, Kg C/M2
C     SOILCMAS- SOIL CARBON MASS FOR EACH OF THE 10 CTEM PFTs + BARE, Kg C/M2
C     PFTEXIST- BINARY ARRAY INDICATING PFTs EXIST (=1) OR NOT (=0)
C     LAMBDA  - FRACTION OF NPP THAT IS USED FOR HORIZONTAL EXPANSION
C     BMASVEG - TOTAL (GLEAF + STEM + ROOT) BIOMASS FOR EACH CTEM PFT, Kg C/M2
C     BURNVEG - AREAS BURNED, KM^2, FOR 10 CTEM PFTs
C     ADD2ALLO- NPP KG C/M2.DAY THAT IS USED FOR EXPANSION AND
C               SUBSEQUENTLY ALLOCATED TO LEAVES, STEM, AND ROOT VIA 
C               THE ALLOCATION PART OF THE MODEL.
C     CC,MM   - COLONIZATION RATE & MORTALITY RATE 
C     FCANMX  - FRACTIONAL COVERAGE OF CLASS' 4 PFTs
C     GRCLAREA- AREA OF THE GRID CELL, KM^2
C     VGBIOMAS- GRID AVERAGED VEGETATION BIOMASS, Kg C/M2
C     GAVGLTMS- GRID AVERAGED LITTER MASS, Kg C/M2
C     GAVGSCMS- GRID AVERAGED SOIL C MASS, Kg C/M2
C
C     TA      - MEAN DAILY TEMPERATURE, K
C     PRECIP  - DAILY PRECIPITATION (MM/DAY)
C     NETRAD  - DAILY NET RADIATION (W/M2)
C     TCURM   - TEMPERATURE OF THE CURRENT MONTH (C)
C     SRPCURYR- WATER SURPLUS FOR THE CURRENT YEAR
C     DFTCURYR- WATER DEFICIT FOR THE CURRENT YEAR
C     TMONTH  - MONTHLY TEMPERATURES
C     ANPCPCUR- ANNUAL PRECIPITATION FOR CURRENT YEAR (MM)
C     ANPECUR - ANNUAL POTENTIAL EVAPORATION FOR CURRENT YEAR (MM)
C     GDD5CUR - GROWING DEGREE DAYS ABOVE 5 C FOR CURRENT YEAR
C     SURMNCUR- NUMBER OF MONTHS WITH SURPLUS WATER FOR CURRENT YEAR
C     DEFMNCUR- NUMBER OF MONTHS WITH WATER DEFICIT FOR CURRENT YEAR
C     SRPLSCUR- WATER SURPLUS FOR THE CURRENT MONTH 
C     DEFCTCUR- WATER DEFICIT FOR THE CURRENT MONTH
C     TWARMM  - TEMPERATURE OF THE WARMEST MONTH (C)
C     TCOLDM  - TEMPERATURE OF THE COLDEST MONTH (C)
C     GDD5    - GROWING DEGREE DAYS ABOVE 5 C
C     ARIDITY - ARIDITY INDEX, RATIO OF POTENTIAL EVAPORATION TO
C               PRECIPITATION
C     SRPLSMON- NUMBER OF MONTHS IN A YEAR WITH SURPLUS WATER I.E.
C               PRECIPITATION MORE THAN POTENTIAL EVAPORATION
C     DEFCTMON- NUMBER OF MONTHS IN A YEAR WITH WATER DEFICIT I.E.
C               PRECIPITATION LESS THAN POTENTIAL EVAPORATION
C     ANNDEFCT- ANNUAL WATER DEFICIT (MM) 
C     ANNSRPLS- ANNUAL WATER SURPLUS (MM)
C     ANNPCP  - ANNUAL PRECIPITATION (MM)
C     ANPOTEVP- ANNUAL POTENTIAL EVAPORATION (MM)
C
      IMPLICIT NONE
C
      INTEGER I,M,L,K,ILG,IL1,IL2,NLAT,NMOS,ICC,IC,MN,
     1        NML,ILMOS(ILG),JLMOS(ILG),NOL2PFTS(IC)
C
C--------INPUT ARRAYS FOR UNMAPPING------------------------------------------
C
      REAL  FCANCMX_CMP(NLAT,ICC), NPPVEG_CMP(NLAT,ICC),
     1      GEREMORT_CMP(NLAT,ICC),INTRMORT_CMP(NLAT,ICC),
     2      GLEAFMAS_CMP(NLAT,ICC),BLEAFMAS_CMP(NLAT,ICC),
     3      STEMMASS_CMP(NLAT,ICC),ROOTMASS_CMP(NLAT,ICC),
     4      LITRMASS_CMP(NLAT,ICC+1),SOILCMAS_CMP(NLAT,ICC+1),
     5      LAMBDA_CMP(NLAT,ICC),
     6      BMASVEG_CMP(NLAT,ICC),   BURNVEG_CMP(NLAT,ICC),
     7      ADD2ALLO_CMP(NLAT,ICC),  CC_CMP(NLAT,ICC),MM_CMP(NLAT,ICC),
     8      FCANMX_CMP(NLAT,IC),     
     9      GRCLAREA_CMP(NLAT),      VGBIOMAS_CMP(NLAT),    
     1      GAVGLTMS_CMP(NLAT),      GAVGSCMS_CMP(NLAT)
      INTEGER PFTEXIST_CMP(NLAT,ICC)
      REAL  TA_CMP(NLAT),       PRECIP_CMP(NLAT),  NETRAD_CMP(NLAT), 
     1      TCURM_CMP(NLAT),    SRPCURYR_CMP(NLAT),DFTCURYR_CMP(NLAT),
     2      TMONTH_CMP(12,NLAT),ANPCPCUR_CMP(NLAT),ANPECUR_CMP(NLAT), 
     3      GDD5CUR_CMP(NLAT),  SURMNCUR_CMP(NLAT),DEFMNCUR_CMP(NLAT),
     4      SRPLSCUR_CMP(NLAT), DEFCTCUR_CMP(NLAT),TWARMM_CMP(NLAT), 
     5      TCOLDM_CMP(NLAT),   GDD5_CMP(NLAT),    ARIDITY_CMP(NLAT),
     6      SRPLSMON_CMP(NLAT), DEFCTMON_CMP(NLAT),ANNDEFCT_CMP(NLAT),
     7      ANNSRPLS_CMP(NLAT), ANNPCP_CMP(NLAT),  ANPOTEVP_CMP(NLAT)
C
C--------INTERMEDIATE ARRAYS FOR UNMAPPING-----------------------------------
C
      REAL  FCANCMXROW(NLAT,NMOS,ICC), NPPVEGROW(NLAT,NMOS,ICC),
     1      GEREMORTROW(NLAT,NMOS,ICC),INTRMORTROW(NLAT,NMOS,ICC),
     2      GLEAFMASROW(NLAT,NMOS,ICC),BLEAFMASROW(NLAT,NMOS,ICC),
     3      STEMMASSROW(NLAT,NMOS,ICC),ROOTMASSROW(NLAT,NMOS,ICC),
     4      LITRMASSROW(NLAT,NMOS,ICC+1),SOILCMASROW(NLAT,NMOS,ICC+1),
     5      LAMBDAROW(NLAT,NMOS,ICC),
     6      BMASVEGROW(NLAT,NMOS,ICC),   BURNVEGROW(NLAT,NMOS,ICC),
     7      ADD2ALLOROW(NLAT,NMOS,ICC),  CCROW(NLAT,NMOS,ICC),
     8      MMROW(NLAT,NMOS,ICC),        FCANMXROW(NLAT,NMOS,IC),
     9      FAREROW(NLAT,NMOS),
     1      GRCLAREAROW(NLAT,NMOS),      VGBIOMASROW(NLAT,NMOS),    
     2      GAVGLTMSROW(NLAT,NMOS),      GAVGSCMSROW(NLAT,NMOS)
      INTEGER PFTEXISTROW(NLAT,NMOS,ICC)      
C--------THESE INTERMEDIATE ARRAYS WERE TRANSFERRED FROM MAPPING------------\\
      REAL  NETRADROW(NLAT,NMOS)
C---------------------------------------------------------------------------//
      REAL  TAROW(NLAT,NMOS),       PRECIPROW(NLAT,NMOS),
     1      TCURMROW(NLAT,NMOS),
     2      SRPCURYRROW(NLAT,NMOS), DFTCURYRROW(NLAT,NMOS),
     3      TMONTHROW(12,NLAT,NMOS),ANPCPCURROW(NLAT,NMOS), 
     4      ANPECURROW(NLAT,NMOS),  GDD5CURROW(NLAT,NMOS), 
     5      SURMNCURROW(NLAT,NMOS), DEFMNCURROW(NLAT,NMOS),
     6      SRPLSCURROW(NLAT,NMOS), DEFCTCURROW(NLAT,NMOS), 
     7      TWARMMROW(NLAT,NMOS),   TCOLDMROW(NLAT,NMOS),  
     8      GDD5ROW(NLAT,NMOS),     ARIDITYROW(NLAT,NMOS),
     9      SRPLSMONROW(NLAT,NMOS), DEFCTMONROW(NLAT,NMOS), 
     1      ANNDEFCTROW(NLAT,NMOS), ANNSRPLSROW(NLAT,NMOS),
     2      ANNPCPROW(NLAT,NMOS),   ANPOTEVPROW(NLAT,NMOS)
C
C--------UPDATED ARRAYS AFTER UNMAPPING--------------------------------------
C
      REAL  FCANCMX(ILG,ICC), FAREGAT(ILG),
     1      NPPVEG(ILG,ICC),  GEREMORT(ILG,ICC),  
     2      INTRMORT(ILG,ICC),GLEAFMAS(ILG,ICC),
     3      BLEAFMAS(ILG,ICC),STEMMASS(ILG,ICC),
     4      ROOTMASS(ILG,ICC),LITRMASS(ILG,ICC+1),
     5      SOILCMAS(ILG,ICC+1),
     6      LAMBDA(ILG,ICC),
     7      BMASVEG(ILG,ICC), BURNVEG(ILG,ICC),
     8      ADD2ALLO(ILG,ICC),CC(ILG,ICC),MM(ILG,ICC),
     9      FCANMX(ILG,IC),   GRCLAREA(ILG),
     1      VGBIOMAS(ILG),    GAVGLTMS(ILG),
     2      GAVGSCMS(ILG)
      INTEGER PFTEXIST(ILG,ICC)
      REAL  TA(ILG),        PRECIP(ILG),   NETRAD(ILG),
     1      TCURM(ILG),     SRPCURYR(ILG), DFTCURYR(ILG),
     2      TMONTH(12,ILG), ANPCPCUR(ILG), ANPECUR(ILG),
     3      GDD5CUR(ILG),   SURMNCUR(ILG), DEFMNCUR(ILG),
     4      SRPLSCUR(ILG),  DEFCTCUR(ILG), TWARMM(ILG),
     5      TCOLDM(ILG),    GDD5(ILG),     ARIDITY(ILG),
     6      SRPLSMON(ILG),  DEFCTMON(ILG), ANNDEFCT(ILG),
     7      ANNSRPLS(ILG),  ANNPCP(ILG),   ANPOTEVP(ILG) 
C
C--------INTERNAL ARRAYS-----------------------------------------------------
C
      INTEGER MCOUNT, MCOUNT1,MCOUNT2
      REAL TPFTFRAC(NLAT)
      LOGICAL BAREEXIST(NLAT)
C
C     ------------------------------------------------------------------
C                           PARAMETERS USED 
C
C     NOTE THE STRUCTURE OF PARAMETER VECTORS WHICH CLEARLY SHOWS THE
C     CLASS PFTs (ALONG ROWS) AND CTEM SUB-PFTs (ALONG COLUMNS)
C
C     NEEDLE LEAF |  EVG1      EVG2      DCD
C     BROAD LEAF  |  EVG   DCD-CLD   DCD-DRY
C     CROPS       |   C3        C4       ---
C     GRASSES     |   C3        C4       ---
C
C     ---------------------------------------------------------------
C
      IF(ICC.NE.9)                     CALL XIT('COMPETE_MAP',-1)
      IF(IC.NE.4)                       CALL XIT('COMPETE_MAP',-2)
C
C     INITIALIZATION
C
      DO I=1,NLAT
       TPFTFRAC(I)=0.0
       DO M=1,NMOS
        DO L=1,ICC
         FCANCMXROW(I,M,L) = 0.0
         NPPVEGROW(I,M,L)  = 0.0
         GEREMORTROW(I,M,L)= 0.0
         INTRMORTROW(I,M,L)= 0.0
         GLEAFMASROW(I,M,L)= 0.0
         BLEAFMASROW(I,M,L)= 0.0
         STEMMASSROW(I,M,L)= 0.0
         ROOTMASSROW(I,M,L)= 0.0
         PFTEXISTROW(I,M,L)= 0
         LAMBDAROW(I,M,L)  = 0.0
         BMASVEGROW(I,M,L) = 0.0
         BURNVEGROW(I,M,L) = 0.0
         ADD2ALLOROW(I,M,L)= 0.0
         CCROW(I,M,L)      = 0.0
         MMROW(I,M,L)      = 0.0
        ENDDO 
        DO L=1,ICC+1
         LITRMASSROW(I,M,L)= 0.0
         SOILCMASROW(I,M,L)= 0.0
        ENDDO
        DO L=1,IC
         FCANMXROW(I,M,L)  = 0.0            
        ENDDO
         FAREROW(I,M)      = 0.0
         GRCLAREAROW(I,M)  = 0.0
         VGBIOMASROW(I,M)  = 0.0
         GAVGLTMSROW(I,M)  = 0.0
         GAVGSCMSROW(I,M)  = 0.0  
         TAROW(I,M)        = 0.0  
         PRECIPROW(I,M)    = 0.0  
C       NOTE THAT NETRADROW IS NOT INITIALIZED HERE BECAUSE IT WAS SAVED ALREADY
         TCURMROW(I,M)     = 0.0  
         SRPCURYRROW(I,M)  = 0.0  
         DFTCURYRROW(I,M)  = 0.0  
         DO MN=1,12
         TMONTHROW(MN,I,M) = 0.0
         ENDDO
         ANPCPCURROW(I,M)  = 0.0  
         ANPECURROW(I,M)   = 0.0  
         GDD5CURROW(I,M)   = 0.0  
         SURMNCURROW(I,M)  = 0.0  
         DEFMNCURROW(I,M)  = 0.0  
         SRPLSCURROW(I,M)  = 0.0    
         DEFCTCURROW(I,M)  = 0.0  
         TWARMMROW(I,M)    = 0.0  
         TCOLDMROW(I,M)    = 0.0  
         GDD5ROW(I,M)      = 0.0   
         ARIDITYROW(I,M)   = 0.0  
         SRPLSMONROW(I,M)  = 0.0  
         DEFCTMONROW(I,M)  = 0.0  
         ANNDEFCTROW(I,M)  = 0.0  
         ANNSRPLSROW(I,M)  = 0.0  
         ANNPCPROW(I,M)    = 0.0  
         ANPOTEVPROW(I,M)  = 0.0  
       ENDDO
      ENDDO
C
      DO I=1,ILG
       DO L=1,ICC
        FCANCMX(I,L) = 0.0
        NPPVEG(I,L)  = 0.0
        GEREMORT(I,L)= 0.0
        INTRMORT(I,L)= 0.0
        GLEAFMAS(I,L)= 0.0
        BLEAFMAS(I,L)= 0.0
        STEMMASS(I,L)= 0.0
        ROOTMASS(I,L)= 0.0
        PFTEXIST(I,L)= 0
        LAMBDA(I,L)  = 0.0
        BMASVEG(I,L) = 0.0
        BURNVEG(I,L) = 0.0
        ADD2ALLO(I,L)= 0.0
        CC(I,L)      = 0.0
        MM(I,L)      = 0.0
       ENDDO
       DO L=1,ICC+1
        LITRMASS(I,L)= 0.0
        SOILCMAS(I,L)= 0.0
       ENDDO
       DO L=1,IC
        FCANMX(I,L)  = 0.0  
       ENDDO
        FAREGAT(I)   = 0.0
        GRCLAREA(I)  = 0.0
        VGBIOMAS(I)  = 0.0
        GAVGLTMS(I)  = 0.0
        GAVGSCMS(I)  = 0.0  
        TA(I)        = 0.0  
        PRECIP(I)    = 0.0  
        NETRAD(I)    = 0.0  
        TCURM(I)     = 0.0  
        SRPCURYR(I)  = 0.0  
        DFTCURYR(I)  = 0.0  
        DO MN=1,12
        TMONTH(MN,I) = 0.0
        ENDDO
        ANPCPCUR(I)  = 0.0  
        ANPECUR(I)   = 0.0  
        GDD5CUR(I)   = 0.0  
        SURMNCUR(I)  = 0.0  
        DEFMNCUR(I)  = 0.0  
        SRPLSCUR(I)  = 0.0    
        DEFCTCUR(I)  = 0.0  
        TWARMM(I)    = 0.0  
        TCOLDM(I)    = 0.0  
        GDD5(I)      = 0.0   
        ARIDITY(I)   = 0.0  
        SRPLSMON(I)  = 0.0  
        DEFCTMON(I)  = 0.0  
        ANNDEFCT(I)  = 0.0  
        ANNSRPLS(I)  = 0.0  
        ANNPCP(I)    = 0.0  
        ANPOTEVP(I)  = 0.0  
      ENDDO
C
C     UNMAPPING THE PFT FRACTION IN EACH GRID CELL (FCANCMX_CMP) 
C     BACK TO THE PFT INDEX IN EACH MOSAIC OF EACH GRID CELL (FCANCMXROW) 
C     AND UPDATE THE PFT AREAL FRACTION IN EACH MOSAIC OF EACH GRID CELL (FAREROW)
C
C     CHECK IF BARE FRACTION IS EXISTED 
C 
      DO 50 I=1,NLAT
      DO 55 L=1,ICC
       TPFTFRAC(I)=TPFTFRAC(I)+FCANCMX_CMP(I,L)
 55   CONTINUE
       IF (TPFTFRAC(I) .LT. 1.) THEN 
        BAREEXIST(I) = .TRUE.
       ELSE   
        BAREEXIST(I) = .FALSE.  
         WRITE(*,*)'MINIMAL BARE FRACTION IS ELIMINATED'
         STOP
       ENDIF
 50   CONTINUE
C
C     UNMAPPING BACK TO FCANCMXROW AND
C     UPDATE FAREROW
C
      DO 100 I=1,NLAT
         IF (BAREEXIST(I)) THEN 
          FAREROW(I,NMOS)=1.000-TPFTFRAC(I)
         ENDIF
         DO L=1,ICC
          IF(FCANCMX_CMP(I,L) .GT. 0.0) THEN
           MCOUNT=L
           FCANCMXROW(I,MCOUNT,L) =1.
           FAREROW(I,MCOUNT)      =FCANCMX_CMP(I,L)
           NPPVEGROW(I,MCOUNT,L)  =NPPVEG_CMP(I,L)
           GEREMORTROW(I,MCOUNT,L)=GEREMORT_CMP(I,L)
           INTRMORTROW(I,MCOUNT,L)=INTRMORT_CMP(I,L)
           GLEAFMASROW(I,MCOUNT,L)=GLEAFMAS_CMP(I,L)
           BLEAFMASROW(I,MCOUNT,L)=BLEAFMAS_CMP(I,L)
           STEMMASSROW(I,MCOUNT,L)=STEMMASS_CMP(I,L)
           ROOTMASSROW(I,MCOUNT,L)=ROOTMASS_CMP(I,L)
           PFTEXISTROW(I,MCOUNT,L)=PFTEXIST_CMP(I,L)
           LAMBDAROW(I,MCOUNT,L)  =LAMBDA_CMP(I,L)
           BMASVEGROW(I,MCOUNT,L) =BMASVEG_CMP(I,L)
           BURNVEGROW(I,MCOUNT,L) =BURNVEG_CMP(I,L)
           ADD2ALLOROW(I,MCOUNT,L)=ADD2ALLO_CMP(I,L)
           CCROW(I,MCOUNT,L)      =CC_CMP(I,L)
           MMROW(I,MCOUNT,L)      =MM_CMP(I,L)
           VGBIOMASROW(I,MCOUNT)  =GLEAFMAS_CMP(I,L)+BLEAFMAS_CMP(I,L)+
     &                             STEMMASS_CMP(I,L)+ROOTMASS_CMP(I,L)
          ENDIF 
         ENDDO
         DO M=1,NMOS
           TAROW(I,M)        =TA_CMP(I)
           PRECIPROW(I,M)    =PRECIP_CMP(I)
           TCURMROW(I,M)     =TCURM_CMP(I)
           SRPCURYRROW(I,M ) =SRPCURYR_CMP(I)
           DFTCURYRROW(I,M)  =DFTCURYR_CMP(I)
           DO MN=1,12
           TMONTHROW(MN,I,M) =TMONTH_CMP(MN,I)
           ENDDO
           ANPCPCURROW(I,M)  =ANPCPCUR_CMP(I)
           ANPECURROW(I,M)   =ANPECUR_CMP(I)  
           GDD5CURROW(I,M)   =GDD5CUR_CMP(I)  
           SURMNCURROW(I,M)  =SURMNCUR_CMP(I)  
           DEFMNCURROW(I,M)  =DEFMNCUR_CMP(I)  
           SRPLSCURROW(I,M)  =SRPLSCUR_CMP(I)    
           DEFCTCURROW(I,M)  =DEFCTCUR_CMP(I)  
           TWARMMROW(I,M)    =TWARMM_CMP(I) 
           TCOLDMROW(I,M)    =TCOLDM_CMP(I)  
           GDD5ROW(I,M)      =GDD5_CMP(I)  
           ARIDITYROW(I,M)   =ARIDITY_CMP(I)  
           SRPLSMONROW(I,M)  =SRPLSMON_CMP(I)  
           DEFCTMONROW(I,M)  =DEFCTMON_CMP(I)  
           ANNDEFCTROW(I,M)  =ANNDEFCT_CMP(I) 
           ANNSRPLSROW(I,M)  =ANNSRPLS_CMP(I)   
           ANNPCPROW(I,M)    =ANNPCP_CMP(I) 
           ANPOTEVPROW(I,M)  =ANPOTEVP_CMP(I)
         ENDDO
         DO L=1,ICC+1
          IF(LITRMASS_CMP(I,L) .GT. 0.0) THEN
           MCOUNT1=L
           LITRMASSROW(I,MCOUNT1,L)=LITRMASS_CMP(I,L)
           SOILCMASROW(I,MCOUNT1,L)=SOILCMAS_CMP(I,L)
           GAVGLTMSROW(I,MCOUNT1)  =LITRMASS_CMP(I,L) 
           GAVGSCMSROW(I,MCOUNT1)  =SOILCMAS_CMP(I,L)
          ENDIF
         ENDDO
         MCOUNT2=1
         DO L=1,IC
          IF(FCANMX_CMP(I,L) .GT. 0.0) THEN
           DO M=MCOUNT2,MCOUNT2+NOL2PFTS(L)-1
            FCANMXROW(I,M,L)=1.
           ENDDO
           MCOUNT2=MCOUNT2+NOL2PFTS(L)
          ENDIF
         ENDDO
 100  CONTINUE
C
C     GATHERING THE PFT INDEX IN EACH MOSAIC OF EACH GRID CELL (FCANCMXROW) 
C     TO THE PFT INDEX IN EACH MOSAIC (FCANCMX) 
C     NML, ILMOS AND JLMOS ARE REFERRING TO GATPREP.F
C           
      DO 200 L=1,ICC
      DO 200 K=1,NML
       FCANCMX(K,L) =FCANCMXROW(ILMOS(K),JLMOS(K),L)
       NPPVEG(K,L)  =NPPVEGROW(ILMOS(K),JLMOS(K),L)
       GEREMORT(K,L)=GEREMORTROW(ILMOS(K),JLMOS(K),L)
       INTRMORT(K,L)=INTRMORTROW(ILMOS(K),JLMOS(K),L)
       GLEAFMAS(K,L)=GLEAFMASROW(ILMOS(K),JLMOS(K),L)
       BLEAFMAS(K,L)=BLEAFMASROW(ILMOS(K),JLMOS(K),L)
       STEMMASS(K,L)=STEMMASSROW(ILMOS(K),JLMOS(K),L)
       ROOTMASS(K,L)=ROOTMASSROW(ILMOS(K),JLMOS(K),L)
       PFTEXIST(K,L)=PFTEXISTROW(ILMOS(K),JLMOS(K),L)
       LAMBDA(K,L)  =LAMBDAROW(ILMOS(K),JLMOS(K),L)
       BMASVEG(K,L) =BMASVEGROW(ILMOS(K),JLMOS(K),L)
       BURNVEG(K,L) =BURNVEGROW(ILMOS(K),JLMOS(K),L)
       ADD2ALLO(K,L)=ADD2ALLOROW(ILMOS(K),JLMOS(K),L)
       CC(K,L)      =CCROW(ILMOS(K),JLMOS(K),L)
       MM(K,L)      =MMROW(ILMOS(K),JLMOS(K),L)
 200  CONTINUE
      DO 210 L=1,ICC+1
      DO 210 K=1,NML
       LITRMASS(K,L)=LITRMASSROW(ILMOS(K),JLMOS(K),L)
       SOILCMAS(K,L)=SOILCMASROW(ILMOS(K),JLMOS(K),L)
 210  CONTINUE
      DO 220 L=1,IC
      DO 220 K=1,NML
       FCANMX(K,L)=FCANMXROW(ILMOS(K),JLMOS(K),L)
 220  CONTINUE
      DO 230 K=1,NML
       FAREGAT(K) =FAREROW(ILMOS(K),JLMOS(K))
       GRCLAREA(K)=GRCLAREAROW(ILMOS(K),JLMOS(K))
       VGBIOMAS(K)=VGBIOMASROW(ILMOS(K),JLMOS(K))
       GAVGLTMS(K)=GAVGLTMSROW(ILMOS(K),JLMOS(K))
       GAVGSCMS(K)=GAVGSCMSROW(ILMOS(K),JLMOS(K))
       TA(K)      =TAROW(ILMOS(K),JLMOS(K))
       PRECIP(K)  =PRECIPROW(ILMOS(K),JLMOS(K))
       NETRAD(K)  =NETRADROW(ILMOS(K),JLMOS(K))
       TCURM(K)   =TCURMROW(ILMOS(K),JLMOS(K))
       SRPCURYR(K)=SRPCURYRROW(ILMOS(K),JLMOS(K))
       DFTCURYR(K)=DFTCURYRROW(ILMOS(K),JLMOS(K))
       DO MN=1,12
       TMONTH(MN,K)=TMONTHROW(MN,ILMOS(K),JLMOS(K))
       ENDDO
       ANPCPCUR(K)=ANPCPCURROW(ILMOS(K),JLMOS(K))
       ANPECUR(K) =ANPECURROW(ILMOS(K),JLMOS(K))  
       GDD5CUR(K) =GDD5CURROW(ILMOS(K),JLMOS(K))  
       SURMNCUR(K)=SURMNCURROW(ILMOS(K),JLMOS(K))  
       DEFMNCUR(K)=DEFMNCURROW(ILMOS(K),JLMOS(K))  
       SRPLSCUR(K)=SRPLSCURROW(ILMOS(K),JLMOS(K))    
       DEFCTCUR(K)=DEFCTCURROW(ILMOS(K),JLMOS(K))  
       TWARMM(K)  =TWARMMROW(ILMOS(K),JLMOS(K)) 
       TCOLDM(K)  =TCOLDMROW(ILMOS(K),JLMOS(K))  
       GDD5(K)    =GDD5ROW(ILMOS(K),JLMOS(K))  
       ARIDITY(K) =ARIDITYROW(ILMOS(K),JLMOS(K))  
       SRPLSMON(K)=SRPLSMONROW(ILMOS(K),JLMOS(K))  
       DEFCTMON(K)=DEFCTMONROW(ILMOS(K),JLMOS(K))  
       ANNDEFCT(K)=ANNDEFCTROW(ILMOS(K),JLMOS(K)) 
       ANNSRPLS(K)=ANNSRPLSROW(ILMOS(K),JLMOS(K))   
       ANNPCP(K)  =ANNPCPROW(ILMOS(K),JLMOS(K)) 
       ANPOTEVP(K)=ANPOTEVPROW(ILMOS(K),JLMOS(K)) 
 230  CONTINUE
C
      RETURN
      END

