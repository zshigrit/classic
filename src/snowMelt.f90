!> \file
!! Addresses melting of the snow pack.
!! @author D. Verseghy, M. Lazare
!
subroutine snowMelt(ZSNOW,TSNOW,QMELT,R,TR,GZERO,RALB, &
                  HMFN,HTCS,HTC,FI,HCPSNO,RHOSNO,WSNOW, &
                  ISAND,IG,ILG,IL1,IL2,JL)
  !
  !     * APR 22/16 - D.VERSEGHY. BUG FIX IN CALCULATION OF HTCS.
  !     * JAN 06/09 - D.VERSEGHY/M.LAZARE. SPLIT 100 LOOP INTO TWO.
  !     * MAR 24/06 - D.VERSEGHY. ALLOW FOR PRESENCE OF WATER IN SNOW.
  !     * SEP 24/04 - D.VERSEGHY. ADD "IMPLICIT NONE" COMMAND.
  !     * JUL 26/02 - D.VERSEGHY. SHORTENED CLASS4 COMMON BLOCK.
  !     * JUN 20/97 - D.VERSEGHY. CLASS - VERSION 2.7.
  !     *                         MODIFICATIONS TO ALLOW FOR VARIABLE
  !     *                         SOIL PERMEABLE DEPTH.
  !     * JAN 02/95 - D.VERSEGHY. CLASS - VERSION 2.5.
  !     *                         COMPLETION OF ENERGY BALANCE
  !     *                         DIAGNOSTICS.
  !     * AUG 18/95 - D.VERSEGHY. CLASS - VERSION 2.4.
  !     *                         REVISIONS TO ALLOW FOR INHOMOGENEITY
  !     *                         BETWEEN SOIL LAYERS.
  !     * JUL 30/93 - D.VERSEGHY/M.LAZARE. CLASS - VERSION 2.2.
  !     *                                  NEW DIAGNOSTIC FIELDS.
  !     * APR 24/92 - D.VERSEGHY/M.LAZARE. CLASS - VERSION 2.1.
  !     *                                  REVISED AND VECTORIZED CODE
  !     *                                  FOR MODEL VERSION GCM7.
  !     * AUG 12/91 - D.VERSEGHY. CODE FOR MODEL VERSION GCM7U -
  !     *                         CLASS VERSION 2.0 (WITH CANOPY).
  !     * APR 11/89 - D.VERSEGHY. MELTING OF SNOWPACK.
  !
  use classic_params, only : DELT,TFREZ,HCPW,HCPICE, &
                            RHOW,RHOICE,CLHMLT

  implicit none
  !
  !     * INTEGER CONSTANTS.
  !
  integer, intent(in) :: IG,ILG,IL1,IL2,JL
  integer :: I
  !
  !     * INPUT/OUTPUT ARRAYS.
  !
  real, intent(inout) :: HTC (ILG,IG) !< Internal energy change of soil layer due to conduction and/or change in mass \f$[W m^{-2}]\f$
  real, intent(inout) :: ZSNOW (ILG)  !< Depth of snow pack [m]
  real, intent(inout) :: TSNOW (ILG)  !< Temperature of the snow pack [C]
  real, intent(inout) :: QMELT (ILG)  !< Energy available for melting of snow \f$[W m^{-2}]\f$
  real, intent(inout) :: R     (ILG)  !< Rainfall rate \f$[m s^{-1}]\f$
  real, intent(inout) :: TR    (ILG)  !< Temperature of rainfall [C]
  real, intent(inout) :: GZERO (ILG)  !< Heat flow into soil surface \f$[W m^{-2}]\f$
  real, intent(out)   :: RALB  (ILG)  !< Rainfall rate saved for snow albedo calculations \f$[m s^{-1}]\f$
  real, intent(inout) :: HMFN  (ILG)  !< Energy associated with freezing or thawing of water in the snow pack \f$[W m^{-2}]\f$
  real, intent(inout) :: HTCS  (ILG)  !< Internal energy change of snow pack due to conduction and/or change in mass \f$[W m^{-2}]\f$
  !
  !     * INPUT ARRAYS.
  !
  real, intent(in) :: FI    (ILG)  !< Fractional coverage of subarea in question on modelled area [ ]
  real, intent(inout) :: HCPSNO(ILG)  !< Heat capacity of snow pack \f$[J m^{-3} K^{-1}]\f$
  real, intent(in) :: RHOSNO(ILG)  !< Density of snow pack \f$[kg m^{-3}]\f$
  real, intent(inout) :: WSNOW (ILG)  !< Liquid water content of snow pack \f$[kg m^{-2}]\f$
  integer, intent(in) :: ISAND (ILG,IG) !< Sand content flag
  !
  !     * TEMPORARY VARIABLES.
  !
  real :: HADD,HCONV,ZMELT,RMELT,RMELTS,TRMELT
  !
  !-----------------------------------------------------------------------
  !>
  !! Melting of the snow pack occurs if a source of available energy
  !! QMELT is produced as a result of the solution of the surface
  !! energy balance, or if the snow pack temperature is projected to
  !! go above 0 C in the current time step (the available energy thus
  !! produced is added to QMELT in subroutine snowTempUpdate). The change in
  !! internal energy in the snow pack is calculated at the beginning
  !! and end of the subroutine, and stored in diagnostic variable HTCS
  !! (see notes on subroutine snowAddNew).
  !!
  !! The calculations in the 100 loop are performed if QFREZ and the
  !! snow depth ZSNOW are both greater than zero. The available energy
  !! HADD to be applied to the snow pack is calculated from QMELT. The
  !! amount of energy required to raise the snow pack temperature to
  !! 0 C and melt it completely is calculated as HCONV. If HADD \f$\leq\f$
  !! HCONV, the depth of snow ZMELT that is warmed to 0 C and melted
  !! is calculated from HADD. (It is assumed that melting of an upper
  !! layer of snow can occur even if the lower part of the snow pack
  !! is still below 0 C.) The amount of water generated by melting
  !! the snow, RMELTS, is calculated from ZMELT, and the temperature
  !! of the meltwater TRMELT is set to 0 C. ZMELT is subtracted from
  !! ZSNOW, the heat capacity of the snow is recalculated, and HTCS is
  !! corrected for the amount of heat used to warm the removed portion
  !! of the snow pack.
  !!
  !! If HADD > HCONV, the amount of available energy is sufficient to
  !! warm and melt the whole snow pack, with some energy left over.
  !! The amount of water generated by melting the snow, RMELTS, is
  !! calculated from ZSNOW, and the total amount of water reaching the
  !! soil, RMELT, is obtained by adding the liquid water content of
  !! the snow pack, WSNOW, to RMELTS. HADD is recalculated as HADD –
  !! HCONV, and used to calculate TRMELT. The snow depth, heat
  !! capacity, temperature and water content are set to zero, and HTCS
  !! is corrected for the amount of heat that was used to warm the
  !! snow pack to 0 C.
  !!
  do I = IL1,IL2 ! loop 100
    if (FI(I) > 0.) then
      if (QMELT(I) > 0. .and. ZSNOW(I) > 0.) then
        HTCS(I) = HTCS(I) - FI(I) * HCPSNO(I) * (TSNOW(I) + TFREZ) * &
                     ZSNOW(I) / DELT
        HADD = QMELT(I) * DELT
        HCONV = (0.0 - TSNOW(I)) * HCPSNO(I) * ZSNOW(I) + &
                           CLHMLT * RHOSNO(I) * ZSNOW(I)
        if (HADD <= HCONV) then
          ZMELT = HADD / ((0.0 - TSNOW(I)) * HCPSNO(I) + &
                       CLHMLT * RHOSNO(I))
          RMELTS = ZMELT * RHOSNO(I) / (RHOW * DELT)
          RMELT = RMELTS
          TRMELT = 0.0
          ZSNOW(I) = ZSNOW(I) - ZMELT
          HCPSNO(I) = HCPICE * RHOSNO(I) / RHOICE + HCPW * WSNOW(I) / &
                     (RHOW * ZSNOW(I))
          HTCS (I) = HTCS(I) - FI(I) * (QMELT(I) - CLHMLT * RMELT * &
                          RHOW)
        else
          RMELTS = ZSNOW(I) * RHOSNO(I) / RHOW
          RMELT = RMELTS + WSNOW(I) / RHOW
          HADD = HADD - HCONV
          TRMELT = HADD / (HCPW * RMELT)
          RMELT = RMELT / DELT
          RMELTS = RMELTS / DELT
          ZSNOW (I) = 0.0
          HCPSNO(I) = 0.0
          TSNOW (I) = 0.0
          WSNOW (I) = 0.0
          HTCS (I) = HTCS(I) - FI(I) * (QMELT(I) - CLHMLT * RMELTS * &
                          RHOW)
        end if
        !>
        !! After the IF block, the diagnostic variable HMFN
        !! describing melting or freezing of water in the snow
        !! pack is updated using RMELTS, the temperature of the
        !! rainfall rate reaching the soil is updated using
        !! TRMELT, and RMELT is added to the rainfall rate R.
        !! QMELT is set to zero, and a flag variable RALB, used
        !! later in subroutine snowAging, is set to the rainfall
        !! rate reaching the ground.
        !!
        HMFN (I) = HMFN(I) + FI(I) * CLHMLT * RMELTS * RHOW
        TR   (I) = (R(I) * TR(I) + RMELT * TRMELT) / (R(I) + RMELT)
        R    (I) = R(I) + RMELT
        QMELT(I) = 0.0
        HTCS(I) = HTCS(I) + FI(I) * HCPSNO(I) * (TSNOW(I) + TFREZ) * &
        ZSNOW(I) / DELT
      end if
      RALB(I) = R(I)
    end if
  end do ! loop 100
  !
  !>
  !! In the 200 loop, a check is performed to see whether QMELT is
  !! still greater than zero and the modelled area is not an ice sheet
  !! (ISAND > -4). In this case QMELT is added to the ground heat flux
  !! GZERO, and the internal energy diagnostics HTCS and HTC for the
  !! snow and soil respectively are corrected. The flag variable RALB
  !! is evaluated as above.
  !!
  do I = IL1,IL2 ! loop 200
    if (FI(I) > 0.) then
      if (QMELT(I) > 0. .and. ISAND(I,1) > - 4) then
        GZERO(I) = GZERO(I) + QMELT(I)
        HTCS (I) = HTCS(I) - FI(I) * QMELT(I)
        HTC(I,1) = HTC(I,1) + FI(I) * QMELT(I)
      end if
      RALB(I) = R(I)
    end if
  end do ! loop 200
  !
  return
end
