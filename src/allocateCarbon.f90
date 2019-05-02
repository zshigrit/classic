!>\file
!! Performs allocation of carbon gained by photosynthesis into plant structural pools
!!@author Vivek Arora, Joe Melton
!!
module allocateCarbon

    implicit none

    public :: allocate
    public :: updatePoolsAllocateRepro

contains

  !>\ingroup allocateCarbon_allocate
  !!@{
  !> Performs allocation of carbon gained by photosynthesis into plant structural pools
  !> @author Vivek Arora and Joe Melton
  subroutine allocate(lfstatus,    thliq,    ailcg,     ailcb,& ! In
                      il1,      il2,      ilg,      sand,  & ! In
                      clay,  rmatctem, gleafmas, stemmass, & ! In
                      rootmass,      sort,  fcancmx, & ! In
                      isand,      THFC,     THLW,& ! In
                      afrleaf,  afrstem,  afrroot,& ! Out 
                      wtstatus, ltstatus) ! Out 

  !     06  Dec 2018  - Pass ilg back in as an argument + minor reorganization
  !     V. Arora        of arguments              
  !
  !     22  Jul 2015  - The code with rmatctem was not set up for >3 soil layers.
  !     J. Melton       Fixed that and also brought in isand so that the layers of
  !                     bedrock won't have their rmat used.
  !
  !     17  Jan 2014  - Moved parameters to global file (classic_params.f90)
  !     J. Melton
  !
  !     5   Jul 2013  - Fixed bug with initializing the variables. Brought in
  !     J. Melton       the modules for global parameters
  !
  !     22  Nov 2012  - Calling this version 1.1 since a fair bit of ctem
  !     V. Arora        subroutines were changed for compatibility with class
  !                     version 3.6 including the capability to run ctem in
  !                     mosaic/tile version along with class.
  !
  !     24  Sep 2012  - Add in checks to prevent calculation of non-present
  !     J. Melton       pfts
  !
  !     05  May 2003  - This subroutine calculates the allocation fractions
  !     V. Arora        for leaf, stem, and root components for ctem's pfts

      use classic_params,   only : eta, kappa, kn, abszero, icc,&
                                    ignd, ican, omega, epsilonl,&
                                    epsilons, epsilonr, caleaf, castem,&
                                    caroot, consallo, rtsrmin,aldrlfon,&
                                    classpfts, nol2pfts, reindexPFTs

      implicit none
      
      integer ilg !<
      integer il1 !<input: il1=1
      integer il2 !<input: il2=ilg
      integer i, j, k
      integer lfstatus(ilg,icc) !<input: leaf status. an integer indicating if leaves are
                                !<in "max. growth", "normal growth", "fall/harvest",
                                !<or "no leaves" mode. see phenolgy subroutine for more details.
      integer n, m
!
      integer sort(icc) !<input: index for correspondence between 9 pfts and the
                        !<12 values in parameters vectors
      integer isand(ilg,ignd)
!
      real   ailcg(ilg,icc) !<input: green or live leaf area index
      real   ailcb(ilg,icc) !<input: brown or dead leaf area index
      real   thliq(ilg,ignd) !<input: liquid soil moisture content in 3 soil layers
      real   THLW(ilg,ignd) !<input: wilting point soil moisture content
      real   THFC(ilg,ignd) !<input: field capacity soil moisture content
      real   rootmass(ilg,icc) !<input: root mass for each of the 9 ctem pfts, kg c/m2
      real   rmatctem(ilg,icc,ignd) !<input: fraction of roots in each soil layer for each pft
      real   gleafmas(ilg,icc) !<input: green or live leaf mass in kg c/m2, for the 9 pfts
      real   stemmass(ilg,icc) !<input: stem mass for each of the 9 ctem pfts, kg c/m2
      real   sand(ilg,ignd) !<input: percentage sand
      real   clay(ilg,ignd) !<input: percentage clay
!
      real   afrleaf(ilg,icc) !<output: allocation fraction for leaves
      real   afrstem(ilg,icc) !<output: allocation fraction for stem
      real   afrroot(ilg,icc) !<output: allocation fraction for root
      real   fcancmx(ilg,icc) !<input: max. fractional coverage of ctem's 9 pfts, but this can be
                              !<modified by land-use change, and competition between pfts
!
      real  avTHLW(ilg,icc),  aTHFC(ilg,icc),    avthliq(ilg,icc)
      real  wtstatus(ilg,icc) !<output: soil water status (0 dry -> 1 wet)
      real  ltstatus(ilg,icc) !<output: light status
      real  nstatus(ilg,icc)
      real  wnstatus(ilg,icc),              denom,   mnstrtms(ilg,icc),&
                        diff,              term1,               term2,&
              aleaf(ilg,icc),     astem(ilg,icc),      aroot(ilg,icc),&
           tot_rmat_ctem(ilg,icc)

  ! --------------
  ! initialize required arrays to 0
  do 140 j = 1,icc
    do 150 i = il1, il2
      afrleaf(i,j)=0.0    !<allocation fraction for leaves
      afrstem(i,j)=0.0    !<allocation fraction for stem
      afrroot(i,j)=0.0    !<allocation fraction for root
      aleaf(i,j)=0.0    !<temporary variable
      astem(i,j)=0.0    !<temporary variable
      aroot(i,j)=0.0    !<temporary variable
                        !<averaged over the root zone
      avTHLW(i,j)=0.0   !<wilting point soil moisture
      aTHFC(i,j)=0.0   !<field capacity soil moisture
      avthliq(i,j)=0.0    !<liquid soil moisture content
      tot_rmat_ctem(i,j)= 0.0 !<temp var.
      wtstatus(i,j)=0.0   !<water status
      ltstatus(i,j)=0.0   !<light status
       nstatus(i,j)=0.0   !<nitrogen status, if and when we
                            !<will have n cycle in the model
      wnstatus(i,j)=0.0   !<min. of water & n status
      mnstrtms(i,j)=0.0   !<min. (stem+root) biomass needed to
                         !<support leaves
150     continue
140   continue

  ! initialization ends

  !> Calculate liquid soil moisture content, and wilting and field capacity
  !! soil moisture contents averaged over the root zone. note that while
  !! the soil moisture content is same under the entire gcm grid cell,
  !! soil moisture averaged over the rooting depth is different for each
  !! pft because of different fraction of roots present in each soil layer.
  do 200 j = 1, icc
    do 210 i = il1, il2
      if (fcancmx(i,j) > 0.0) then
        do 215 n = 1, ignd
          if (isand(i,n) /= -3) then !Only for non-bedrock
            avTHLW(i,j) = avTHLW(i,j) + THLW(i,n) * rmatctem(i,j,n)
            aTHFC(i,j) = aTHFC(i,j) + THFC(i,n) * rmatctem(i,j,n)
            avthliq(i,j)  = avthliq(i,j) + thliq(i,n) * rmatctem(i,j,n)
            tot_rmat_ctem(i,j) = tot_rmat_ctem(i,j) + rmatctem(i,j,n)
          end if
215     continue
        avTHLW(i,j) = avTHLW(i,j) / tot_rmat_ctem(i,j)
        aTHFC(i,j) = aTHFC(i,j) / tot_rmat_ctem(i,j)
        avthliq(i,j)  = avthliq(i,j) / tot_rmat_ctem(i,j)
      end if
210 continue
200 continue

  !> Using liquid soil moisture content together with wilting and field
  !! capacity soil moisture contents averaged over the root zone, find
  !! soil water status.
  do 230 j = 1, icc
    do 240 i = il1, il2
      if (fcancmx(i,j) > 0.0) then
        if (avthliq(i,j) <= avTHLW(i,j)) then
          wtstatus(i,j) = 0.0
        else if (avthliq(i,j) > avTHLW(i,j) .and. &
                 avthliq(i,j) < aTHFC(i,j)) then
          wtstatus(i,j) = (avthliq(i,j) - avTHLW(i,j)) &
                           / (aTHFC(i,j) - avTHLW(i,j))
        else
          wtstatus(i,j) = 1.0
        end if
      end if
240 continue
230 continue

  !> Calculate light status as a function of lai and light extinction
  !! parameter. for now set nitrogen status equal to 1, which means
  !! nitrogen is non-limiting.
  do 250 j = 1, ican
    do 255 m = reindexPFTs(j,1), reindexPFTs(j,2)
      do 260 i = il1, il2
        select case (classpfts(j))
        case ('NdlTr' , 'BdlTr', 'Crops', 'BdlSh')    ! trees, crops and shrub
          ltstatus(i,m) = exp(-kn(sort(m)) * ailcg(i,m))    
        case ('Grass')  ! grass
          ltstatus(i,m)=max(0.0, (1.0 - (ailcg(i,m) / 4.0)))    
        case default
          print*,'Unknown CLASS PFT in allocate ',classpfts(j)
          call XIT('allocate',-1)                 
        end select
        nstatus(i,m) = 1.0
260   continue
255 continue
250 continue
  
  !> allocation to roots is determined by min. of water and nitrogen
  !! status
  do 380 j = 1,icc
    do 390 i = il1, il2
      if (fcancmx(i,j) > 0.0) then
        wnstatus(i,j) = min(nstatus(i,j), wtstatus(i,j))
      end if
390 continue
380 continue

  !> now that we know water, light, and nitrogen status we can find
  !! allocation fractions for leaves, stem, and root components. note
  !! that allocation formulae for grasses are different from those
  !! for trees and crops, since there is no stem component in grasses.
      do 400 j = 1, ican
        do 405 m = reindexPFTs(j,1), reindexPFTs(j,2)
          do 410 i = il1, il2
            n = sort(m)
            select case (classpfts(j))
            case ('NdlTr' , 'BdlTr', 'Crops', 'BdlSh')    ! trees, crops and shrub
              denom = 1.0 + (omega(n) * (2.0 - ltstatus(i,m) - wnstatus(i,m)))    
              afrstem(i,m) = (epsilons(n) + omega(n) * (1.0 - ltstatus(i,m))) &
                                                  / denom  
              afrroot(i,m) = (epsilonr(n)+omega(n)*(1.0-wnstatus(i,m)))/&
       &                      denom  
              afrleaf(i,m)=epsilonl(n)/denom        
            case ('Grass') ! grass
              denom =1.0+(omega(n)*(1.0+ltstatus(i,m)-wnstatus(i,m)))
              afrleaf(i,m)=(epsilonl(n)+omega(n)*ltstatus(i,m))/denom  
              afrroot(i,m)=(epsilonr(n)+omega(n)*(1.0-wnstatus(i,m)))/&
       &                     denom  
              afrstem(i,m)= 0.0    
            case default
              print*,'Unknown CLASS PFT in allocate ',classpfts(j)
              call XIT('allocate',-2)                                 
            end select
410     continue
405    continue
400   continue
!>
!!if using constant allocation factors then replace the dynamically
!!calculated allocation fractions.
!!
      if(consallo)then
        do 420 j = 1, icc
          do 421 i = il1, il2
           if (fcancmx(i,j).gt.0.0) then
            afrleaf(i,j)=caleaf(sort(j))
            afrstem(i,j)=castem(sort(j))
            afrroot(i,j)=caroot(sort(j))
           endif
421       continue
420     continue
      endif
!>
!!make sure allocation fractions add to one
!!


      do 430 j = 1, icc
        do 440 i = il1, il2
         if (fcancmx(i,j).gt.0.0) then
          if(abs(afrstem(i,j)+afrroot(i,j)+afrleaf(i,j)-1.0).gt.abszero)&
     &    then
           write(6,2000) i,j,(afrstem(i,j)+afrroot(i,j)+afrleaf(i,j))
2000       format(' at (i) = (',i3,'), pft=',i2,'  allocation fractions&
     &not adding to one. sum  = ',e12.7)
          call xit('allocate',-3)
          endif
         endif
440     continue
430   continue
!>
!!the allocation fractions calculated above are overridden by two
!!rules.
!!
!!rule 1 which states that at the time of leaf onset which corresponds
!!to leaf status equal to 1, more c is allocated to leaves so
!!that they can grow asap. in addition when leaf status is
!!"fall/harvest" then nothing is allocated to leaves.
!!
      do 500 j = 1, ican
       do 505 m = reindexPFTs(j,1), reindexPFTs(j,2)
        do 510 i = il1, il2
         if (fcancmx(i,m).gt.0.0) then
          if(lfstatus(i,m).eq.1) then
            aleaf(i,m)=aldrlfon(sort(m))

	           !>for grasses we use the usual allocation even at leaf onset
             
            select case (classpfts(j)) 
            case ('Grass') 
              aleaf(i,m)=afrleaf(i,m)
            case ('NdlTr' , 'BdlTr', 'Crops', 'BdlSh') 
              ! Do nothing for non-grass
            case default
              print*,'Unknown CLASS PFT in allocate ',classpfts(j)
              call XIT('allocate',-4)                               
            end select

            diff  = afrleaf(i,m)-aleaf(i,m)
            if((afrstem(i,m)+afrroot(i,m)).gt.abszero)then
              term1 = afrstem(i,m)/(afrstem(i,m)+afrroot(i,m))
              term2 = afrroot(i,m)/(afrstem(i,m)+afrroot(i,m))
            else
              term1 = 0.0
              term2 = 0.0
            endif
            astem(i,m) = afrstem(i,m) + diff*term1
            aroot(i,m) = afrroot(i,m) + diff*term2
            afrleaf(i,m)=aleaf(i,m)
            afrstem(i,m)=max(0.0,astem(i,m))
            afrroot(i,m)=max(0.0,aroot(i,m))
          else if(lfstatus(i,m).eq.3)then
            aleaf(i,m)=0.0
            diff  = afrleaf(i,m)-aleaf(i,m)
            if((afrstem(i,m)+afrroot(i,m)).gt.abszero)then
              term1 = afrstem(i,m)/(afrstem(i,m)+afrroot(i,m))
              term2 = afrroot(i,m)/(afrstem(i,m)+afrroot(i,m))
            else
              term1 = 0.0
              term2 = 0.0
            endif
            astem(i,m) = afrstem(i,m) + diff*term1
            aroot(i,m) = afrroot(i,m) + diff*term2
            afrleaf(i,m)=aleaf(i,m)
            afrstem(i,m)=astem(i,m)
            afrroot(i,m)=aroot(i,m)
          endif
         endif
510     continue
505    continue
500   continue

!>
!!rule 2 overrides rule 1 above and makes sure that we do not allow the
!!amount of leaves on trees and crops (i.e. pfts 1 to 7) to exceed
!!an amount such that the remaining woody biomass cannot support.
!!if this happens, allocation to leaves is reduced and most npp
!!is allocated to stem and roots, in a proportion based on calculated
!!afrstem and afrroot. for grasses this rule essentially constrains
!!the root:shoot ratio, meaning that the model grasses can't have
!!lots of leaves without having a reasonable amount of roots.
!!
      do 530 j = 1, icc
        n=sort(j)
        do 540 i = il1, il2
         if (fcancmx(i,j).gt.0.0) then
!         find min. stem+root biomass needed to support the green leaf
!         biomass.
          mnstrtms(i,j)=eta(n)*(gleafmas(i,j)**kappa(n))
!
          if( (stemmass(i,j)+rootmass(i,j)).lt.mnstrtms(i,j)) then
            if( (afrstem(i,j)+afrroot(i,j)).gt.abszero ) then
              aleaf(i,j)=min(0.05,afrleaf(i,j))
              diff  = afrleaf(i,j)-aleaf(i,j)
              term1 = afrstem(i,j)/(afrstem(i,j)+afrroot(i,j))
              term2 = afrroot(i,j)/(afrstem(i,j)+afrroot(i,j))
              astem(i,j) = afrstem(i,j) + diff*term1
              aroot(i,j) = afrroot(i,j) + diff*term2
              afrleaf(i,j)=aleaf(i,j)
              afrstem(i,j)=astem(i,j)
              afrroot(i,j)=aroot(i,j)
            else
              aleaf(i,j)=min(0.05,afrleaf(i,j))
              diff  = afrleaf(i,j)-aleaf(i,j)
              afrleaf(i,j)=aleaf(i,j)
              afrstem(i,j)=diff*0.5 + afrstem(i,j)
              afrroot(i,j)=diff*0.5 + afrroot(i,j)
            endif
          endif
         endif
540     continue
530   continue
!>
!!make sure that root:shoot ratio is at least equal to rtsrmin. if not
!!allocate more to root and decrease allocation to stem.
!!
      do 541 j = 1, icc
        n=sort(j)
        do 542 i = il1, il2
         if (fcancmx(i,j) > 0.0) then
          if ((stemmass(i,j)+gleafmas(i,j)) > 0.05) then
            if ((rootmass(i,j) / (stemmass(i,j) + gleafmas(i,j))) < rtsrmin(n)) then
              astem(i,j) = min(0.05, afrstem(i,j))
              diff = afrstem(i,j)- astem(i,j)
              afrstem(i,j) = afrstem(i,j)- diff
              afrroot(i,j) = afrroot(i,j)+ diff
            end if
          end if
         end if
542     continue
541   continue
!>
!!finally check if all allocation fractions are positive and check
!!again they all add to one.
!!
      do 550 j = 1, icc
        do 560 i = il1, il2
         if (fcancmx(i,j).gt.0.0) then
          if( (afrleaf(i,j).lt.0.0).or.(afrstem(i,j).lt.0.0).or.&
     &    (afrroot(i,j).lt.0.0))then
           write(6,2200) i,j
2200       format(' at (i) = (',i3,'), pft=',i2,'  allocation fractions&
      &negative')
           write(6,2100)afrleaf(i,j),afrstem(i,j),afrroot(i,j)
2100       format(' aleaf = ',f12.9,' astem = ',f12.9,' aroot = ',f12.9)
           call xit('allocate',-5)
          endif
         endif
560     continue
550   continue
!
      do 580 j = 1, icc
        do 590 i = il1, il2
         if (fcancmx(i,j).gt.0.0) then
          if(abs(afrstem(i,j)+afrroot(i,j)+afrleaf(i,j)-1.0).gt.abszero)&
     &    then
           write(6,2300) i,j,(afrstem(i,j)+afrroot(i,j)+afrleaf(i,j))
2300       format(' at (i) = (',i3,'), pft=',i2,'  allocation fractions&
     &not adding to one. sum  = ',f12.7)
           call xit('allocate',-6)
          endif
         endif
590     continue
580   continue
!
      return
end subroutine allocate
!!@}
! ---------------------------------------------------------------------------------------------------

!>\ingroup allocateCarbon_updatePoolsAllocateRepro
!!@{
!> Performs allocation of carbon gained by photosynthesis into plant structural pools
!> @author Vivek Arora and Joe Melton
subroutine updatePoolsAllocateRepro(il1,il2,ilg,sort,ailcg,lfstatus,nppveg,PFTCompetition, & ! In
                                    pftexist,gppveg,rmsveg,rmrveg,rmlveg, fcancmx,  & ! In 
                                    lambda, afrleaf, afrstem,afrroot, gleafmas,stemmass, rootmass,bleafmas, & ! In/Out 
                                    reprocost, ntchlveg, ntchsveg, ntchrveg, repro_cost_g) ! Out 
  
  use classic_params,        only : icc, deltat, repro_fraction, zero
  use competition_scheme, only : expansion 
  
  implicit none 
  
  integer, intent(in) :: ilg          !< Number of grid cells in latitude circle
  integer, intent(in) :: il1          !<il1=1
  integer, intent(in) :: il2          !<il2=ilg
  logical, intent(in) :: PFTCompetition                   !<logical boolean telling if competition between pfts is on or not
  integer, intent(in) :: sort(icc)    !<index for correspondence between 9 pfts and 12 values in the parameter vectors
  real, intent(in) :: ailcg(ilg,icc)        !< Green LAI for ctem's pfts \f$(m^2 leaf/m^2 ground)\f$
  integer, intent(in) :: lfstatus(ilg,icc)  !<leaf phenology status
  real, intent(in) :: nppveg(ilg,icc)       !< NPP for individual pfts, (\f$\mu mol CO_2 m^{-2} s^{-1}\f$)
  logical, intent(in) :: pftexist(ilg,icc)  !< True if PFT is present in tile.
  real, intent(in) :: gppveg(ilg,icc)       !< Gross primary productivity per PFT (\f$\mu mol CO_2 m^{-2} s^{-1}\f$)
  real, intent(in) :: rmsveg(ilg,icc)       !< Maintenance respiration for stem for the CTEM pfts in u mol co2/m2. sec
  real, intent(in) :: rmrveg(ilg,icc)       !< Maintenance respiration for root for the CTEM pfts in u mol co2/m2. sec
  real, intent(in) :: rmlveg(ilg,icc)       !< Leaf maintenance respiration per PFT (\f$\mu mol CO_2 m^{-2} s^{-1}\f$)
  real, dimension(ilg,icc), intent(in) :: fcancmx      !< max. fractional coverage of CTEM's pfts, but this can be
                                                          !< modified by land-use change, and competition between pfts
                                                          
  real, intent(inout) :: afrleaf(ilg,icc)        !<allocation fraction for leaves
  real, intent(inout) :: afrstem(ilg,icc)        !<allocation fraction for stem
  real, intent(inout) :: afrroot(ilg,icc)        !<allocation fraction for root
  real, intent(inout) :: lambda(ilg,icc) !< Fraction of npp that is to be used for 
                                                            !! horizontal expansion (lambda) during the next
                                                            !! day (i.e. this will be determining
                                                            !! the colonization rate in competition)
  real, intent(inout) :: gleafmas(ilg,icc)     !<green leaf mass for each of the ctem pfts, \f$(kg C/m^2)\f$ 
  real, intent(inout) :: bleafmas(ilg,icc)     !<brown leaf mass for each of the ctem pfts, \f$(kg C/m^2)\f$  
  real, intent(inout) :: stemmass(ilg,icc)     !<stem mass for each of the ctem pfts, \f$(kg C/m^2)\f$                                  
  real, intent(inout) :: rootmass(ilg,icc)     !<root mass for each of the ctem pfts, \f$(kg C/m^2)\f$ 
  real, intent(out) :: reprocost(ilg,icc) !< Cost of making reproductive tissues, only non-zero when NPP is positive (\f$\mu mol CO_2 m^{-2} s^{-1}\f$) 
  real, intent(out) :: ntchlveg(ilg,icc)  !<fluxes for each pft: Net change in leaf biomass, u-mol CO2/m2.sec
  real, intent(out) :: ntchsveg(ilg,icc)  !<fluxes for each pft: Net change in stem biomass, u-mol CO2/m2.sec
  real, intent(out) :: ntchrveg(ilg,icc)  !<fluxes for each pft: Net change in root biomass, 
                                          !! the net change is the difference between allocation and
                                          !! autotrophic respiratory fluxes, u-mol CO2/m2.sec
  real, intent(out) ::repro_cost_g(ilg)  !< Tile-level cost of making reproductive tissues, only non-zero when NPP is positive (\f$\mu mol CO_2 m^{-2} s^{-1}\f$) 
                            
  ! Local
  integer :: i,j
  real gppvgstp(ilg,icc) !<
  real nppvgstp(ilg,icc) !<
  real rmlvgstp(ilg,icc) !<
  real rmsvgstp(ilg,icc) !<
  real rmrvgstp(ilg,icc) !<

  real :: convertUnits      !< This converts the units from u-mol CO2/m2.sec to kg C/m^2
  
  convertUnits = deltat / 963.62
  
  !>
  !! Estimate fraction of npp that is to be used for horizontal
  !! expansion (lambda) during the next day (i.e. this will be determining
  !! the colonization rate in competition).
  !!
  if (PFTCompetition)  lambda = expansion(il1,il2,ilg,sort,ailcg,lfstatus,nppveg,pftexist)

  !> Maintenance respiration also reduces leaf, stem, and root biomass.
  !! when NPP for a given pft is positive then this is taken care by
  !! allocating positive NPP amongst the leaves, stem, and root component.
  !! when NPP for a given pft is negative then maintenance respiration
  !! loss is explicitly deducted from each component.

  do 600 j = 1, icc
    do 610 i = il1, il2

        !! Convert NPP and maintenance respiration from different components
        !! from units of u mol co2/m2.sec -> \f$(kg C/m^2)\f$ sequestered 
        !! or respired over the model time step (deltat)

        gppvgstp(i,j) = gppveg(i,j) * convertUnits !+ add2allo(i,j)

        !> Remove the cost of making reproductive tissues. This cost can
        !! only be removed when NPP is positive.
        reprocost(i,j) = max(0., nppveg(i,j) * repro_fraction)

        ! Not in use. We now use a constant reproductive cost as the prior formulation
        ! produces perturbations that do not allow closing of the C balance. JM Jun 2014.
        ! nppvgstp(i,j)=nppveg(i,j)*(1.0/963.62)*deltat*(1.-lambda(i,j))
        !     &                  + add2allo(i,j)
        nppvgstp(i,j) = (nppveg(i,j) - reprocost(i,j)) * convertUnits

        ! Amount of c related to horizontal expansion
        ! Not in use. JM Jun 2014
        ! expbalvg(i,j)=-1.0*nppveg(i,j)*deltat*lambda(i,j)+ add2allo(i,j)*(963.62/1.0)
        
        rmlvgstp(i,j) = rmlveg(i,j) * convertUnits
        rmsvgstp(i,j) = rmsveg(i,j) * convertUnits
        rmrvgstp(i,j) = rmrveg(i,j) * convertUnits
        
        if (lfstatus(i,j) /= 4) then ! real leaves exist 
          if (nppvgstp(i,j) > 0.0) then ! and there is C to allocate.
            ntchlveg(i,j) = afrleaf(i,j) * nppvgstp(i,j)
            ntchsveg(i,j) = afrstem(i,j) * nppvgstp(i,j)
            ntchrveg(i,j) = afrroot(i,j) * nppvgstp(i,j)
          else ! We lose C, not gain.
            ntchlveg(i,j) = -rmlvgstp(i,j) + afrleaf(i,j) * gppvgstp(i,j)
            ntchsveg(i,j) = -rmsvgstp(i,j) + afrstem(i,j) * gppvgstp(i,j)
            ntchrveg(i,j) = -rmrvgstp(i,j) + afrroot(i,j) * gppvgstp(i,j)
          end if
        else  !>i.e. if lfstatus == 4 (no leaves)
          
          !> And since we do not have any real leaves on then we do not take into
          !! account CO2 uptake by imaginary leaves in carbon budget. rmlvgstp(i,j)
          !! should be zero because we set maintenance respiration from storage/imaginary 
          !! leaves equal to zero. in loop 180
          !!
          ntchlveg(i,j) = -rmlvgstp(i,j)
          ntchsveg(i,j) = -rmsvgstp(i,j)
          ntchrveg(i,j) = -rmrvgstp(i,j)
          
          !> Since no real leaves are on, make allocation fractions equal to zero.
          afrleaf(i,j) = 0.0
          afrstem(i,j) = 0.0
          afrroot(i,j) = 0.0
          
        end if

        gleafmas(i,j) = gleafmas(i,j) + ntchlveg(i,j)
        stemmass(i,j) = stemmass(i,j) + ntchsveg(i,j)
        rootmass(i,j) = rootmass(i,j) + ntchrveg(i,j)

        if (gleafmas(i,j) < 0.0) then
          write(6,1900)'gleafmas < zero at i=',i,' for pft=',j,''
          write(6,1901)'gleafmas = ',gleafmas(i,j)
          write(6,1901)'ntchlveg = ',ntchlveg(i,j)
          write(6,1902)'lfstatus = ',lfstatus(i,j)
          write(6,1901)'ailcg    = ',ailcg(i,j)
          ! write(6,1901)'slai     = ',slai(i,j)
  1900    format(a23,i4,a10,i2,a1)
  1902    format(a11,i4)
          call xit ('updatePoolsAllocateRepro',-2)
        end if

        if (stemmass(i,j) < 0.0) then
          write(6,1900)'stemmass < zero at i=(',i,') for pft=',j,')'
          write(6,1901)'stemmass = ',stemmass(i,j)
          write(6,1901)'ntchsveg = ',ntchsveg(i,j)
          write(6,1902)'lfstatus = ',lfstatus(i,j)
          write(6,1901)'rmsvgstp = ',rmsvgstp(i,j)
          write(6,1901)'afrstem  = ',afrstem(i,j)
          write(6,1901)'gppvgstp = ',gppvgstp(i,j)
          write(6,1901)'rmsveg = ',rmsveg(i,j)
  1901    format(a11,f12.8)
          call xit ('updatePoolsAllocateRepro',-3)
        end if

        if (rootmass(i,j) < 0.0) then
          write(6,1900)'rootmass < zero at i=(',i,') for pft=',j,')'
          write(6,1901)'rootmass = ',rootmass(i,j)
          call xit ('updatePoolsAllocateRepro',-4)
        end if

        !! Convert net change in leaf, stem, and root biomass into
        !! u-mol co2/m2.sec for use in balcar subroutine
        !!
        ntchlveg(i,j) = ntchlveg(i,j) * (963.62 / deltat)
        ntchsveg(i,j) = ntchsveg(i,j) * (963.62 / deltat)
        ntchrveg(i,j) = ntchrveg(i,j) * (963.62 / deltat)

        !! To avoid over/underflow problems set gleafmas, stemmass, and
        !! rootmass to zero if they get too small
        !!
        if(bleafmas(i,j) < zero) bleafmas(i,j) = 0.0
        if(gleafmas(i,j) < zero) gleafmas(i,j) = 0.0
        if(stemmass(i,j) < zero) stemmass(i,j) = 0.0
        if(rootmass(i,j) < zero) rootmass(i,j) = 0.0
      
610 continue
600 continue
  
  !> Calculate grid averaged value of C related to spatial expansion
  
  repro_cost_g(:)=0.0    !< amount of C for production of reproductive tissues
  do 620 j = 1,icc
    do 621 i = il1, il2
      repro_cost_g(i) = repro_cost_g(i) + fcancmx(i,j) * reprocost(i,j)
621 continue
620 continue

end subroutine updatePoolsAllocateRepro

!!@}
! ---------------------------------------------------------------------------------------------------

!>\namespace allocateCarbon
!!Positive NPP is allocated daily to the leaf, stem and root components, which generally causes their respective
!!biomass to increase, although the biomass may also decrease depending on the autotrophic respiration flux of a
!!component. Negative NPP generally causes net carbon loss from the components. While CTEM offers the ability to
!!use both specified constant or dynamically calculated allocation fractions for leaves, stems and roots, in
!!practice the dynamic allocation fractions are primarily used. The formulation used in CTEM v. 2.0 differs
!!from that for CTEM v. 1.0 as described in Arora and Boer (2005) \cite Arora2005-6b1 only in the parameter values.
!!
!!The dynamic allocation to the live plant tissues is based on the light, water and leaf phenological status
!!of vegetation. The preferential allocation of carbon to the different tissue pools is based on three
!!assumptions: (i) if soil moisture is limiting, carbon should be preferentially allocated to roots for
!!greater access to water, (ii) if LAI is low, carbon should be allocated to leaves for enhanced
!!photosynthesis and finally (iii) carbon is allocated to the stem to increase vegetation height and
!!lateral spread of vegetation when the increase in LAI results in a decrease in light penetration.
!!
!!The vegetation water status, \f$W\f$, is determined as a linear scalar quantity that varies between
!!0 and 1 for each PFT and calculated by weighting the degree of soil saturation (\f$\phi_{i} (\theta_{i} )\f$)
!!with the fraction of roots in each soil layer
!!
!!\f[  W = \phi_{root} = \sum_{i=1}^g \phi_{i}(\theta_{i})  r_{i}. \hspace{10pt}[Eqn 1]\f]
!!
!!The light status, \f$L\f$, is parametrized as a function of LAI and nitrogen extinction
!!coefficient, \f$k_\mathrm{n}\f$ (PFT-dependent; see also classic_params.f90), as for trees and crops:
!!
!!\f[ L = \exp(-k_\mathrm{n} LAI) ;\hspace{10pt}[Eqn 2]\f]
!!
!! and for grasses:
!!
!!\f[ L = \max\left(0,1-\frac{LAI}{4.5}\right).  \hspace{10pt}[Eqn 3]\f]
!!
!!For PFTs with a stem component (i.e. tree and crop PFTs), the fractions of positive NPP
!!allocated to stem (\f$a_{fS}\f$), leaf (\f$a_{fL}\f$) and root (\f$a_{fR}\f$) components
!!are calculated as
!!\f[ a_{fS}=\frac{\epsilon_\mathrm{S}+\omega_\mathrm{a}(1-L)}{1+\omega_\mathrm{a}(2-L-W)}, \hspace{10pt}[Eqn 4] \f]
!!
!!\f[ a_{fR}=\frac{\epsilon_\mathrm{R}+ \omega_\mathrm{a}(1-W)}{1+\omega_\mathrm{a}(2-L-W)}, \hspace{10pt}[Eqn 5]\f]
!!
!!\f[ a_{fL}=\frac{\epsilon_\mathrm{L}}{1+\omega_\mathrm{a}(2-L-W)}= 1-a_{fS}-a_{fR}. \hspace{10pt}[Eqn 6]\f]
!!
!!The base allocation fractions for each component (leaves -- \f$\epsilon_\mathrm{L}\f$,
!!stem -- \f$\epsilon_\mathrm{S}\f$, and roots -- \f$\epsilon_\mathrm{R}\f$) are PFT-dependent
!!(see also classic_params.f90) and sum to 1, i.e. \f$\epsilon_\mathrm{L} + \epsilon_\mathrm{S} + \epsilon_\mathrm{R} = 1\f$.
!!The parameter \f$\omega_\mathrm{a}\f$, which varies by PFT (see also classic_params.f90), determines the sensitivity
!!of the allocation scheme to changes in \f$W\f$ and \f$L\f$. Larger values of \f$\omega_\mathrm{a}\f$ yield
!!higher sensitivity to changes in \f$L\f$ and \f$W\f$.
!!
!!Grasses do not have a stem component (i.e. \f$a_{fS}=0\f$) and the allocation fractions for leaf
!!and root components are given by
!!
!!\f[ a_{fL}=\frac{\epsilon_\mathrm{L}+\omega_\mathrm{a} L}{1+\omega_\mathrm{a}(1+L-W)} ;\hspace{10pt}[Eqn 7]\f]
!!
!!\f[ a_{fR}=\frac{\epsilon_\mathrm{R}+\omega_\mathrm{a}(1-W)}{1+\omega_\mathrm{a}(1+L-W)}. \hspace{10pt}[Eqn 8]\f]
!!
!!The above equations (4-8) ensure that the allocation fractions add up to one (\f$a_{fL} + a_{fR} + a_{fS} = 1\f$).
!!
!!The dynamic allocation fractions are superseded under three conditions. First, during the leaf
!!onset for crops and deciduous trees, all carbon must be allocated to leaves (\f$a_{fL} = 1\f$,
!!\f$a_{fS} = a_{fR} = 0\f$). Second, the proportion of stem plus root biomasses to leaf biomass
!!must satisfy the relationship:
!!\f[ C_\mathrm{S} + C_\mathrm{R} = \eta C_\mathrm{L}^{\kappa}, \hspace{10pt}[Eqn 9]\f]
!!
!!where \f$C_\mathrm{S}\f$, \f$C_\mathrm{R}\f$ and \f$C_\mathrm{L}\f$ are the carbon in the stem,
!!root and leaves, respectively. The parameter \f$\eta\f$ is PFT-specific (see also classic_params.f90)
!!and parameter \f$\kappa\f$ has a value of 1.6 for trees and crops and 1.2 for grasses. Both parameters
!!are based on the Frankfurt Biosphere Model (FBM) Ludeke et al. (1994) \cite Ludeke1994-px. This constraint (Eq. 9) is based
!!on the physical requirement of sufficient stem and root tissues to support a given leaf biomass. As
!!grasses have no stem component, Eq. 9 determines their root to shoot ratio (i.e. the ratio of
!!belowground to aboveground biomass). The final condition ensures that a minimum realistic root
!!to shoot ratio is maintained for all PFTs (\f${lr}_{min}\f$, see also classic_params.f90). Root mass
!!is required for nutrient and water uptake and support for the aboveground biomass. If the minimum
!!root to shoot ratio is not being maintained, carbon is allocated preferentially to roots.
!!
!>\file
end module allocateCarbon

