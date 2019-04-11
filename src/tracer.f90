!>\file
!> Module containing all relevant subroutines for the model 
!! tracer.
!!@author Joe Melton
!!
module tracerModule

implicit none

public :: updateTracerPools
public :: decay14C
public :: fractionate13C
public :: convertTracerUnits
public :: checkTracerBalance

contains

!>\ingroup tracer_tracerDynamics
!!@{Subroutine which tracks C flow through the system.
!! No fractionation effects are applied in this subroutine. 
!! The tracer's value depends on how 
!! the model is initialized and the input file used.
!!
!! The tracer trackes the C movement through the green leaf,
!! brown leaf, root, stem, litter and soil C. Carbon that is 
!! incorporated into the plants are given a tracer value of 
!! tracerValue, which corresponds to that read in from the 
!! tracerCO2 file for the year simulated. As the simulation 
!! runs and C is transferred from the living pools to the detrital 
!! pools, the tracer also is transfered. 
!!
!! The subroutine contains a tracer pools balance check that should be 
!! run before using the tracer subroutines, in case any other model 
!! developments have not be added to the fluxes for the tracer pools but 
!! have been applied elsewhere. To do the balance check, set useTracer
!! to 1 (for simple tracer). This ensure not fractionation or decay is 
!! performed on the tracer. Ensure that the initFile tracer pool sizes 
!! are the same as the model C pools otherwise it will fail immediately.
!! Next set checkTracerBalance to True in the updateTracerPools code. This
!! replaces the read in tracerCO2 value with a value of 1, which means
!! the tracer is given the same amount of C as the normal C pools. Then
!! at the end of updateTracerPools a small section of code is called 
!! that checks that the tracer C pools are the same size as the model C pools.
!! If they differ it indicates a missing flux term in updateTracerPools or 
!! that the initFile was not set up with identical tracer and normal C pools 
!! at the start of the balance check.
!!
!> @author Joe Melton
  subroutine updateTracerPools(il1, il2, pglfmass, pblfmass,& !In
                               pstemass, protmass, plitmass,& !In
                               psocmass,pCmossmas, plitrmsmoss) !In
    
    use classic_params, only : icc, deltat, iccp2, zero, grass, ignd, nlat
    use ctem_statevars, only : tracer,c_switch,vgat

    implicit none 
    
    integer, intent(in) :: il1 !<other variables: il1=1
    integer, intent(in) :: il2 !<other variables: il2=ilg
    real, intent(in) :: pglfmass(:,:)     !< Green leaf mass for each of the CTEM PFTs at the start of ctem subroutine, \f$kg c/m^2\f$
    real, intent(in) :: pblfmass(:,:)     !< Brown leaf mass for each of the CTEM PFTs at the start of ctem subroutine, \f$kg c/m^2\f$
    real, intent(in) :: pstemass(:,:)     !< Stem mass for each of the CTEM PFTs at the start of ctem subroutine, \f$kg c/m^2\f$
    real, intent(in) :: protmass(:,:)     !< Root mass for each of the CTEM PFTs at the start of ctem subroutine, \f$kg c/m^2\f$
    real, intent(in) :: plitmass(:,:,:)   !< Litter mass for each of the CTEM PFTs + bare + LUC product pools at the start of ctem subroutine, \f$kg c/m^2\f$
    real, intent(in) :: psocmass(:,:,:)   !< Soil carbon mass for each of the CTEM PFTs + bare + LUC product pools at the start of ctem subroutine, \f$kg c/m^2\f$
    real, intent(in) :: pCmossmas(:)       !<C in moss biomass, \f$kg C/m^2\f$
    real, intent(in) :: plitrmsmoss(:)     !<moss litter mass, \f$kg C/m^2\f$

    real, pointer :: tracerGLeafMass(:,:)      !< Tracer mass in the green leaf pool for each of the CTEM pfts, \f$kg c/m^2\f$
    real, pointer :: tracerBLeafMass(:,:)      !< Tracer mass in the brown leaf pool for each of the CTEM pfts, \f$kg c/m^2\f$
    real, pointer :: tracerStemMass(:,:)       !< Tracer mass in the stem for each of the CTEM pfts, \f$kg c/m^2\f$
    real, pointer :: tracerRootMass(:,:)       !< Tracer mass in the roots for each of the CTEM pfts, \f$kg c/m^2\f$
    real, pointer :: tracerLitrMass(:,:,:)     !< Tracer mass in the litter pool for each of the CTEM pfts + bareground and LUC products, \f$kg c/m^2\f$
    real, pointer :: tracerSoilCMass(:,:,:)    !< Tracer mass in the soil carbon pool for each of the CTEM pfts + bareground and LUC products, \f$kg c/m^2\f$
    real, pointer :: tracerMossCMass(:)      !< Tracer mass in moss biomass, \f$kg C/m^2\f$
    real, pointer :: tracerMossLitrMass(:)   !< Tracer mass in moss litter, \f$kg C/m^2\f$
    real, pointer :: tracerCO2(:)           !< Tracer CO2 value read in from tracerCO2File, units vary (simple: ppm, 14C \f$\Delta ^{14}C\f$)
    real, pointer :: litresveg(:,:,:)   !<fluxes for each pft: litter respiration for each pft + bare fraction
    real, pointer :: soilcresveg(:,:,:)  !<soil carbon respiration in umol co2/m2.s, for ctem's pfts
    real, pointer :: humiftrsveg(:,:,:) !< Transfers to the soil carbon pool in umol co2/m2.s, for ctem's pfts
    real, pointer :: reprocost(:,:)   !< Cost of making reproductive tissues, only non-zero when NPP is positive (\f$\mu mol CO_2 m^{-2} s^{-1}\f$) 
    real, pointer :: tltrleaf(:,:)    !<total leaf litter fall rate (u-mol co2/m2.sec)
    real, pointer :: tltrstem(:,:)    !<total stem litter fall rate (u-mol co2/m2.sec)
    real, pointer :: tltrroot(:,:)    !<total root litter fall rate (u-mol co2/m2.sec)
    real, pointer :: blfltrdt(:,:)    !<brown leaf litter generated due to disturbance \f$(kg c/m^2)\f$
    real, pointer :: glfltrdt(:,:)    !<green leaf litter generated due to disturbance \f$(kg c/m^2)\f$
    real, pointer :: glcaemls(:,:)  !<green leaf carbon emission disturbance losses, \f$kg c/m^2\f$
    real, pointer :: blcaemls(:,:)  !<brown leaf carbon emission disturbance losses, \f$kg c/m^2\f$
    real, pointer :: rtcaemls(:,:)  !<root carbon emission disturbance losses, \f$kg c/m^2\f$
    real, pointer :: stcaemls(:,:)  !<stem carbon emission disturbance losses, \f$kg c/m^2\f$
    real, pointer :: ltrcemls(:,:)  !<litter carbon emission disturbance losses, \f$kg c/m^2\f$
    real, pointer :: ntchlveg(:,:)  !<fluxes for each pft: Net change in leaf biomass, u-mol CO2/m2.sec
    real, pointer :: ntchsveg(:,:)  !<fluxes for each pft: Net change in stem biomass, u-mol CO2/m2.sec
    real, pointer :: ntchrveg(:,:)  !<fluxes for each pft: Net change in root biomass, 
                                    !! the net change is the difference between allocation and
                                    !! autotrophic respiratory fluxes, u-mol CO2/m2.sec
    real, pointer :: mortLeafGtoB(:,:)  !< Green leaf mass converted to brown due to mortality \f$(kg C/m^2)\f$
    real, pointer :: phenLeafGtoB(:,:)  !< Green leaf mass converted to brown due to phenology \f$(kg C/m^2)\f$
    real, pointer :: fcancmx(:,:)    !< Maximum fractional coverage of CTEM PFTs, but this can be
                                     !! modified by land-use change, and competition between PFTs
    real, pointer :: leaflitr(:,:)   !< Leaf litter fall rate (\f$\mu mol CO2 m^{-2} s^{-1}\f$). 
                                     !! this leaf litter does not include litter generated 
                                     !! due to mortality/fire
    real, pointer :: rmatctem(:,:,:)   !< Fraction of roots for each of CTEM's PFTs in each soil layer
    real, pointer :: turbLitter(:,:,:) !< Litter gains/losses due to turbation [ \f$kg C/m^2\f$ ], negative is a gain.
    real, pointer :: turbSoilC(:,:,:)  !< Soil C gains/losses due to turbation [ \f$kg C/m^2\f$ ], negative is a gain.
    real, pointer :: gleafmas(:,:)     !< Green leaf mass for each of the CTEM PFTs, \f$kg c/m^2\f$
    real, pointer :: bleafmas(:,:)     !< Brown leaf mass for each of the CTEM PFTs, \f$kg c/m^2\f$
    real, pointer :: stemmass(:,:)     !< Stem mass for each of the CTEM PFTs, \f$kg c/m^2\f$
    real, pointer :: rootmass(:,:)     !< Root mass for each of the CTEM PFTs, \f$kg c/m^2\f$
    real, pointer :: litrmass(:,:,:)   !< Litter mass for each of the CTEM PFTs + bare + LUC product pools, \f$kg c/m^2\f$
    real, pointer :: soilcmas(:,:,:)   !< Soil carbon mass for each of the CTEM PFTs + bare + LUC product pools, \f$kg c/m^2\f$
    real, pointer :: Cmossmas(:)       !<C in moss biomass, \f$kg C/m^2\f$
    real, pointer :: litrmsmoss(:)     !<moss litter mass, \f$kg C/m^2\f$
    real, pointer :: gLeafLandCompChg(:,:)    !< Tracker variable for C movement due to competition and LUC in the green leaf pool  [ \f$kg C/m^2\f$ ], negative is a gain.
    real, pointer :: bLeafLandCompChg(:,:)    !< Tracker variable for C movement due to competition and LUC in the brown leaf pool  [ \f$kg C/m^2\f$ ], negative is a gain.
    real, pointer :: stemLandCompChg(:,:)   !< Tracker variable for C movement due to competition and LUC in the stem pool  [ \f$kg C/m^2\f$ ], negative is a gain.
    real, pointer :: rootLandCompChg(:,:)   !< Tracker variable for C movement due to competition and LUC in the root pool  [ \f$kg C/m^2\f$ ], negative is a gain.
    real, pointer :: litterLandCompChg(:,:,:) !< Tracker variable for C movement due to competition and LUC in the litter pool  [ \f$kg C/m^2\f$ ], negative is a gain.
    real, pointer :: soilCLandCompChg(:,:,:) !< Tracker variable for C movement due to competition and LUC in the soil C pool  [ \f$kg C/m^2\f$ ], negative is a gain.
    integer, pointer :: ipeatland(:) !<Peatland flag: 0 = not a peatland, 1= bog, 2 = fen
    
    ! Local
    integer :: i,j,k
    real :: gains, losses
    real :: convertUnits      !< This converts the units from u-mol CO2/m2.sec to kg C/m^2
    real :: tracerValue(nlat) !< Temporary variable containing the tracer CO2 value to be used. Units vary.
    logical :: doTracerBalance  !< Logical to determine if the tracer pool balance check is performed.
    
    ! Point pointers 
    tracerCO2         => tracer%tracerCO2rot
    tracerGLeafMass   => tracer%gLeafMassgat
    tracerBLeafMass   => tracer%bLeafMassgat
    tracerStemMass    => tracer%stemMassgat
    tracerRootMass    => tracer%rootMassgat
    tracerLitrMass    => tracer%litrMassgat
    tracerSoilCMass   => tracer%soilCMassgat
    tracerMossCMass   => tracer%mossCMassgat
    tracerMossLitrMass => tracer%mossLitrMassgat
    litresveg         => vgat%litresveg
    soilcresveg       => vgat%soilcresveg
    humiftrsveg       => vgat%humiftrsveg
    reprocost         => vgat%reprocost
    tltrleaf          => vgat%tltrleaf
    tltrstem          => vgat%tltrstem
    tltrroot          => vgat%tltrroot
    blfltrdt          => vgat%blfltrdt
    glfltrdt          => vgat%glfltrdt
    glcaemls          => vgat%glcaemls
    blcaemls          => vgat%blcaemls
    rtcaemls          => vgat%rtcaemls
    stcaemls          => vgat%stcaemls
    ltrcemls          => vgat%ltrcemls
    ntchlveg          => vgat%ntchlveg
    ntchsveg          => vgat%ntchsveg
    ntchrveg          => vgat%ntchrveg
    mortLeafGtoB      => vgat%mortLeafGtoB
    phenLeafGtoB      => vgat%phenLeafGtoB
    fcancmx           => vgat%fcancmx
    leaflitr          => vgat%leaflitr
    rmatctem          => vgat%rmatctem
    turbLitter        => vgat%turbLitter
    turbSoilC         => vgat%turbSoilC
    gleafmas          => vgat%gleafmas
    bleafmas          => vgat%bleafmas
    stemmass          => vgat%stemmass
    rootmass          => vgat%rootmass
    litrmass          => vgat%litrmass
    soilcmas          => vgat%soilcmas
    Cmossmas          => vgat%Cmossmas
    litrmsmoss        => vgat%litrmsmoss
    gLeafLandCompChg  => vgat%gLeafLandCompChg
    bLeafLandCompChg  => vgat%bLeafLandCompChg
    stemLandCompChg  => vgat%stemLandCompChg
    rootLandCompChg  => vgat%rootLandCompChg
    litterLandCompChg => vgat%litterLandCompChg
    soilCLandCompChg  => vgat%soilCLandCompChg
    ipeatland        => vgat%ipeatland 
    
    ! ---------
    
    convertUnits = deltat / 963.62
    
    ! Set to true if you want to check for tracer balance. 
    ! NOTE: See the comments in the header for how to set 
    ! up run for this check.
    doTracerBalance = .false.

    ! If doTracerBalance is true, Check for mass balance for the tracer.
    !  First set the tracer CO2 value to 1 so it gets the same inputs as the 
    ! model CO2 pools. Otherwise just use the read in tracerValue.   
    if (doTracerBalance) then 
      tracerValue = 1.
    else
      tracerValue = tracerCO2
    end if 
      
    !> We don't need to do any conversion of the carbon that is uptaked
    !! in this timestep. We assume that the tracerValue should just be applied as is.
    do i = il1, il2 
      do j = 1, iccp2
        if (j <= icc) then !these are just icc sized arrays.
          if (fcancmx(i,j) > zero) then
                        
            ! *** Update the green leaves *** 
                        
            if (ntchlveg(i,j) > 0.) then ! NPP was positive to leaves
              gains = ntchlveg(i,j) * convertUnits * tracerValue(i)  
            else ! loss of C from leaves due to negative NPP.
              gains = ntchlveg(i,j) * convertUnits  
            end if
            ! tltrleaf (phenology litter, mortality, disturbance) includes brown leaf
            ! generation from disturbance so remove that)
            if (.not. grass(j) ) then
              losses = (tltrleaf(i,j) - (blfltrdt(i,j)/convertUnits)) * convertUnits & 
                       + glcaemls(i,j) * convertUnits !combusted by fire.
            else 
              losses = glfltrdt(i,j) & !green leaf litter generated by fire.
                       + mortLeafGtoB(i,j) & !mortality transfer to brown leaves, only >0 for grasses
                       + phenLeafGtoB(i,j) & !phenology transfer to brown leaves, only >0 for grasses
                       + glcaemls(i,j) * convertUnits !combusted by fire.
            end if 
                     
            !> When the tracer is calculated we apply the gain and losses to the exisiting
            !! pool. We also include the gains/losses due to changing PFT areas after land 
            !! use change or competition. 
            print*,gains,losses,tracerValue(i)
            tracerGLeafMass(i,j) = tracerGLeafMass(i,j) + gains - losses - gLeafLandCompChg(i,j)
            
            if (tracerGLeafMass(i,j) < zero) tracerGLeafMass(i,j) = 0.
 
            ! ***  Update brown leaves (grass only) *** 
            if (grass(j) ) then
              gains = phenLeafGtoB(i,j) & ! phenology transfer to brown leaves, only >0 for grasses
                      + mortLeafGtoB(i,j) ! mortality transfer to brown leaves, only >0 for grasses
              
              losses = leaflitr(i,j)  * convertUnits & ! phenology litter generation.
                       + blfltrdt(i,j) & !brown leaf litter generated by fire.
                       + blcaemls(i,j) * convertUnits !combusted by fire.
              
              tracerBLeafMass(i,j) = tracerBLeafMass(i,j) + gains - losses - bLeafLandCompChg(i,j)
              if (tracerBLeafMass(i,j) < zero) tracerBLeafMass(i,j) = 0.
            end if 
            
            ! ***  Update stem mass (all except grass) *** 
            if (.not. grass(j)) then
            
              if (ntchsveg(i,j) > 0.) then ! NPP was positive to leaves
                gains = ntchsveg(i,j) * convertUnits * tracerValue(i)  
              else ! loss of C from leaves due to negative NPP.
                gains = ntchsveg(i,j) * convertUnits  
              end if

              losses = tltrstem(i,j) * convertUnits & !turnover, mortality, disturbance => litter.
                      + stcaemls(i,j) * convertUnits ! combusted by fire.
              
              tracerStemMass(i,j) = tracerStemMass(i,j) + gains - losses - stemLandCompChg(i,j)
              if (tracerStemMass(i,j) < zero) tracerStemMass(i,j) = 0.
              
            end if 
            
            ! ***  Update root mass *** 
            if (ntchrveg(i,j) > 0.) then ! NPP was positive to leaves
              gains = ntchrveg(i,j) * convertUnits * tracerValue(i)  
            else ! loss of C from leaves due to negative NPP.
              gains = ntchrveg(i,j) * convertUnits  
            end if
            
            losses = tltrroot(i,j) * convertUnits &
                    + rtcaemls(i,j) * convertUnits
                    
            tracerRootMass(i,j) = tracerRootMass(i,j) + gains - losses - rootLandCompChg(i,j)
            if (tracerRootMass(i,j) < zero) tracerRootMass(i,j) = 0.

          end if         
          if (rootmass(i,j) < zero) tracerRootMass(i,j) = 0.
          if (stemmass(i,j) < zero) tracerStemMass(i,j) = 0.
          if (bleafmas(i,j) < zero) tracerBLeafMass(i,j) = 0.
          if (gleafmas(i,j) < zero) tracerGLeafMass(i,j) = 0.
        end if
      
        ! ***  Update litter mass *** 
        do k = 1, ignd
          if (j <= icc) then 
            if (k == 1) then 
              ! surface gains 
              gains = (tltrleaf(i,j) & !leaf litter 
                      + tltrstem(i,j) & ! stem 
                      + tltrroot(i,j) * rmatctem(i,j,k) & ! root 
                      + reprocost(i,j))  * convertUnits  ! reproductive tissues
              losses = (litresveg(i,j,k)  & !litter respiration
                      + humiftrsveg(i,j,k) &  ! humification
                      + ltrcemls(i,j)) * convertUnits !combusted
            else 
              ! deeper layers 
              gains = tltrroot(i,j) * rmatctem(i,j,k)  * convertUnits !from roots only.
              losses = (litresveg(i,j,k)  & !litter respiration
                      + humiftrsveg(i,j,k)) * convertUnits !humification
            end if                
          else ! bareground or LUC product pools
            gains = 0. ! The gains come from LUC, so are in the litterLandCompChg term.
            losses = (litresveg(i,j,k)  & !litter respiration
                    + humiftrsveg(i,j,k)) * convertUnits  ! humification
          end if 
          
          ! Litter mass is mixed by soil turbation (cryo, bio) so we also consider the turbation movements
          ! but LUC product pools are not considered to be turbated.
          if (j < iccp2) then
            tracerLitrMass(i,j,k) = tracerLitrMass(i,j,k) + gains - losses &
                                                          - turbLitter(i,j,k) &
                                                          - litterLandCompChg(i,j,k)
          else 
            tracerLitrMass(i,j,k) = tracerLitrMass(i,j,k) + gains - losses  - litterLandCompChg(i,j,k)
          end if 
          if (tracerLitrMass(i,j,k) < zero) tracerLitrMass(i,j,k) = 0.
        end do 
                
        ! ***  Update soil C mass ***          
        do k = 1, ignd
          gains = humiftrsveg(i,j,k) * convertUnits ! humification 
          losses = soilcresveg(i,j,k) * convertUnits ! respiration 
          if (j < iccp2) then
            tracerSoilCMass(i,j,k) = tracerSoilCMass(i,j,k) + gains - losses &
                                                            - turbSoilC(i,j,k)&
                                                            - soilCLandCompChg(i,j,k)         
          else ! no turbation of LUC product pools.
            tracerSoilCMass(i,j,k) = tracerSoilCMass(i,j,k) + gains - losses - soilCLandCompChg(i,j,k)
          end if
          if (tracerSoilCMass(i,j,k) < zero) tracerSoilCMass(i,j,k) = 0.
        end do
        
        if (sum(litrmass(i,j,:)) < zero) tracerLitrMass(i,j,:) = 0.
        if (sum(soilcmas(i,j,:)) < zero) tracerSoilCMass(i,j,:) = 0.       
           
      end do ! j 
      
      if (ipeatland(i) > 0) print*,'Tracer not set up yet for peatlands.'
      
    end do ! i 
    
    ! Check for mass balance for the tracer.
    if (doTracerBalance) call checkTracerBalance(il1,il2)
  
  end subroutine updateTracerPools
!!@}
! -------------------------------------------------------
!>\ingroup tracer_decay14C
!!@{Calculates the decay of \f$^{14}C\f$ in the tracer pools.
!!
!! Once a year we calculate the decay of \f$^{14}C\f$ in the tracer pools.
!! This calculation is only called if useTracer == 2. 
!! If using spinfast to equilibrate the model we need to 
!! adjust the decay of 14C in the model soil C pool. Since 
!! spinfast increases the turnover time of soil C by the factor 
!! 1/spinfast, the 14C in the soils generated with a spinfast > 1 
!! will be too young by the same factor. Following Koven et al .2013 
!! \cite Koven2013-dd we adjust for that faster equilbration by
!! increasing the decay in the soil C tracer pool by spinfast.
!!@author Joe Melton
  subroutine decay14C(il1,il2)
    
    use ctem_statevars, only : c_switch,iccp2,icc,tracer,ignd
    use classic_params, only : lambda14C

    implicit none 

    integer, intent(in) :: il1 !<other variables: il1=1
    integer, intent(in) :: il2 !<other variables: il2=ilg
            
    real, pointer :: tracerGLeafMass(:,:)      !< Tracer mass in the green leaf pool for each of the CTEM pfts, \f$kg c/m^2\f$
    real, pointer :: tracerBLeafMass(:,:)      !< Tracer mass in the brown leaf pool for each of the CTEM pfts, \f$kg c/m^2\f$
    real, pointer :: tracerStemMass(:,:)       !< Tracer mass in the stem for each of the CTEM pfts, \f$kg c/m^2\f$
    real, pointer :: tracerRootMass(:,:)       !< Tracer mass in the roots for each of the CTEM pfts, \f$kg c/m^2\f$
    real, pointer :: tracerLitrMass(:,:,:)     !< Tracer mass in the litter pool for each of the CTEM pfts + bareground and LUC products, \f$kg c/m^2\f$
    real, pointer :: tracerSoilCMass(:,:,:)    !< Tracer mass in the soil carbon pool for each of the CTEM pfts + bareground and LUC products, \f$kg c/m^2\f$
    real, pointer :: tracerMossCMass(:)      !< Tracer mass in moss biomass, \f$kg C/m^2\f$
    real, pointer :: tracerMossLitrMass(:)   !< Tracer mass in moss litter, \f$kg C/m^2\f$
    integer, pointer :: spinfast              !< Set this to a higher number up to 10 to spin up
                                              !< soil carbon pool faster

    integer  :: i,j,k    !counters
    real :: dfac    !< decay constant. \f$y^{-1}\f$

    !point pointers
    tracerGLeafMass   => tracer%gLeafMassgat
    tracerBLeafMass   => tracer%bLeafMassgat
    tracerStemMass    => tracer%stemMassgat
    tracerRootMass    => tracer%rootMassgat
    tracerLitrMass    => tracer%litrMassgat
    tracerSoilCMass   => tracer%soilCMassgat
    tracerMossCMass   => tracer%mossCMassgat
    tracerMossLitrMass => tracer%mossLitrMassgat
    spinfast          => c_switch%spinfast
    !----------
    !begin calculations
    
    dfac = exp(-1. / lambda14C)
        
    do i = il1, il2 
      tracerMossCMass = ((tracerMossCMass(i) + 1.) * dfac) - 1.
      tracerMossLitrMass = ((tracerMossLitrMass(i) + 1.) * dfac) - 1.
      do j = 1, iccp2
        if (j <= icc) then
          tracerGLeafMass(i,j) = ((tracerGLeafMass(i,j) + 1.) * dfac) - 1.
          tracerBLeafMass(i,j) = ((tracerBLeafMass(i,j) + 1.) * dfac) - 1.
          tracerStemMass(i,j) = ((tracerStemMass(i,j) + 1.) * dfac) - 1.
          tracerRootMass(i,j) = ((tracerRootMass(i,j) + 1.) * dfac) - 1.
        end if  
        do k = 1, ignd
          tracerLitrMass(i,j,k) = ((tracerLitrMass(i,j,k) + 1.) * dfac) - 1.
          tracerSoilCMass(i,j,k) = ((tracerSoilCMass(i,j,k) + 1.) * dfac * spinfast) - 1.
        end do
      end do
    end do

  end subroutine decay14C
!!@}
! -------------------------------------------------------
!>\ingroup tracer_fractionate13C
!!@{ 13C tracer -- NOT IMPLEMENTED YET.
  subroutine fractionate13C()
    
    use ctem_statevars, only : c_switch

    implicit none 
    
    print*,'fractionate13C: Not implemented yet. Usetracer cannot == 3!'
    call xit('tracer',-1)
  end subroutine fractionate13C
!!@}
! -------------------------------------------------------
!>\ingroup tracer_convertTracerUnits
!!@{Converts the units of the tracers, depending on the tracer
!! being simulated.
!! 
!! If the tracer is a simple tracer, no conversion of units is needed.
!! If the tracer is \f$^{14}C\f$ then we apply a conversion as follows.
!! Incoming units expected are \f$\Delta ^{14}C\f$ reported
!! relative to the Modern standard, including corrections for
!! age and fractionation following Stuiver and Polach 1977 \cite Stuiver1977-yj
!! 
!! \f$\Delta ^{14}C = 1000 \left( \left[ 1 + \frac{\delta ^{14}C}{1000} \right]
!! \frac{0.975^2}{1 + \frac{\delta ^{13}C}{1000}} - 1 \right)\f$
!!
!! Here \f$\delta ^{14}C\f$ is  the  measured value and \f$\Delta ^{14}C\f$ corrects
!! for isotopic fractionation by mass-dependent processes. The 0.975 term is the 
!! fractionation of \f$^{13}C\f$ by photosynthesis. Since we have only one tracer
!! we make a few simplifying assumptions. First we assume that no fractionation of
!! \f$^{14}C\f$ occurs, thus 0.975 becomes 1 and the \f$\delta ^{13}C\f$ becomes 0.
!! \f$\Delta ^{14}C\f$ then simplifies to \f$\delta ^{14}C\f$ and becomes:
!! 
!! \f$\Delta ^{14}C = \delta ^{14}C = 1000 \left(\frac{A_s}{A_{abs}} - 1 \right)\f$
!!
!! where the \f$A_s\f$ is the \f$^{14}C/C\f$ ratio in a given sample. We follow Koven 
!! et al. (2013) \cite Koven2013-dd in assuming a background preindustrial atmospheric
!! \f$^{14}C/C\f$ ratio (\f$A_{abs}\f$) of \f$10^{-12}\f$. Technically, the standard value of this is 
!! 0.2260 \f$\pm\f$ 0.0012 Bq/gC where a Bq is 433.2 x \f$10^{-15}\f$ mole (\f$^{14}C\f$).
!! The \f$^{14}C/C\f$ ratio, or \f$A_s\f$ can then be solved to be:
!!
!! \f$ A_s = 10^{-12}\left( \frac{\Delta ^{14}C}{1000} + 1 \right)\f$
!!
!!@author Joe Melton
function convertTracerUnits(tracerco2conc)
  
  use ctem_statevars, only : c_switch,tracer,nlat  
  
  implicit none 
  
  real, dimension(nlat) :: convertTracerUnits
  real, dimension(:), intent(in) :: tracerco2conc
  integer, pointer :: useTracer !< useTracer = 0, the tracer code is not used. 
                      ! useTracer = 1 turns on a simple tracer that tracks pools and fluxes. The simple tracer then requires that the 
                      !               tracer values in the init_file and the tracerCO2file are set to meaningful values for the experiment being run.                         
                      ! useTracer = 2 means the tracer is 14C and will then call a 14C decay scheme. 
                      ! useTracer = 3 means the tracer is 13C and will then call a 13C fractionation scheme. 
  
  useTracer         => c_switch%useTracer
  
  ! ------------------------
  
  if (useTracer == 0) then 
    
    print*,'Error, entered convertTracerUnits with a useTracer value of 0'
    call xit('tracer',1)
    
  else if (useTracer == 1) then 
    
    ! Simple tracer, no conversion of units needed.
    convertTracerUnits = tracerco2conc
    
  else if (useTracer == 2) then 
    
    ! Incoming units expected are \Delta ^{14}C so need to convert to 14C/C ratio   
    convertTracerUnits(:) = (tracerco2conc(:) / 1000. + 1.) * 1E-12
    
  else if (useTracer == 3) then 
    
    print*,'convertTracerUnits: Error, 13C not implemented (useTracer == 3 used)'
    call xit('tracer',2)
    
  end if

end function convertTracerUnits
!!@}
! -------------------------------------------------------
!>\ingroup tracer_checkTracerBalance
!! Checks for balance between the tracer pools and the 
!! model normal C pools. The subroutine is called when 
!! the doTracerBalance logical is set to true in updateTracerPools
!! and the model initFile is set up as described in the 
!! notes of updateTracerPools. checkTracerBalance uses the 
!! same tolerance for comparisions as balcar.
!!@author Joe Melton
subroutine checkTracerBalance(il1,il2)
  
  use classic_params, only : icc, iccp2, ignd, tolrance
  use ctem_statevars, only : tracer,vgat,c_switch

  implicit none 
  
  integer, intent(in) :: il1 !<other variables: il1=1
  integer, intent(in) :: il2 !<other variables: il2=ilg

  real, pointer :: tracerGLeafMass(:,:)      !< Tracer mass in the green leaf pool for each of the CTEM pfts, \f$kg c/m^2\f$
  real, pointer :: tracerBLeafMass(:,:)      !< Tracer mass in the brown leaf pool for each of the CTEM pfts, \f$kg c/m^2\f$
  real, pointer :: tracerStemMass(:,:)       !< Tracer mass in the stem for each of the CTEM pfts, \f$kg c/m^2\f$
  real, pointer :: tracerRootMass(:,:)       !< Tracer mass in the roots for each of the CTEM pfts, \f$kg c/m^2\f$
  real, pointer :: tracerLitrMass(:,:,:)     !< Tracer mass in the litter pool for each of the CTEM pfts + bareground and LUC products, \f$kg c/m^2\f$
  real, pointer :: tracerSoilCMass(:,:,:)    !< Tracer mass in the soil carbon pool for each of the CTEM pfts + bareground and LUC products, \f$kg c/m^2\f$
  real, pointer :: tracerMossCMass(:)      !< Tracer mass in moss biomass, \f$kg C/m^2\f$
  real, pointer :: tracerMossLitrMass(:)   !< Tracer mass in moss litter, \f$kg C/m^2\f$
  real, pointer :: gleafmas(:,:)     !< Green leaf mass for each of the CTEM PFTs, \f$kg c/m^2\f$
  real, pointer :: bleafmas(:,:)     !< Brown leaf mass for each of the CTEM PFTs, \f$kg c/m^2\f$
  real, pointer :: stemmass(:,:)     !< Stem mass for each of the CTEM PFTs, \f$kg c/m^2\f$
  real, pointer :: rootmass(:,:)     !< Root mass for each of the CTEM PFTs, \f$kg c/m^2\f$
  real, pointer :: litrmass(:,:,:)   !< Litter mass for each of the CTEM PFTs + bare + LUC product pools, \f$kg c/m^2\f$
  real, pointer :: soilcmas(:,:,:)   !< Soil carbon mass for each of the CTEM PFTs + bare + LUC product pools, \f$kg c/m^2\f$
  integer, pointer :: useTracer !< useTracer = 0, the tracer code is not used. 
                      ! useTracer = 1 turns on a simple tracer that tracks pools and fluxes. The simple tracer then requires that the 
                      !               tracer values in the init_file and the tracerCO2file are set to meaningful values for the experiment being run.                         
                      ! useTracer = 2 means the tracer is 14C and will then call a 14C decay scheme. 
                      ! useTracer = 3 means the tracer is 13C and will then call a 13C fractionation scheme. 

  integer :: i,j,k 
  
  tracerGLeafMass   => tracer%gLeafMassgat
  tracerBLeafMass   => tracer%bLeafMassgat
  tracerStemMass    => tracer%stemMassgat
  tracerRootMass    => tracer%rootMassgat
  tracerLitrMass    => tracer%litrMassgat
  tracerSoilCMass   => tracer%soilCMassgat
  tracerMossCMass   => tracer%mossCMassgat
  tracerMossLitrMass => tracer%mossLitrMassgat
  gleafmas          => vgat%gleafmas
  bleafmas          => vgat%bleafmas
  stemmass          => vgat%stemmass
  rootmass          => vgat%rootmass
  litrmass          => vgat%litrmass
  soilcmas          => vgat%soilcmas
  useTracer         => c_switch%useTracer
  
  ! ---------
  
  if (useTracer /= 1) then
    print*,'checkTracerBalance: useTracer must == 1 for this check, you have:',useTracer 
    print*,'Ending run.'
    call xit('checkTracerBalance',1)
  end if 
  
  do i = il1, il2
    do j = 1, iccp2
      if (j <= icc) then 

        ! green leaf mass 
        if (abs(tracerGLeafMass(i,j) - gleafmas(i,j)) > tolrance) then 
          print*,'checkTracerBalance: Tracer balance fail for green leaf mass'
          print*,i,'PFT',j,'tracerGLeafMass',tracerGLeafMass(i,j),&
                    'gleafmas',gleafmas(i,j)   
          call xit('checkTracerBalance',-1)
        end if 
         
        ! brown leaf mass 
        if (abs(tracerBLeafMass(i,j) - bleafmas(i,j)) > tolrance) then 
          print*,'checkTracerBalance: Tracer balance fail for brown leaf mass'
          print*,i,'PFT',j,'tracerBLeafMass',tracerBLeafMass(i,j),&
                    'bleafmas',bleafmas(i,j)        
          call xit('checkTracerBalance',-2)
        end if 
        
        ! stem mass 
        if (abs(tracerStemMass(i,j) - stemmass(i,j)) > tolrance) then 
          print*,'checkTracerBalance: Tracer balance fail for stem mass'
          print*,i,'PFT',j,'tracerStemMass',tracerStemMass(i,j),&
                    'stemmass',stemmass(i,j)   
          call xit('checkTracerBalance',-1)
        end if 
        
        ! root mass 
        if (abs(tracerRootMass(i,j) - rootmass(i,j)) > tolrance) then 
          print*,'checkTracerBalance: Tracer balance fail for root mass'
          print*,i,'PFT',j,'tracerRootMass',tracerRootMass(i,j),&
                    'rootmass',rootmass(i,j)      
          call xit('checkTracerBalance',-1)
        end if 
      end if 

      do k = 1, ignd
        ! green leaf mass 
        if (abs(tracerLitrMass(i,j,k) - litrmass(i,j,k)) > tolrance) then 
          print*,'checkTracerBalance: Tracer balance fail for litter mass'
          print*,i,'PFT',j,'layer',k,'tracerLitrMass',tracerLitrMass(i,j,k),&
                    'litrmass',litrmass(i,j,k)            
          call xit('checkTracerBalance',-1)
        end if 
        ! green leaf mass 
        if (abs(tracerSoilCMass(i,j,k) - soilcmas(i,j,k)) > tolrance) then 
          print*,'checkTracerBalance: Tracer balance fail for soil C mass'
          print*,i,'PFT',j,'layer',k,'tracerSoilCMass',tracerSoilCMass(i,j,k),&
                    'soilcmas',soilcmas(i,j,k)    
          call xit('checkTracerBalance',-1)
        end if 
      end do 
    end do
  end do  

end subroutine checkTracerBalance
!!@}
! -------------------------------------------------------

!>\namespace tracer
!!
!!
!>\file
end module tracerModule
