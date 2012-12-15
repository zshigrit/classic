      SUBROUTINE COMPETITION_MAP(NLAT, NMOS, ILG, 
     1                           NML, ILMOS, JLMOS, ICC, IC,
     2                           FAREGAT,  FCANCMX,  NPPVEG,GEREMORT,
     3                           INTRMORT,GLEAFMAS,BLEAFMAS,STEMMASS,
     4                           ROOTMASS,LITRMASS,SOILCMAS,
     5                           PFTEXIST,  LAMBDA, BMASVEG, BURNVEG,
     6                           ADD2ALLO,      CC,      MM,  FCANMX,
     7                           GRCLAREA,VGBIOMAS,GAVGLTMS,GAVGSCMS,
     8                           TA,PRECIP, NETRAD,   TCURM,SRPCURYR,
     9                           DFTCURYR,  TMONTH,ANPCPCUR, ANPECUR, 
     1                            GDD5CUR,SURMNCUR,DEFMNCUR,SRPLSCUR,  
     2                           DEFCTCUR,  TWARMM,  TCOLDM,    GDD5, 
     3                            ARIDITY,SRPLSMON,DEFCTMON,ANNDEFCT,
     4                           ANNSRPLS,  ANNPCP,ANPOTEVP,
     5                           LUCEMCOM,  LUCLTRIN, LUCSOCIN,
     6                           PFCANCMX,  NFCANCMX,
C    ------------------- INPUTS ABOVE THIS LINE ---------------------
     A                             NETRADROW,
C    ------------------- INTERMEDIATE AND TO SAVE ABOVE THIS LINE ---
     a                           FARE_CMP,  NPPVEG_CMP,GEREMORT_CMP,
     b                          INTRMORT_CMP,GLEAFMAS_CMP,BLEAFMAS_CMP,
     c                          STEMMASS_CMP,ROOTMASS_CMP,LITRMASS_CMP,
     d                          SOILCMAS_CMP,PFTEXIST_CMP,  LAMBDA_CMP,
     e                           BMASVEG_CMP, BURNVEG_CMP,ADD2ALLO_CMP,
     f                                CC_CMP,      MM_CMP,  FCANMX_CMP,
     g                          GRCLAREA_CMP,VGBIOMAS_CMP,
     h                          GAVGLTMS_CMP,GAVGSCMS_CMP,
     i                                TA_CMP,  PRECIP_CMP,  NETRAD_CMP, 
     j                             TCURM_CMP,SRPCURYR_CMP,DFTCURYR_CMP,
     k                            TMONTH_CMP,ANPCPCUR_CMP, ANPECUR_CMP, 
     l                           GDD5CUR_CMP,SURMNCUR_CMP,DEFMNCUR_CMP,
     m                          SRPLSCUR_CMP,DEFCTCUR_CMP,  TWARMM_CMP, 
     n                            TCOLDM_CMP,    GDD5_CMP, ARIDITY_CMP,
     o                          SRPLSMON_CMP,DEFCTMON_CMP,ANNDEFCT_CMP,
     p                          ANNSRPLS_CMP,  ANNPCP_CMP,ANPOTEVP_CMP,
     q                         LUCEMCOM_CMP, LUCLTRIN_CMP, LUCSOCIN_CMP,
     r                           PFCANCMX_CMP,  NFCANCMX_CMP)      
C    ------------------- OUTPUTS ABOVE THIS LINE----------------------   
C
C
C               CANADIAN TERRESTRIAL ECOSYSTEM MODEL (CTEM) V1.1
C                    MAPPING FOR COMPETITION SUBROUTINE
C
C    28 AUG 2012 - THIS SUBROUTINE PREPARES FOR THE COMPETITION 
C    Y. PENG       CALCULATION BY MAPPING THE ONLY PFT IN EACH 
C                  MOSAIC TO PFT FRACTIONS IN EACH GRID CELL
C
C                  INPUT:        ARRAY(ILG,ICC)
C                    | 
C                    | SCATTERING      
C                    V
C                  INTERMEDIATE: ARRAYROW(NLAT,NMOS,ICC)
C                    | 
C                    | MAPPING
C                    V
C                  OUTPUT:       ARRAY_CMP(NLAT,ICC)
C
C                  ARRAY_CMP: MAPPED ARRAY PREPARED FOR COMPETITION
C
C    -----------------------------------------------------------------
C
C    INDICES
C
C     NLAT    - MAX. NUMBER OF GRID CELLS IN THE LATITUDE CIRCLE, WHICH
C               IS PRESCRIBED IN RUNCLASS36CTEM.F
C     NMOS    - MAX. NUMBER OF MOSAIC TILES IN EACH LATITUDINAL GRID CELL, 
C               WHICH IS PRESCRIBED IN RUNCLASS35CTEM.F
C     ILG     - ILG=NLAT*NMOS
C     NML     - TOTAL NUMBER OF MOSAIC TILES WITH PFT FRACTIONS LARGER THAN 1,
C               SEE GATPREP.F
C     ILMOS   - INDICES FOR SCATTERING, SEE GATPREP.F
C     JLMOS   - INDICES FOR SCATTERING, SEE GATPREP.F
C     ICC     - NUMBER OF PFTs FOR USE BY CTEM, CURRENTLY 10
C     IC      - NUMBER OF PFTs FOR USE BY CLASS, CURRENTLY 4
C
C    INPUTS 
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
C     LUCEMCOM - LAND USE CHANGE (LUC) RELATED COMBUSTION EMISSION LOSSES,
C                u-MOL CO2/M2.SEC 
C     LUCLTRIN - LUC RELATED INPUTS TO LITTER POOL, u-MOL CO2/M2.SEC
C     LUCSOCIN - LUC RELATED INPUTS TO SOIL C POOL, u-MOL CO2/M2.SEC
C     TODFRAC  - MAX. FRACTIONAL COVERAGE OF CTEM's 9 PFTs BY THE END
C                OF THE DAY, FOR USE BY LAND USE SUBROUTINE
C     PFCANCMX - PREVIOUS YEAR's FRACTIONAL COVERAGES OF PFTs
C     NFCANCMX - NEXT YEAR's FRACTIONAL COVERAGES OF PFTs

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
C    OUTPUTS
C
C     FARE_CMP    - FRACTIONAL COVERAGE OF CTEM's 10 PFTs IN EACH 
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
C     LUCEMCOM_CMP- LAND USE CHANGE (LUC) RELATED COMBUSTION EMISSION LOSSES
C                   IN EACH LATITUDIONAL GRID CELL, u-MOL CO2/M2.SEC 
C     LUCLTRIN_CMP- LUC RELATED INPUTS TO LITTER POOL, IN EACH LATITUDIONAL 
C                   GRID CELL, u-MOL CO2/M2.SEC
C     LUCSOCIN_CMP- LUC RELATED INPUTS TO SOIL C POOL, IN EACH LATITUDIONAL 
C                   GRID CELL, u-MOL CO2/M2.SEC
C     TODFRAC_CMP - MAX. FRACTIONAL COVERAGE OF CTEM's 9 PFTs BY THE END
C                   OF THE DAYIN EACH LATITUDINAL GRID CELL, FOR USE BY LAND USE SUBROUTINE
C     PFCANCMX_CMP- PREVIOUS YEAR's FRACTIONAL COVERAGES OF PFTs IN EACH LATITUDINAL GRID CELL
C     NFCANCMX_CMP- NEXT YEAR's FRACTIONAL COVERAGES OF PFTs IN EACH LATITUDINAL GRID CELL
C
      IMPLICIT NONE
C
      INTEGER I,M,L,K,ILG,NLAT,NMOS,ICC,IC,MN,
     1        NML,ILMOS(ILG),JLMOS(ILG)
C
C--------INPUT ARRAYS FOR MAPPING------------------------------------------
C
      REAL  FCANCMX(ILG,ICC), FAREGAT(ILG),
     1      NPPVEG(ILG,ICC),  GEREMORT(ILG,ICC),  
     2      INTRMORT(ILG,ICC),GLEAFMAS(ILG,ICC),
     3      BLEAFMAS(ILG,ICC),STEMMASS(ILG,ICC),
     4      ROOTMASS(ILG,ICC),LITRMASS(ILG,ICC+1),
     5      SOILCMAS(ILG,ICC+1),
     6      LAMBDA(ILG,ICC),  TODFRAC(ILG,ICC),
     7      BMASVEG(ILG,ICC), BURNVEG(ILG,ICC),
     8      ADD2ALLO(ILG,ICC),CC(ILG,ICC),MM(ILG,ICC),
     9      FCANMX(ILG,IC),   GRCLAREA(ILG),
     1      VGBIOMAS(ILG),    GAVGLTMS(ILG),
     2      GAVGSCMS(ILG),
     3      LUCEMCOM(ILG),  LUCLTRIN(ILG), LUCSOCIN(ILG),
     4      PFCANCMX(ILG,ICC), NFCANCMX(ILG,ICC)
C
      INTEGER PFTEXIST(ILG,ICC)
C
      REAL  TA(ILG),        PRECIP(ILG),   NETRAD(ILG),
     1      TCURM(ILG),     SRPCURYR(ILG), DFTCURYR(ILG),
     2      TMONTH(12,ILG), ANPCPCUR(ILG), ANPECUR(ILG),
     3      GDD5CUR(ILG),   SURMNCUR(ILG), DEFMNCUR(ILG),
     4      SRPLSCUR(ILG),  DEFCTCUR(ILG), TWARMM(ILG),
     5      TCOLDM(ILG),    GDD5(ILG),     ARIDITY(ILG),
     6      SRPLSMON(ILG),  DEFCTMON(ILG), ANNDEFCT(ILG),
     7      ANNSRPLS(ILG),  ANNPCP(ILG),   ANPOTEVP(ILG)
 
C
C--------INTERMEDIATE ARRAYS FOR MAPPING-----------------------------------
C
      REAL  FCANCMXROW(NLAT,NMOS,ICC),   NPPVEGROW(NLAT,NMOS,ICC),
     1      GEREMORTROW(NLAT,NMOS,ICC),  INTRMORTROW(NLAT,NMOS,ICC),
     2      GLEAFMASROW(NLAT,NMOS,ICC),  BLEAFMASROW(NLAT,NMOS,ICC),
     3      STEMMASSROW(NLAT,NMOS,ICC),  ROOTMASSROW(NLAT,NMOS,ICC),
     4      LITRMASSROW(NLAT,NMOS,ICC+1),SOILCMASROW(NLAT,NMOS,ICC+1),
     5      LAMBDAROW(NLAT,NMOS,ICC),    TODFRACROW(NLAT,NMOS,ICC),  
     6      BMASVEGROW(NLAT,NMOS,ICC),   BURNVEGROW(NLAT,NMOS,ICC),
     7      ADD2ALLOROW(NLAT,NMOS,ICC),  CCROW(NLAT,NMOS,ICC),
     8      MMROW(NLAT,NMOS,ICC),        FCANMXROW(NLAT,NMOS,IC),
     9      FAREROW(NLAT,NMOS),
     1      GRCLAREAROW(NLAT,NMOS),      VGBIOMASROW(NLAT,NMOS),    
     2      GAVGLTMSROW(NLAT,NMOS),      GAVGSCMSROW(NLAT,NMOS),
     3      LUCEMCOMROW(NLAT,NMOS),      LUCLTRINROW(NLAT,NMOS),
     4      LUCSOCINROW(NLAT,NMOS),
     5      PFCANCMXROW(NLAT,NMOS,ICC), NFCANCMXROW(NLAT,NMOS,ICC)
C
      INTEGER PFTEXISTROW(NLAT,NMOS,ICC)
C
C--------THESE INTERMEDIATE ARRAYS WILL BE SAVED FOR UNMAPPING------------\\
C
      REAL  NETRADROW(NLAT,NMOS)
C
C-------------------------------------------------------------------------//
C
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
C--------OUTPUT ARRAYS AFTER MAPPING---------------------------------------
C
      REAL  FARE_CMP(NLAT,ICC),   NPPVEG_CMP(NLAT,ICC),
     1      GEREMORT_CMP(NLAT,ICC),  INTRMORT_CMP(NLAT,ICC),
     2      GLEAFMAS_CMP(NLAT,ICC),  BLEAFMAS_CMP(NLAT,ICC),
     3      STEMMASS_CMP(NLAT,ICC),  ROOTMASS_CMP(NLAT,ICC),
     4      LITRMASS_CMP(NLAT,ICC+1),SOILCMAS_CMP(NLAT,ICC+1),
     5      LAMBDA_CMP(NLAT,ICC),    TODFRAC_CMP(NLAT,ICC),
     6      BMASVEG_CMP(NLAT,ICC),   BURNVEG_CMP(NLAT,ICC),
     7      ADD2ALLO_CMP(NLAT,ICC),  CC_CMP(NLAT,ICC),MM_CMP(NLAT,ICC),
     8      FCANMX_CMP(NLAT,IC),     
     9      GRCLAREA_CMP(NLAT),      VGBIOMAS_CMP(NLAT),    
     1      GAVGLTMS_CMP(NLAT),      GAVGSCMS_CMP(NLAT),
     2      LUCEMCOM_CMP(NLAT),  LUCLTRIN_CMP(NLAT), LUCSOCIN_CMP(NLAT),
     3      PFCANCMX_CMP(NLAT,ICC), NFCANCMX_CMP(NLAT,ICC)
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
      IF(ICC.NE.9)                    CALL XIT('COMPETE_UNMAP',-1)
      IF(IC.NE.4)                     CALL XIT('COMPETE_UNMAP',-2)
C
C     INITIALIZATION
C
      DO 90 I = 1, NLAT
       DO 91 M = 1, NMOS
C
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
         TODFRACROW(I,M,L) = 0.0
         PFCANCMXROW(I,M,L)= 0.0
         NFCANCMXROW(I,M,L)= 0.0
         BMASVEGROW(I,M,L) = 0.0
         BURNVEGROW(I,M,L) = 0.0
         ADD2ALLOROW(I,M,L)= 0.0
         CCROW(I,M,L)      = 0.0
         MMROW(I,M,L)      = 0.0
        ENDDO       
C
        DO L=1,ICC+1
         LITRMASSROW(I,M,L)= 0.0
         SOILCMASROW(I,M,L)= 0.0
        ENDDO
C
        DO L=1,IC
         FCANMXROW(I,M,L)  = 0.0            
        ENDDO
C
         FAREROW(I,M)      = 0.0
         GRCLAREAROW(I,M)  = 0.0
         VGBIOMASROW(I,M)  = 0.0
         GAVGLTMSROW(I,M)  = 0.0
         GAVGSCMSROW(I,M)  = 0.0 
         LUCEMCOMROW(I,M)  = 0.0
         LUCLTRINROW(I,M)  = 0.0
         LUCSOCINROW(I,M)  = 0.0 
         TAROW(I,M)        = 0.0  
         PRECIPROW(I,M)    = 0.0  
         NETRADROW(I,M)    = 0.0  
         TCURMROW(I,M)     = 0.0  
         SRPCURYRROW(I,M)  = 0.0  
         DFTCURYRROW(I,M)  = 0.0  
C
         DO MN=1,12
          TMONTHROW(MN,I,M) = 0.0
         ENDDO
C
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
91     CONTINUE
C
       DO L=1,ICC
        FARE_CMP(I,L) = 0.0
        NPPVEG_CMP(I,L)  = 0.0
        GEREMORT_CMP(I,L)= 0.0
        INTRMORT_CMP(I,L)= 0.0
        GLEAFMAS_CMP(I,L)= 0.0
        BLEAFMAS_CMP(I,L)= 0.0
        STEMMASS_CMP(I,L)= 0.0
        ROOTMASS_CMP(I,L)= 0.0
        PFTEXIST_CMP(I,L)= 0
        LAMBDA_CMP(I,L)  = 0.0
        TODFRAC_CMP(I,L) = 0.0
        PFCANCMX_CMP(I,L)= 0.0
        NFCANCMX_CMP(I,L)= 0.0
        BMASVEG_CMP(I,L) = 0.0
        BURNVEG_CMP(I,L) = 0.0
        ADD2ALLO_CMP(I,L)= 0.0
        CC_CMP(I,L)      = 0.0
        MM_CMP(I,L)      = 0.0
       ENDDO
C
       DO L=1,ICC+1
        LITRMASS_CMP(I,L)= 0.0
        SOILCMAS_CMP(I,L)= 0.0
       ENDDO
C
       DO L=1,IC
        FCANMX_CMP(I,L)  = 0.0  
       ENDDO
C
        GRCLAREA_CMP(I)  = 0.0
        VGBIOMAS_CMP(I)  = 0.0
        GAVGLTMS_CMP(I)  = 0.0
        GAVGSCMS_CMP(I)  = 0.0 
        LUCEMCOM_CMP(I)  = 0.0 
        LUCLTRIN_CMP(I)  = 0.0
        LUCSOCIN_CMP(I)  = 0.0
        TA_CMP(I)        = 0.0  
        PRECIP_CMP(I)    = 0.0  
        NETRAD_CMP(I)    = 0.0  
        TCURM_CMP(I)     = 0.0  
        SRPCURYR_CMP(I)  = 0.0  
        DFTCURYR_CMP(I)  = 0.0  
C
        DO MN=1,12
         TMONTH_CMP(MN,I) = 0.0
        ENDDO
C
        ANPCPCUR_CMP(I)  = 0.0  
        ANPECUR_CMP(I)   = 0.0  
        GDD5CUR_CMP(I)   = 0.0  
        SURMNCUR_CMP(I)  = 0.0  
        DEFMNCUR_CMP(I)  = 0.0  
        SRPLSCUR_CMP(I)  = 0.0    
        DEFCTCUR_CMP(I)  = 0.0  
        TWARMM_CMP(I)    = 0.0  
        TCOLDM_CMP(I)    = 0.0  
        GDD5_CMP(I)      = 0.0   
        ARIDITY_CMP(I)   = 0.0  
        SRPLSMON_CMP(I)  = 0.0  
        DEFCTMON_CMP(I)  = 0.0  
        ANNDEFCT_CMP(I)  = 0.0  
        ANNSRPLS_CMP(I)  = 0.0  
        ANNPCP_CMP(I)    = 0.0  
        ANPOTEVP_CMP(I)  = 0.0  
90    CONTINUE 
C
C     SCATTERING THE PFT INDEX IN EACH MOSAIC (FCANCMX) TO 
C     PFT INDEX IN EACH MOSAIC OF EACH GRID CELL (FCANCMXROW)
C     NML, ILMOS AND JLMOS ARE REFERRING TO GATPREP.F
C
      DO 100 L=1,ICC
       DO 100 K=1,NML
         FCANCMXROW(ILMOS(K),JLMOS(K),L)  = FCANCMX(K,L)
         NPPVEGROW(ILMOS(K),JLMOS(K),L)   = NPPVEG(K,L)
         GEREMORTROW(ILMOS(K),JLMOS(K),L) = GEREMORT(K,L)
         INTRMORTROW(ILMOS(K),JLMOS(K),L) = INTRMORT(K,L)
         GLEAFMASROW(ILMOS(K),JLMOS(K),L) = GLEAFMAS(K,L)
         BLEAFMASROW(ILMOS(K),JLMOS(K),L) = BLEAFMAS(K,L)
         STEMMASSROW(ILMOS(K),JLMOS(K),L) = STEMMASS(K,L)
         ROOTMASSROW(ILMOS(K),JLMOS(K),L) = ROOTMASS(K,L)
         LITRMASSROW(ILMOS(K),JLMOS(K),L) = LITRMASS(K,L)
         SOILCMASROW(ILMOS(K),JLMOS(K),L) = SOILCMAS(K,L)
         PFTEXISTROW(ILMOS(K),JLMOS(K),L) = PFTEXIST(K,L)
         LAMBDAROW(ILMOS(K),JLMOS(K),L)   = LAMBDA(K,L)
         TODFRACROW(ILMOS(K),JLMOS(K),L)  = TODFRAC(K,L)
         PFCANCMXROW(ILMOS(K),JLMOS(K),L) = PFCANCMX(K,L)
         NFCANCMXROW(ILMOS(K),JLMOS(K),L) = NFCANCMX(K,L)
         BMASVEGROW(ILMOS(K),JLMOS(K),L)  = BMASVEG(K,L)
         BURNVEGROW(ILMOS(K),JLMOS(K),L)  = BURNVEG(K,L)
         ADD2ALLOROW(ILMOS(K),JLMOS(K),L) = ADD2ALLO(K,L)
         CCROW(ILMOS(K),JLMOS(K),L)       = CC(K,L)
         MMROW(ILMOS(K),JLMOS(K),L)       = MM(K,L)   
 100  CONTINUE
C
      DO 110 L=1,ICC+1
       DO 110 K=1,NML
         LITRMASSROW(ILMOS(K),JLMOS(K),L) = LITRMASS(K,L)
         SOILCMASROW(ILMOS(K),JLMOS(K),L) = SOILCMAS(K,L)
 110  CONTINUE
C
      DO 120 L=1,IC
       DO 120 K=1,NML
         FCANMXROW(ILMOS(K),JLMOS(K),L) = FCANMX(K,L)
 120  CONTINUE
C
      DO 130 K=1,NML
         FAREROW(ILMOS(K),JLMOS(K))     = FAREGAT(K)
         GRCLAREAROW(ILMOS(K),JLMOS(K)) = GRCLAREA(K)
         VGBIOMASROW(ILMOS(K),JLMOS(K)) = VGBIOMAS(K)
         GAVGLTMSROW(ILMOS(K),JLMOS(K)) = GAVGLTMS(K)
         GAVGSCMSROW(ILMOS(K),JLMOS(K)) = GAVGSCMS(K) 
         LUCEMCOMROW(ILMOS(K),JLMOS(K)) = LUCEMCOM(K)
         LUCLTRINROW(ILMOS(K),JLMOS(K)) = LUCLTRIN(K) 
         LUCSOCINROW(ILMOS(K),JLMOS(K)) = LUCSOCIN(K)  
         TAROW(ILMOS(K),JLMOS(K))       = TA(K)
         PRECIPROW(ILMOS(K),JLMOS(K))   = PRECIP(K)
         NETRADROW(ILMOS(K),JLMOS(K))   = NETRAD(K)
         TCURMROW(ILMOS(K),JLMOS(K))    = TCURM(K)
         SRPCURYRROW(ILMOS(K),JLMOS(K)) = SRPCURYR(K)
         DFTCURYRROW(ILMOS(K),JLMOS(K)) = DFTCURYR(K)
C
         DO MN=1,12
          TMONTHROW(MN,ILMOS(K),JLMOS(K)) = TMONTH(MN,K)
         ENDDO
C
         ANPCPCURROW(ILMOS(K),JLMOS(K)) = ANPCPCUR(K)
         ANPECURROW(ILMOS(K),JLMOS(K))  = ANPECUR(K)  
         GDD5CURROW(ILMOS(K),JLMOS(K))  = GDD5CUR(K)  
         SURMNCURROW(ILMOS(K),JLMOS(K)) = SURMNCUR(K)  
         DEFMNCURROW(ILMOS(K),JLMOS(K)) = DEFMNCUR(K)  
         SRPLSCURROW(ILMOS(K),JLMOS(K)) = SRPLSCUR(K)    
         DEFCTCURROW(ILMOS(K),JLMOS(K)) = DEFCTCUR(K)  
         TWARMMROW(ILMOS(K),JLMOS(K))   = TWARMM(K) 
         TCOLDMROW(ILMOS(K),JLMOS(K))   = TCOLDM(K)  
         GDD5ROW(ILMOS(K),JLMOS(K))     = GDD5(K)  
         ARIDITYROW(ILMOS(K),JLMOS(K))  = ARIDITY(K)  
         SRPLSMONROW(ILMOS(K),JLMOS(K)) = SRPLSMON(K)  
         DEFCTMONROW(ILMOS(K),JLMOS(K)) = DEFCTMON(K)  
         ANNDEFCTROW(ILMOS(K),JLMOS(K)) = ANNDEFCT(K) 
         ANNSRPLSROW(ILMOS(K),JLMOS(K)) = ANNSRPLS(K)   
         ANNPCPROW(ILMOS(K),JLMOS(K))   = ANNPCP(K) 
         ANPOTEVPROW(ILMOS(K),JLMOS(K)) = ANPOTEVP(K)  
 130  CONTINUE
C
C     MAPPING THE PFT AREAL FRACTION IN EACH MOSAIC OF EACH
C     GRID CELL (FAREROW) TO PFT FRACTION IN EACH GRID CELL (FARE_CMP)
C
      DO 200 I=1,NLAT
      DO 210 M=1,NMOS
C
       DO L=1,ICC
        IF (FCANCMXROW(I,M,L) .EQ. 1.0) THEN
         FARE_CMP(I,L)    = FAREROW(I,M)
         NPPVEG_CMP(I,L)  = NPPVEGROW(I,M,L)
         GEREMORT_CMP(I,L)= GEREMORTROW(I,M,L)
         INTRMORT_CMP(I,L)= INTRMORTROW(I,M,L)
         GLEAFMAS_CMP(I,L)= GLEAFMASROW(I,M,L)
         BLEAFMAS_CMP(I,L)= BLEAFMASROW(I,M,L)
         STEMMASS_CMP(I,L)= STEMMASSROW(I,M,L)
         ROOTMASS_CMP(I,L)= ROOTMASSROW(I,M,L)
         PFTEXIST_CMP(I,L)= PFTEXISTROW(I,M,L)
         LAMBDA_CMP(I,L)  = LAMBDAROW(I,M,L)
         TODFRAC_CMP(I,L) = TODFRACROW(I,M,L)
         PFCANCMX_CMP(I,L)= PFCANCMXROW(I,M,L)
         NFCANCMX_CMP(I,L)= NFCANCMXROW(I,M,L)
         BMASVEG_CMP(I,L) = BMASVEGROW(I,M,L)
         BURNVEG_CMP(I,L) = BURNVEGROW(I,M,L)
         ADD2ALLO_CMP(I,L)= ADD2ALLOROW(I,M,L)
         CC_CMP(I,L)      = CCROW(I,M,L)
         MM_CMP(I,L)      = MMROW(I,M,L)
        ENDIF
       ENDDO
C
       DO L=1,ICC+1
        IF (LITRMASSROW(I,M,L) .GT. 0.) THEN
         LITRMASS_CMP(I,L) = LITRMASSROW(I,M,L)
         SOILCMAS_CMP(I,L) = SOILCMASROW(I,M,L)
        ENDIF
       ENDDO 
C
       DO L=1,IC
        IF (FCANMXROW(I,M,L) .EQ. 1.0) THEN
         FCANMX_CMP(I,L)  = FCANMXROW(I,M,L)
        ENDIF
       ENDDO     
C
210   CONTINUE
C
       DO M=1,NMOS                                    
        GRCLAREA_CMP(I) = GRCLAREAROW(I,M)
        VGBIOMAS_CMP(I) = VGBIOMAS_CMP(I)+VGBIOMASROW(I,M)*FAREROW(I,M)
        GAVGLTMS_CMP(I) = GAVGLTMS_CMP(I)+GAVGLTMSROW(I,M)*FAREROW(I,M)
        GAVGSCMS_CMP(I) = GAVGSCMS_CMP(I)+GAVGSCMSROW(I,M)*FAREROW(I,M) 
        LUCEMCOM_CMP(I) = LUCEMCOM_CMP(I)+LUCEMCOMROW(I,M)*FAREROW(I,M)
        LUCLTRIN_CMP(I) = LUCLTRIN_CMP(I)+LUCLTRINROW(I,M)*FAREROW(I,M)
        LUCSOCIN_CMP(I) = LUCSOCIN_CMP(I)+LUCSOCINROW(I,M)*FAREROW(I,M)
        TA_CMP(I)       = TAROW(I,M)
        PRECIP_CMP(I)   = PRECIPROW(I,M)
        NETRAD_CMP(I)   = NETRAD_CMP(I)+NETRADROW(I,M)*FAREROW(I,M)
        TCURM_CMP(I)    = TCURMROW(I,M)
        SRPCURYR_CMP(I) = SRPCURYRROW(I,M)
        DFTCURYR_CMP(I) = DFTCURYRROW(I,M)
C
        DO MN=1,12
         TMONTH_CMP(MN,I) = TMONTHROW(MN,I,M)
        ENDDO
C
        ANPCPCUR_CMP(I) = ANPCPCURROW(I,M)
        ANPECUR_CMP(I)  = ANPECURROW(I,M)  
        GDD5CUR_CMP(I)  = GDD5CURROW(I,M)  
        SURMNCUR_CMP(I) = SURMNCURROW(I,M)  
        DEFMNCUR_CMP(I) = DEFMNCURROW(I,M)  
        SRPLSCUR_CMP(I) = SRPLSCURROW(I,M)    
        DEFCTCUR_CMP(I) = DEFCTCURROW(I,M)  
        TWARMM_CMP(I)   = TWARMMROW(I,M) 
        TCOLDM_CMP(I)   = TCOLDMROW(I,M)  
        GDD5_CMP(I)     = GDD5ROW(I,M)  
        ARIDITY_CMP(I)  = ARIDITYROW(I,M)  
        SRPLSMON_CMP(I) = SRPLSMONROW(I,M)  
        DEFCTMON_CMP(I) = DEFCTMONROW(I,M)  
        ANNDEFCT_CMP(I) = ANNDEFCTROW(I,M) 
        ANNSRPLS_CMP(I) = ANNSRPLSROW(I,M)   
        ANNPCP_CMP(I)   = ANNPCPROW(I,M) 
        ANPOTEVP_CMP(I) = ANPOTEVPROW(I,M)
       ENDDO 
C
200   CONTINUE
C
      RETURN
      END

