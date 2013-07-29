      subroutine hetresv ( fcan,      fct, litrmass, soilcmas,   
     1                      il1,
     2                      il2,     tbar,    thliq,     sand,     
     3                     clay, roottemp,    zbotw,     sort,
     4                     isand,
c    -------------- inputs above this line, outputs below -------------
     5                 ltresveg, scresveg)  
c
C               Canadian Terrestrial Ecosystem Model (CTEM) 
C           Heterotrophic Respiration Subtoutine For Vegetated Fraction
c
c     16  oct. 2001 - this subroutine calculates heterotrophic respiration
c     v. arora        for a given sub-area, from litter and soil carbon
c                     pools. 
c
c     change history:

c     22  Jul 2013  - Add in module for parameters
C     J. Melton
c
c     j. melton and v.arora - changed tanhq10 parameters, they were switched
c               25 sep 2012
c     j. melton 23 aug 2012 - bring in isand, converting sand to
c                             int was missing some gridcells assigned
c                             to bedrock in classb
c     ------
c     inputs 
c
c     fcan      - fractional coverage of ctem's 9 pfts
c     fct       - sum of all fcan
c                 fcan & fct are not used at this time but could
c                 be used at some later stage
c     litrmass  - litter mass for the 9 pfts + bare in kg c/m2
c     soilcmas  - soil carbon mass for the 9 pfts + bare in kg c/m2
c     icc       - no. of vegetation types (currently 9)
c     ignd        - no. of soil layers (currently 3)
c     ilg       - no. of grid cells in latitude circle
c     il1,il2   - il1=1, il2=ilg
c     tbar      - soil temperature, k
c     thliq     - liquid soil moisture content in 3 soil layers
c     sand      - percentage sand
c     clay      - percentage clay
c     roottemp  - root temperature as estimated in mainres subroutine
c     zbotw     - bottom of soil layers
c     sort      - index for correspondence between 9 pfts and 12 values
c                 in the parameters vectors
c
c     outputs
c
c     ltresveg  - litter respiration for the given sub-area in
c                 umol co2/m2.s, for ctem's 9 pfts
c     scresveg  - soil carbon respiration for the given sub-area in
c                 umol co2/m2.s, for ctem's 9 pfts
c
      use ctem_params,        only : icc, ilg, ignd, kk, zero

      implicit none

      integer  il1, il2, i, j, k, sort(icc), isand(ilg,ignd) 
c
      real    fcan(ilg,icc),           fct(ilg),  litrmass(ilg,icc+1), 
     1         tbar(ilg,ignd),soilcmas(ilg,icc+1),      thliq(ilg,ignd),  
     2         sand(ilg,ignd),       clay(ilg,ignd),  roottemp(ilg,icc),  
     3        zbotw(ilg,ignd),  ltresveg(ilg,icc),    scresveg(ilg,icc)

      real     bsratelt(kk),       bsratesc(kk), 
     1              litrq10,           soilcq10,               alpha,
     2    litrtemp(ilg,icc),  solctemp(ilg,icc),             q10func,
     3       psisat(ilg,ignd),     grksat(ilg,ignd),        b(ilg,ignd),
     4        thpor(ilg,ignd),       
     5  fracarb(ilg,icc,ignd),           abar(kk),             zcarbon,
     6    tempq10l(ilg,icc),  socmoscl(ilg,icc),     scmotrm(ilg,ignd),
     7        ltrmoscl(ilg),        psi(ilg,ignd),   tempq10s(ilg,icc),
     8               fcoeff,         tanhq10(4)  
c
c     ------------------------------------------------------------------
c                     constants and parameters
c
c     note the structure of vectors which clearly shows the class
c     pfts (along rows) and ctem sub-pfts (along columns)
c
c     needle leaf |  evg       dcd       ---
c     broad leaf  |  evg   dcd-cld   dcd-dry
c     crops       |   c3        c4       ---
c     grasses     |   c3        c4       ---
c
c     litter respiration rates at 15 c in in kg c/kg c.year 
      data bsratelt/0.4453, 0.5986, 0.0000,
     &              0.6339, 0.7576, 0.6957,
c     &              0.4020, 0.4020, 0.0000,
     &              0.6000, 0.6000, 0.0000,
     &              0.5260, 0.5260, 0.0000/ 
c
c     soil carbon respiration rates at 15 c in kg c/kg c.year
      data bsratesc/0.0260, 0.0260, 0.0000, 
     &              0.0208, 0.0208, 0.0208,
c     &              0.0310, 0.0310, 0.0000,
     &              0.0350, 0.0350, 0.0000, 
     &              0.0125, 0.0125, 0.0000/ 
c
c     parameter determining average carbon profile, same as in bio2str f0r
c     average root profile
c
      data abar/4.70, 5.86, 0.00,
     &          3.87, 3.46, 3.97,
     &          3.97, 3.97, 0.00,
     &          5.86, 4.92, 0.00/
c
c     parameters of the hyperbolic tan q10 formulation
c
      data tanhq10/1.44, 0.56, 0.075, 46.0/
c                     a     b      c     d
c     q10 = a + b * tanh[ c (d-temperature) ]
c     when a = 2, b = 0, we get the constant q10 of 2. if b is non
c     zero then q10 becomes temperature dependent
c
c     alpha, parameter for finding litter temperature as a weighted average 
c     of top soil layer temperature and root temperature
      data alpha/0.7/
c
c     ---------------------------------------------------------------
c
c     initialize required arrays to zero

      do 100 j = 1, icc
        do 110 i = il1, il2
          litrtemp(i,j)=0.0       ! litter temperature
          tempq10l(i,j)=0.0
          solctemp(i,j)=0.0       ! soil carbon pool temperature
          tempq10s(i,j)=0.0
          socmoscl(i,j)=0.0       ! soil moisture scalar for soil carbon decomposition
          ltresveg(i,j)=0.0       ! litter resp. rate for each pft 
          scresveg(i,j)=0.0       ! soil c resp. rate for each pft
110     continue
100   continue
c
      do 120 j = 1, ignd
        do 130 i = il1, il2
          psisat(i,j) = 0.0       ! saturation matric potential
          grksat(i,j) = 0.0       ! saturation hyd. conductivity
          thpor(i,j) = 0.0        ! porosity
          b(i,j) = 0.0            ! parameter b of clapp and hornberger
          scmotrm(i,j)=0.0        ! soil carbon moisture term
c         isand(i,j)=nint(sand(i,j)) !now passed in. jm. aug 23 2012
130     continue
120   continue

      do 140 i = il1, il2
        ltrmoscl(i)=0.0           ! soil moisture scalar for litter decomposition
140   continue
c
      do 150 k = 1, ignd
        do 150 j = 1, icc
          do 150 i = il1, il2
            fracarb(i,j,k)=0.0    ! fraction of carbon in each soil layer for each vegetation
150   continue
c
c     initialization ends    
c
c     ------------------------------------------------------------------
c
c     estimate temperature of the litter and soil carbon pools. litter
c     temperature is weighted average of temperatue of top soil layer
c     (where the stem and leaf litter sits) and root temperature, because
c     litter pool is made of leaf, stem, and root litter.
c     
      do 200 j = 1,icc
        do 210 i = il1, il2
         if (fcan(i,j) .gt. 0.) then
          litrtemp(i,j)=alpha*tbar(i,1)+roottemp(i,j)*(1.0-alpha)
         endif
210     continue
200   continue
c
c     estimation of soil carbon pool temperature is not straight forward.
c     ideally soil c pool temperature should be set same as root temperature,
c     since soil c profiles are similar to root profiles. but in the event
c     when the roots die then we may run into trouble. so we find the 
c     temperature of the soil c pool assuming that soil carbon is
c     exponentially distributed, just like roots. but rather than using 
c     the parameter of this exponential profile from our variable root 
c     distribution we use fixed vegetation-dependent parameters.
c
      do 230 j = 1, icc
        do 240 i = il1, il2
         if (fcan(i,j) .gt. 0.) then
c
          zcarbon=3.0/abar(sort(j))                ! 95% depth
          if(zcarbon.le.zbotw(i,1)) then
              fracarb(i,j,1)=1.0             ! fraction of carbon in
              fracarb(i,j,2)=0.0             ! soil layers
              fracarb(i,j,3)=0.0
          else
              fcoeff=exp(-abar(sort(j))*zcarbon)
              fracarb(i,j,1)=
     &          1.0-(exp(-abar(sort(j))*zbotw(i,1))-fcoeff)/(1.0-fcoeff) 
              if(zcarbon.le.zbotw(i,2)) then
                  fracarb(i,j,2)=1.0-fracarb(i,j,1)
                  fracarb(i,j,3)=0.0
              else
                  fracarb(i,j,3)=
     &             (exp(-abar(sort(j))*zbotw(i,2))-fcoeff)/(1.0-fcoeff)    
                  fracarb(i,j,2)=1.0-fracarb(i,j,1)-fracarb(i,j,3)
              endif
          endif
c
          solctemp(i,j)=tbar(i,1)*fracarb(i,j,1) +
     &                  tbar(i,2)*fracarb(i,j,2) +
     &                  tbar(i,3)*fracarb(i,j,3)
          solctemp(i,j)=solctemp(i,j) /
     &       (fracarb(i,j,1)+fracarb(i,j,2)+fracarb(i,j,3))
c
c         make sure we don't use temperatures of 2nd and 3rd soil layers
c         if they are specified bedrock via sand -3 flag
c
          if(isand(i,3).eq.-3)then ! third layer bed rock
            solctemp(i,j)=tbar(i,1)*fracarb(i,j,1) +
     &                    tbar(i,2)*fracarb(i,j,2) 
            solctemp(i,j)=solctemp(i,j) /
     &         (fracarb(i,j,1)+fracarb(i,j,2))
          endif 
          if(isand(i,2).eq.-3)then ! second layer bed rock
            solctemp(i,j)=tbar(i,1)
          endif
        endif
240     continue     
230   continue     
c
c     find moisture scalar for soil c decomposition
c
c     this is modelled as function of logarithm of matric potential. 
c     we find values for all soil layers, and then find an average value 
c     based on fraction of carbon present in each layer. this makes
c     moisture scalar a function of vegetation type.
c
      do 260 j = 1, ignd
        do 270 i = il1, il2
c
          if(isand(i,j).eq.-3.or.isand(i,j).eq.-4)then
            scmotrm (i,j)=0.2
            psi (i,j) = 10000.0 ! set to large number so that
c                               ! ltrmoscl becomes 0.2
          else ! i.e., sand.ne.-3 or -4
            psisat(i,j)= (10.0**(-0.0131*sand(i,j)+1.88))/100.0
            b(i,j)     = 0.159*clay(i,j)+2.91
            thpor(i,j) = (-0.126*sand(i,j)+48.9)/100.0
            psi(i,j)   = psisat(i,j)*(thliq(i,j)/thpor(i,j))**(-b(i,j)) 
c   
            if(psi(i,j).gt.10000.0) then
              scmotrm(i,j)=0.2
            else if( psi(i,j).le.10000.0 .and.  psi(i,j).gt.6.0 ) then
              scmotrm(i,j)=1.0 - 0.8*
     &    ( (log10(psi(i,j)) - log10(6.0))/(log10(10000.0)-log10(6.0)) )               
            else if( psi(i,j).le.6.0 .and. psi(i,j).ge.4.0 ) then
              scmotrm(i,j)=1.0
            else if( psi(i,j).lt.4.0 .and. psi(i,j).gt.psisat(i,j) )then 
              scmotrm(i,j)=1.0 - 
     &          0.5*( (log10(4.0) - log10(psi(i,j))) / 
     &         (log10(4.0)-log10(psisat(i,j))) )
            else if( psi(i,j).le.psisat(i,j) ) then
              scmotrm(i,j)=0.5
            endif
            scmotrm(i,j)=max(0.2,min(1.0,scmotrm(i,j)))
          endif ! sand.eq.-3 or -4
c
270     continue     
260   continue     
c
      do 280 j = 1, icc
        do 290 i = il1, il2
         if (fcan(i,j) .gt. 0.) then
          socmoscl(i,j) = scmotrm(i,1)*fracarb(i,j,1) + 
     &                    scmotrm(i,2)*fracarb(i,j,2) +
     &                    scmotrm(i,3)*fracarb(i,j,3)
          socmoscl(i,j) = socmoscl(i,j) /
     &       (fracarb(i,j,1)+fracarb(i,j,2)+fracarb(i,j,3))    
c
c         make sure we don't use scmotrm of 2nd and 3rd soil layers
c         if they are specified bedrock via sand -3 flag
c
          if(isand(i,3).eq.-3)then ! third layer bed rock
            socmoscl(i,j) = scmotrm(i,1)*fracarb(i,j,1) + 
     &                      scmotrm(i,2)*fracarb(i,j,2) 
            socmoscl(i,j) = socmoscl(i,j) /
     &       (fracarb(i,j,1)+fracarb(i,j,2))
          endif
          if(isand(i,2).eq.-3)then ! second layer bed rock
            socmoscl(i,j) = scmotrm(i,1)
          endif
          socmoscl(i,j)=max(0.2,min(1.0,socmoscl(i,j)))
         endif
290     continue     
280   continue     
c
c     find moisture scalar for litter decomposition
c
c     the difference between moisture scalar for litter and soil c
c     is that the litter decomposition is not constrained by high
c     soil moisture (assuming that litter is always exposed to air).
c     in addition, we use moisture content of the top soil layer
c     as a surrogate for litter moisture content. so we use only 
c     psi(i,1) calculated in loops 260 and 270 above.
c
      do 300 i = il1, il2
        if(psi(i,1).gt.10000.0) then
          ltrmoscl(i)=0.2
        else if( psi(i,1).le.10000.0 .and. psi(i,1).gt.6.0 ) then
          ltrmoscl(i)=1.0 -  0.8*
     &    ( (log10(psi(i,1)) - log10(6.0))/(log10(10000.0)-log10(6.0)) )
        else if( psi(i,1).le.6.0 ) then
          ltrmoscl(i)=1.0 
        endif
        ltrmoscl(i)=max(0.2,min(1.0,ltrmoscl(i)))
300   continue
c
c     use temperature of the litter and soil c pools, and their soil
c     moisture scalars to find respiration rates from these pools
c
      do 320 j = 1, icc
        do 330 i = il1, il2
         if (fcan(i,j) .gt. 0.) then
c
c         first find the q10 response function to scale base respiration
c         rate from 15 c to current temperature, we do litter first
c
          tempq10l(i,j)=litrtemp(i,j)-273.16
          litrq10 = tanhq10(1) + tanhq10(2)*
     &              ( tanh( tanhq10(3)*(tanhq10(4)-tempq10l(i,j))  ) )
c
          q10func = litrq10**(0.1*(litrtemp(i,j)-273.16-15.0))
          ltresveg(i,j)= ltrmoscl(i) * litrmass(i,j)*
     &      bsratelt(sort(j))*2.64*q10func ! 2.64 converts bsratelt from kg c/kg c.year
c                                          ! to u-mol co2/kg c.s
c         respiration from soil c pool
c
          tempq10s(i,j)=solctemp(i,j)-273.16
          soilcq10= tanhq10(1) + tanhq10(2)*
     &              ( tanh( tanhq10(3)*(tanhq10(4)-tempq10s(i,j))  ) )
c
          q10func = soilcq10**(0.1*(solctemp(i,j)-273.16-15.0))
          scresveg(i,j)= socmoscl(i,j)* soilcmas(i,j)*
     &      bsratesc(sort(j))*2.64*q10func  ! 2.64 converts bsratesc from kg c/kg c.year 
c                                           ! to u-mol co2/kg c.s
c
         endif
330     continue
320   continue
c
      return
      end
