      subroutine phenolgy(gleafmas, bleafmas,     
     1                         il1,      il2,     tbar,    
     2                       thliq,   wiltsm,  fieldsm,       ta,  
     3                       anveg,     iday,     radl, roottemp,
     4                    rmatctem, stemmass, rootmass,     sort,
     5                    nol2pfts,  fcancmx,
c    6 ------------------ inputs above this line ----------------------   
     7                    flhrloss, leaflitr, lfstatus,  pandays,
     8                    colddays)  
c    9 --- variables which are updated and outputs above this line ----
c
c               Canadian Terrestrial Ecosystem Model (CTEM)
C               Phenology, Leaf Turnover & Mortality Subroutine
c
c     17  Jan 2014  - Moved parameters to global file (ctem_params.f90)
c     J. Melton
c
c     22  Jul 2013  - Add in module for parameters
C     J. Melton
c
c     24  Sep 2012  - add in checks to prevent calculation of non-present
c     J. Melton       pfts
c
c     15  Apr. 2003 - this subroutine calculates the leaf status 
c     V. Arora        for ctem's pfts and leaf litter generated by
c                     normal turnover of leaves and cold and drought 
c                     stress. crop harvest is also modelled in this
c                     subroutine, and for grasses green leaves are
c                     converted into brown.
c
c     inputs 
c
c     fcancmx  - max. fractional coverage of ctem's 9 pfts, but this can be
c                modified by land-use change, and competition between pfts
c     gleafmas  - green or live leaf mass in kg c/m2, for the 9 pfts
c     bleafmas  - brown or dead leaf mass in kg c/m2, for the 9 pfts
c     icc       - no. of ctem plant function types, currently 9
c     ignd        - no. of soil layers (currently 3)
c     ilg       - no. of grid cells in latitude circle
c     il1,il2   - il1=1, il2=ilg
c     tbar      - soil temperature, k
c     thliq     - liquid soil moisture content in 3 soil layers
c     wiltsm    - wilting point soil moisture content
c     fieldsm   - field capacity soil moisture content
c                 both calculated in allocate subroutine
c     ta        - air temperature, k
c     anveg     - net photosynthesis rate of ctem's pfts, umol co2/m2.s
c     iday      - day of year
c     radl      - latitude in radians
c     roottemp  - root temperature, which is a function of soil temperature
c                 of course, k.
c     rmatctem  - fraction of roots in each soil layer for each pft
c     stemmass  - stem mass for each of the 9 ctem pfts, kg c/m2
c     rootmass  - root mass for each of the 9 ctem pfts, kg c/m2
c     sort      - index for correspondence between 9 pfts and the
c                 12 values in parameters vectors
c     l2max     - maximum number of level 2 ctem pfts
c     nol2pfts  - number of level 2 ctem pfts
c     ican        - number of class pfts
c
c     updates
c
c     flhrloss  - fall & harvest loss for bdl dcd plants and crops, 
c                 respectively, kg c/m2.
c     pandays   - counter for positive net photosynthesis (an) days for 
c                 initiating leaf onset
c     lfstatus  - integer indicating leaf status or mode
c                 1 - max. growth or onset, when all npp is allocated to
c                     leaves
c                 2 - normal growth, when npp is allocated to leaves, stem,
c                     and root
c                 3 - fall for dcd trees/harvest for crops, when allocation
c                     to leaves is zero.
c                 4 - no leaves
c     colddays  - cold days counter for tracking days below a certain 
c                 temperature threshold for ndl dcd and crop pfts.
c
c     outputs
c
c     leaflitr  - leaf litter generated by normal turnover, cold and
c                 drought stress, and leaf fall/harvest, kg c/m2
c
c     ------------------------------------------------------------------    
c
      use ctem_params,        only : kn, pi, zero, kappa, eta, lfespany,
     1                               fracbofg, specsla,ilg,ignd,icc,kk,
     2                               ican, cdlsrtmx, drlsrtmx, drgta,
     3                               colda, lwrthrsh, dayschk, coldlmt,
     4                               coldthrs, harvthrs, flhrspan,
     5                               thrprcnt, roothrsh     


      implicit none
c
      integer il1, il2, i, j, k, iday, n, m, k1, k2
c
      integer        sort(icc),     nol2pfts(ican)
c
      real  gleafmas(ilg,icc), bleafmas(ilg,icc),              ta(ilg),
     1           tbar(ilg,ignd),     thliq(ilg,ignd),    sand(ilg,ignd), 
     2           clay(ilg,ignd),    anveg(ilg,icc),   leaflitr(ilg,icc),
     3      roottemp(ilg,icc),                   rmatctem(ilg,icc,ignd),
     4      stemmass(ilg,icc), rootmass(ilg,icc),     fcancmx(ilg,icc)
c
      integer pandays(ilg,icc),     lfstatus(ilg,icc),   
     1    chkmode(ilg,icc),     colddays(ilg,2) 
c
      real        sla(icc),      ailcg(ilg,icc),        ailcb(ilg,icc)
c
      real                      fieldsm(ilg,ignd),     wiltsm(ilg,ignd),
     1                day,            radl(ilg),                 theta,
     2              decli,                 term,         daylngth(ilg),
     3  nrmlloss(ilg,icc),     betadrgt(ilg,ignd),    drgtstrs(ilg,icc),
     4  drgtlsrt(ilg,icc),    drgtloss(ilg,icc),     coldloss(ilg,icc),
     5  coldstrs(ilg,icc),    coldlsrt(ilg,icc),     flhrloss(ilg,icc),
     6    lfthrs(ilg,icc)      
c
c
c     ------------------------------------------------------------------
c     Constants and parameters are located in ctem_params.f90
c
c     ---------------------------------------------------------------
c
      if(icc.ne.9)                            call xit('phenolgy',-1)
c
c     initialize required arrays to zero
c
      do 120 j = 1, ignd
        do 130 i = il1, il2
          betadrgt(i,j)=0.0       ! (1 - drought stress)
130     continue
120   continue
c
      do 140 j = 1,icc

        sla(j)=0.0                ! specific leaf area

        do 150 i = il1, il2
          ailcg(i,j)=0.0          ! green lai
          ailcb(i,j)=0.0          ! brown lai
          chkmode(i,j)=0          ! indicator for making sure that leaf status 
c                                 ! is updated
          leaflitr(i,j)=0.0       ! leaf litter
          nrmlloss(i,j)=0.0       ! leaf loss due to normal turnover
          drgtstrs(i,j)=0.0       ! drought stress term
          drgtlsrt(i,j)=0.0       ! drought loss rate
          drgtloss(i,j)=0.0       ! leaf loss due to drought stress
          coldstrs(i,j)=0.0       ! cold stress term
          coldlsrt(i,j)=0.0       ! cold loss rate
          coldloss(i,j)=0.0       ! leaf loss due to cold stress
          lfthrs(i,j)=0.0         ! threshold lai for finding leaf status
150     continue                  
140   continue
c
c     initialization ends    
c
c     ------------------------------------------------------------------
c
c     convert green leaf mass into leaf area index using specific leaf
c     area (sla, m2/kg c) estimated using leaf life span. see bio2str
c     subroutine for more details. 
c
      do 170 j = 1,icc

        sla(j) = 25.0*(lfespany(sort(j))**(-0.50))
        if(specsla(sort(j)).gt.zero) sla(j)=specsla(sort(j))

        n = sort(j)

        do 180 i = il1,il2
         if (fcancmx(i,j).gt.0.0) then 
          ailcg(i,j)=sla(j)*gleafmas(i,j)
          ailcb(i,j)=sla(j)*bleafmas(i,j)*fracbofg
c         also find threshold lai as a function of stem+root biomass
c         which is used to determine leaf status
          lfthrs(i,j)=((stemmass(i,j)+rootmass(i,j))/eta(n))
     &     **(1.0/kappa(n))   
          lfthrs(i,j)=(thrprcnt(n)/100.0)*sla(j)*lfthrs(i,j)

c        using green leaf area index (ailcg) determine the leaf status for
c        each pft. loops 190 and 200 thus initialize lfstatus, if this
c        this information is not passed specifically as an initialization
c        quantity. 

          if(lfstatus(i,j).eq.0)then
            if(ailcg(i,j).le.zero)then            
              lfstatus(i,j)=4                      !no leaves
            else if (ailcg(i,j).gt.lfthrs(i,j))then 
              lfstatus(i,j)=2                      !normal growth
            else                                  
              lfstatus(i,j)=4                      !treat this as no leaves
            endif                                  !so that we start growing 
           endif                                    !if possible
c
         endif !fcancmx
180     continue
170   continue
c
c     knowing lfstatus (after initialization above or using value from
c     from previous time step) we decide if we stay in a given leaf
c     mode or we move to some other mode.
c
c     we start with the "no leaves" mode
c     ----------------------------------
c
c     add one to pandays(i,j) if daily an is positive, otherwise set it to
c     zero.
c
      do 220 j = 1, icc
        n = sort(j)
        do 230 i = il1, il2
         if (fcancmx(i,j).gt.0.0) then 
          if(anveg(i,j).gt.zero) then
            pandays(i,j)=pandays(i,j)+1
            if(pandays(i,j).gt.dayschk(n))then
              pandays(i,j)=dayschk(n)
            endif
          else
            pandays(i,j)=0
          endif
         endif
230     continue
220   continue
c
c     if in "no leaves" mode check if an has been positive over last
c     dayschk(j) days to move into "max. growth" mode. if not we stay
c     in "no leaves" mode. also set the chkmode(i,j) switch to 1.
c
      do 240 j = 1, icc
        n = sort(j)
        do 250 i = il1, il2
         if (fcancmx(i,j).gt.0.0) then 
          if(chkmode(i,j).eq.0.and.lfstatus(i,j).eq.4)then
            if(pandays(i,j).ge.dayschk(n))then
              lfstatus(i,j)=1        ! switch to "max. growth" mode
              chkmode(i,j)=1         ! mode checked, no more checks further down
            else
              lfstatus(i,j)=4        ! stay in "no leaves" mode
              chkmode(i,j)=1         ! mode checked, no more checks further down
            endif
          endif
         endif
250     continue
240   continue
c
c     find day length using day of year and latitude. this is to be used for
c     initiating leaf offset for broad leaf dcd trees.
c
      day=real(iday)
      do 260 i = il1, il2
       theta=0.2163108 + 2.0*atan(0.9671396*tan(0.0086*(day-186.0)))
       decli=asin(0.39795*cos(theta))    !declination
       term=(sin(radl(i))*sin(decli))/(cos(radl(i))*cos(decli))
       term=max(-1.0,min(term,1.0))
       daylngth(i)=24.0-(24.0/pi)*acos(term)
260   continue
c
c     even if pandays criteria has been satisfied do not go into max. growth
c     mode if environmental conditions are such that they will force leaf fall
c     or harvest mode.
c
      do 270 i = il1, il2
c       needle leaf dcd
       if (fcancmx(i,2).gt.0.0) then 
        if(lfstatus(i,2).eq.1.and.chkmode(i,2).eq.1)then
          if(ta(i).lt.(coldthrs(1)+273.16))then
            lfstatus(i,2)=4
          endif
        endif
       endif
c
c       broad leaf dcd cld & dry
       if (fcancmx(i,4).gt.0.0) then 
        if(lfstatus(i,4).eq.1.and.chkmode(i,4).eq.1)then
          if(roottemp(i,4).lt.(roothrsh+273.16).or.
     &    (daylngth(i).lt.11.0.and.roottemp(i,4).lt.(11.15+273.16)))then
            lfstatus(i,4)=4
!       write(*,'(a5,2i4,3f10.3)')'lf1=',lfstatus(i,4),iday,roottemp(i,4)
!     & ,daylngth(i),ailcg(i,4)
          endif
        endif
       endif

       if (fcancmx(i,5).gt.0.0) then 
        if(lfstatus(i,5).eq.1.and.chkmode(i,5).eq.1)then
          if(roottemp(i,5).lt.(roothrsh+273.16).or.
     &    (daylngth(i).lt.11.0.and.roottemp(i,5).lt.(11.15+273.16)))then
            lfstatus(i,5)=4
          endif
        endif
       endif
c
c       crops
       if (fcancmx(i,6).gt.0.0) then 
        if(lfstatus(i,6).eq.1.and.chkmode(i,6).eq.1)then
          if(ta(i).lt.(coldthrs(2)+273.16))then
            lfstatus(i,6)=4
          endif
        endif
       endif
       if (fcancmx(i,7).gt.0.0) then 
        if(lfstatus(i,7).eq.1.and.chkmode(i,7).eq.1)then
          if(ta(i).lt.(coldthrs(2)+273.16))then
            lfstatus(i,7)=4
          endif
        endif
       endif
270   continue
c
c     similar to the way we count no. of days when an is positive, we
c     find no. of days when temperature is below -5 c. we need this to
c     determine if we go into "leaf fall" mode for needle leaf dcd trees.
c
c     also estimate no. of days below 8 c. we use these days to decide 
c     if its cold enough to harvest crops.
c
      do 280 k = 1, 2
        do 290 i = il1, il2
          if(ta(i).lt.(coldthrs(k)+273.16)) then
            colddays(i,k)=colddays(i,k)+1
            if(colddays(i,k).gt.coldlmt(k))then
              colddays(i,k)=coldlmt(k)
            endif
          else
            colddays(i,k)=0
          endif
290     continue
280   continue
c
c     if in "max growth" mode
c     ------------------------
c
c     if mode hasn't been checked and we are in "max. growth" mode, then 
c     check if we are above pft-dependent lai threshold. if lai is more
c     then this threshold we move into "normal growth" mode, otherwise
c     we stay in "max growth" mode so that leaves can grow at their
c     max. climate-dependent rate
c
      do 300 j = 1, icc
        do 310 i = il1, il2
         if (fcancmx(i,j).gt.0.0) then 
          if(chkmode(i,j).eq.0.and.lfstatus(i,j).eq.1)then
            if(ailcg(i,j).ge.lfthrs(i,j))then
              lfstatus(i,j)=2        ! switch to "normal growth" mode
              chkmode(i,j)=1         
            else if(ailcg(i,j).le.zero) then
              lfstatus(i,j)=4        ! switch to "no leaves" mode
              chkmode(i,j)=1         
              pandays(i,j)=0
            else 
              lfstatus(i,j)=1        ! stay in "max. growth" mode
              chkmode(i,j)=1         
            endif
c
c           for dcd trees we also need to go into "leaf fall" mode
c           directly from "max. growth" mode.
c
c           ndl dcd
            if(j.eq.2)then
              if(ailcg(i,j).lt.lfthrs(i,j).and.
     &        colddays(i,1).ge.coldlmt(1).and.
     &        ailcg(i,j).gt.zero)then
                lfstatus(i,j)=3        ! go into "leaf fall" mode
                chkmode(i,j)=1         
              endif
            endif
c
c           bdl dcd cold 
            if(j.eq.4)then
              if( ailcg(i,j).gt.zero.and. 
     &        ((daylngth(i).lt.11.0.and.roottemp(i,j).lt.(11.15+273.16)) 
     &        .or. roottemp(i,j).lt.(roothrsh+273.16)) )then
                lfstatus(i,j)=3        ! go into "leaf fall" mode
                chkmode(i,j)=1         
                flhrloss(i,j)=gleafmas(i,j)*(1.0/flhrspan(2))
              endif
            endif

c           bdl dcd dry
            if(j.eq.5)then
              if( ailcg(i,j).gt.zero.and. 
     &        ((daylngth(i).lt.11.0.and.roottemp(i,j).lt.(11.15+273.16)) 
     &        .or. roottemp(i,j).lt.(roothrsh+273.16)) )then
                lfstatus(i,j)=3        ! go into "leaf fall" mode
                chkmode(i,j)=1         
              endif
            endif

          endif
         endif
310     continue
300   continue
c
c     if in "normal growth" mode
c     --------------------------
c
c     if in "normal growth" mode then go through every pft individually
c     and follow set of rules to determine if we go into "fall/harvest"
c     mode
c
      do 320 i =  il1, il2
c
c       needle leaf evg
       if (fcancmx(i,1).gt.0.0) then 
        if(chkmode(i,1).eq.0.and.lfstatus(i,1).eq.2)then
          if(ailcg(i,1).lt.lfthrs(i,1).and.ailcg(i,1).gt.zero)then  
            lfstatus(i,1)=1         ! go back to "max. growth" mode
            chkmode(i,1)=1         
          else if(ailcg(i,1).le.zero) then
            lfstatus(i,1)=4         ! switch to "no leaves" mode
            chkmode(i,1)=1         
            pandays(i,1)=0
          else
            lfstatus(i,1)=2         ! stay in "normal growth" mode
            chkmode(i,1)=1         
          endif
        endif
       endif 
c
c       needle leaf dcd
       if (fcancmx(i,2).gt.0.0) then 
        if(chkmode(i,2).eq.0.and.lfstatus(i,2).eq.2)then
          if(ailcg(i,2).lt.lfthrs(i,2).and.
     &      colddays(i,1).ge.coldlmt(1).and.
     &      ailcg(i,2).gt.zero)then
            lfstatus(i,2)=3         ! go into "leaf fall" mode
            chkmode(i,2)=1         
          else if(ailcg(i,2).le.zero) then
            lfstatus(i,2)=4         ! switch to "no leaves" mode
            chkmode(i,2)=1         
            pandays(i,2)=0
          else
            lfstatus(i,2)=2         ! stay in "normal growth" mode
            chkmode(i,2)=1         
          endif
        endif
      endif
c
c       broad leaf evg
       if (fcancmx(i,3).gt.0.0) then 
        if(chkmode(i,3).eq.0.and.lfstatus(i,3).eq.2)then
          if(ailcg(i,3).lt.lfthrs(i,3).and.ailcg(i,3).gt.zero)then  
            lfstatus(i,3)=1         ! go back to "max. growth" mode
            chkmode(i,3)=1         
          else if(ailcg(i,3).le.zero) then
            lfstatus(i,3)=4         ! switch to "no leaves" mode
            chkmode(i,3)=1         
            pandays(i,3)=0
          else
            lfstatus(i,3)=2         ! stay in "normal growth" mode
            chkmode(i,3)=1         
          endif
        endif 
       endif
c
c       broad leaf dcd cold
c       we use daylength and roottemp to initiate leaf offset
       if (fcancmx(i,4).gt.0.0) then 
        if(chkmode(i,4).eq.0.and.lfstatus(i,4).eq.2)then
          if( ailcg(i,4).gt.zero.and. 
     &    ((daylngth(i).lt.11.0.and.roottemp(i,4).lt.(11.15+273.16))  
     &    .or. roottemp(i,4).lt.(roothrsh+273.16)) )then
            lfstatus(i,4)=3         ! go into "leaf fall" mode
            chkmode(i,4)=1         
            flhrloss(i,4)=gleafmas(i,4)*(1.0/flhrspan(2))
          else if(ailcg(i,4).gt.zero.and.ailcg(i,4).lt.lfthrs(i,4))then 
            lfstatus(i,4)=1         ! switch to "max. growth" mode
            chkmode(i,4)=1         
          else if(ailcg(i,4).le.zero) then
            lfstatus(i,4)=4         ! switch to "no leaves" mode
            chkmode(i,4)=1         
            pandays(i,4)=0
            flhrloss(i,4)=0.0
          else
            lfstatus(i,4)=2         ! stay in "normal growth" mode
            chkmode(i,4)=1         
          endif
        endif 
       endif
c
c       broad leaf dcd dry
c       we still use daylength and roottemp to initiate leaf offset,
c       for the pathological cases of dry dcd trees being further
c       away from the equator then we can imagine. other wise leaf
c       loss will occur due to drought anyway.
       if (fcancmx(i,5).gt.0.0) then 
        if(chkmode(i,5).eq.0.and.lfstatus(i,5).eq.2)then
          if( ailcg(i,5).gt.zero.and. 
     &    ((daylngth(i).lt.11.0.and.roottemp(i,5).lt.(11.15+273.16))  
     &    .or. roottemp(i,5).lt.(roothrsh+273.16)) )then
            lfstatus(i,5)=3         ! go into "leaf fall" mode
            chkmode(i,5)=1         
          else if(ailcg(i,5).gt.zero.and.ailcg(i,5).lt.lfthrs(i,5))then   
            lfstatus(i,5)=1         ! switch to "max. growth" mode
            chkmode(i,5)=1         
          else if(ailcg(i,5).le.zero) then
            lfstatus(i,5)=4         ! switch to "no leaves" mode
            chkmode(i,5)=1         
            pandays(i,5)=0
          else
            lfstatus(i,5)=2         ! stay in "normal growth" mode
            chkmode(i,5)=1         
          endif
        endif 
       endif
c
320   continue
c
c     "normal growth" to "fall/harvest" transition for crops is based on
c     specified lai. we harvest if lai of crops reaches a threshold.
c     if lai doesn't reach this threshold (say due to a bad year)
c     we harvest anyway if it starts getting cold, otherwise we
c     don't harvest.
c
      do 340 j = 6,7
       n = sort(j)
        do 350 i = il1, il2
         if (fcancmx(i,j).gt.0.0) then 
          if(chkmode(i,j).eq.0.and.lfstatus(i,j).eq.2)then
            if(ailcg(i,j).ge.harvthrs(n))then
              lfstatus(i,j)=3        ! go into "harvest" mode
              chkmode(i,j)=1
              flhrloss(i,j)=gleafmas(i,j)*(1.0/flhrspan(1))
            else if( ailcg(i,j).gt.zero.and.
     &      colddays(i,2).ge.coldlmt(2) ) then
              lfstatus(i,j)=3        ! go into "harvest" mode
              chkmode(i,j)=1         ! regardless of lai
              flhrloss(i,j)=gleafmas(i,j)*(1.0/flhrspan(1))
            else if(ailcg(i,j).le.zero) then
              lfstatus(i,j)=4        ! switch to "no leaves" mode
              chkmode(i,j)=1         
              pandays(i,j)=0
              flhrloss(i,j)=0.0
            else
              lfstatus(i,j)=2        ! stay in "normal growth" mode
              chkmode(i,j)=1         
            endif
          endif
         endif
350     continue
340   continue
c
c     "normal growth" to "max. growth" transition for grasses 
c
      do 370 j = 8,9
        do 380 i = il1, il2
         if (fcancmx(i,j).gt.0.0) then 
          if(chkmode(i,j).eq.0.and.lfstatus(i,j).eq.2)then
            if(ailcg(i,j).lt.lfthrs(i,j).and.ailcg(i,j).gt.zero)then  
              lfstatus(i,j)=1        ! switch back to "max. growth" mode
              chkmode(i,j)=1
            else if(ailcg(i,j).le.zero) then
              lfstatus(i,j)=4        ! switch to "no leaves" mode
              chkmode(i,j)=1         
              pandays(i,j)=0
            else
              lfstatus(i,j)=2        ! stay in "normal growth" mode
              chkmode(i,j)=1
            endif
          endif
         endif
380     continue
370   continue 
c
c     if in "fall/harvest" mode
c     --------------------------
c
c     grasses and evg trees do not come into this mode, because they want
c     to stay green if possible. this mode is activated for dcd plants and
c     crops. once in this mode dcd trees loose their leaves and crops are
c     harvested. ndl dcd trees keep loosing their leaves at rate determined
c     by cold stress, bdl dcd trees loose their leaves at a specified
c     rate, and crops are harvested over a period of ~15 days. dcd trees
c     and crops stay in "leaf fall/harvest" model until all green leaves
c     are gone at which time they switch into "no leaves" mode, and then 
c     wait for the climate to become favourable to go into "max. growth"
c     mode
c

      do 400 j = 1, icc
        if(j.eq.2.or.j.eq.4.or.j.eq.5.or.j.eq.6.or.j.eq.7)then  !only dcd trees and crops
          do 410 i = il1, il2
           if (fcancmx(i,j).gt.0.0) then 
            if(chkmode(i,j).eq.0.and.lfstatus(i,j).eq.3)then
              if(ailcg(i,j).le.0.01)then
                lfstatus(i,j)=4            ! go into "no leaves" mode
                chkmode(i,j)=1
                pandays(i,j)=0
                flhrloss(i,j)=0.0
              else
                if(j.eq.2)then             ! ndl dcd trees
                  if(pandays(i,j).ge.dayschk(j).and.
     &            ta(i).gt.(coldthrs(1)+273.16)) then
                    if(ailcg(i,j).lt.lfthrs(i,j))then
                      lfstatus(i,j)=1      ! go into "max. growth" mode
                      chkmode(i,j)=1
                    else
                      lfstatus(i,j)=2      ! go into "normal growth" mode
                      chkmode(i,j)=1
                    endif
                  else  
                    lfstatus(i,j)=3        ! stay in "fall/harvest" mode 
                    chkmode(i,j)=1
                  endif
                else if(j.eq.4.or.j.eq.5)then        ! bdl dcd trees
                  if( (pandays(i,j).ge.dayschk(j)).and.
     &            ((roottemp(i,4).gt.(roothrsh+273.16)).and.
     &             (daylngth(i).gt.11.0) ) )then 
                    if(ailcg(i,j).lt.lfthrs(i,j))then
!       write(*,'(a5,2i4,3f10.3)')'lf6=',lfstatus(i,4),iday,roottemp(i,4)
!     & ,daylngth(i),ailcg(i,4)
                      lfstatus(i,j)=1      ! go into "max. growth" mode
                      chkmode(i,j)=1
                    else
!       write(*,'(a5,2i4,3f10.3)')'lf7=',lfstatus(i,4),iday,roottemp(i,4)
!     & ,daylngth(i),ailcg(i,4)
                      lfstatus(i,j)=2      ! go into "normal growth" mode
                      chkmode(i,j)=1
                    endif
                  else  
!       write(*,'(a5,2i4,3f10.3)')'lf8=',lfstatus(i,4),iday,roottemp(i,4)
!     & ,daylngth(i),ailcg(i,4)
                    lfstatus(i,j)=3        ! stay in "fall/harvest" mode 
                    chkmode(i,j)=1
                  endif
                else                       ! crops
                  lfstatus(i,j)=3          ! stay in "fall/harvest" mode 
                  chkmode(i,j)=1
                endif
              endif
            endif
           endif
410       continue
        endif
400   continue
c
!
!       FLAG test done to see impact of no alloc to leaves after 20 days past solstice! JM Dec 5 2014.
      do i = il1, il2
         j = 2 !needle dcd
           if (ailcg(i,j).gt.0.0) then 
             if (iday > 192 .and. radl(i) > 0. .and. lfstatus(i,j).ne.
     &             4) then ! north hemi past summer solstice
                 lfstatus(i,j) = 3 ! no allocation to leaves permitted
             else if ((iday < 172 .and. iday > 10) .and. radl(i) < 0.  !172 is solstice / 355 is austral summer 
     &               .and. lfstatus(i,j).ne. 4)then  ! southern hemi after austral summer solstice but before austral winter solstice
                 lfstatus(i,j) = 3 ! no allocation to leaves permitted
             end if
           endif
         j = 4  ! broad dcd
           if (ailcg(i,j).gt.0.0) then 
              if (iday > 192  .and.  radl(i) >0. .and. lfstatus(i,j).ne.
     &             4) then ! north hemi past summer solstice
                 lfstatus(i,j) = 3 ! no allocation to leaves permitted
              else if ((iday < 172 .and. iday > 10) .and. radl(i) < 0.
     &               .and. lfstatus(i,j).ne. 4) then  ! southern hemi after austral summer solstice but before austral winter solstice
                 lfstatus(i,j) = 3 ! no allocation to leaves permitted
              end if
           endif
      end do


c     check that leaf status of all vegetation types in all grid cells has
c     been updated
c
      do 411 j = 1, icc
        do 412 i = il1, il2
         if (fcancmx(i,j).gt.0.0) then 
          if(chkmode(i,j).eq.0)then
           write(6,2000) i,j
2000       format(' at (i) = (',i3,'), pft=',i2,' lfstatus not updated')   
           call xit('phenolgy',-2)
          endif
         endif
412     continue
411   continue
c
c     ------------------------------------------------------------------     
c
c     having decided leaf status for every pft, we now calculate normal
c     leaf turnover, cold and drought stress mortality, and for bdl dcd 
c     plants we also calculate specified loss rate if they are in "leaf fall"
c     mode, and for crops we calculate harvest loss, if they are in
c     "harvest" mode.
c
c     all these loss calculations will yield leaf litter in kg c/m2 for
c     the given day for all pfts 
c
c     normal leaf turn over
c
      do 420 j = 1, icc
        n = sort(j)
        do 430 i = il1, il2
         if (fcancmx(i,j).gt.0.0) then 
!         nrmlloss(i,j)=gleafmas(i,j)*(1.0-exp(-1.0/(365.0*lfespany(n)))) 
         ! FLAG! TEST Dec 10 2014 JM. Testing the influence of only allowing
         ! leaf aging turnover when the lfstatus is >1 (so normal alloc or 
         ! no alloc to leaves). When lfstatus is 1, it is not applied. 
           if (j == 2 .or. j == 4) then !only deciduous PFTs
                if (lfstatus(i,j) .ne. 1) then
                    nrmlloss(i,j)=gleafmas(i,j)*(1.0-exp(-1.0/
     &                          (365.0*lfespany(n))))
                else
                    nrmlloss(i,j)=0. ! no loss during leaf out.
                end if
            else ! pfts other than deciduous
                nrmlloss(i,j)=gleafmas(i,j)*(1.0-exp(-1.0/
     &                (365.0*lfespany(n))))
            end if  !decid/non
         endif   !fcancmx 
    
430     continue
420   continue
c
c     for drought stress related mortality we need field capacity 
c     and wilting point soil moisture contents, which we calculated
c     in allocate subroutine
c
c
      do 450 j = 1, ignd
        do 460 i = il1, il2
c
c         estimate (1-drought stress) 
c
          if(thliq(i,j).le.wiltsm(i,j)) then
            betadrgt(i,j)=0.0
          else if(thliq(i,j).gt.wiltsm(i,j).and.
     &      thliq(i,j).lt.fieldsm(i,j))then
            betadrgt(i,j)=(thliq(i,j)-wiltsm(i,j))
            betadrgt(i,j)=betadrgt(i,j)/(fieldsm(i,j)-wiltsm(i,j))
          else 
            betadrgt(i,j)=1.0
          endif          
          betadrgt(i,j)=max(0.0, min(1.0,betadrgt(i,j)))
c
460     continue
450   continue
c
c     estimate drought stress term averaged over the rooting depth
c     for each pft
c
      do 480 j = 1, icc
        n = sort(j)
        do 490 i = il1, il2
         if (fcancmx(i,j).gt.0.0) then 
          drgtstrs(i,j) =  (1.0-betadrgt(i,1))*rmatctem(i,j,1) +  
     &                     (1.0-betadrgt(i,2))*rmatctem(i,j,2) +  
     &                     (1.0-betadrgt(i,3))*rmatctem(i,j,3)   
          drgtstrs(i,j) = drgtstrs(i,j) /
     &     (rmatctem(i,j,1)+rmatctem(i,j,2)+rmatctem(i,j,3))  
          drgtstrs(i,j)=max(0.0, min(1.0,drgtstrs(i,j)))
c
c         using this drought stress term and our two vegetation-dependent
c         parameters we find leaf loss rate associated with drought
c
c         drought related leaf loss rate
          drgtlsrt(i,j)=drlsrtmx(n)*(drgtstrs(i,j)**drgta(n))
c
c         estimate leaf loss in kg c/m2 due to drought stress
          drgtloss(i,j)=gleafmas(i,j)*( 1.0-exp(-drgtlsrt(i,j)) )

c         similar to drgtstrs we find coldstrs for each pft. we assume that
c         max. cold stress related leaf loss occurs when temperature is 5 c
c         or more below pft's threshold

          if(ta(i).le.(lwrthrsh(n)-5.0+273.16))then
            coldstrs(i,j)=1.0
          else if(ta(i).gt.(lwrthrsh(n)-5.0+273.16).and.
     &    ta(i).lt.(lwrthrsh(n)+273.16))then
            coldstrs(i,j)=1.0-((ta(i)-(lwrthrsh(n)-5.0+273.16))/(5.0))   
          else 
            coldstrs(i,j)=0.0
          endif
          coldstrs(i,j)=max(0.0, min(1.0,coldstrs(i,j)))

c         using this cold stress term and our two vegetation-dependent
c         parameters we find leaf loss rate associated with cold

c         cold related leaf loss rate
          coldlsrt(i,j)=cdlsrtmx(n)*(coldstrs(i,j)**colda(n))
c
c         estimate leaf loss in kg c/m2 due to cold stress
          coldloss(i,j)=gleafmas(i,j)*( 1.0-exp(-coldlsrt(i,j)) )

         endif
490     continue 
480   continue 

c     now that we have all types of leaf losses (due to normal turnover,
c     cold and drought stress, and fall/harvest) we take the losses
c     for grasses and use those to turn live green grass into dead
c     brown grass. we then find the leaf litter from the brown grass
c     which will then go into the litter pool.
c
      do 620 j = 8,9
        n = sort(j)
        do 630 i = il1, il2
         if (fcancmx(i,j).gt.0.0) then 
          gleafmas(i,j)   = gleafmas(i,j)-nrmlloss(i,j)-drgtloss(i,j)-  
     &                      coldloss(i,j)
          if( gleafmas(i,j).lt.0.0) then
            bleafmas(i,j) = bleafmas(i,j)+nrmlloss(i,j)+drgtloss(i,j)+  
     &                      coldloss(i,j)+gleafmas(i,j)
            gleafmas(i,j)=0.0
          else
            bleafmas(i,j) = bleafmas(i,j)+nrmlloss(i,j)+drgtloss(i,j)+  
     &                      coldloss(i,j)
          endif
          nrmlloss(i,j) = 0.0
          drgtloss(i,j) = 0.0
          coldloss(i,j) = 0.0
c         we assume life span of brown grass is 10% that of green grass
c         but this is an adjustable parameter.
          nrmlloss(i,j) = bleafmas(i,j)*
     &      (1.0-exp(-1.0/(0.10*365.0*lfespany(n)))) 
         endif      
630     continue
620   continue 
c
c     combine nrmlloss, drgtloss, and coldloss together to get total
c     leaf litter generated, which is what we use to update gleafmass,
c     except for grasses, for which we have alerady updated gleafmass.
c
      do 650 j = 1, icc
        do 660 i = il1, il2
         if (fcancmx(i,j).gt.0.0) then 
          leaflitr(i,j) = nrmlloss(i,j)+drgtloss(i,j)+coldloss(i,j)+
     &                    flhrloss(i,j)
         endif
660     continue
650   continue
c
      return
      end

