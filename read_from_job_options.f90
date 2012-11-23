subroutine read_from_job_options(ARGBUFF,CTEMLOOP,CTEM1,CTEM2,NCYEAR,LNDUSEON,SPINFAST,CYCLEMET, &
                  NUMMETCYLYRS,METCYLYRST,CO2ON,SETCO2CONC,POPDON,POPCYCLEYR, &
                  PARALLELRUN,DOFIRE,COMPETE,START_BARE,RSFILE,IDISP,IZREF,ISLFD,IPCP,ITC,ITCG, &
                  ITG,IWF,IPAI,IHGT,IALC,IALS,IALG,JHHSTD,JHHENDD,JDSTD, & 
                  JDENDD,JHHSTY,JHHENDY,JDSTY,JDENDY)

!#ifdef NAGf95
!use F90_UNIX
!#endif

!           CANADIAN TERRESTRIAL ECOSYSTEM MODEL (CTEM) V1.1
!                    JOBOPTIONS READ-IN SUBROUTINE 
!
!     17  OCT. 2012 - ADDED THE START_BARE SWITCH FOR COMPETE RUNS
!     J. MELTON

!     25  APR. 2012 - THIS SUBROUTINE TAKES IN MODEL SWITCHES FROM
!     J. MELTON       A JOB FILE AND PUSHES THEM TO RUNCLASS35CTEM
!		      

implicit none

! -------------
! CTEM Model Switches

character(80), intent(out) :: ARGBUFF !prefix of file names

integer, intent(out) :: CTEMLOOP ! NO. OF TIMES THE .MET FILE IS TO BE READ. THIS
                    	         ! OPTION IS USEFUL TO SEE HOW CTEM's C POOLS
                    	         ! EQUILIBRATE WHEN DRIVEN WITH SAME CLIMATE DATA
                    	         ! OVER AND OVER AGAIN.

logical, intent(out) :: CTEM1    ! AS OF CLASS36CTEM, THIS IS NO LONGER USED! KEEP AS TRUE.
                                 ! SET THIS TO TRUE FOR USING STOMATAL CONDUCTANCE
				 ! CALCULATED BY PHTSYN SUBROUTINE, ELSE THE STANDARD
 				 ! JARVIS TYPE FORMULATION OF CLASS 2.7 IS USED. WITH
 				 ! ONLY THIS SWITCH ON CLASS' LAI IS USED.
				 
logical, intent(out) :: CTEM2    ! SET THIS TO TRUE FOR USING CTEM SIMULATED DYNAMIC
 				 ! LAI AND CANOPY MASS, ELSE CLASS SIMULATED SPECIFIED
 				 ! LAI AND CANOPY MASS ARE USED. WITH THIS SWITCH ON,
 				 ! ALL CTEM SUBROUTINES ARE RUN.

integer, intent(out) :: NCYEAR   ! NO. OF YEARS IN THE .MET FILE. 

logical, intent(out) :: LNDUSEON ! SET THIS TO 1 IF LAND USE CHANGE IS TO BE
 				 ! IMPLIMENTED BY READING IN THE FRACTIONS OF 9 CTEM
 				 ! PFTs FROM A FILE. KEEP IN MIND THAT ONCE ON, LUC READ-IN IS
                                 ! ALSO INFLUENCED BY THE CYCLEMET AND POPCYCLEYR
                                 ! SWITCHES

integer, intent(out) :: SPINFAST ! SET THIS TO A HIGHER NUMBER UP TO 10 TO SPIN UP
 				 ! SOIL CARBON POOL FASTER

logical, intent(out) :: CYCLEMET ! TO CYCLE OVER ONLY A FIXED NUMBER OF YEARS 
 				 ! (NUMMETCYLYRS) STARTING AT A CERTAIN YEAR (METCYLYRST)
 				 ! IF CYCLEMET, THEN PUT CO2ON = FALSE AND SET AN APPOPRIATE SETCO2CONC, ALSO
 				 ! IF POPDON IS TRUE, IT WILL CHOOSE THE POPN AND LUC DATA FOR YEAR
 				 ! METCYLYRST AND CYCLE ON THAT.

integer, intent(out) :: NUMMETCYLYRS ! YEARS OF THE CLIMATE FILE TO SPIN UP ON REPEATEDLY
 				 ! IGNORED IF CYCLEMET IS FALSE

integer, intent(out) :: METCYLYRST   ! CLIMATE YEAR TO START THE SPIN UP ON
 				 ! IGNORED IF CYCLEMET IS FALSE

logical, intent(out) :: CO2ON    ! USE CO2 TIME SERIES, SET TO FALSE IF CYCLEMET IS TRUE

real, intent(out) :: SETCO2CONC  ! SET THE VALUE OF ATMOSPHERIC CO2 IF CO2ON IS FALSE.

logical, intent(out) :: POPDON   ! IF SET TRUE USE POPULATION DENSITY DATA TO CALCULATE FIRE EXTINGUISHING 
 				 ! PROBABILITY AND PROBABILITY OF FIRE DUE TO HUMAN CAUSES, 
 				 ! OR IF FALSE, READ DIRECTLY FROM .CTM FILE

integer, intent(out) :: POPCYCLEYR ! POPD AND LUC YEAR TO CYCLE ON WHEN CYCLEMET IS TRUE, SET TO -9999
				 ! TO CYCLE ON METCYLYRST FOR BOTH POPD AND LUC. IF CYCLEMET IS FALSE
                                 ! THIS DEFAULTS TO -9999, WHICH WILL THEN CAUSE THE MODEL TO CYCLE ON
                                 ! WHATEVER IS THE FIRST YEAR IN THE POPD AND LUC DATASETS

logical, intent(out) :: PARALLELRUN ! SET THIS TO BE TRUE IF MODEL IS RUN IN PARALLEL MODE FOR 
 				 ! MULTIPLE GRID CELLS, OUTPUT IS LIMITED TO MONTHLY & YEARLY 
 				 ! GRID-MEAN ONLY. ELSE THE RUN IS IN STAND ALONE MODE, IN WHICH 
 				 ! OUTPUT INCLUDES HALF-HOURLY AND DAILY AND MOSAIC-MEAN AS WELL.

logical, intent(out) :: DOFIRE   ! IF TRUE THE FIRE/DISTURBANCE SUBROUTINE WILL BE USED.

logical, intent(out) :: COMPETE  ! SET THIS TO TRUE IF COMPETITION BETWEEN PFTs IS
 				 ! TO BE IMPLIMENTED

logical, intent(out) :: START_BARE !SET THIS TO TRUE IF COMPETITION IS TRUE, AND IF YOU WISH
                                 ! TO START FROM BARE GROUND. IF THIS IS SET TO FALSE, THE 
                                 ! INI AND CTM FILE INFO WILL BE USED TO SET UP THE RUN.

logical, intent(out) :: RSFILE   ! SET THIS TO TRUE IF RESTART FILES (.INI_RS AND .CTM_RS)   
 				 ! ARE WRITTEN AT THE END OF EACH YEAR. THESE FILES ARE  
 				 ! NECESSARY FOR CHECKING WHETHER THE MODEL REACHES 
 				 ! EQUILIBRIUM AFTER RUNNING FOR A CERTAIN YEARS. 
 				 ! SET THIS TO FALSE IF RESTART FILES ARE NOT NEEDED 
 				 ! (KNOWN HOW MANY YEARS THE MODEL WILL RUN)

! -------------
! CLASS Model Switches

integer, intent(out) :: IDISP    ! IF IDISP=0, VEGETATION DISPLACEMENT HEIGHTS ARE IGNORED,
				 ! BECAUSE THE ATMOSPHERIC MODEL CONSIDERS THESE TO BE PART
				 ! OF THE "TERRAIN".
				 ! IF IDISP=1, VEGETATION DISPLACEMENT HEIGHTS ARE CALCULATED.

integer, intent(out) :: IZREF    ! IF IZREF=1, THE BOTTOM OF THE ATMOSPHERIC MODEL IS TAKEN
				 ! TO LIE AT THE GROUND SURFACE.
				 ! IF IZREF=2, THE BOTTOM OF THE ATMOSPHERIC MODEL IS TAKEN
				 ! TO LIE AT THE LOCAL ROUGHNESS HEIGHT.

integer, intent(out) :: ISLFD    ! IF ISLFD=0, DRCOEF IS CALLED FOR SURFACE STABILITY CORRECTIONS
				 ! AND THE ORIGINAL GCM SET OF SCREEN-LEVEL DIAGNOSTIC CALCULATIONS 
				 ! IS DONE.
				 ! IF ISLFD=1, DRCOEF IS CALLED FOR SURFACE STABILITY CORRECTIONS
				 ! AND SLDIAG IS CALLED FOR SCREEN-LEVEL DIAGNOSTIC CALCULATIONS. 
				 ! IF ISLFD=2, FLXSURFZ IS CALLED FOR SURFACE STABILITY CORRECTIONS
				 ! AND DIASURF IS CALLED FOR SCREEN-LEVEL DIAGNOSTIC CALCULATIONS. 

integer, intent(out) :: IPCP     ! IF IPCP=1, THE RAINFALL-SNOWFALL CUTOFF IS TAKEN TO LIE AT 0 C.
				 ! IF IPCP=2, A LINEAR PARTITIONING OF PRECIPITATION BETWEEEN 
				 ! RAINFALL AND SNOWFALL IS DONE BETWEEN 0 C AND 2 C.
				 ! IF IPCP=3, RAINFALL AND SNOWFALL ARE PARTITIONED ACCORDING TO
				 ! A POLYNOMIAL CURVE BETWEEN 0 C AND 6 C.

integer, intent(out) :: IWF     ! IF IWF=0, ONLY OVERLAND FLOW AND BASEFLOW ARE MODELLED, AND
				! THE GROUND SURFACE SLOPE IS NOT MODELLED.
				! IF IWF=n (0<n<4), THE WATFLOOD CALCULATIONS OF OVERLAND FLOW 
				! AND INTERFLOW ARE PERFORMED; INTERFLOW IS DRAWN FROM THE TOP 
				! n SOIL LAYERS.

! ITC, ITCG AND ITG ARE SWITCHES TO CHOOSE THE ITERATION SCHEME TO
! BE USED IN CALCULATING THE CANOPY OR GROUND SURFACE TEMPERATURE
! RESPECTIVELY.  IF THE SWITCH IS SET TO 1, A BISECTION METHOD IS
! USED; IF TO 2, THE NEWTON-RAPHSON METHOD IS USED.
integer, intent(out) :: ITC
integer, intent(out) :: ITCG
integer, intent(out) :: ITG

! IF IPAI, IHGT, IALC, IALS AND IALG ARE ZERO, THE VALUES OF 
! PLANT AREA INDEX, VEGETATION HEIGHT, CANOPY ALBEDO, SNOW ALBEDO
! AND SOIL ALBEDO RESPECTIVELY CALCULATED BY CLASS ARE USED.
! IF ANY OF THESE SWITCHES IS SET TO 1, THE VALUE OF THE
! CORRESPONDING PARAMETER CALCULATED BY CLASS IS OVERRIDDEN BY
! A USER-SUPPLIED INPUT VALUE.
!      
integer, intent(out) :: IPAI
integer, intent(out) :: IHGT
integer, intent(out) :: IALC
integer, intent(out) :: IALS
integer, intent(out) :: IALG

! -------------
! CLASS35CTEM OUTPUT SWITCHES

! >>>> NOTE: If you wish to use the values in the .INI file, set all to -9999 in the job options file
!            and the .INI file will be used.

integer, intent(out) :: JHHSTD    ! DAY OF THE YEAR TO START WRITING THE HALF-HOURLY OUTPUT
integer, intent(out) :: JHHENDD   ! DAY OF THE YEAR TO STOP WRITING THE HALF-HOURLY OUTPUT
integer, intent(out) :: JDSTD     ! DAY OF THE YEAR TO START WRITING THE DAILY OUTPUT
integer, intent(out) :: JDENDD    ! DAY OF THE YEAR TO STOP WRITING THE DAILY OUTPUT
integer, intent(out) :: JHHSTY    ! SIMULATION YEAR (IYEAR) TO START WRITING THE HALF-HOURLY OUTPUT
integer, intent(out) :: JHHENDY   ! SIMULATION YEAR (IYEAR) TO STOP WRITING THE HALF-HOURLY OUTPUT
integer, intent(out) :: JDSTY     ! SIMULATION YEAR (IYEAR) TO START WRITING THE DAILY OUTPUT
integer, intent(out) :: JDENDY    ! SIMULATION YEAR (IYEAR) TO STOP WRITING THE DAILY OUTPUT

! -------------

namelist /joboptions/ &
  CTEMLOOP,           &
  CTEM1,              &
  CTEM2,              &
  NCYEAR,             &
  LNDUSEON,           &
  SPINFAST,           &
  CYCLEMET,           &
  NUMMETCYLYRS,       &
  METCYLYRST,         &
  CO2ON,              &
  SETCO2CONC,         &
  POPDON,             &
  POPCYCLEYR,         &
  PARALLELRUN,        &
  DOFIRE,             &
  COMPETE,            &
  START_BARE,         &
  RSFILE,             &
  IDISP,              &
  IZREF,              &
  ISLFD,              &
  IPCP,               &
  ITC,                &
  ITCG,               &
  ITG,                &
  IWF,                &
  IPAI,               &
  IHGT,               &
  IALC,               &
  IALS,               &
  IALG,               &
  JHHSTD,             &
  JHHENDD,            &
  JDSTD,              &
  JDENDD,             &
  JHHSTY,             &
  JHHENDY,            &
  JDSTY,              &
  JDENDY

character(140) :: jobfile
integer :: argcount, IARGC 

!-------------------------
!read the joboptions

argcount = IARGC()

       IF(argcount .NE. 2)THEN
         WRITE(*,*)'Usage is as follows'
         WRITE(*,*)' '
         WRITE(*,*)'RUNCLASS36CTEM joboptions_file SITE_NAME'
         WRITE(*,*)' '
         WRITE(*,*)'- joboptions_file - an example can be found '
         WRITE(*,*)'  in the src folder - template_job_options_file.txt.'
         WRITE(*,*)'  Descriptions of the various variables '
         WRITE(*,*)'  can be found in read_from_job_options.f90 '
         WRITE(*,*)' '
         WRITE(*,*)'- SITE_NAME is the prefix of your input files '
         WRITE(*,*)' '
         STOP
      END IF


call getarg(1,jobfile)

open(10,file=jobfile,status='old')

read(10,nml = joboptions)

close(10)

call getarg(2,ARGBUFF)


end subroutine read_from_job_options

