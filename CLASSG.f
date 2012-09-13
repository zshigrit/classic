      SUBROUTINE CLASSG(TBARGAT,THLQGAT,THICGAT,TPNDGAT,ZPNDGAT,
     1                  TBASGAT,ALBSGAT,TSNOGAT,RHOSGAT,SNOGAT, 
     2                  TCANGAT,RCANGAT,SCANGAT,GROGAT, CMAIGAT,
     3                  FCANGAT,LNZ0GAT,ALVCGAT,ALICGAT,PAMXGAT,
     4                  PAMNGAT,CMASGAT,ROOTGAT,RSMNGAT,QA50GAT,
     5                  VPDAGAT,VPDBGAT,PSGAGAT,PSGBGAT,PAIDGAT,
     6                  HGTDGAT,ACVDGAT,ACIDGAT,TSFSGAT,WSNOGAT,
     7                  THPGAT, THRGAT, THMGAT, BIGAT,  PSISGAT,
     8                  GRKSGAT,THRAGAT,HCPSGAT,TCSGAT, IGDRGAT,
     9                  THFCGAT,PSIWGAT,DLZWGAT,ZBTWGAT,VMODGAT,
     A                  ZSNLGAT,ZPLGGAT,ZPLSGAT,TACGAT, QACGAT,
     B                  DRNGAT, XSLPGAT,GRKFGAT,WFSFGAT,WFCIGAT,
     C                  ALGWGAT,ALGDGAT,ASVDGAT,ASIDGAT,AGVDGAT,
     D                  AGIDGAT,ISNDGAT,RADJGAT,ZBLDGAT,Z0ORGAT,
     E                  ZRFMGAT,ZRFHGAT,ZDMGAT, ZDHGAT, FSVHGAT,
     F                  FSIHGAT,CSZGAT, FDLGAT, ULGAT,  VLGAT,  
     G                  TAGAT,  QAGAT,  PRESGAT,PREGAT, PADRGAT,
     H                  VPDGAT, TADPGAT,RHOAGAT,RPCPGAT,TRPCGAT,
     I                  SPCPGAT,TSPCGAT,RHSIGAT,FCLOGAT,DLONGAT,
     J                  GGEOGAT,
     K                  ILMOS,JLMOS,IWMOS,JWMOS,
     L                  NML,NL,NM,ILG,IG,IC,ICP1,
     M                  TBARROT,THLQROT,THICROT,TPNDROT,ZPNDROT,
     N                  TBASROT,ALBSROT,TSNOROT,RHOSROT,SNOROT, 
     O                  TCANROT,RCANROT,SCANROT,GROROT, CMAIROT,
     P                  FCANROT,LNZ0ROT,ALVCROT,ALICROT,PAMXROT,
     Q                  PAMNROT,CMASROT,ROOTROT,RSMNROT,QA50ROT,
     R                  VPDAROT,VPDBROT,PSGAROT,PSGBROT,PAIDROT,
     S                  HGTDROT,ACVDROT,ACIDROT,TSFSROT,WSNOROT,
     T                  THPROT, THRROT, THMROT, BIROT,  PSISROT,
     U                  GRKSROT,THRAROT,HCPSROT,TCSROT, IGDRROT,
     V                  THFCROT,PSIWROT,DLZWROT,ZBTWROT,VMODL,
     W                  ZSNLROT,ZPLGROT,ZPLSROT,TACROT, QACROT,
     X                  DRNROT, XSLPROT,GRKFROT,WFSFROT,WFCIROT,
     Y                  ALGWROT,ALGDROT,ASVDROT,ASIDROT,AGVDROT,
     Z                  AGIDROT,ISNDROT,RADJ   ,ZBLDROW,Z0ORROW,
     +                  ZRFMROW,ZRFHROW,ZDMROW, ZDHROW, FSVHROW,
     +                  FSIHROW,CSZROW, FDLROW, ULROW,  VLROW,  
     +                  TAROW,  QAROW,  PRESROW,PREROW, PADRROW,
     +                  VPDROW, TADPROW,RHOAROW,RPCPROW,TRPCROW,
     +                  SPCPROW,TSPCROW,RHSIROW,FCLOROW,DLONROW,
     +                  GGEOROW  )
C
C     * OCT 18/11 - M.LAZARE.  ADD IGDR.
C     * OCT 07/11 - M.LAZARE.  ADD VMODL->VMODGAT.
C     * OCT 05/11 - M.LAZARE.  PUT BACK IN PRESGROW->PRESGAT
C     *                        REQUIRED FOR ADDED SURFACE RH 
C     *                        CALCULATION.
C     * OCT 03/11 - M.LAZARE.  REMOVE ALL INITIALIZATION TO
C     *                        ZERO OF GAT ARRAYS (NOW DONE
C     *                        IN CLASS DRIVER).
C     * SEP 16/11 - M.LAZARE.  - ROW->ROT AND GRD->ROW.
C     *                        - REMOVE INITIALIZATION OF
C     *                          {ALVS,ALIR} TO ZERO.
C     *                        - REMOVE PRESGROW->PRESGAT 
C     *                          (OCEAN-ONLY NOW).
C     *                        - RADJROW (64-BIT) NOW RADJ
C     *                          (32-BIT).
C     * MAR 23/06 - D.VERSEGHY. ADD WSNO,FSNO,GGEO.
C     * MAR 18/05 - D.VERSEGHY. ADDITIONAL VARIABLES.
C     * FEB 18/05 - D.VERSEGHY. ADD "TSFS" VARIABLES.
C     * NOV 03/04 - D.VERSEGHY. ADD "IMPLICIT NONE" COMMAND.
C     * AUG 15/02 - D.VERSEGHY. GATHER OPERATION ON CLASS 
C     *                         VARIABLES.
C 
      IMPLICIT NONE
C
C     * INTEGER CONSTANTS.
C
      INTEGER  NML,NL,NM,ILG,IG,IC,ICP1,K,L,M
C
C     * LAND SURFACE PROGNOSTIC VARIABLES.
C
      REAL    TBARROT(NL,NM,IG), THLQROT(NL,NM,IG), THICROT(NL,NM,IG), 
     1        TPNDROT(NL,NM),    ZPNDROT(NL,NM),    TBASROT(NL,NM),   
     2        ALBSROT(NL,NM),    TSNOROT(NL,NM),    RHOSROT(NL,NM),   
     3        SNOROT (NL,NM),    TCANROT(NL,NM),    RCANROT(NL,NM),   
     4        SCANROT(NL,NM),    GROROT (NL,NM),    CMAIROT(NL,NM),
     5        TSFSROT(NL,NM,4),  TACROT (NL,NM),    QACROT (NL,NM),
     6        WSNOROT(NL,NM)
C
      REAL    TBARGAT(ILG,IG),   THLQGAT(ILG,IG),   THICGAT(ILG,IG), 
     1        TPNDGAT(ILG),      ZPNDGAT(ILG),      TBASGAT(ILG),   
     2        ALBSGAT(ILG),      TSNOGAT(ILG),      RHOSGAT(ILG),   
     3        SNOGAT (ILG),      TCANGAT(ILG),      RCANGAT(ILG),   
     4        SCANGAT(ILG),      GROGAT (ILG),      CMAIGAT(ILG),
     5        TSFSGAT(ILG,4),    TACGAT (ILG),      QACGAT (ILG),
     6        WSNOGAT(ILG)
C
C     * GATHER-SCATTER INDEX ARRAYS.
C
      INTEGER  ILMOS (ILG),  JLMOS  (ILG),  IWMOS  (ILG),  JWMOS (ILG)
C
C     * CANOPY AND SOIL INFORMATION ARRAYS.
C     * (THE LENGTH OF THESE ARRAYS IS DETERMINED BY THE NUMBER
C     * OF SOIL LAYERS (3) AND THE NUMBER OF BROAD VEGETATION
C     * CATEGORIES (4, OR 5 INCLUDING URBAN AREAS).)
C
      REAL          FCANROT(NL,NM,ICP1), LNZ0ROT(NL,NM,ICP1),
     1              ALVCROT(NL,NM,ICP1), ALICROT(NL,NM,ICP1),
     2              PAMXROT(NL,NM,IC),   PAMNROT(NL,NM,IC),
     3              CMASROT(NL,NM,IC),   ROOTROT(NL,NM,IC),
     4              RSMNROT(NL,NM,IC),   QA50ROT(NL,NM,IC),
     5              VPDAROT(NL,NM,IC),   VPDBROT(NL,NM,IC),
     6              PSGAROT(NL,NM,IC),   PSGBROT(NL,NM,IC),
     7              PAIDROT(NL,NM,IC),   HGTDROT(NL,NM,IC),
     8              ACVDROT(NL,NM,IC),   ACIDROT(NL,NM,IC)
C
      REAL          FCANGAT(ILG,ICP1),   LNZ0GAT(ILG,ICP1),
     1              ALVCGAT(ILG,ICP1),   ALICGAT(ILG,ICP1),
     2              PAMXGAT(ILG,IC),     PAMNGAT(ILG,IC),
     3              CMASGAT(ILG,IC),     ROOTGAT(ILG,IC),
     4              RSMNGAT(ILG,IC),     QA50GAT(ILG,IC),
     5              VPDAGAT(ILG,IC),     VPDBGAT(ILG,IC),
     6              PSGAGAT(ILG,IC),     PSGBGAT(ILG,IC),
     7              PAIDGAT(ILG,IC),     HGTDGAT(ILG,IC),
     8              ACVDGAT(ILG,IC),     ACIDGAT(ILG,IC)
C
      REAL    THPROT (NL,NM,IG), THRROT (NL,NM,IG), THMROT (NL,NM,IG),
     1        BIROT  (NL,NM,IG), PSISROT(NL,NM,IG), GRKSROT(NL,NM,IG),   
     2        THRAROT(NL,NM,IG), HCPSROT(NL,NM,IG), 
     3        TCSROT (NL,NM,IG), THFCROT(NL,NM,IG), PSIWROT(NL,NM,IG),  
     4        DLZWROT(NL,NM,IG), ZBTWROT(NL,NM,IG), 
     5        DRNROT (NL,NM),    XSLPROT(NL,NM),    GRKFROT(NL,NM),
     6        WFSFROT(NL,NM),    WFCIROT(NL,NM),    ALGWROT(NL,NM),   
     7        ALGDROT(NL,NM),    ASVDROT(NL,NM),    ASIDROT(NL,NM),   
     8        AGVDROT(NL,NM),    AGIDROT(NL,NM),    ZSNLROT(NL,NM),
     9        ZPLGROT(NL,NM),    ZPLSROT(NL,NM)
C

      REAL    THPGAT (ILG,IG),   THRGAT (ILG,IG),   THMGAT (ILG,IG),
     1        BIGAT  (ILG,IG),   PSISGAT(ILG,IG),   GRKSGAT(ILG,IG),   
     2        THRAGAT(ILG,IG),   HCPSGAT(ILG,IG), 
     3        TCSGAT (ILG,IG),   THFCGAT(ILG,IG),   PSIWGAT(ILG,IG),  
     4        DLZWGAT(ILG,IG),   ZBTWGAT(ILG,IG),   
     5        DRNGAT (ILG),      XSLPGAT(ILG),      GRKFGAT(ILG),
     6        WFSFGAT(ILG),      WFCIGAT(ILG),      ALGWGAT(ILG),     
     7        ALGDGAT(ILG),      ASVDGAT(ILG),      ASIDGAT(ILG),     
     8        AGVDGAT(ILG),      AGIDGAT(ILG),      ZSNLGAT(ILG),
     9        ZPLGGAT(ILG),      ZPLSGAT(ILG)
C
      INTEGER ISNDROT(NL,NM,IG), ISNDGAT(ILG,IG)
      INTEGER IGDRROT(NL,NM),    IGDRGAT(ILG)

C     * ATMOSPHERIC AND GRID-CONSTANT INPUT VARIABLES.
C
      REAL  ZRFMROW( NL), ZRFHROW( NL), ZDMROW ( NL), ZDHROW ( NL),
     1      FSVHROW( NL), FSIHROW( NL), CSZROW ( NL), FDLROW ( NL), 
     2      ULROW  ( NL), VLROW  ( NL), TAROW  ( NL), QAROW  ( NL), 
     3      PRESROW( NL), PREROW ( NL), PADRROW( NL), VPDROW ( NL), 
     4      TADPROW( NL), RHOAROW( NL), ZBLDROW( NL), Z0ORROW( NL),
     5      RPCPROW( NL), TRPCROW( NL), SPCPROW( NL), TSPCROW( NL),
     6      RHSIROW( NL), FCLOROW( NL), DLONROW( NL), GGEOROW( NL),
     7      RADJ   ( NL), VMODL  ( NL)
C
      REAL  ZRFMGAT(ILG), ZRFHGAT(ILG), ZDMGAT (ILG), ZDHGAT (ILG),
     1      FSVHGAT(ILG), FSIHGAT(ILG), CSZGAT (ILG), FDLGAT (ILG), 
     2      ULGAT  (ILG), VLGAT  (ILG), TAGAT  (ILG), QAGAT  (ILG), 
     3      PRESGAT(ILG), PREGAT (ILG), PADRGAT(ILG), VPDGAT (ILG), 
     4      TADPGAT(ILG), RHOAGAT(ILG), ZBLDGAT(ILG), Z0ORGAT(ILG),
     5      RPCPGAT(ILG), TRPCGAT(ILG), SPCPGAT(ILG), TSPCGAT(ILG),
     6      RHSIGAT(ILG), FCLOGAT(ILG), DLONGAT(ILG), GGEOGAT(ILG),
     7      RADJGAT(ILG), VMODGAT(ILG)
C----------------------------------------------------------------------

      DO 100 K=1,NML
          TPNDGAT(K)=TPNDROT(ILMOS(K),JLMOS(K))  
          ZPNDGAT(K)=ZPNDROT(ILMOS(K),JLMOS(K))  
          TBASGAT(K)=TBASROT(ILMOS(K),JLMOS(K))  
          ALBSGAT(K)=ALBSROT(ILMOS(K),JLMOS(K))  
          TSNOGAT(K)=TSNOROT(ILMOS(K),JLMOS(K))  
          RHOSGAT(K)=RHOSROT(ILMOS(K),JLMOS(K))  
          SNOGAT (K)=SNOROT (ILMOS(K),JLMOS(K))  
          WSNOGAT(K)=WSNOROT(ILMOS(K),JLMOS(K))  
          TCANGAT(K)=TCANROT(ILMOS(K),JLMOS(K))  
          RCANGAT(K)=RCANROT(ILMOS(K),JLMOS(K))  
          SCANGAT(K)=SCANROT(ILMOS(K),JLMOS(K))  
          GROGAT (K)=GROROT (ILMOS(K),JLMOS(K))  
          CMAIGAT(K)=CMAIROT(ILMOS(K),JLMOS(K))  
          DRNGAT (K)=DRNROT (ILMOS(K),JLMOS(K))  
c         XSLPGAT(K)=XSLPROT(ILMOS(K),JLMOS(K))  
c         GRKFGAT(K)=GRKFROT(ILMOS(K),JLMOS(K))  
c         WFSFGAT(K)=WFSFROT(ILMOS(K),JLMOS(K))  
c         WFCIGAT(K)=WFCIROT(ILMOS(K),JLMOS(K))  
          ALGWGAT(K)=ALGWROT(ILMOS(K),JLMOS(K))  
          ALGDGAT(K)=ALGDROT(ILMOS(K),JLMOS(K))  
c         ASVDGAT(K)=ASVDROT(ILMOS(K),JLMOS(K))  
c         ASIDGAT(K)=ASIDROT(ILMOS(K),JLMOS(K))  
c         AGVDGAT(K)=AGVDROT(ILMOS(K),JLMOS(K))  
c         AGIDGAT(K)=AGIDROT(ILMOS(K),JLMOS(K))  
          ZSNLGAT(K)=ZSNLROT(ILMOS(K),JLMOS(K))  
c         ZPLGGAT(K)=ZPLGROT(ILMOS(K),JLMOS(K))  
c         ZPLSGAT(K)=ZPLSROT(ILMOS(K),JLMOS(K))  
          TACGAT (K)=TACROT (ILMOS(K),JLMOS(K))  
          QACGAT (K)=QACROT (ILMOS(K),JLMOS(K))  
          IGDRGAT(K)=IGDRROT(ILMOS(K),JLMOS(K))
          ZBLDGAT(K)=ZBLDROW(ILMOS(K))
          Z0ORGAT(K)=Z0ORROW(ILMOS(K))
          ZRFMGAT(K)=ZRFMROW(ILMOS(K))
          ZRFHGAT(K)=ZRFHROW(ILMOS(K))
          ZDMGAT (K)=ZDMROW(ILMOS(K))
          ZDHGAT (K)=ZDHROW(ILMOS(K))
          FSVHGAT(K)=FSVHROW(ILMOS(K))
          FSIHGAT(K)=FSIHROW(ILMOS(K))
          CSZGAT (K)=CSZROW (ILMOS(K))
          FDLGAT (K)=FDLROW (ILMOS(K))
          ULGAT  (K)=ULROW  (ILMOS(K))
          VLGAT  (K)=VLROW  (ILMOS(K))
          TAGAT  (K)=TAROW  (ILMOS(K))
          QAGAT  (K)=QAROW  (ILMOS(K))
          PRESGAT(K)=PRESROW(ILMOS(K))
          PREGAT (K)=PREROW (ILMOS(K))
          PADRGAT(K)=PADRROW(ILMOS(K))
          VPDGAT (K)=VPDROW (ILMOS(K))
          TADPGAT(K)=TADPROW(ILMOS(K))
          RHOAGAT(K)=RHOAROW(ILMOS(K))
          RPCPGAT(K)=RPCPROW(ILMOS(K))
          TRPCGAT(K)=TRPCROW(ILMOS(K))
          SPCPGAT(K)=SPCPROW(ILMOS(K))
          TSPCGAT(K)=TSPCROW(ILMOS(K))
          RHSIGAT(K)=RHSIROW(ILMOS(K))
          FCLOGAT(K)=FCLOROW(ILMOS(K))
          DLONGAT(K)=DLONROW(ILMOS(K))
          GGEOGAT(K)=GGEOROW(ILMOS(K))
          RADJGAT(K)=RADJ   (ILMOS(K))
          VMODGAT(K)=VMODL  (ILMOS(K))
  100 CONTINUE
C
      DO 250 L=1,IG
      DO 200 K=1,NML
          TBARGAT(K,L)=TBARROT(ILMOS(K),JLMOS(K),L)
          THLQGAT(K,L)=THLQROT(ILMOS(K),JLMOS(K),L)
          THICGAT(K,L)=THICROT(ILMOS(K),JLMOS(K),L)
          THPGAT (K,L)=THPROT (ILMOS(K),JLMOS(K),L)
          THRGAT (K,L)=THRROT (ILMOS(K),JLMOS(K),L)
          THMGAT (K,L)=THMROT (ILMOS(K),JLMOS(K),L)
          BIGAT  (K,L)=BIROT  (ILMOS(K),JLMOS(K),L)
          PSISGAT(K,L)=PSISROT(ILMOS(K),JLMOS(K),L)
          GRKSGAT(K,L)=GRKSROT(ILMOS(K),JLMOS(K),L)
          THRAGAT(K,L)=THRAROT(ILMOS(K),JLMOS(K),L)
          HCPSGAT(K,L)=HCPSROT(ILMOS(K),JLMOS(K),L)
          TCSGAT (K,L)=TCSROT (ILMOS(K),JLMOS(K),L)
          THFCGAT(K,L)=THFCROT(ILMOS(K),JLMOS(K),L)
          PSIWGAT(K,L)=PSIWROT(ILMOS(K),JLMOS(K),L)
          DLZWGAT(K,L)=DLZWROT(ILMOS(K),JLMOS(K),L)
          ZBTWGAT(K,L)=ZBTWROT(ILMOS(K),JLMOS(K),L)
          ISNDGAT(K,L)=ISNDROT(ILMOS(K),JLMOS(K),L)
  200 CONTINUE
  250 CONTINUE
C
      DO 300 L=1,ICP1
      DO 300 K=1,NML
          FCANGAT(K,L)=FCANROT(ILMOS(K),JLMOS(K),L)
          LNZ0GAT(K,L)=LNZ0ROT(ILMOS(K),JLMOS(K),L)
          ALVCGAT(K,L)=ALVCROT(ILMOS(K),JLMOS(K),L)
          ALICGAT(K,L)=ALICROT(ILMOS(K),JLMOS(K),L)
  300 CONTINUE
C
      DO 400 L=1,IC
      DO 400 K=1,NML
          PAMXGAT(K,L)=PAMXROT(ILMOS(K),JLMOS(K),L)
          PAMNGAT(K,L)=PAMNROT(ILMOS(K),JLMOS(K),L)
          CMASGAT(K,L)=CMASROT(ILMOS(K),JLMOS(K),L)
          ROOTGAT(K,L)=ROOTROT(ILMOS(K),JLMOS(K),L)
          RSMNGAT(K,L)=RSMNROT(ILMOS(K),JLMOS(K),L)
          QA50GAT(K,L)=QA50ROT(ILMOS(K),JLMOS(K),L)
          VPDAGAT(K,L)=VPDAROT(ILMOS(K),JLMOS(K),L)
          VPDBGAT(K,L)=VPDBROT(ILMOS(K),JLMOS(K),L)
          PSGAGAT(K,L)=PSGAROT(ILMOS(K),JLMOS(K),L)
          PSGBGAT(K,L)=PSGBROT(ILMOS(K),JLMOS(K),L)
c         PAIDGAT(K,L)=PAIDROT(ILMOS(K),JLMOS(K),L)
c         HGTDGAT(K,L)=HGTDROT(ILMOS(K),JLMOS(K),L)
c         ACVDGAT(K,L)=ACVDROT(ILMOS(K),JLMOS(K),L)
c         ACIDGAT(K,L)=ACIDROT(ILMOS(K),JLMOS(K),L)
          TSFSGAT(K,L)=TSFSROT(ILMOS(K),JLMOS(K),L)
400   CONTINUE

      RETURN
      END
