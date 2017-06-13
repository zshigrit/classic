!>\file
!! Main model driver for CLASSIC in stand-alone mode using specified boundary
!! conditions and atmospheric forcing. This driver program initializes the run,
!! reads in CLASS input files, manages the run and the coupling between CLASS
!! and CTEM, writes the CLASS sub-monthly outputs, and closes the run.

module main_driver

    implicit none

    public :: CLASSIC_driver

contains

    subroutine CLASSIC_driver(longitude, latitude)
        !
        !>
        !!------------------------------------------------------------------
        !! ## Dimension statements.

        !!     ### first set of definitions:
        !!     background variables, and prognostic and diagnostic
        !!     variables normally provided by and/or used by the gcm.
        !!      the suffix "rot" refers to variables existing on the
        !!      mosaic grid on the current latitude circle.  the suffix
        !!      "gat" refers to the same variables after they have undergone
        !!      a "gather" operation in which the two mosaic dimensions
        !!      are collapsed into one.  the suffix "row" refers both to
        !!      grid-constant input variables. and to grid-averaged
        !!      diagnostic variables.
        !!
        !!      the first dimension element of the "rot" variables
        !!      refers to the number of grid cells on the current
        !!      latitude circle.  in this stand-alone version, this
        !!      number is arbitrarily set to three, to allow up to three
        !!      simultaneous tests to be run.  the second dimension
        !!      element of the "rot" variables refers to the maximum
        !!      number of tiles in the mosaic.  in this stand-alone
        !!      version, this number is set to eight.  the first
        !!      dimension element in the "gat" variables is given by
        !!      the product of the first two dimension elements in the
        !!      "rot" variables.
        !!
        !!     The majority of CTEM parameters are stored in ctem_params.f90.
        !!     Also the CTEM variables are stored in modules that we point to
        !!     in this driver. We access the variables and parameters
        !!     through use statements for modules:

        use ctem_params,        only : nlat,nmos,ilg,nmon,&
            &                               ican, ignd,icp1, icc, iccp1,&
            &                               monthend, mmday,modelpft, l2max,&
            &                                deltat, abszero, monthdays,seed,&
            &                                NBS, earthrad,&
            &                                readin_params,crop

        use landuse_change,     only : initialize_luc, readin_luc

        use ctem_statevars,     only : vrot,vgat,c_switch,initrowvars,&
            &                               class_out,resetclassmon,&
            &                               resetclassyr,&
            &                               resetmonthend,resetyearend,&
            &                               resetclassaccum,ctem_grd,&
            &                               ctem_tile,resetgridavg,&
            &                               finddaylength,&
            &                               ctem_mo,ctem_grd_mo,ctem_tile_mo, &
            &                               ctem_yr,ctem_grd_yr,ctem_tile_yr

        use class_statevars,    only : class_gat,class_rot

        use io_driver,          only : read_from_ctm, create_outfiles,&
            &                               write_ctm_rs, class_monthly_aw,&
            &                               ctem_annual_aw,ctem_monthly_aw,&
            &                               close_outfiles,ctem_daily_aw,&
            &                               class_annual_aw,bounds

        use model_state_drivers, only : read_initialstate

        implicit none

        ! Flag test
        real, intent(in) :: longitude, latitude

        !
        !     * INTEGER CONSTANTS.
        !
        INTEGER IDISP  !<Flag governing treatment of vegetation displacement height
        INTEGER IZREF  !<Flag governing treatment of surface roughness length
        INTEGER ISLFD  !<Flag governing options for surface stability functions and diagnostic calculations
        INTEGER IPCP   !<Flag selecting algorithm for dividing precipitation between rainfall and snowfall
        INTEGER IWF    !<Flag governing lateral soil water flow calculations
        INTEGER IPAI   !<Flag to enable use of user-specified plant area index
        INTEGER IHGT   !<Flag to enable use of user-specified vegetation height
        INTEGER IALC   !<Flag to enable use of user-specified canopy albedo
        INTEGER IALS   !<Flag to enable use of user-specified snow albedo
        INTEGER IALG   !<Flag to enable use of user-specified ground albedo
        INTEGER ITG    !<Flag to select iteration scheme for ground or snow surface
        INTEGER ITC    !<Flag to select iteration scheme for canopy temperature
        INTEGER ITCG   !<Flag to select iteration scheme for surface under canopy
        INTEGER isnoalb!<
        INTEGER igralb !<

        INTEGER NLTEST  !<Number of grid cells being modelled for this run
        INTEGER NMTEST  !<Number of mosaic tiles per grid cell being modelled for this run
        INTEGER NCOUNT  !<Counter for daily averaging
        INTEGER NDAY    !<
        INTEGER IMONTH  !<
        INTEGER NDMONTH !<
        INTEGER NT      !<
        INTEGER IHOUR   !<Hour of day
        INTEGER IMIN    !<Minutes elapsed in current hour
        INTEGER IDAY    !<Julian day of the year
        INTEGER IYEAR   !<Year of run
        INTEGER NML     !<Counter representing number of mosaic tiles on modelled domain that are land
        INTEGER NMW     !<Counter representing number of mosaic tiles on modelled domain that are lakes
        INTEGER JLAT    !<Integer index corresponding to latitude of grid cell
        INTEGER NLANDCS !<Number of modelled areas that contain subareas of canopy over snow
        INTEGER NLANDGS !<Number of modelled areas that contain subareas of snow over bare ground
        INTEGER NLANDC  !<Number of modelled areas that contain subareas of canopy over bare ground
        INTEGER NLANDG  !<Number of modelled areas that contain subareas of bare ground
        INTEGER NLANDI  !<Number of modelled areas that are ice sheets
        INTEGER I,J,K,L,M,N
        INTEGER NTLD    !<
        !
        INTEGER K1,K2,K3,K4,K5,K6,K7,K8,K9,K10,K11
        INTEGER ITA        !<
        INTEGER ITCAN      !<
        INTEGER ITD        !<
        INTEGER ITAC       !<
        INTEGER ITS        !<
        INTEGER ITSCR      !<
        INTEGER ITD2       !<
        INTEGER ITD3       !<
        INTEGER ITD4       !<
        INTEGER NFS        !<
        INTEGER NDRY       !<

        INTEGER*4 TODAY(3), NOW(3)

        ! The following are stored in the data structure: class_gat
        ! they are allocatted in alloc_class_vars in the class_statevars
        ! module and pointed to here.

        ! These will be allocated the dimension: 'ilg'

        integer, pointer, dimension(:) :: ILMOS     !<Index of grid cell corresponding to current element of gathered vector of land surface variables [ ]
        integer, pointer, dimension(:) :: JLMOS     !<Index of mosaic tile corresponding to current element of gathered vector of land surface variables [ ]
        integer, pointer, dimension(:) :: IWMOS     !<Index of grid cell corresponding to current element of gathered vector of inland water body variables [ ]
        integer, pointer, dimension(:) :: JWMOS     !<Index of mosaic tile corresponding to current element of gathered vector of inland water body variables [ ]
        integer, pointer, dimension(:) :: IGDRGAT   !<Index of soil layer in which bedrock is encountered

        real, pointer, dimension(:) :: DELZ    !<
        real, pointer, dimension(:) :: ZBOT    !<
        real, pointer, dimension(:) :: ALBSGAT !<Snow albedo [ ]
        real, pointer, dimension(:) :: CMAIGAT !<Aggregated mass of vegetation canopy \f$[kg m^{-2} ]\f$
        real, pointer, dimension(:) :: GROGAT  !<Vegetation growth index [ ]
        real, pointer, dimension(:) :: QACGAT  !<Specific humidity of air within vegetation canopy space \f$[kg kg^{-1} ]\f$
        real, pointer, dimension(:) :: RCANGAT !<Intercepted liquid water stored on canopy \f$[kg m^{-2} ]\f$
        real, pointer, dimension(:) :: RHOSGAT !<Density of snow \f$[kg m^{-3} ]\f$
        real, pointer, dimension(:) :: SCANGAT !<Intercepted frozen water stored on canopy \f$[kg m^{-2} ]\f$
        real, pointer, dimension(:) :: SNOGAT  !<Mass of snow pack [kg m^{-2} ]\f$
        real, pointer, dimension(:) :: TACGAT  !<Temperature of air within vegetation canopy [K]
        real, pointer, dimension(:) :: TBASGAT !<Temperature of bedrock in third soil layer [K]
        real, pointer, dimension(:) :: TCANGAT !<Vegetation canopy temperature [K]
        real, pointer, dimension(:) :: TPNDGAT !<Temperature of ponded water [K]
        real, pointer, dimension(:) :: TSNOGAT !<Snowpack temperature [K]
        real, pointer, dimension(:) :: WSNOGAT !<Liquid water content of snow pack \f$[kg m^{-2} ]\f$
        real, pointer, dimension(:) :: ZPNDGAT !<Depth of ponded water on surface [m]
        real, pointer, dimension(:) :: REFGAT  !<
        real, pointer, dimension(:) :: BCSNGAT !<
        real, pointer, dimension(:) :: AGIDGAT !<Optional user-specified value of ground near-infrared albedo to override CLASS-calculated value [ ]
        real, pointer, dimension(:) :: AGVDGAT !<Optional user-specified value of ground visible albedo to override CLASS-calculated value [ ]
        real, pointer, dimension(:) :: ALGDGAT !<Reference albedo for dry soil [ ]
        real, pointer, dimension(:) :: ALGWGAT !<Reference albedo for saturated soil [ ]
        real, pointer, dimension(:) :: ASIDGAT !<Optional user-specified value of snow near-infrared albedo to override CLASS-calculated value [ ]
        real, pointer, dimension(:) :: ASVDGAT !<Optional user-specified value of snow visible albedo to override CLASS-calculated value [ ]
        real, pointer, dimension(:) :: DRNGAT  !<Drainage index at bottom of soil profile [ ]
        real, pointer, dimension(:) :: GRKFGAT !<WATROF parameter used when running MESH code [ ]
        real, pointer, dimension(:) :: WFCIGAT !<WATROF parameter used when running MESH code [ ]
        real, pointer, dimension(:) :: WFSFGAT !<WATROF parameter used when running MESH code [ ]
        real, pointer, dimension(:) :: XSLPGAT !<Surface slope (used when running MESH code) [degrees]
        real, pointer, dimension(:) :: ZPLGGAT !<Maximum water ponding depth for snow-free subareas (user-specified when running MESH code) [m]
        real, pointer, dimension(:) :: ZPLSGAT !<Maximum water ponding depth for snow-covered subareas (user-specified when running MESH code) [m]
        real, pointer, dimension(:) :: ZSNLGAT !<Limiting snow depth below which coverage is < 100% [m]
        real, pointer, dimension(:) :: ALGWVGAT !<
        real, pointer, dimension(:) :: ALGWNGAT !<
        real, pointer, dimension(:) :: ALGDVGAT !<
        real, pointer, dimension(:) :: ALGDNGAT !<
        real, pointer, dimension(:) :: EMISGAT  !<
        real, pointer, dimension(:) :: CSZGAT  !<Cosine of solar zenith angle [ ]
        real, pointer, dimension(:) :: DLONGAT !<Longitude of grid cell (east of Greenwich) [degrees]
        real, pointer, dimension(:) :: DLATGAT !< Latitude of grid cell [degrees]
        real, pointer, dimension(:) :: FCLOGAT !<Fractional cloud cover [ ]
        real, pointer, dimension(:) :: FDLGAT  !<Downwelling longwave radiation at bottom of atmosphere (i.e. incident on modelled land surface elements \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: FSIHGAT !<Near-infrared radiation incident on horizontal surface \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: FSVHGAT !<Visible radiation incident on horizontal surface \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: GGEOGAT !<Geothermal heat flux at bottom of soil profile \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: PADRGAT !<Partial pressure of dry air [Pa]
        real, pointer, dimension(:) :: PREGAT  !<Surface precipitation rate \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: PRESGAT !<Surface air pressure [Pa]
        real, pointer, dimension(:) :: QAGAT   !<Specific humidity at reference height \f$[kg kg^{-1} ]\f$
        real, pointer, dimension(:) :: RADJGAT !<Latitude of grid cell (positive north of equator) [rad]
        real, pointer, dimension(:) :: RHOAGAT !<Density of air \f$[kg m^{-3} ]\f$
        real, pointer, dimension(:) :: RHSIGAT !<Density of fresh snow \f$[kg m^{-3} ]\f$
        real, pointer, dimension(:) :: RPCPGAT !<Rainfall rate over modelled area \f$[m s^{-1} ]\f$
        real, pointer, dimension(:) :: SPCPGAT !<Snowfall rate over modelled area \f$[m s^{-1} ]\f$
        real, pointer, dimension(:) :: TAGAT   !<Air temperature at reference height [K]
        real, pointer, dimension(:) :: TADPGAT !<Dew point temperature of air [K]
        real, pointer, dimension(:) :: TRPCGAT !<Rainfall temperature [K]
        real, pointer, dimension(:) :: TSPCGAT !<Snowfall temperature [K]
        real, pointer, dimension(:) :: ULGAT   !<Zonal component of wind velocity \f$[m s^{-1} ]\f$
        real, pointer, dimension(:) :: VLGAT   !<Meridional component of wind velocity \f$[m s^{-1} ]\f$
        real, pointer, dimension(:) :: VMODGAT !<Wind speed at reference height \f$[m s^{-1} ]\f$
        real, pointer, dimension(:) :: VPDGAT  !<Vapour pressure deficit [mb]
        real, pointer, dimension(:) :: Z0ORGAT !<Orographic roughness length [m]
        real, pointer, dimension(:) :: ZBLDGAT !<Atmospheric blending height for surface roughness length averaging [m]
        real, pointer, dimension(:) :: ZDHGAT  !<User-specified height associated with diagnosed screen-level variables [m]
        real, pointer, dimension(:) :: ZDMGAT  !<User-specified height associated with diagnosed anemometer-level wind speed [m]
        real, pointer, dimension(:) :: ZRFHGAT !<Reference height associated with forcing air temperature and humidity [m]
        real, pointer, dimension(:) :: ZRFMGAT !<Reference height associated with forcing wind speed [m]
        real, pointer, dimension(:) :: FSGGAT  !<
        real, pointer, dimension(:) :: FLGGAT  !<
        real, pointer, dimension(:) :: GUSTGAT !<
        real, pointer, dimension(:) :: DEPBGAT !<
        real, pointer, dimension(:) :: GTBS    !<
        real, pointer, dimension(:) :: SFCUBS  !<
        real, pointer, dimension(:) :: SFCVBS  !<
        real, pointer, dimension(:) :: USTARBS !<
        real, pointer, dimension(:) :: TCSNOW  !<
        real, pointer, dimension(:) :: GSNOW   !<
        real, pointer, dimension(:) :: ALIRGAT !<Diagnosed total near-infrared albedo of land surface [ ]
        real, pointer, dimension(:) :: ALVSGAT !<Diagnosed total visible albedo of land surface [ ]
        real, pointer, dimension(:) :: CDHGAT  !<Surface drag coefficient for heat [ ]
        real, pointer, dimension(:) :: CDMGAT  !<Surface drag coefficient for momentum [ ]
        real, pointer, dimension(:) :: DRGAT   !<Surface drag coefficient under neutral stability [ ]
        real, pointer, dimension(:) :: EFGAT   !<Evaporation efficiency at ground surface [ ]
        real, pointer, dimension(:) :: FLGGGAT !<Diagnosed net longwave radiation at soil surface \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: FLGSGAT !<Diagnosed net longwave radiation at snow surface \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: FLGVGAT !<Diagnosed net longwave radiation on vegetation canopy \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: FSGGGAT !<Diagnosed net shortwave radiation at soil surface \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: FSGSGAT !<Diagnosed net shortwave radiation at snow surface \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: FSGVGAT !<Diagnosed net shortwave radiation on vegetation canopy \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: FSNOGAT !<Diagnosed fractional snow coverage [ ]
        real, pointer, dimension(:) :: GAGAT   !<Diagnosed product of drag coefficient and wind speed over modelled area \f$[m s^{-1} ]\f$
        real, pointer, dimension(:) :: GTGAT   !<Diagnosed effective surface black-body temperature [K]
        real, pointer, dimension(:) :: HBLGAT  !<Height of the atmospheric boundary layer [m]
        real, pointer, dimension(:) :: HEVCGAT !<Diagnosed latent heat flux on vegetation canopy \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: HEVGGAT !<Diagnosed latent heat flux at soil surface \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: HEVSGAT !<Diagnosed latent heat flux at snow surface \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: HFSGAT  !<Diagnosed total surface sensible heat flux over modelled area \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: HFSCGAT !<Diagnosed sensible heat flux on vegetation canopy \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: HFSGGAT !<Diagnosed sensible heat flux at soil surface \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: HFSSGAT !<Diagnosed sensible heat flux at snow surface \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: HMFCGAT !<Diagnosed energy associated with phase change of water on vegetation \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: HMFNGAT !<Diagnosed energy associated with phase change of water in snow pack \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: HTCCGAT !<Diagnosed internal energy change of vegetation canopy due to conduction and/or change in mass \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: HTCSGAT !<Diagnosed internal energy change of snow pack due to conduction and/or change in mass \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: ILMOGAT !<Inverse of Monin-Obukhov roughness length \f$(m^{-1} ]\f$
        real, pointer, dimension(:) :: PCFCGAT !<Diagnosed frozen precipitation intercepted by vegetation \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: PCLCGAT !<Diagnosed liquid precipitation intercepted by vegetation \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: PCPGGAT !<Diagnosed precipitation incident on ground \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: PCPNGAT !<Diagnosed precipitation incident on snow pack \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: PETGAT  !<Diagnosed potential evapotranspiration \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: QEVPGAT !<Diagnosed total surface latent heat flux over modelled area \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: QFCFGAT !<Diagnosed vapour flux from frozen water on vegetation \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: QFCLGAT !<Diagnosed vapour flux from liquid water on vegetation \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: QFGGAT  !<Diagnosed water vapour flux from ground \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: QFNGAT  !<Diagnosed water vapour flux from snow pack \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: QFSGAT  !<Diagnosed total surface water vapour flux over modelled area \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: QFXGAT  !<Product of surface drag coefficient, wind speed and surface-air specific humidity difference \f$[m s^{-1} ]\f$
        real, pointer, dimension(:) :: QGGAT   !<Diagnosed surface specific humidity \f$[kg kg^{-1} ]\f$
        real, pointer, dimension(:) :: ROFGAT  !<Total runoff from soil \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: ROFBGAT !<Base flow from bottom of soil column \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: ROFCGAT !<Liquid/frozen water runoff from vegetation \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: ROFNGAT !<Liquid water runoff from snow pack \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: ROFOGAT !<Overland flow from top of soil column \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: ROFSGAT !<Interflow from sides of soil column \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: ROVGGAT !<Diagnosed liquid/frozen water runoff from vegetation to ground surface \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: SFCQGAT !<Diagnosed screen-level specific humidity \f$[kg kg^{-1} ]\f$
        real, pointer, dimension(:) :: SFCTGAT !<Diagnosed screen-level air temperature [K]
        real, pointer, dimension(:) :: SFCUGAT !<Diagnosed anemometer-level zonal wind \f$[m s^{-1} ]\f$
        real, pointer, dimension(:) :: SFCVGAT !<Diagnosed anemometer-level meridional wind \f$[m s^{-1} ]\f$
        real, pointer, dimension(:) :: TFXGAT  !<Product of surface drag coefficient, wind speed and surface-air temperature difference \f$[K m s^{-1} ]\f$
        real, pointer, dimension(:) :: TROBGAT !<Temperature of base flow from bottom of soil column [K]
        real, pointer, dimension(:) :: TROFGAT !<Temperature of total runoff [K]
        real, pointer, dimension(:) :: TROOGAT !<Temperature of overland flow from top of soil column [K]
        real, pointer, dimension(:) :: TROSGAT !<Temperature of interflow from sides of soil column [K]
        real, pointer, dimension(:) :: UEGAT   !<Friction velocity of air \f$[m s^{-1} ]\f$
        real, pointer, dimension(:) :: WTABGAT !<Depth of water table in soil [m]
        real, pointer, dimension(:) :: WTRCGAT !<Diagnosed residual water transferred off the vegetation canopy \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: WTRGGAT !<Diagnosed residual water transferred into or out of the soil \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: WTRSGAT !<Diagnosed residual water transferred into or out of the snow pack \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: QLWOGAT !<
        real, pointer, dimension(:) :: SFRHGAT !<
        real, pointer, dimension(:) :: FTEMP   !<
        real, pointer, dimension(:) :: FVAP    !<
        real, pointer, dimension(:) :: RIB     !<
        real, pointer, dimension(:) :: FC      !<
        real, pointer, dimension(:) :: FG      !<
        real, pointer, dimension(:) :: FCS     !<
        real, pointer, dimension(:) :: FGS     !<
        real, pointer, dimension(:) :: RBCOEF  !<
        real, pointer, dimension(:) :: ZSNOW   !<
        real, pointer, dimension(:) :: FSVF    !<
        real, pointer, dimension(:) :: FSVFS   !<
        real, pointer, dimension(:) :: ALVSCN  !<
        real, pointer, dimension(:) :: ALIRCN  !<
        real, pointer, dimension(:) :: ALVSG   !<
        real, pointer, dimension(:) :: ALIRG   !<
        real, pointer, dimension(:) :: ALVSCS  !<
        real, pointer, dimension(:) :: ALIRCS  !<
        real, pointer, dimension(:) :: ALVSSN  !<
        real, pointer, dimension(:) :: ALIRSN  !<
        real, pointer, dimension(:) :: ALVSGC  !<
        real, pointer, dimension(:) :: ALIRGC  !<
        real, pointer, dimension(:) :: ALVSSC  !<
        real, pointer, dimension(:) :: ALIRSC  !<
        real, pointer, dimension(:) :: TRVSCN  !<
        real, pointer, dimension(:) :: TRIRCN  !<
        real, pointer, dimension(:) :: TRVSCS  !<
        real, pointer, dimension(:) :: TRIRCS  !<
        real, pointer, dimension(:) :: RC      !<
        real, pointer, dimension(:) :: RCS     !<
        real, pointer, dimension(:) :: FRAINC  !<
        real, pointer, dimension(:) :: FSNOWC  !<
        real, pointer, dimension(:) :: FRAICS  !<
        real, pointer, dimension(:) :: FSNOCS  !<
        real, pointer, dimension(:) :: CMASSC  !<
        real, pointer, dimension(:) :: CMASCS  !<
        real, pointer, dimension(:) :: DISP    !<
        real, pointer, dimension(:) :: DISPS   !<
        real, pointer, dimension(:) :: ZOMLNC  !<
        real, pointer, dimension(:) :: ZOELNC  !<
        real, pointer, dimension(:) :: ZOMLNG  !<
        real, pointer, dimension(:) :: ZOELNG  !<
        real, pointer, dimension(:) :: ZOMLCS  !<
        real, pointer, dimension(:) :: ZOELCS  !<
        real, pointer, dimension(:) :: ZOMLNS  !<
        real, pointer, dimension(:) :: ZOELNS  !<
        real, pointer, dimension(:) :: TRSNOWC !<
        real, pointer, dimension(:) :: CHCAP   !<
        real, pointer, dimension(:) :: CHCAPS  !<
        real, pointer, dimension(:) :: GZEROC  !<
        real, pointer, dimension(:) :: GZEROG  !<
        real, pointer, dimension(:) :: GZROCS  !<
        real, pointer, dimension(:) :: GZROGS  !<
        real, pointer, dimension(:) :: G12C    !<
        real, pointer, dimension(:) :: G12G    !<
        real, pointer, dimension(:) :: G12CS   !<
        real, pointer, dimension(:) :: G12GS   !<
        real, pointer, dimension(:) :: G23C    !<
        real, pointer, dimension(:) :: G23G    !<
        real, pointer, dimension(:) :: G23CS   !<
        real, pointer, dimension(:) :: G23GS   !<
        real, pointer, dimension(:) :: QFREZC  !<
        real, pointer, dimension(:) :: QFREZG  !<
        real, pointer, dimension(:) :: QMELTC  !<
        real, pointer, dimension(:) :: QMELTG  !<
        real, pointer, dimension(:) :: EVAPC   !<
        real, pointer, dimension(:) :: EVAPCG  !<
        real, pointer, dimension(:) :: EVAPG   !<
        real, pointer, dimension(:) :: EVAPCS  !<
        real, pointer, dimension(:) :: EVPCSG  !<
        real, pointer, dimension(:) :: EVAPGS  !<
        real, pointer, dimension(:) :: TCANO   !<
        real, pointer, dimension(:) :: TCANS   !<
        real, pointer, dimension(:) :: RAICAN  !<
        real, pointer, dimension(:) :: SNOCAN  !<
        real, pointer, dimension(:) :: RAICNS  !<
        real, pointer, dimension(:) :: SNOCNS  !<
        real, pointer, dimension(:) :: CWLCAP  !<
        real, pointer, dimension(:) :: CWFCAP  !<
        real, pointer, dimension(:) :: CWLCPS  !<
        real, pointer, dimension(:) :: CWFCPS  !<
        real, pointer, dimension(:) :: TSNOCS  !<
        real, pointer, dimension(:) :: TSNOGS  !<
        real, pointer, dimension(:) :: RHOSCS  !<
        real, pointer, dimension(:) :: RHOSGS  !<
        real, pointer, dimension(:) :: WSNOCS  !<
        real, pointer, dimension(:) :: WSNOGS  !<
        real, pointer, dimension(:) :: TPONDC  !<
        real, pointer, dimension(:) :: TPONDG  !<
        real, pointer, dimension(:) :: TPNDCS  !<
        real, pointer, dimension(:) :: TPNDGS  !<
        real, pointer, dimension(:) :: ZPLMCS  !<
        real, pointer, dimension(:) :: ZPLMGS  !<
        real, pointer, dimension(:) :: ZPLIMC  !<
        real, pointer, dimension(:) :: ZPLIMG  !<
        !
        !     * DIAGNOSTIC ARRAYS USED FOR CHECKING ENERGY AND WATER
        !     * BALANCES.
        !
        real, pointer, dimension(:) :: CTVSTP !<
        real, pointer, dimension(:) :: CTSSTP !<
        real, pointer, dimension(:) :: CT1STP !<
        real, pointer, dimension(:) :: CT2STP !<
        real, pointer, dimension(:) :: CT3STP !<
        real, pointer, dimension(:) :: WTVSTP !<
        real, pointer, dimension(:) :: WTSSTP !<
        real, pointer, dimension(:) :: WTGSTP !<

        ! These will be allocated the dimension: 'ilg, ignd'
        integer, pointer, dimension(:,:) :: ISNDGAT !<Integer identifier associated with sand content
        real, pointer, dimension(:,:) :: TBARGAT !<Temperature of soil layers [K]
        real, pointer, dimension(:,:) :: THICGAT !<Volumetric frozen water content of soil layers \f$[m^3 m^{-3} ]\f$
        real, pointer, dimension(:,:) :: THLQGAT !<Volumetric liquid water content of soil layers \f$[m^3 m^{-3} ]\f$
        real, pointer, dimension(:,:) :: BIGAT   !<Clapp and Hornberger empirical “b” parameter [ ]
        real, pointer, dimension(:,:) :: DLZWGAT !<Permeable thickness of soil layer [m]
        real, pointer, dimension(:,:) :: GRKSGAT !<Saturated hydraulic conductivity of soil layers \f$[m s^{-1} ]\f$
        real, pointer, dimension(:,:) :: HCPSGAT !<Volumetric heat capacity of soil particles \f$[J m^{-3} ]\f$
        real, pointer, dimension(:,:) :: PSISGAT !<Soil moisture suction at saturation [m]
        real, pointer, dimension(:,:) :: PSIWGAT !<Soil moisture suction at wilting point [m]
        real, pointer, dimension(:,:) :: TCSGAT  !<Thermal conductivity of soil particles \f$[W m^{-1} K^{-1} ]\f$\
        real, pointer, dimension(:,:) :: THFCGAT !<Field capacity \f$[m^3 m^{-3} ]\f$
        real, pointer, dimension(:,:) :: THMGAT  !<Residual soil liquid water content remaining after freezing or evaporation \f$[m^3 m^{-3} ]\f$
        real, pointer, dimension(:,:) :: THPGAT  !<Pore volume in soil layer \f$[m^3 m^{-3} ]\f$
        real, pointer, dimension(:,:) :: THRGAT  !<Liquid water retention capacity for organic soil \f$[m^3 m^{-3} ]\f$
        real, pointer, dimension(:,:) :: THRAGAT !<Fractional saturation of soil behind the wetting front [ ]
        real, pointer, dimension(:,:) :: ZBTWGAT !<Depth to permeable bottom of soil layer [m]
        real, pointer, dimension(:,:) :: THLWGAT !<
        real, pointer, dimension(:,:) :: GFLXGAT !<Heat conduction between soil layers \f$[W m^{-2} ]\f$
        real, pointer, dimension(:,:) :: HMFGGAT !<Diagnosed energy associated with phase change of water in soil layers \f$[W m^{-2} ]\f$
        real, pointer, dimension(:,:) :: HTCGAT  !<Diagnosed internal energy change of soil layer due to conduction and/or change in mass \f$[W m^{-2} ]\f$
        real, pointer, dimension(:,:) :: QFCGAT  !<Diagnosed vapour flux from transpiration over modelled area \f$[W m^{-2} ]\f$
        real, pointer, dimension(:,:) :: TBARC  !<
        real, pointer, dimension(:,:) :: TBARG  !<
        real, pointer, dimension(:,:) :: TBARCS !<
        real, pointer, dimension(:,:) :: TBARGS !<
        real, pointer, dimension(:,:) :: THLIQC !<
        real, pointer, dimension(:,:) :: THLIQG !<
        real, pointer, dimension(:,:) :: THICEC !<
        real, pointer, dimension(:,:) :: THICEG !<
        real, pointer, dimension(:,:) :: FROOT  !<
        real, pointer, dimension(:,:) :: HCPC   !<
        real, pointer, dimension(:,:) :: HCPG   !<
        real, pointer, dimension(:,:) :: FROOTS !<
        real, pointer, dimension(:,:) :: TCTOPC !<
        real, pointer, dimension(:,:) :: TCBOTC !<
        real, pointer, dimension(:,:) :: TCTOPG !<
        real, pointer, dimension(:,:) :: TCBOTG !<

        ! These will be allocated the dimension: 'ilg, ican'
        real, pointer, dimension(:,:) :: ACIDGAT !<Optional user-specified value of canopy near-infrared albedo to override CLASS-calculated value [ ]
        real, pointer, dimension(:,:) :: ACVDGAT !<Optional user-specified value of canopy visible albedo to override CLASS-calculated value [ ]
        real, pointer, dimension(:,:) :: CMASGAT !<Maximum canopy mass for vegetation category \f$[kg m^{-2} ]\f$
        real, pointer, dimension(:,:) :: HGTDGAT !<Optional user-specified values of height of vegetation categories to override CLASS-calculated values [m]
        real, pointer, dimension(:,:) :: PAIDGAT !<Optional user-specified value of plant area indices of vegetation categories to override CLASS-calculated values [ ]
        real, pointer, dimension(:,:) :: PAMNGAT !<Minimum plant area index of vegetation category [ ]
        real, pointer, dimension(:,:) :: PAMXGAT !<Minimum plant area index of vegetation category [ ]
        real, pointer, dimension(:,:) :: PSGAGAT !<Soil moisture suction coefficient for vegetation category (used in stomatal resistance calculation) [ ]
        real, pointer, dimension(:,:) :: PSGBGAT !<Soil moisture suction coefficient for vegetation category (used in stomatal resistance calculation) [ ]
        real, pointer, dimension(:,:) :: QA50GAT !<Reference value of incoming shortwave radiation for vegetation category (used in stomatal resistance calculation) \f$[W m^{-2} ]\f$
        real, pointer, dimension(:,:) :: ROOTGAT !<Maximum rooting depth of vegetation category [m]
        real, pointer, dimension(:,:) :: RSMNGAT !<Minimum stomatal resistance of vegetation category \f$[s m^{-1} ]\f$
        real, pointer, dimension(:,:) :: VPDAGAT !<Vapour pressure deficit coefficient for vegetation category (used in stomatal resistance calculation) [ ]
        real, pointer, dimension(:,:) :: VPDBGAT !<Vapour pressure deficit coefficient for vegetation category (used in stomatal resistance calculation) [ ]


        ! These will be allocated the dimension: 'ilg, icp1'
        real, pointer, dimension(:,:) :: ALICGAT !<Background average near-infrared albedo of vegetation category [ ]
        real, pointer, dimension(:,:) :: ALVCGAT !<Background average visible albedo of vegetation category [ ]
        real, pointer, dimension(:,:) :: FCANGAT !<Maximum fractional coverage of modelled area by vegetation category [ ]
        real, pointer, dimension(:,:) :: LNZ0GAT !<Natural logarithm of maximum roughness length of vegetation category [ ]

        ! These will be allocated the dimension: 'ilg, nbs'
        real, pointer, dimension(:,:) :: FSDBGAT !<
        real, pointer, dimension(:,:) :: FSFBGAT !<
        real, pointer, dimension(:,:) :: FSSBGAT !<
        real, pointer, dimension(:,:) :: SALBGAT !<
        real, pointer, dimension(:,:) :: CSALGAT !<
        real, pointer, dimension(:,:) :: ALTG    !<
        real, pointer, dimension(:,:) :: ALSNO   !<
        real, pointer, dimension(:,:) :: TRSNOWG !<

        ! These will be allocated the dimension: 'ilg, 4'
        real, pointer, dimension(:,:) :: TSFSGAT !<Ground surface temperature over subarea [K]

        ! These will be allocated the dimension: 'ilg, 6, 50'
        integer, pointer, dimension(:,:,:) :: ITCTGAT !<Counter of number of iterations required to solve surface energy balance for the elements of the four subareas

        ! The following are stored in the data structure: class_rot
        ! they are allocatted in alloc_class_vars in the class_statevars
        ! module and pointed to here.

        ! These will be allocated the dimension: 'nlat'

        real, pointer, dimension(:) :: ALIRACC !<Diagnosed total near-infrared albedo of land surface [ ]
        real, pointer, dimension(:) :: ALVSACC !<Diagnosed total visible albedo of land surface [ ]
        real, pointer, dimension(:) :: EVAPACC !<Diagnosed total surface water vapour flux over modelled area \f$[kg m^{-2} ]\f$
        real, pointer, dimension(:) :: FLINACC !<Downwelling longwave radiation above surface \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: FLUTACC !<Upwelling longwave radiation from surface \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: FSINACC !<Downwelling shortwave radiation above surface \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: GROACC  !<Vegetation growth index [ ]
        real, pointer, dimension(:) :: GTACC   !<Diagnosed effective surface black-body temperature [K]
        real, pointer, dimension(:) :: HFSACC  !<Diagnosed total surface sensible heat flux over modelled area \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: HMFNACC !<Diagnosed energy associated with phase change of water in snow pack \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: OVRACC  !<Overland flow from top of soil column \f$[kg m^{-2} ]\f$
        real, pointer, dimension(:) :: PREACC  !<Surface precipitation rate \f$[kg m^{-2} ]\f$
        real, pointer, dimension(:) :: PRESACC !<Surface air pressure [Pa]
        real, pointer, dimension(:) :: QAACC   !<Specific humidity at reference height \f$[kg kg^{-1} ]\f$
        real, pointer, dimension(:) :: QEVPACC !<Diagnosed total surface latent heat flux over modelled area \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: RCANACC !<Intercepted liquid water stored on canopy \f$[kg m^{-2} ]\f$
        real, pointer, dimension(:) :: RHOSACC !<Density of snow \f$[kg m^{-3} ]\f$
        real, pointer, dimension(:) :: ROFACC  !<Total runoff from soil \f$[kg m^{-2} ]\f$
        real, pointer, dimension(:) :: SCANACC !<Intercepted frozen water stored on canopy \f$[kg m^{-2} ]\f$
        real, pointer, dimension(:) :: SNOACC  !<Mass of snow pack \f$[kg m^{-2} ]\f$
        real, pointer, dimension(:) :: TAACC   !<Air temperature at reference height [K]
        real, pointer, dimension(:) :: TCANACC !<Vegetation canopy temperature [K]
        real, pointer, dimension(:) :: TSNOACC !<Snowpack temperature [K]
        real, pointer, dimension(:) :: UVACC   !<Wind speed \f$[m s^{-1} ]\f$
        real, pointer, dimension(:) :: WSNOACC !<Liquid water content of snow pack \f$[kg m^{-2} ]\f$
        real, pointer, dimension(:) :: WTBLACC !<Depth of water table in soil [m]
        real, pointer, dimension(:) :: ALTOTACC!<Broadband albedo [-]
        real, pointer, dimension(:) :: CANARE  !<
        real, pointer, dimension(:) :: SNOARE  !<
        real, pointer, dimension(:) :: CSZROW  !<
        real, pointer, dimension(:) :: DLONROW !<
        real, pointer, dimension(:) :: DLATROW !<
        real, pointer, dimension(:) :: FCLOROW !<
        real, pointer, dimension(:) :: FDLROW  !<
        real, pointer, dimension(:) :: FSIHROW !<
        real, pointer, dimension(:) :: FSVHROW !<
        real, pointer, dimension(:) :: GCROW   !<Type identifier for grid cell (1 = sea ice, 0 = ocean, -1 = land)
        real, pointer, dimension(:) :: GGEOROW !<
        real, pointer, dimension(:) :: PADRROW !<
        real, pointer, dimension(:) :: PREROW  !<
        real, pointer, dimension(:) :: PRESROW !<
        real, pointer, dimension(:) :: QAROW   !<
        real, pointer, dimension(:) :: RADJROW !<
        real, pointer, dimension(:) :: RHOAROW !<
        real, pointer, dimension(:) :: RHSIROW !<
        real, pointer, dimension(:) :: RPCPROW !<
        real, pointer, dimension(:) :: RPREROW !<Rainfall rate over modelled area \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: SPCPROW !<
        real, pointer, dimension(:) :: SPREROW !<Snowfall rate over modelled area \f$[kg m^{-2} s^{-1} ]\f$
        real, pointer, dimension(:) :: TAROW   !<
        real, pointer, dimension(:) :: TADPROW !<
        real, pointer, dimension(:) :: TRPCROW !<
        real, pointer, dimension(:) :: TSPCROW !<
        real, pointer, dimension(:) :: ULROW   !<
        real, pointer, dimension(:) :: VLROW   !<
        real, pointer, dimension(:) :: VMODROW !<
        real, pointer, dimension(:) :: VPDROW  !<
        real, pointer, dimension(:) :: ZBLDROW !<
        real, pointer, dimension(:) :: ZDHROW  !<
        real, pointer, dimension(:) :: ZDMROW  !<
        real, pointer, dimension(:) :: ZRFHROW !<
        real, pointer, dimension(:) :: ZRFMROW !<
        real, pointer, dimension(:) :: UVROW   !<
        real, pointer, dimension(:) :: XDIFFUS !<
        real, pointer, dimension(:) :: Z0ORROW !<
        real, pointer, dimension(:) :: FSSROW  !< Shortwave radiation \f$[W m^{-2} ]\f$
        real, pointer, dimension(:) :: PRENROW !<
        real, pointer, dimension(:) :: CLDTROW !<
        real, pointer, dimension(:) :: FSGROL  !<
        real, pointer, dimension(:) :: FLGROL  !<
        real, pointer, dimension(:) :: GUSTROL !<
        real, pointer, dimension(:) :: DEPBROW !<
        real, pointer, dimension(:) :: ALIRROW !<
        real, pointer, dimension(:) :: ALVSROW !<
        real, pointer, dimension(:) :: CDHROW  !<
        real, pointer, dimension(:) :: CDMROW  !<
        real, pointer, dimension(:) :: DRROW   !<
        real, pointer, dimension(:) :: EFROW   !<
        real, pointer, dimension(:) :: FLGGROW !<
        real, pointer, dimension(:) :: FLGSROW !<
        real, pointer, dimension(:) :: FLGVROW !<
        real, pointer, dimension(:) :: FSGGROW !<
        real, pointer, dimension(:) :: FSGSROW !<
        real, pointer, dimension(:) :: FSGVROW !<
        real, pointer, dimension(:) :: FSNOROW !<
        real, pointer, dimension(:) :: GAROW   !<
        real, pointer, dimension(:) :: GTROW   !<
        real, pointer, dimension(:) :: HBLROW  !<
        real, pointer, dimension(:) :: HEVCROW !<
        real, pointer, dimension(:) :: HEVGROW !<
        real, pointer, dimension(:) :: HEVSROW !<
        real, pointer, dimension(:) :: HFSROW  !<
        real, pointer, dimension(:) :: HFSCROW !<
        real, pointer, dimension(:) :: HFSGROW !<
        real, pointer, dimension(:) :: HFSSROW !<
        real, pointer, dimension(:) :: HMFCROW !<
        real, pointer, dimension(:) :: HMFNROW !<
        real, pointer, dimension(:) :: HTCCROW !<
        real, pointer, dimension(:) :: HTCSROW !<
        real, pointer, dimension(:) :: ILMOROW !<
        real, pointer, dimension(:) :: PCFCROW !<
        real, pointer, dimension(:) :: PCLCROW !<
        real, pointer, dimension(:) :: PCPGROW !<
        real, pointer, dimension(:) :: PCPNROW !<
        real, pointer, dimension(:) :: PETROW  !<
        real, pointer, dimension(:) :: QEVPROW !<
        real, pointer, dimension(:) :: QFCFROW !<
        real, pointer, dimension(:) :: QFCLROW !<
        real, pointer, dimension(:) :: QFGROW  !<
        real, pointer, dimension(:) :: QFNROW  !<
        real, pointer, dimension(:) :: QFSROW  !<
        real, pointer, dimension(:) :: QFXROW  !<
        real, pointer, dimension(:) :: QGROW   !<
        real, pointer, dimension(:) :: ROFROW  !<
        real, pointer, dimension(:) :: ROFBROW !<
        real, pointer, dimension(:) :: ROFCROW !<
        real, pointer, dimension(:) :: ROFNROW !<
        real, pointer, dimension(:) :: ROFOROW !<
        real, pointer, dimension(:) :: ROFSROW !<
        real, pointer, dimension(:) :: ROVGROW !<
        real, pointer, dimension(:) :: SFCQROW !<
        real, pointer, dimension(:) :: SFCTROW !<
        real, pointer, dimension(:) :: SFCUROW !<
        real, pointer, dimension(:) :: SFCVROW !<
        real, pointer, dimension(:) :: TFXROW  !<
        real, pointer, dimension(:) :: UEROW   !<
        real, pointer, dimension(:) :: WTABROW !<
        real, pointer, dimension(:) :: WTRCROW !<
        real, pointer, dimension(:) :: WTRGROW !<
        real, pointer, dimension(:) :: WTRSROW !<
        real, pointer, dimension(:) :: SFRHROW !<

        ! These will be allocated the dimension: 'nlat,nmos'

        integer, pointer, dimension(:,:) :: IGDRROT !<
        integer, pointer, dimension(:,:) :: MIDROT  !<Mosaic tile type identifier (1 for land surface, 0 for inland lake)
        real, pointer, DIMENSION(:,:) :: ALBSROT !<
        real, pointer, dimension(:,:) :: CMAIROT !<
        real, pointer, dimension(:,:) :: GROROT  !<
        real, pointer, dimension(:,:) :: QACROT  !<
        real, pointer, dimension(:,:) :: RCANROT !<
        real, pointer, dimension(:,:) :: RHOSROT !<
        real, pointer, dimension(:,:) :: SCANROT !<
        real, pointer, dimension(:,:) :: SNOROT  !<
        real, pointer, dimension(:,:) :: TACROT  !<
        real, pointer, dimension(:,:) :: TBASROT !<
        real, pointer, dimension(:,:) :: TCANROT !<
        real, pointer, dimension(:,:) :: TPNDROT !<
        real, pointer, dimension(:,:) :: TSNOROT !<
        real, pointer, dimension(:,:) :: WSNOROT !<
        real, pointer, dimension(:,:) :: ZPNDROT !<
        real, pointer, dimension(:,:) :: REFROT  !<
        real, pointer, dimension(:,:) :: BCSNROT !<
        real, pointer, dimension(:,:) :: AGIDROT !<
        real, pointer, dimension(:,:) :: AGVDROT !<
        real, pointer, dimension(:,:) :: ALGDROT !<
        real, pointer, dimension(:,:) :: ALGWROT !<
        real, pointer, dimension(:,:) :: ASIDROT !<
        real, pointer, dimension(:,:) :: ASVDROT !<
        real, pointer, dimension(:,:) :: DRNROT  !<
        real, pointer, dimension(:,:) :: FAREROT !<Fractional coverage of mosaic tile on modelled area
        real, pointer, dimension(:,:) :: GRKFROT !<
        real, pointer, dimension(:,:) :: WFCIROT !<
        real, pointer, dimension(:,:) :: WFSFROT !<
        real, pointer, dimension(:,:) :: XSLPROT !<
        real, pointer, dimension(:,:) :: ZPLGROT !<
        real, pointer, dimension(:,:) :: ZPLSROT !<
        real, pointer, dimension(:,:) :: ZSNLROT !<
        real, pointer, dimension(:,:) :: ZSNOROT  !<
        real, pointer, dimension(:,:) :: ALGWVROT !<
        real, pointer, dimension(:,:) :: ALGWNROT !<
        real, pointer, dimension(:,:) :: ALGDVROT !<
        real, pointer, dimension(:,:) :: ALGDNROT !<
        real, pointer, dimension(:,:) :: EMISROT  !<
        real, pointer, dimension(:,:) :: ALIRROT !<
        real, pointer, dimension(:,:) :: ALVSROT !<
        real, pointer, dimension(:,:) :: CDHROT  !<
        real, pointer, dimension(:,:) :: CDMROT  !<
        real, pointer, dimension(:,:) :: DRROT   !<
        real, pointer, dimension(:,:) :: EFROT   !<
        real, pointer, dimension(:,:) :: FLGGROT !<
        real, pointer, dimension(:,:) :: FLGSROT !<
        real, pointer, dimension(:,:) :: FLGVROT !<
        real, pointer, dimension(:,:) :: FSGGROT !<
        real, pointer, dimension(:,:) :: FSGSROT !<
        real, pointer, dimension(:,:) :: FSGVROT !<
        real, pointer, dimension(:,:) :: FSNOROT !<
        real, pointer, dimension(:,:) :: GAROT   !<
        real, pointer, dimension(:,:) :: GTROT   !<
        real, pointer, dimension(:,:) :: HBLROT  !<
        real, pointer, dimension(:,:) :: HEVCROT !<
        real, pointer, dimension(:,:) :: HEVGROT !<
        real, pointer, dimension(:,:) :: HEVSROT !<
        real, pointer, dimension(:,:) :: HFSROT  !<
        real, pointer, dimension(:,:) :: HFSCROT !<
        real, pointer, dimension(:,:) :: HFSGROT !<
        real, pointer, dimension(:,:) :: HFSSROT !<
        real, pointer, dimension(:,:) :: HMFCROT !<
        real, pointer, dimension(:,:) :: HMFNROT !<
        real, pointer, dimension(:,:) :: HTCCROT !<
        real, pointer, dimension(:,:) :: SDEPROT !<Depth to bedrock in the soil profile
        real, pointer, dimension(:,:) :: SOCIROT  !<
        real, pointer, dimension(:,:) :: HTCSROT !<
        real, pointer, dimension(:,:) :: ILMOROT !<
        real, pointer, dimension(:,:) :: PCFCROT !<
        real, pointer, dimension(:,:) :: PCLCROT !<
        real, pointer, dimension(:,:) :: PCPGROT !<
        real, pointer, dimension(:,:) :: PCPNROT !<
        real, pointer, dimension(:,:) :: PETROT  !<
        real, pointer, dimension(:,:) :: QEVPROT !<
        real, pointer, dimension(:,:) :: QFCFROT !<
        real, pointer, dimension(:,:) :: QFCLROT !<
        real, pointer, dimension(:,:) :: QFGROT  !<
        real, pointer, dimension(:,:) :: QFNROT  !<
        real, pointer, dimension(:,:) :: QFSROT  !<
        real, pointer, dimension(:,:) :: QFXROT  !<
        real, pointer, dimension(:,:) :: QGROT   !<
        real, pointer, dimension(:,:) :: ROFROT  !<
        real, pointer, dimension(:,:) :: ROFBROT !<
        real, pointer, dimension(:,:) :: ROFCROT !<
        real, pointer, dimension(:,:) :: ROFNROT !<
        real, pointer, dimension(:,:) :: ROFOROT !<
        real, pointer, dimension(:,:) :: ROFSROT !<
        real, pointer, dimension(:,:) :: ROVGROT !<
        real, pointer, dimension(:,:) :: SFCQROT !<
        real, pointer, dimension(:,:) :: SFCTROT !<
        real, pointer, dimension(:,:) :: SFCUROT !<
        real, pointer, dimension(:,:) :: SFCVROT !<
        real, pointer, dimension(:,:) :: TFXROT  !<
        real, pointer, dimension(:,:) :: TROBROT !<
        real, pointer, dimension(:,:) :: TROFROT !<
        real, pointer, dimension(:,:) :: TROOROT !<
        real, pointer, dimension(:,:) :: TROSROT !<
        real, pointer, dimension(:,:) :: UEROT   !<
        real, pointer, dimension(:,:) :: WTABROT !<
        real, pointer, dimension(:,:) :: WTRCROT !<
        real, pointer, dimension(:,:) :: WTRGROT !<
        real, pointer, dimension(:,:) :: WTRSROT !<
        real, pointer, dimension(:,:) :: SFRHROT !<

        ! There will be allocated the dimension: 'nlat,nmos,ignd'
        integer, pointer, dimension(:,:,:) :: ISNDROT !<
        real, pointer, dimension(:,:,:) :: TBARROT !<
        real, pointer, dimension(:,:,:) :: THICROT !<
        real, pointer, dimension(:,:,:) :: THLQROT !<
        real, pointer, dimension(:,:,:) :: BIROT   !<
        real, pointer, dimension(:,:,:) :: DLZWROT !<
        real, pointer, dimension(:,:,:) :: GRKSROT !<
        real, pointer, dimension(:,:,:) :: HCPSROT !<
        real, pointer, dimension(:,:,:) :: SANDROT !<Percentage sand content of soil
        real, pointer, dimension(:,:,:) :: CLAYROT !<Percentage clay content of soil
        real, pointer, dimension(:,:,:) :: ORGMROT !<Percentage organic matter content of soil
        real, pointer, dimension(:,:,:) :: PSISROT !<
        real, pointer, dimension(:,:,:) :: PSIWROT !<
        real, pointer, dimension(:,:,:) :: TCSROT  !<
        real, pointer, dimension(:,:,:) :: THFCROT !<
        real, pointer, dimension(:,:,:) :: THMROT  !<
        real, pointer, dimension(:,:,:) :: THPROT  !<
        real, pointer, dimension(:,:,:) :: THRROT  !<
        real, pointer, dimension(:,:,:) :: THRAROT !<
        real, pointer, dimension(:,:,:) :: ZBTWROT !<
        real, pointer, dimension(:,:,:) :: THLWROT !<
        real, pointer, dimension(:,:,:) :: GFLXROT !<
        real, pointer, dimension(:,:,:) :: HMFGROT !<
        real, pointer, dimension(:,:,:) :: HTCROT  !<
        real, pointer, dimension(:,:,:) :: QFCROT  !<

        ! These will be allocated the dimension: 'nlat,nmos,ican'
        real, pointer, dimension(:,:,:) :: ACIDROT !<
        real, pointer, dimension(:,:,:) :: ACVDROT !<
        real, pointer, dimension(:,:,:) :: CMASROT !<
        real, pointer, dimension(:,:,:) :: HGTDROT !<
        real, pointer, dimension(:,:,:) :: PAIDROT !<
        real, pointer, dimension(:,:,:) :: PAMNROT !<
        real, pointer, dimension(:,:,:) :: PAMXROT !<
        real, pointer, dimension(:,:,:) :: PSGAROT !<
        real, pointer, dimension(:,:,:) :: PSGBROT !<
        real, pointer, dimension(:,:,:) :: QA50ROT !<
        real, pointer, dimension(:,:,:) :: ROOTROT !<
        real, pointer, dimension(:,:,:) :: RSMNROT !<
        real, pointer, dimension(:,:,:) :: VPDAROT !<
        real, pointer, dimension(:,:,:) :: VPDBROT !<

        ! These will be allocated the dimension: 'nlat,nmos,icp1'
        real, pointer, dimension(:,:,:) :: ALICROT !<
        real, pointer, dimension(:,:,:) :: ALVCROT !<
        real, pointer, dimension(:,:,:) :: FCANROT !<
        real, pointer, dimension(:,:,:) :: LNZ0ROT !<

        ! These will be allocated the dimension: 'nlat,nmos,nbs'
        real, pointer, dimension(:,:,:)  :: SALBROT  !<
        real, pointer, dimension(:,:,:)  :: CSALROT  !<

        ! These will be allocated the dimension: 'nlat,nbs'
        real, pointer, dimension(:,:) :: FSDBROL  !<
        real, pointer, dimension(:,:) :: FSFBROL  !<
        real, pointer, dimension(:,:) :: FSSBROL  !<

        ! These will be allocated the dimension: 'nlat,ignd'

        real, pointer, dimension(:,:) :: TBARACC !<Temperature of soil layers [K]
        real, pointer, dimension(:,:) :: THALACC !<Total volumetric water content of soil layers \f$[m^3 m^{-3} ]\f$
        real, pointer, dimension(:,:) :: THICACC !<Volumetric frozen water content of soil layers \f$[m^3 m^{-3} ]\f$
        real, pointer, dimension(:,:) :: THLQACC !<Volumetric liquid water content of soil layers \f$[m^3 m^{-3} ]\f$
        real, pointer, dimension(:,:) :: GFLXROW !<
        real, pointer, dimension(:,:) :: HMFGROW !<
        real, pointer, dimension(:,:) :: HTCROW  !<
        real, pointer, dimension(:,:) :: QFCROW  !<

        ! These will be allocated the dimension: 'nlat,nmos,6,50'
        integer, pointer, dimension(:,:,:,:) :: ITCTROT !<

        ! These will be allocated the dimension: 'nlat,nmos,4'
        real, pointer, dimension(:,:,:)  :: TSFSROT !<

        !       REAL,DIMENSION(ILG)            :: ALBSGAT !<Snow albedo [ ]
        !       REAL,DIMENSION(NLAT,NMOS)      :: ALBSROT !<
        !       REAL,DIMENSION(ILG)            :: CMAIGAT !<Aggregated mass of vegetation canopy \f$[kg m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS)      :: CMAIROT !<
        !       REAL,DIMENSION(ILG)            :: GROGAT  !<Vegetation growth index [ ]
        !       REAL,DIMENSION(NLAT,NMOS)      :: GROROT  !<
        !       REAL,DIMENSION(ILG)            :: QACGAT  !<Specific humidity of air within vegetation canopy space \f$[kg kg^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS)      :: QACROT  !<
        !       REAL,DIMENSION(ILG)            :: RCANGAT !<Intercepted liquid water stored on canopy \f$[kg m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS)      :: RCANROT !<
        !       REAL,DIMENSION(ILG)            :: RHOSGAT !<Density of snow \f$[kg m^{-3} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS)      :: RHOSROT !<
        !       REAL,DIMENSION(ILG)            :: SCANGAT !<Intercepted frozen water stored on canopy \f$[kg m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS)      :: SCANROT !<
        !       REAL,DIMENSION(ILG)            :: SNOGAT  !<Mass of snow pack [kg m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS)      :: SNOROT  !<
        !       REAL,DIMENSION(ILG)            :: TACGAT  !<Temperature of air within vegetation canopy [K]
        !       REAL,DIMENSION(NLAT,NMOS)      :: TACROT  !<
        !       REAL,DIMENSION(ILG,IGND)       :: TBARGAT !<Temperature of soil layers [K]
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: TBARROT !<
        !       REAL,DIMENSION(ILG)            :: TBASGAT !<Temperature of bedrock in third soil layer [K]
        !       REAL,DIMENSION(NLAT,NMOS)      :: TBASROT !<
        !       REAL,DIMENSION(ILG)            :: TCANGAT !<Vegetation canopy temperature [K]
        !       REAL,DIMENSION(NLAT,NMOS)      :: TCANROT !<
        !       REAL,DIMENSION(ILG,IGND)       :: THICGAT !<Volumetric frozen water content of soil layers \f$[m^3 m^{-3} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: THICROT !<
        !       REAL,DIMENSION(ILG,IGND)       :: THLQGAT !<Volumetric liquid water content of soil layers \f$[m^3 m^{-3} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: THLQROT !<
        !       REAL,DIMENSION(ILG)            :: TPNDGAT !<Temperature of ponded water [K]
        !       REAL,DIMENSION(NLAT,NMOS)      :: TPNDROT !<
        !       REAL                       TSFSGAT(ILG,4) !<Ground surface temperature over subarea [K]
        !       REAL                 TSFSROT(NLAT,NMOS,4) !<
        !       REAL,DIMENSION(ILG)            :: TSNOGAT !<Snowpack temperature [K]
        !       REAL,DIMENSION(NLAT,NMOS)      :: TSNOROT !<
        !       REAL,DIMENSION(ILG)            :: WSNOGAT !<Liquid water content of snow pack \f$[kg m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS)      :: WSNOROT !<
        !       REAL,DIMENSION(ILG)            :: ZPNDGAT !<Depth of ponded water on surface [m]
        !       REAL,DIMENSION(NLAT,NMOS)      :: ZPNDROT !<
        !
        ! !
        ! !     * LAND SURFACE PROGNOSTIC VARIABLES.
        ! !
        ! !
        !       REAL,DIMENSION(NLAT,NMOS) :: REFROT  !<
        !       REAL,DIMENSION(NLAT,NMOS) :: BCSNROT !<
        !       REAL,DIMENSION(ILG)       :: REFGAT  !<
        !       REAL,DIMENSION(ILG)       :: BCSNGAT !<
        ! !
        ! !     * GATHER-SCATTER INDEX ARRAYS.
        ! !
        ! !       INTEGER ILMOS (ILG) !<Index of grid cell corresponding to current element of gathered vector of land surface variables [ ]
        ! !       INTEGER JLMOS (ILG) !<Index of mosaic tile corresponding to current element of gathered vector of land surface variables [ ]
        ! !       INTEGER IWMOS (ILG) !<Index of grid cell corresponding to current element of gathered vector of inland water body variables [ ]
        ! !       INTEGER JWMOS (ILG) !<Index of mosaic tile corresponding to current element of gathered vector of inland water body variables [ ]
        ! !
        ! !     * CANOPY AND SOIL INFORMATION ARRAYS.
        ! !     * (THE LAST DIMENSION OF MOST OF THESE ARRAYS IS GIVEN BY
        ! !     * THE NUMBER OF SOIL LAYERS (IGND), THE NUMBER OF BROAD
        ! !     * VEGETATION CATEGORIES (ICAN), OR ICAN+1.
        ! !
        !
        !       REAL,DIMENSION(ILG,ICAN)       :: ACIDGAT !<Optional user-specified value of canopy near-infrared albedo to override CLASS-calculated value [ ]
        !       REAL,DIMENSION(NLAT,NMOS,ICAN) :: ACIDROT !<
        !       REAL,DIMENSION(ILG,ICAN)       :: ACVDGAT !<Optional user-specified value of canopy visible albedo to override CLASS-calculated value [ ]
        !       REAL,DIMENSION(NLAT,NMOS,ICAN) :: ACVDROT !<
        !       REAL,DIMENSION(ILG)            :: AGIDGAT !<Optional user-specified value of ground near-infrared albedo to override CLASS-calculated value [ ]
        !       REAL,DIMENSION(NLAT,NMOS)      :: AGIDROT !<
        !       REAL,DIMENSION(ILG)            :: AGVDGAT !<Optional user-specified value of ground visible albedo to override CLASS-calculated value [ ]
        !       REAL,DIMENSION(NLAT,NMOS)      :: AGVDROT !<
        !       REAL,DIMENSION(ILG)            :: ALGDGAT !<Reference albedo for dry soil [ ]
        !       REAL,DIMENSION(NLAT,NMOS)      :: ALGDROT !<
        !       REAL,DIMENSION(ILG)            :: ALGWGAT !<Reference albedo for saturated soil [ ]
        !       REAL,DIMENSION(NLAT,NMOS)      :: ALGWROT !<
        !       REAL,DIMENSION(ILG,ICP1)       :: ALICGAT !<Background average near-infrared albedo of vegetation category [ ]
        !       REAL,DIMENSION(NLAT,NMOS,ICP1) :: ALICROT !<
        !       REAL,DIMENSION(ILG,ICP1)       :: ALVCGAT !<Background average visible albedo of vegetation category [ ]
        !       REAL,DIMENSION(NLAT,NMOS,ICP1) :: ALVCROT !<
        !       REAL,DIMENSION(ILG)            :: ASIDGAT !<Optional user-specified value of snow near-infrared albedo to override CLASS-calculated value [ ]
        !       REAL,DIMENSION(NLAT,NMOS)      :: ASIDROT !<
        !       REAL,DIMENSION(ILG)            :: ASVDGAT !<Optional user-specified value of snow visible albedo to override CLASS-calculated value [ ]
        !       REAL,DIMENSION(NLAT,NMOS)      :: ASVDROT !<
        !       REAL,DIMENSION(ILG,IGND)       :: BIGAT   !<Clapp and Hornberger empirical “b” parameter [ ]
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: BIROT   !<
        !       REAL CLAYROT(NLAT,NMOS,IGND)              !<Percentage clay content of soil
        !       REAL,DIMENSION(ILG,ICAN)       :: CMASGAT !<Maximum canopy mass for vegetation category \f$[kg m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS,ICAN) :: CMASROT !<
        !       REAL,DIMENSION(ILG,IGND)       :: DLZWGAT !<Permeable thickness of soil layer [m]
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: DLZWROT !<
        !       REAL,DIMENSION(ILG)            :: DRNGAT  !<Drainage index at bottom of soil profile [ ]
        !       REAL,DIMENSION(NLAT,NMOS)      :: DRNROT  !<
        !       REAL FAREROT(NLAT,NMOS)                   !<Fractional coverage of mosaic tile on modelled area
        !       REAL,DIMENSION(ILG,ICP1)       :: FCANGAT !<Maximum fractional coverage of modelled area by vegetation category [ ]
        !       REAL,DIMENSION(NLAT,NMOS,ICP1) :: FCANROT !<
        !       REAL,DIMENSION(ILG)            :: GRKFGAT !<WATROF parameter used when running MESH code [ ]
        !       REAL,DIMENSION(NLAT,NMOS)      :: GRKFROT !<
        !       REAL,DIMENSION(ILG,IGND)       :: GRKSGAT !<Saturated hydraulic conductivity of soil layers \f$[m s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: GRKSROT !<
        !       REAL,DIMENSION(ILG,IGND)       :: HCPSGAT !<Volumetric heat capacity of soil particles \f$[J m^{-3} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: HCPSROT !<
        !       REAL,DIMENSION(ILG,ICAN)       :: HGTDGAT !<Optional user-specified values of height of vegetation categories to override CLASS-calculated values [m]
        !       REAL,DIMENSION(NLAT,NMOS,ICAN) :: HGTDROT !<
        !       INTEGER IGDRGAT(ILG)                      !<Index of soil layer in which bedrock is encountered
        !       INTEGER IGDRROT(NLAT,NMOS)                !<
        !       INTEGER ISNDGAT(ILG,IGND)                 !<Integer identifier associated with sand content
        !       INTEGER ISNDROT(NLAT,NMOS,IGND)           !<
        !       REAL,DIMENSION(ILG,ICP1)       :: LNZ0GAT !<Natural logarithm of maximum roughness length of vegetation category [ ]
        !       REAL,DIMENSION(NLAT,NMOS,ICP1) :: LNZ0ROT !<
        !       INTEGER MIDROT (NLAT,NMOS)                !<Mosaic tile type identifier (1 for land surface, 0 for inland lake)
        !       REAL ORGMROT(NLAT,NMOS,IGND)              !<Percentage organic matter content of soil
        !       REAL,DIMENSION(ILG,ICAN)       :: PAIDGAT !<Optional user-specified value of plant area indices of vegetation categories to override CLASS-calculated values [ ]
        !       REAL,DIMENSION(NLAT,NMOS,ICAN) :: PAIDROT !<
        !       REAL,DIMENSION(ILG,ICAN)       :: PAMNGAT !<Minimum plant area index of vegetation category [ ]
        !       REAL,DIMENSION(NLAT,NMOS,ICAN) :: PAMNROT !<
        !       REAL,DIMENSION(ILG,ICAN)       :: PAMXGAT !<Minimum plant area index of vegetation category [ ]
        !       REAL,DIMENSION(NLAT,NMOS,ICAN) :: PAMXROT !<
        !       REAL,DIMENSION(ILG,ICAN)       :: PSGAGAT !<Soil moisture suction coefficient for vegetation category (used in stomatal resistance calculation) [ ]
        !       REAL,DIMENSION(NLAT,NMOS,ICAN) :: PSGAROT !<
        !       REAL,DIMENSION(ILG,ICAN)       :: PSGBGAT !<Soil moisture suction coefficient for vegetation category (used in stomatal resistance calculation) [ ]
        !       REAL,DIMENSION(NLAT,NMOS,ICAN) :: PSGBROT !<
        !       REAL,DIMENSION(ILG,IGND)       :: PSISGAT !<Soil moisture suction at saturation [m]
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: PSISROT !<
        !       REAL,DIMENSION(ILG,IGND)       :: PSIWGAT !<Soil moisture suction at wilting point [m]
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: PSIWROT !<
        !       REAL,DIMENSION(ILG,ICAN)       :: QA50GAT !<Reference value of incoming shortwave radiation for vegetation category (used in stomatal resistance calculation) \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS,ICAN) :: QA50ROT !<
        !       REAL,DIMENSION(ILG,ICAN)       :: ROOTGAT !<Maximum rooting depth of vegetation category [m]
        !       REAL,DIMENSION(NLAT,NMOS,ICAN) :: ROOTROT !<
        !       REAL,DIMENSION(ILG,ICAN)       :: RSMNGAT !<Minimum stomatal resistance of vegetation category \f$[s m^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS,ICAN) :: RSMNROT !<
        !       REAL SANDROT(NLAT,NMOS,IGND)              !<Percentage sand content of soil
        !       REAL SDEPROT(NLAT,NMOS)                   !<Depth to bedrock in the soil profile
        !       REAL,DIMENSION(ILG,IGND)       :: TCSGAT  !<Thermal conductivity of soil particles \f$[W m^{-1} K^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: TCSROT  !<
        !       REAL,DIMENSION(ILG,IGND)       :: THFCGAT !<Field capacity \f$[m^3 m^{-3} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: THFCROT !<
        !       REAL,DIMENSION(ILG,IGND)       :: THMGAT  !<Residual soil liquid water content remaining after freezing or evaporation \f$[m^3 m^{-3} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: THMROT  !<
        !       REAL,DIMENSION(ILG,IGND)       :: THPGAT  !<Pore volume in soil layer \f$[m^3 m^{-3} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: THPROT  !<
        !       REAL,DIMENSION(ILG,IGND)       :: THRGAT  !<Liquid water retention capacity for organic soil \f$[m^3 m^{-3} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: THRROT  !<
        !       REAL,DIMENSION(ILG,IGND)       :: THRAGAT !<Fractional saturation of soil behind the wetting front [ ]
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: THRAROT !<
        !       REAL,DIMENSION(ILG,ICAN)       :: VPDAGAT !<Vapour pressure deficit coefficient for vegetation category (used in stomatal resistance calculation) [ ]
        !       REAL,DIMENSION(NLAT,NMOS,ICAN) :: VPDAROT !<
        !       REAL,DIMENSION(ILG,ICAN)       :: VPDBGAT !<Vapour pressure deficit coefficient for vegetation category (used in stomatal resistance calculation) [ ]
        !       REAL,DIMENSION(NLAT,NMOS,ICAN) :: VPDBROT !<
        !       REAL,DIMENSION(ILG)            :: WFCIGAT !<WATROF parameter used when running MESH code [ ]
        !       REAL,DIMENSION(NLAT,NMOS)      :: WFCIROT !<
        !       REAL,DIMENSION(ILG)            :: WFSFGAT !<WATROF parameter used when running MESH code [ ]
        !       REAL,DIMENSION(NLAT,NMOS)      :: WFSFROT !<
        !       REAL,DIMENSION(ILG)            :: XSLPGAT !<Surface slope (used when running MESH code) [degrees]
        !       REAL,DIMENSION(NLAT,NMOS)      :: XSLPROT !<
        !       REAL,DIMENSION(ILG,IGND)       :: ZBTWGAT !<Depth to permeable bottom of soil layer [m]
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: ZBTWROT !<
        !       REAL,DIMENSION(ILG)            :: ZPLGGAT !<Maximum water ponding depth for snow-free subareas (user-specified when running MESH code) [m]
        !       REAL,DIMENSION(NLAT,NMOS)      :: ZPLGROT !<
        !       REAL,DIMENSION(ILG)            :: ZPLSGAT !<Maximum water ponding depth for snow-covered subareas (user-specified when running MESH code) [m]
        !       REAL,DIMENSION(NLAT,NMOS)      :: ZPLSROT !<
        !       REAL,DIMENSION(ILG)            :: ZSNLGAT !<Limiting snow depth below which coverage is < 100% [m]
        !       REAL,DIMENSION(NLAT,NMOS)      :: ZSNLROT !<
        !
        !
        !
        !       REAL,DIMENSION(NLAT,NMOS,IGND) :: THLWROT  !<
        !       REAL,DIMENSION(NLAT,NMOS)      :: ZSNOROT  !<
        !       REAL,DIMENSION(NLAT,NMOS)      :: ALGWVROT !<
        !       REAL,DIMENSION(NLAT,NMOS)      :: ALGWNROT !<
        !       REAL,DIMENSION(NLAT,NMOS)      :: ALGDVROT !<
        !       REAL,DIMENSION(NLAT,NMOS)      :: ALGDNROT !<
        !       REAL,DIMENSION(NLAT,NMOS)      :: EMISROT  !<
        !       REAL,DIMENSION(NLAT,NMOS,NBS)  :: SALBROT  !<
        !       REAL,DIMENSION(NLAT,NMOS,NBS)  :: CSALROT  !<
        !       REAL,DIMENSION(NLAT,NBS)       :: FSDBROL  !<
        !       REAL,DIMENSION(NLAT,NBS)       :: FSFBROL  !<
        !       REAL,DIMENSION(NLAT,NBS)       :: FSSBROL  !<
        !
        !       REAL,DIMENSION(ILG,IGND)       :: THLWGAT  !<
        !       REAL,DIMENSION(ILG)            :: ALGWVGAT !<
        !       REAL,DIMENSION(ILG)            :: ALGWNGAT !<
        !       REAL,DIMENSION(ILG)            :: ALGDVGAT !<
        !       REAL,DIMENSION(ILG)            :: ALGDNGAT !<
        !       REAL,DIMENSION(ILG)            :: EMISGAT  !<
        !       REAL SOCIROT(NLAT,NMOS)                    !<
        ! !
        !       REAL,DIMENSION(ILG,NBS) :: FSDBGAT !<
        !       REAL,DIMENSION(ILG,NBS) :: FSFBGAT !<
        !       REAL,DIMENSION(ILG,NBS) :: FSSBGAT !<
        !       REAL,DIMENSION(ILG,NBS) :: SALBGAT !<
        !       REAL,DIMENSION(ILG,NBS) :: CSALGAT !<
        !
        !     * ARRAYS ASSOCIATED WITH COMMON BLOCKS.
        !FLAG! >>> Not in the new structure
        REAL THPORG (  3) !<
        REAL THRORG (  3) !<
        REAL THMORG (  3) !<
        REAL BORG   (  3) !<
        REAL PSISORG(  3) !<
        REAL GRKSORG(  3) !<

        REAL CANEXT(ICAN) !<
        REAL XLEAF (ICAN) !<
        REAL ZORAT (ICAN) !<
        !FLAG! <<< Not in the new structure
        !
        !       REAL DELZ  (IGND) !<
        !       REAL ZBOT  (IGND) !<
        !FLAG! >>> Not in the new structure
        REAL GROWYR (  18,4,2) !< !
        !FLAG! <<< Not in the new structure
        !
        ! !     * ATMOSPHERIC AND GRID-CONSTANT INPUT VARIABLES.
        ! !
        !       REAL,DIMENSION(ILG)  :: CSZGAT  !<Cosine of solar zenith angle [ ]
        !       REAL,DIMENSION(NLAT) :: CSZROW  !<
        !       REAL,DIMENSION(ILG)  :: DLONGAT !<Longitude of grid cell (east of Greenwich) [degrees]
        !       REAL,DIMENSION(NLAT) :: DLONROW !<
        !       REAL,DIMENSION(NLAT) :: DLATROW !< Latitude of grid cell [degrees]
        !       REAL,DIMENSION(ILG)  :: DLATGAT !<
        !
        !       REAL,DIMENSION(ILG)  :: FCLOGAT !<Fractional cloud cover [ ]
        !       REAL,DIMENSION(NLAT) :: FCLOROW !<
        !       REAL,DIMENSION(ILG)  :: FDLGAT  !<Downwelling longwave radiation at bottom of atmosphere (i.e. incident on modelled land surface elements \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: FDLROW  !<
        !       REAL,DIMENSION(ILG)  :: FSIHGAT !<Near-infrared radiation incident on horizontal surface \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: FSIHROW !<
        !       REAL,DIMENSION(ILG)  :: FSVHGAT !<Visible radiation incident on horizontal surface \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: FSVHROW !<
        !       REAL,DIMENSION(NLAT) :: GCROW   !<Type identifier for grid cell (1 = sea ice, 0 = ocean, -1 = land)
        !       REAL,DIMENSION(ILG)  :: GGEOGAT !<Geothermal heat flux at bottom of soil profile \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: GGEOROW !<
        !       REAL,DIMENSION(ILG)  :: PADRGAT !<Partial pressure of dry air [Pa]
        !       REAL,DIMENSION(NLAT) :: PADRROW !<
        !       REAL,DIMENSION(ILG)  :: PREGAT  !<Surface precipitation rate \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT) :: PREROW  !<
        !       REAL,DIMENSION(ILG)  :: PRESGAT !<Surface air pressure [Pa]
        !       REAL,DIMENSION(NLAT) :: PRESROW !<
        !       REAL,DIMENSION(ILG)  :: QAGAT   !<Specific humidity at reference height \f$[kg kg^{-1} ]\f$
        !       REAL,DIMENSION(NLAT) :: QAROW   !<
        !       REAL,DIMENSION(ILG)  :: RADJGAT !<Latitude of grid cell (positive north of equator) [rad]
        !       REAL,DIMENSION(NLAT) :: RADJROW !<
        !       REAL,DIMENSION(ILG)  :: RHOAGAT !<Density of air \f$[kg m^{-3} ]\f$
        !       REAL,DIMENSION(NLAT) :: RHOAROW !<
        !       REAL,DIMENSION(ILG)  :: RHSIGAT !<Density of fresh snow \f$[kg m^{-3} ]\f$
        !       REAL,DIMENSION(NLAT) :: RHSIROW !<
        !       REAL,DIMENSION(ILG)  :: RPCPGAT !<Rainfall rate over modelled area \f$[m s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT) :: RPCPROW !<
        !       REAL,DIMENSION(NLAT) :: RPREROW !<Rainfall rate over modelled area \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(ILG)  :: SPCPGAT !<Snowfall rate over modelled area \f$[m s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT) :: SPCPROW !<
        !       REAL,DIMENSION(NLAT) :: SPREROW !<Snowfall rate over modelled area \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(ILG)  :: TAGAT   !<Air temperature at reference height [K]
        !       REAL,DIMENSION(NLAT) :: TAROW   !<
        !       REAL,DIMENSION(ILG)  :: TADPGAT !<Dew point temperature of air [K]
        !       REAL,DIMENSION(NLAT) :: TADPROW !<
        !       REAL,DIMENSION(ILG)  :: TRPCGAT !<Rainfall temperature [K]
        !       REAL,DIMENSION(NLAT) :: TRPCROW !<
        !       REAL,DIMENSION(ILG)  :: TSPCGAT !<Snowfall temperature [K]
        !       REAL,DIMENSION(NLAT) :: TSPCROW !<
        !       REAL,DIMENSION(ILG)  :: ULGAT   !<Zonal component of wind velocity \f$[m s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT) :: ULROW   !<
        !       REAL,DIMENSION(ILG)  :: VLGAT   !<Meridional component of wind velocity \f$[m s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT) :: VLROW   !<
        !       REAL,DIMENSION(ILG)  :: VMODGAT !<Wind speed at reference height \f$[m s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT) :: VMODROW !<
        !       REAL,DIMENSION(ILG)  :: VPDGAT  !<Vapour pressure deficit [mb]
        !       REAL,DIMENSION(NLAT) :: VPDROW  !<
        !       REAL,DIMENSION(ILG)  :: Z0ORGAT !<Orographic roughness length [m]
        !       REAL,DIMENSION(ILG)  :: ZBLDGAT !<Atmospheric blending height for surface roughness length averaging [m]
        !       REAL,DIMENSION(NLAT) :: ZBLDROW !<
        !       REAL,DIMENSION(ILG)  :: ZDHGAT  !<User-specified height associated with diagnosed screen-level variables [m]
        !       REAL,DIMENSION(NLAT) :: ZDHROW  !<
        !       REAL,DIMENSION(ILG)  :: ZDMGAT  !<User-specified height associated with diagnosed anemometer-level wind speed [m]
        !       REAL,DIMENSION(NLAT) :: ZDMROW  !<
        !       REAL,DIMENSION(ILG)  :: ZRFHGAT !<Reference height associated with forcing air temperature and humidity [m]
        !       REAL,DIMENSION(NLAT) :: ZRFHROW !<
        !       REAL,DIMENSION(ILG)  :: ZRFMGAT !<Reference height associated with forcing wind speed [m]
        !       REAL,DIMENSION(NLAT) :: ZRFMROW !<
        !
        !
        !
        !       REAL,DIMENSION(NLAT) :: UVROW   !<
        !       REAL,DIMENSION(NLAT) :: XDIFFUS !<
        !       REAL,DIMENSION(NLAT) :: Z0ORROW !<
        !
        !
        !       REAL,DIMENSION(NLAT) :: FSSROW  !< Shortwave radiation \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: PRENROW !<
        !       REAL,DIMENSION(NLAT) :: CLDTROW !<
        !       REAL,DIMENSION(NLAT) :: FSGROL  !<
        !       REAL,DIMENSION(NLAT) :: FLGROL  !<
        !       REAL,DIMENSION(NLAT) :: GUSTROL !<
        !       REAL,DIMENSION(NLAT) :: DEPBROW !<
        ! !
        !       REAL,DIMENSION(ILG)  :: FSGGAT  !<
        !       REAL,DIMENSION(ILG)  :: FLGGAT  !<
        !       REAL,DIMENSION(ILG)  :: GUSTGAT !<
        !       REAL,DIMENSION(ILG)  :: DEPBGAT !<
        !       REAL,DIMENSION(ILG)  :: GTBS    !<
        !       REAL,DIMENSION(ILG)  :: SFCUBS  !<
        !       REAL,DIMENSION(ILG)  :: SFCVBS  !<
        !       REAL,DIMENSION(ILG)  :: USTARBS !<
        !       REAL,DIMENSION(ILG)  :: TCSNOW  !<
        !       REAL,DIMENSION(ILG)  :: GSNOW   !<
        !
        ! !
        ! !     * LAND SURFACE DIAGNOSTIC VARIABLES.
        ! !
        !
        !       REAL,DIMENSION(ILG)       :: ALIRGAT !<Diagnosed total near-infrared albedo of land surface [ ]
        !       REAL,DIMENSION(NLAT,NMOS) :: ALIRROT !<
        !       REAL,DIMENSION(NLAT)      :: ALIRROW !<
        !       REAL,DIMENSION(ILG)       :: ALVSGAT !<Diagnosed total visible albedo of land surface [ ]
        !       REAL,DIMENSION(NLAT,NMOS) :: ALVSROT !<
        !       REAL,DIMENSION(NLAT)      :: ALVSROW !<
        !       REAL,DIMENSION(ILG)       :: CDHGAT  !<Surface drag coefficient for heat [ ]
        !       REAL,DIMENSION(NLAT,NMOS) :: CDHROT  !<
        !       REAL,DIMENSION(NLAT)      :: CDHROW  !<
        !       REAL,DIMENSION(ILG)       :: CDMGAT  !<Surface drag coefficient for momentum [ ]
        !       REAL,DIMENSION(NLAT,NMOS) :: CDMROT  !<
        !       REAL,DIMENSION(NLAT)      :: CDMROW  !<
        !       REAL,DIMENSION(ILG)       :: DRGAT   !<Surface drag coefficient under neutral stability [ ]
        !       REAL,DIMENSION(NLAT,NMOS) :: DRROT   !<
        !       REAL,DIMENSION(NLAT)      :: DRROW   !<
        !       REAL,DIMENSION(ILG)       :: EFGAT   !<Evaporation efficiency at ground surface [ ]
        !       REAL,DIMENSION(NLAT,NMOS) :: EFROT   !<
        !       REAL,DIMENSION(NLAT)      :: EFROW   !<
        !       REAL,DIMENSION(ILG)       :: FLGGGAT !<Diagnosed net longwave radiation at soil surface \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: FLGGROT !<
        !       REAL,DIMENSION(NLAT)      :: FLGGROW !<
        !       REAL,DIMENSION(ILG)       :: FLGSGAT !<Diagnosed net longwave radiation at snow surface \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: FLGSROT !<
        !       REAL,DIMENSION(NLAT)      :: FLGSROW !<
        !       REAL,DIMENSION(ILG)       :: FLGVGAT !<Diagnosed net longwave radiation on vegetation canopy \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: FLGVROT !<
        !       REAL,DIMENSION(NLAT)      :: FLGVROW !<
        !       REAL,DIMENSION(ILG)       :: FSGGGAT !<Diagnosed net shortwave radiation at soil surface \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: FSGGROT !<
        !       REAL,DIMENSION(NLAT)      :: FSGGROW !<
        !       REAL,DIMENSION(ILG)       :: FSGSGAT !<Diagnosed net shortwave radiation at snow surface \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: FSGSROT !<
        !       REAL,DIMENSION(NLAT)      :: FSGSROW !<
        !       REAL,DIMENSION(ILG)       :: FSGVGAT !<Diagnosed net shortwave radiation on vegetation canopy \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: FSGVROT !<
        !       REAL,DIMENSION(NLAT)      :: FSGVROW !<
        !       REAL,DIMENSION(ILG)       :: FSNOGAT !<Diagnosed fractional snow coverage [ ]
        !       REAL,DIMENSION(NLAT,NMOS) :: FSNOROT !<
        !       REAL,DIMENSION(NLAT)      :: FSNOROW !<
        !       REAL,DIMENSION(ILG)       :: GAGAT   !<Diagnosed product of drag coefficient and wind speed over modelled area \f$[m s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: GAROT   !<
        !       REAL,DIMENSION(NLAT)      :: GAROW   !<
        !       REAL GFLXGAT(ILG,IGND)               !<Heat conduction between soil layers \f$[W m^{-2} ]\f$
        !       REAL GFLXROT(NLAT,NMOS,IGND)         !<
        !       REAL GFLXROW(NLAT,IGND)              !<
        !       REAL,DIMENSION(ILG)       :: GTGAT   !<Diagnosed effective surface black-body temperature [K]
        !       REAL,DIMENSION(NLAT,NMOS) :: GTROT   !<
        !       REAL,DIMENSION(NLAT)      :: GTROW   !<
        !       REAL,DIMENSION(ILG)       :: HBLGAT  !<Height of the atmospheric boundary layer [m]
        !       REAL,DIMENSION(NLAT,NMOS) :: HBLROT  !<
        !       REAL,DIMENSION(NLAT)      :: HBLROW  !<
        !       REAL,DIMENSION(ILG)       :: HEVCGAT !<Diagnosed latent heat flux on vegetation canopy \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: HEVCROT !<
        !       REAL,DIMENSION(NLAT)      :: HEVCROW !<
        !       REAL,DIMENSION(ILG)       :: HEVGGAT !<Diagnosed latent heat flux at soil surface \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: HEVGROT !<
        !       REAL,DIMENSION(NLAT)      :: HEVGROW !<
        !       REAL,DIMENSION(ILG)       :: HEVSGAT !<Diagnosed latent heat flux at snow surface \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: HEVSROT !<
        !       REAL,DIMENSION(NLAT)      :: HEVSROW !<
        !       REAL,DIMENSION(ILG)       :: HFSGAT  !<Diagnosed total surface sensible heat flux over modelled area \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: HFSROT  !<
        !       REAL,DIMENSION(NLAT)      :: HFSROW  !<
        !       REAL,DIMENSION(ILG)       :: HFSCGAT !<Diagnosed sensible heat flux on vegetation canopy \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: HFSCROT !<
        !       REAL,DIMENSION(NLAT)      :: HFSCROW !<
        !       REAL,DIMENSION(ILG)       :: HFSGGAT !<Diagnosed sensible heat flux at soil surface \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: HFSGROT !<
        !       REAL,DIMENSION(NLAT)      :: HFSGROW !<
        !       REAL,DIMENSION(ILG)       :: HFSSGAT !<Diagnosed sensible heat flux at snow surface \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: HFSSROT !<
        !       REAL,DIMENSION(NLAT)      :: HFSSROW !<
        !       REAL,DIMENSION(ILG)       :: HMFCGAT !<Diagnosed energy associated with phase change of water on vegetation \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: HMFCROT !<
        !       REAL,DIMENSION(NLAT)      :: HMFCROW !<
        !       REAL HMFGGAT(ILG,IGND)               !<Diagnosed energy associated with phase change of water in soil layers \f$[W m^{-2} ]\f$
        !       REAL HMFGROT(NLAT,NMOS,IGND)         !<
        !       REAL HMFGROW(NLAT,IGND)              !<
        !       REAL,DIMENSION(ILG)       :: HMFNGAT !<Diagnosed energy associated with phase change of water in snow pack \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: HMFNROT !<
        !       REAL,DIMENSION(NLAT)      :: HMFNROW !<
        !       REAL HTCGAT (ILG,IGND)               !<Diagnosed internal energy change of soil layer due to conduction and/or change in mass \f$[W m^{-2} ]\f$
        !       REAL HTCROT (NLAT,NMOS,IGND)         !<
        !       REAL HTCROW (NLAT,IGND)              !<
        !       REAL,DIMENSION(ILG)       :: HTCCGAT !<Diagnosed internal energy change of vegetation canopy due to conduction and/or change in mass \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: HTCCROT !<
        !       REAL,DIMENSION(NLAT)      :: HTCCROW !<
        !       REAL,DIMENSION(ILG)       :: HTCSGAT !<Diagnosed internal energy change of snow pack due to conduction and/or change in mass \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: HTCSROT !<
        !       REAL,DIMENSION(NLAT)      :: HTCSROW !<
        !       REAL,DIMENSION(ILG)       :: ILMOGAT !<Inverse of Monin-Obukhov roughness length \f$(m^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: ILMOROT !<
        !       REAL,DIMENSION(NLAT)      :: ILMOROW !<
        !FLAG! >>> Not in the new structure
        INTEGER ISUM(6)                      !<Total number of iterations required to solve surface energy balance for the elements of the four subareas for the current run
        !FLAG! <<< Not in the new structure
        !       INTEGER ITCTGAT(ILG,6,50)            !<Counter of number of iterations required to solve surface energy balance for the elements of the four subareas
        !       INTEGER ITCTROT(NLAT,NMOS,6,50)      !<
        !       REAL,DIMENSION(ILG)       :: PCFCGAT !<Diagnosed frozen precipitation intercepted by vegetation \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: PCFCROT !<
        !       REAL,DIMENSION(NLAT)      :: PCFCROW !<
        !       REAL,DIMENSION(ILG)       :: PCLCGAT !<Diagnosed liquid precipitation intercepted by vegetation \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: PCLCROT !<
        !       REAL,DIMENSION(NLAT)      :: PCLCROW !<
        !       REAL,DIMENSION(ILG)       :: PCPGGAT !<Diagnosed precipitation incident on ground \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: PCPGROT !<
        !       REAL,DIMENSION(NLAT)      :: PCPGROW !<
        !       REAL,DIMENSION(ILG)       :: PCPNGAT !<Diagnosed precipitation incident on snow pack \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: PCPNROT !<
        !       REAL,DIMENSION(NLAT)      :: PCPNROW !<
        !       REAL,DIMENSION(ILG)       :: PETGAT  !<Diagnosed potential evapotranspiration \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: PETROT  !<
        !       REAL,DIMENSION(NLAT)      :: PETROW  !<
        !       REAL,DIMENSION(ILG)       :: QEVPGAT !<Diagnosed total surface latent heat flux over modelled area \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: QEVPROT !<
        !       REAL,DIMENSION(NLAT)      :: QEVPROW !<
        !       REAL QFCGAT (ILG,IGND)               !<Diagnosed vapour flux from transpiration over modelled area \f$[W m^{-2} ]\f$
        !       REAL QFCROT (NLAT,NMOS,IGND)         !<
        !       REAL QFCROW (NLAT,IGND)              !<
        !       REAL,DIMENSION(ILG)       :: QFCFGAT !<Diagnosed vapour flux from frozen water on vegetation \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: QFCFROT !<
        !       REAL,DIMENSION(NLAT)      :: QFCFROW !<
        !       REAL,DIMENSION(ILG)       :: QFCLGAT !<Diagnosed vapour flux from liquid water on vegetation \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: QFCLROT !<
        !       REAL,DIMENSION(NLAT)      :: QFCLROW !<
        !       REAL,DIMENSION(ILG)       :: QFGGAT  !<Diagnosed water vapour flux from ground \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: QFGROT  !<
        !       REAL,DIMENSION(NLAT)      :: QFGROW  !<
        !       REAL,DIMENSION(ILG)       :: QFNGAT  !<Diagnosed water vapour flux from snow pack \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: QFNROT  !<
        !       REAL,DIMENSION(NLAT)      :: QFNROW  !<
        !       REAL,DIMENSION(ILG)       :: QFSGAT  !<Diagnosed total surface water vapour flux over modelled area \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: QFSROT  !<
        !       REAL,DIMENSION(NLAT)      :: QFSROW  !<
        !       REAL,DIMENSION(ILG)       :: QFXGAT  !<Product of surface drag coefficient, wind speed and surface-air specific humidity difference \f$[m s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: QFXROT  !<
        !       REAL,DIMENSION(NLAT)      :: QFXROW  !<
        !       REAL,DIMENSION(ILG)       :: QGGAT   !<Diagnosed surface specific humidity \f$[kg kg^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: QGROT   !<
        !       REAL,DIMENSION(NLAT)      :: QGROW   !<
        !       REAL,DIMENSION(ILG)       :: ROFGAT  !<Total runoff from soil \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: ROFROT  !<
        !       REAL,DIMENSION(NLAT)      :: ROFROW  !<
        !       REAL,DIMENSION(ILG)       :: ROFBGAT !<Base flow from bottom of soil column \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: ROFBROT !<
        !       REAL,DIMENSION(NLAT)      :: ROFBROW !<
        !       REAL,DIMENSION(ILG)       :: ROFCGAT !<Liquid/frozen water runoff from vegetation \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: ROFCROT !<
        !       REAL,DIMENSION(NLAT)      :: ROFCROW !<
        !       REAL,DIMENSION(ILG)       :: ROFNGAT !<Liquid water runoff from snow pack \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: ROFNROT !<
        !       REAL,DIMENSION(NLAT)      :: ROFNROW !<
        !       REAL,DIMENSION(ILG)       :: ROFOGAT !<Overland flow from top of soil column \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: ROFOROT !<
        !       REAL,DIMENSION(NLAT)      :: ROFOROW !<
        !       REAL,DIMENSION(ILG)       :: ROFSGAT !<Interflow from sides of soil column \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: ROFSROT !<
        !       REAL,DIMENSION(NLAT)      :: ROFSROW !<
        !       REAL,DIMENSION(ILG)       :: ROVGGAT !<Diagnosed liquid/frozen water runoff from vegetation to ground surface \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: ROVGROT !<
        !       REAL,DIMENSION(NLAT)      :: ROVGROW !<
        !       REAL,DIMENSION(ILG)       :: SFCQGAT !<Diagnosed screen-level specific humidity \f$[kg kg^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: SFCQROT !<
        !       REAL,DIMENSION(NLAT)      :: SFCQROW !<
        !       REAL,DIMENSION(ILG)       :: SFCTGAT !<Diagnosed screen-level air temperature [K]
        !       REAL,DIMENSION(NLAT,NMOS) :: SFCTROT !<
        !       REAL,DIMENSION(NLAT)      :: SFCTROW !<
        !       REAL,DIMENSION(ILG)       :: SFCUGAT !<Diagnosed anemometer-level zonal wind \f$[m s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: SFCUROT !<
        !       REAL,DIMENSION(NLAT)      :: SFCUROW !<
        !       REAL,DIMENSION(ILG)       :: SFCVGAT !<Diagnosed anemometer-level meridional wind \f$[m s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: SFCVROT !<
        !       REAL,DIMENSION(NLAT)      :: SFCVROW !<
        !       REAL,DIMENSION(ILG)       :: TFXGAT  !<Product of surface drag coefficient, wind speed and surface-air temperature difference \f$[K m s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: TFXROT  !<
        !       REAL,DIMENSION(NLAT)      :: TFXROW  !<
        !       REAL,DIMENSION(ILG)       :: TROBGAT !<Temperature of base flow from bottom of soil column [K]
        !       REAL,DIMENSION(NLAT,NMOS) :: TROBROT !<
        !       REAL,DIMENSION(ILG)       :: TROFGAT !<Temperature of total runoff [K]
        !       REAL,DIMENSION(NLAT,NMOS) :: TROFROT !<
        !       REAL,DIMENSION(ILG)       :: TROOGAT !<Temperature of overland flow from top of soil column [K]
        !       REAL,DIMENSION(NLAT,NMOS) :: TROOROT !<
        !       REAL,DIMENSION(ILG)       :: TROSGAT !<Temperature of interflow from sides of soil column [K]
        !       REAL,DIMENSION(NLAT,NMOS) :: TROSROT !<
        !       REAL,DIMENSION(ILG)       :: UEGAT   !<Friction velocity of air \f$[m s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: UEROT   !<
        !       REAL,DIMENSION(NLAT)      :: UEROW   !<
        !       REAL,DIMENSION(ILG)       :: WTABGAT !<Depth of water table in soil [m]
        !       REAL,DIMENSION(NLAT,NMOS) :: WTABROT !<
        !       REAL,DIMENSION(NLAT)      :: WTABROW !<
        !       REAL,DIMENSION(ILG)       :: WTRCGAT !<Diagnosed residual water transferred off the vegetation canopy \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: WTRCROT !<
        !       REAL,DIMENSION(NLAT)      :: WTRCROW !<
        !       REAL,DIMENSION(ILG)       :: WTRGGAT !<Diagnosed residual water transferred into or out of the soil \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: WTRGROT !<
        !       REAL,DIMENSION(NLAT)      :: WTRGROW !<
        !       REAL,DIMENSION(ILG)       :: WTRSGAT !<Diagnosed residual water transferred into or out of the snow pack \f$[kg m^{-2} s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT,NMOS) :: WTRSROT !<
        !       REAL,DIMENSION(NLAT)      :: WTRSROW !<
        !
        !       REAL,DIMENSION(ILG)       :: QLWOGAT !<
        !       REAL,DIMENSION(ILG)       :: SFRHGAT !<
        !       REAL,DIMENSION(NLAT,NMOS) :: SFRHROT !<
        !       REAL,DIMENSION(NLAT)      :: SFRHROW !<
        !
        !       REAL,DIMENSION(ILG)       :: FTEMP   !<
        !       REAL,DIMENSION(ILG)       :: FVAP    !<
        !       REAL,DIMENSION(ILG)       :: RIB     !<
        !
        !    * ARRAYS USED FOR OUTPUT AND DISPLAY PURPOSES.
        !    * (THE SUFFIX "ACC" REFERS TO ACCUMULATOR ARRAYS USED IN
        !    * CALCULATING TIME AVERAGES.)
        !       REAL,DIMENSION(NLAT) :: ALIRACC !<Diagnosed total near-infrared albedo of land surface [ ]
        !       REAL,DIMENSION(NLAT) :: ALVSACC !<Diagnosed total visible albedo of land surface [ ]
        !       REAL,DIMENSION(NLAT) :: EVAPACC !<Diagnosed total surface water vapour flux over modelled area \f$[kg m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: FLINACC !<Downwelling longwave radiation above surface \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: FLUTACC !<Upwelling longwave radiation from surface \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: FSINACC !<Downwelling shortwave radiation above surface \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: GROACC  !<Vegetation growth index [ ]
        !       REAL,DIMENSION(NLAT) :: GTACC   !<Diagnosed effective surface black-body temperature [K]
        !       REAL,DIMENSION(NLAT) :: HFSACC  !<Diagnosed total surface sensible heat flux over modelled area \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: HMFNACC !<Diagnosed energy associated with phase change of water in snow pack \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: OVRACC  !<Overland flow from top of soil column \f$[kg m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: PREACC  !<Surface precipitation rate \f$[kg m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: PRESACC !<Surface air pressure [Pa]
        !       REAL,DIMENSION(NLAT) :: QAACC   !<Specific humidity at reference height \f$[kg kg^{-1} ]\f$
        !       REAL,DIMENSION(NLAT) :: QEVPACC !<Diagnosed total surface latent heat flux over modelled area \f$[W m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: RCANACC !<Intercepted liquid water stored on canopy \f$[kg m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: RHOSACC !<Density of snow \f$[kg m^{-3} ]\f$
        !       REAL,DIMENSION(NLAT) :: ROFACC  !<Total runoff from soil \f$[kg m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: SCANACC !<Intercepted frozen water stored on canopy \f$[kg m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: SNOACC  !<Mass of snow pack \f$[kg m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: TAACC   !<Air temperature at reference height [K]
        !       REAL TBARACC(NLAT,IGND)         !<Temperature of soil layers [K]
        !       REAL THALACC(NLAT,IGND)         !<Total volumetric water content of soil layers \f$[m^3 m^{-3} ]\f$
        !       REAL THICACC(NLAT,IGND)         !<Volumetric frozen water content of soil layers \f$[m^3 m^{-3} ]\f$
        !       REAL THLQACC(NLAT,IGND)         !<Volumetric liquid water content of soil layers \f$[m^3 m^{-3} ]\f$
        !       REAL,DIMENSION(NLAT) :: TCANACC !<Vegetation canopy temperature [K]
        !       REAL,DIMENSION(NLAT) :: TSNOACC !<Snowpack temperature [K]
        !       REAL,DIMENSION(NLAT) :: UVACC   !<Wind speed \f$[m s^{-1} ]\f$
        !       REAL,DIMENSION(NLAT) :: WSNOACC !<Liquid water content of snow pack \f$[kg m^{-2} ]\f$
        !       REAL,DIMENSION(NLAT) :: WTBLACC !<Depth of water table in soil [m]
        !       REAL,DIMENSION(NLAT) :: ALTOTACC!<Broadband albedo [-]
        !
        !       REAL,DIMENSION(NLAT) :: CANARE  !<
        !       REAL,DIMENSION(NLAT) :: SNOARE  !<
        !
        ! !
        ! !     * ARRAYS DEFINED TO PASS INFORMATION BETWEEN THE THREE MAJOR
        ! !     * SUBSECTIONS OF CLASS ("CLASSA", "CLASST" AND "CLASSW").
        !  !<
        !       REAL,DIMENSION(ILG,IGND) :: TBARC  !<
        !       REAL,DIMENSION(ILG,IGND) :: TBARG  !<
        !       REAL,DIMENSION(ILG,IGND) :: TBARCS !<
        !       REAL,DIMENSION(ILG,IGND) :: TBARGS !<
        !       REAL,DIMENSION(ILG,IGND) :: THLIQC !<
        !       REAL,DIMENSION(ILG,IGND) :: THLIQG !<
        !       REAL,DIMENSION(ILG,IGND) :: THICEC !<
        !       REAL,DIMENSION(ILG,IGND) :: THICEG !<
        !       REAL,DIMENSION(ILG,IGND) :: FROOT  !<
        !       REAL,DIMENSION(ILG,IGND) :: HCPC   !<
        !       REAL,DIMENSION(ILG,IGND) :: HCPG   !<
        !       REAL,DIMENSION(ILG,IGND) :: FROOTS !<
        !       REAL,DIMENSION(ILG,IGND) :: TCTOPC !<
        !       REAL,DIMENSION(ILG,IGND) :: TCBOTC !<
        !       REAL,DIMENSION(ILG,IGND) :: TCTOPG !<
        !       REAL,DIMENSION(ILG,IGND) :: TCBOTG !<
        ! !
        !       REAL FC     (ILG)  !<
        !       REAL FG     (ILG)  !<
        !       REAL FCS    (ILG)  !<
        !       REAL FGS    (ILG)  !<
        !       REAL RBCOEF (ILG)  !<
        !       REAL ZSNOW  (ILG)  !<
        !       REAL FSVF   (ILG)  !<
        !       REAL FSVFS  (ILG)  !<
        !       REAL ALVSCN (ILG)  !<
        !       REAL ALIRCN (ILG)  !<
        !       REAL ALVSG  (ILG)  !<
        !       REAL ALIRG  (ILG)  !<
        !       REAL ALVSCS (ILG)  !<
        !       REAL ALIRCS (ILG)  !<
        !       REAL ALVSSN (ILG)  !<
        !       REAL ALIRSN (ILG)  !<
        !       REAL ALVSGC (ILG)  !<
        !       REAL ALIRGC (ILG)  !<
        !       REAL ALVSSC (ILG)  !<
        !       REAL ALIRSC (ILG)  !<
        !       REAL TRVSCN (ILG)  !<
        !       REAL TRIRCN (ILG)  !<
        !       REAL TRVSCS (ILG)  !<
        !       REAL TRIRCS (ILG)  !<
        !       REAL RC     (ILG)  !<
        !       REAL RCS    (ILG)  !<
        !       REAL FRAINC (ILG)  !<
        !       REAL FSNOWC (ILG)  !<
        !       REAL FRAICS (ILG)  !<
        !       REAL FSNOCS (ILG)  !<
        !       REAL CMASSC (ILG)  !<
        !       REAL CMASCS (ILG)  !<
        !       REAL DISP   (ILG)  !<
        !       REAL DISPS  (ILG)  !<
        !       REAL ZOMLNC (ILG)  !<
        !       REAL ZOELNC (ILG)  !<
        !       REAL ZOMLNG (ILG)  !<
        !       REAL ZOELNG (ILG)  !<
        !       REAL ZOMLCS (ILG)  !<
        !       REAL ZOELCS (ILG)  !<
        !       REAL ZOMLNS (ILG)  !<
        !       REAL ZOELNS (ILG)  !<
        !       REAL TRSNOWC (ILG) !<
        !       REAL CHCAP  (ILG)  !<
        !       REAL CHCAPS (ILG)  !<
        !       REAL GZEROC (ILG)  !<
        !       REAL GZEROG (ILG)  !<
        !       REAL GZROCS (ILG)  !<
        !       REAL GZROGS (ILG)  !<
        !       REAL G12C   (ILG)  !<
        !       REAL G12G   (ILG)  !<
        !       REAL G12CS  (ILG)  !<
        !       REAL G12GS  (ILG)  !<
        !       REAL G23C   (ILG)  !<
        !       REAL G23G   (ILG)  !<
        !       REAL G23CS  (ILG)  !<
        !       REAL G23GS  (ILG)  !<
        !       REAL QFREZC (ILG)  !<
        !       REAL QFREZG (ILG)  !<
        !       REAL QMELTC (ILG)  !<
        !       REAL QMELTG (ILG)  !<
        !       REAL EVAPC  (ILG)  !<
        !       REAL EVAPCG (ILG)  !<
        !       REAL EVAPG  (ILG)  !<
        !       REAL EVAPCS (ILG)  !<
        !       REAL EVPCSG (ILG)  !<
        !       REAL EVAPGS (ILG)  !<
        !       REAL TCANO  (ILG)  !<
        !       REAL TCANS  (ILG)  !<
        !       REAL RAICAN (ILG)  !<
        !       REAL SNOCAN (ILG)  !<
        !       REAL RAICNS (ILG)  !<
        !       REAL SNOCNS (ILG)  !<
        !       REAL CWLCAP (ILG)  !<
        !       REAL CWFCAP (ILG)  !<
        !       REAL CWLCPS (ILG)  !<
        !       REAL CWFCPS (ILG)  !<
        !       REAL TSNOCS (ILG)  !<
        !       REAL TSNOGS (ILG)  !<
        !       REAL RHOSCS (ILG)  !<
        !       REAL RHOSGS (ILG)  !<
        !       REAL WSNOCS (ILG)  !<
        !       REAL WSNOGS (ILG)  !<
        !       REAL TPONDC (ILG)  !<
        !       REAL TPONDG (ILG)  !<
        !       REAL TPNDCS (ILG)  !<
        !       REAL TPNDGS (ILG)  !<
        !       REAL ZPLMCS (ILG)  !<
        !       REAL ZPLMGS (ILG)  !<
        !       REAL ZPLIMC (ILG)  !<
        !       REAL ZPLIMG (ILG)  !<
        ! !
        !       REAL ALTG(ILG,NBS)    !<
        !       REAL ALSNO(ILG,NBS)   !<
        !       REAL TRSNOWG(ILG,NBS) !<
        !
        ! !
        ! !     * DIAGNOSTIC ARRAYS USED FOR CHECKING ENERGY AND WATER
        ! !     * BALANCES.
        ! !
        !       REAL CTVSTP(ILG) !<
        !       REAL CTSSTP(ILG) !<
        !       REAL CT1STP(ILG) !<
        !       REAL CT2STP(ILG) !<
        !       REAL CT3STP(ILG) !<
        !       REAL WTVSTP(ILG) !<
        !       REAL WTSSTP(ILG) !<
        !       REAL WTGSTP(ILG) !<

        !     * CONSTANTS AND TEMPORARY VARIABLES.
        !
        REAL DAY,DECL,HOUR,COSZ,CUMSNO,EVAPSUM,&
            &     QSUMV,QSUMS,QSUM1,QSUM2,QSUM3,WSUMV,WSUMS,WSUMG,ALTOT,&
            &     FSSTAR,FLSTAR,QH,QE,BEG,SNOMLT,ZSN,TCN,TSN,TPN,GTOUT,TAC,&
            &     TSURF
        !
        !     * COMMON BLOCK PARAMETERS.
        !
        REAL X1,X2,X3,X4,G,GAS,X5,X6,CPRES,GASV,X7,CPI,X8,CELZRO,X9,&
            &     X10,X11,X12,X13,X14,X15,SIGMA,X16,DELTIM,DELT,TFREZ,&
            &     RGAS,RGASV,GRAV,SBC,VKC,CT,VMIN,TCW,TCICE,TCSAND,TCCLAY,&
            &     TCOM,TCDRYS,RHOSOL,RHOOM,HCPW,HCPICE,HCPSOL,HCPOM,HCPSND,&
            &     HCPCLY,SPHW,SPHICE,SPHVEG,SPHAIR,RHOW,RHOICE,TCGLAC,CLHMLT,&
            &     CLHVAP,PI,ZOLNG,ZOLNS,ZOLNI,ZORATG,ALVSI,ALIRI,ALVSO,ALIRO,&
            &     ALBRCK,DELTA,CGRAV,CKARM,CPD,AS,ASX,CI,BS,BETA,FACTN,HMIN,&
            &     ANGMAX,A,B


        !
        !================= CTEM array declaration ===============================\
        !
        !     Local variables for coupling CLASS and CTEM
        !
        integer strlen
        character*80   titlec1
        character*80   argbuff
        character*160  command

        integer   lopcount,  isumc,     k1c,       k2c,&
            &           jhhstd,    jhhendd,   jdstd,   jdendd,&
            &           jhhsty,     jhhendy,   jdsty,   jdendy,&
            &           month1,     month2,      xday,  ctemloop,&
            &           nummetcylyrs, ncyear,  co2yr,   spinfast,&
            &           nol2pfts(4),  popyr, metcylyrst, metcycendyr,&
            &           climiyear,   popcycleyr,    cypopyr, lucyr,&
            &           cylucyr, endyr,bigpftc(1), obswetyr,&
            &           cywetldyr, trans_startyr, jmosty, obslghtyr,testyr

        real      co2concin,    setco2conc, sumfare,&
            &           temp_var, barefrac,ch4concin, setch4conc

        integer, allocatable, dimension(:) :: curlatno !ilg
        integer, allocatable, dimension(:) :: altotcount_ctm !nlat
        real, allocatable, dimension(:,:)  :: todfrac  !(ilg,icc)
        real, allocatable, dimension(:,:)  :: barf  !(nlat,nmos)
        real, allocatable, dimension(:)    :: currlat !(ilg)
        real, allocatable, dimension(:)    :: fsinacc_gat !(ilg)
        real, allocatable, dimension(:)    :: flutacc_gat !(ilg)
        real, allocatable, dimension(:)    :: flinacc_gat !(ilg)
        real, allocatable, dimension(:)    :: alswacc_gat !(ilg)
        real, allocatable, dimension(:)    :: allwacc_gat !(ilg)
        real, allocatable, dimension(:)    :: pregacc_gat !(ilg)
        real, allocatable, dimension(:)    :: altotacc_gat !(ilg)
        real, allocatable, dimension(:)    :: netrad_gat !(ilg)
        real, allocatable, dimension(:)    :: preacc_gat !(ilg)
        real, allocatable, dimension(:)    :: sdepgat !(ilg)
        real, allocatable, dimension(:,:)  :: rgmgat !(ilg,ignd)
        real, allocatable, dimension(:,:)  :: sandgat !(ilg,ignd)
        real, allocatable, dimension(:,:)  :: claygat !(ilg,ignd)
        real, allocatable, dimension(:,:)  :: orgmgat !(ilg,ignd)
        real, allocatable, dimension(:)    :: xdiffusgat !(ilg) ! the corresponding ROW is CLASS's XDIFFUS
        real, allocatable, dimension(:)    :: faregat !(ilg)   ! the ROT is FAREROT
        real, allocatable, dimension(:,:)  :: FTABLE !(NLAT,NMOS) !,ALAVG,ALMAX,FTAVG,FTMAX
        real, allocatable, dimension(:,:)  :: ACTLYR !(NLAT,NMOS)

        real fsstar_gat, flstar_gat !FLAG should these have more dimensions? JM Feb 2016.

        ! Model switches:
        logical, pointer :: ctem_on
        logical, pointer :: parallelrun
        logical, pointer :: cyclemet
        logical, pointer :: dofire
        logical, pointer :: run_model
        logical, pointer :: met_rewound
        logical, pointer :: reach_eof
        logical, pointer :: compete
        logical, pointer :: start_bare
        logical, pointer :: rsfile
        logical, pointer :: lnduseon
        logical, pointer :: co2on
        logical, pointer :: ch4on
        logical, pointer :: popdon
        logical, pointer :: inibioclim
        logical, pointer :: dowetlands
        logical, pointer :: obswetf
        logical, pointer :: transient_run
        logical, pointer :: use_netcdf
        character(180), pointer :: met_file
        character(180), pointer :: init_file

        ! ROW vars:
        logical, pointer, dimension(:,:,:) :: pftexistrow
        integer, pointer, dimension(:,:,:) :: colddaysrow
        integer, pointer, dimension(:,:) :: icountrow
        integer, pointer, dimension(:,:,:) :: lfstatusrow
        integer, pointer, dimension(:,:,:) :: pandaysrow
        integer, pointer, dimension(:,:) :: stdalnrow
        real, pointer, dimension(:,:) :: tcanrs
        real, pointer, dimension(:,:) :: tsnors
        real, pointer, dimension(:,:) :: tpndrs
        real, pointer, dimension(:,:,:) :: csum
        real, pointer, dimension(:,:,:) :: tbaraccrow_m
        real, pointer, dimension(:,:) :: tcanoaccrow_m
        real, pointer, dimension(:,:) :: uvaccrow_m
        real, pointer, dimension(:,:) :: vvaccrow_m

        real, pointer, dimension(:,:,:) :: ailcminrow         !
        real, pointer, dimension(:,:,:) :: ailcmaxrow         !
        real, pointer, dimension(:,:,:) :: dvdfcanrow         !
        real, pointer, dimension(:,:,:) :: gleafmasrow        !
        real, pointer, dimension(:,:,:) :: bleafmasrow        !
        real, pointer, dimension(:,:,:) :: stemmassrow        !
        real, pointer, dimension(:,:,:) :: rootmassrow        !
        real, pointer, dimension(:,:,:) :: pstemmassrow       !
        real, pointer, dimension(:,:,:) :: pgleafmassrow      !
        real, pointer, dimension(:,:,:) :: fcancmxrow
        real, pointer, dimension(:,:) :: gavglairow
        real, pointer, dimension(:,:,:) :: zolncrow
        real, pointer, dimension(:,:,:) :: ailcrow
        real, pointer, dimension(:,:,:) :: ailcgrow
        real, pointer, dimension(:,:,:) :: ailcgsrow
        real, pointer, dimension(:,:,:) :: fcancsrow
        real, pointer, dimension(:,:,:) :: fcancrow
        real, pointer, dimension(:,:) :: co2concrow
        real, pointer, dimension(:,:) :: ch4concrow
        real, pointer, dimension(:,:,:) :: co2i1cgrow
        real, pointer, dimension(:,:,:) :: co2i1csrow
        real, pointer, dimension(:,:,:) :: co2i2cgrow
        real, pointer, dimension(:,:,:) :: co2i2csrow
        real, pointer, dimension(:,:,:) :: ancsvegrow
        real, pointer, dimension(:,:,:) :: ancgvegrow
        real, pointer, dimension(:,:,:) :: rmlcsvegrow
        real, pointer, dimension(:,:,:) :: rmlcgvegrow
        real, pointer, dimension(:,:,:) :: slairow
        real, pointer, dimension(:,:,:) :: ailcbrow
        real, pointer, dimension(:,:) :: canresrow
        real, pointer, dimension(:,:,:) :: flhrlossrow

        real, pointer, dimension(:,:,:) :: grwtheffrow
        real, pointer, dimension(:,:,:) :: lystmmasrow
        real, pointer, dimension(:,:,:) :: lyrotmasrow
        real, pointer, dimension(:,:,:) :: tymaxlairow
        real, pointer, dimension(:,:) :: vgbiomasrow
        real, pointer, dimension(:,:) :: gavgltmsrow
        real, pointer, dimension(:,:) :: gavgscmsrow
        real, pointer, dimension(:,:,:) :: stmhrlosrow
        real, pointer, dimension(:,:,:,:) :: rmatcrow
        real, pointer, dimension(:,:,:,:) :: rmatctemrow
        real, pointer, dimension(:,:,:) :: litrmassrow
        real, pointer, dimension(:,:,:) :: soilcmasrow
        real, pointer, dimension(:,:,:) :: vgbiomas_vegrow

        real, pointer, dimension(:,:,:) :: emit_co2row
        real, pointer, dimension(:,:,:) :: emit_corow
        real, pointer, dimension(:,:,:) :: emit_ch4row
        real, pointer, dimension(:,:,:) :: emit_nmhcrow
        real, pointer, dimension(:,:,:) :: emit_h2row
        real, pointer, dimension(:,:,:) :: emit_noxrow
        real, pointer, dimension(:,:,:) :: emit_n2orow
        real, pointer, dimension(:,:,:) :: emit_pm25row
        real, pointer, dimension(:,:,:) :: emit_tpmrow
        real, pointer, dimension(:,:,:) :: emit_tcrow
        real, pointer, dimension(:,:,:) :: emit_ocrow
        real, pointer, dimension(:,:,:) :: emit_bcrow
        real, pointer, dimension(:,:) :: burnfracrow
        real, pointer, dimension(:,:,:) :: burnvegfrow
        real, pointer, dimension(:,:,:) :: smfuncvegrow
        real, pointer, dimension(:,:) :: popdinrow
        real, pointer, dimension(:,:,:) :: btermrow
        real, pointer, dimension(:,:) :: ltermrow
        real, pointer, dimension(:,:,:) :: mtermrow

        real, pointer, dimension(:,:) :: extnprobrow
        real, pointer, dimension(:,:) :: prbfrhucrow
        real, pointer, dimension(:,:,:) :: mlightngrow
        real, pointer, dimension(:) :: dayl_maxrow
        real, pointer, dimension(:) :: daylrow
        real, pointer, dimension(:) :: grclarea

        real, pointer, dimension(:,:,:) :: bmasvegrow
        real, pointer, dimension(:,:,:) :: cmasvegcrow
        real, pointer, dimension(:,:,:) :: veghghtrow
        real, pointer, dimension(:,:,:) :: rootdpthrow
        real, pointer, dimension(:,:) :: rmlrow
        real, pointer, dimension(:,:) :: rmsrow
        real, pointer, dimension(:,:,:) :: tltrleafrow
        real, pointer, dimension(:,:,:) :: tltrstemrow
        real, pointer, dimension(:,:,:) :: tltrrootrow
        real, pointer, dimension(:,:,:) :: leaflitrrow
        real, pointer, dimension(:,:,:) :: roottemprow
        real, pointer, dimension(:,:,:) :: afrleafrow
        real, pointer, dimension(:,:,:) :: afrstemrow
        real, pointer, dimension(:,:,:) :: afrrootrow
        real, pointer, dimension(:,:,:) :: wtstatusrow
        real, pointer, dimension(:,:,:) :: ltstatusrow
        real, pointer, dimension(:,:) :: rmrrow

        real, pointer, dimension(:,:,:) :: slopefracrow
        real, pointer, dimension(:,:) :: ch4wet1row
        real, pointer, dimension(:,:) :: ch4wet2row
        real, pointer, dimension(:,:) :: wetfdynrow
        real, pointer, dimension(:,:) :: ch4dyn1row
        real, pointer, dimension(:,:) :: ch4dyn2row
        real, pointer, dimension(:,:,:) :: wetfrac_monrow
        real, pointer, dimension(:,:) :: ch4soillsrow

        real, pointer, dimension(:,:) :: lucemcomrow
        real, pointer, dimension(:,:) :: lucltrinrow
        real, pointer, dimension(:,:) :: lucsocinrow

        real, pointer, dimension(:,:) :: npprow
        real, pointer, dimension(:,:) :: neprow
        real, pointer, dimension(:,:) :: nbprow
        real, pointer, dimension(:,:) :: gpprow
        real, pointer, dimension(:,:) :: hetroresrow
        real, pointer, dimension(:,:) :: autoresrow
        real, pointer, dimension(:,:) :: soilcresprow
        real, pointer, dimension(:,:) :: rmrow
        real, pointer, dimension(:,:) :: rgrow
        real, pointer, dimension(:,:) :: litresrow
        real, pointer, dimension(:,:) :: socresrow
        real, pointer, dimension(:,:) :: dstcemlsrow
        real, pointer, dimension(:,:) :: litrfallrow
        real, pointer, dimension(:,:) :: humiftrsrow

        real, pointer, dimension(:,:,:) :: gppvegrow
        real, pointer, dimension(:,:,:) :: nepvegrow
        real, pointer, dimension(:,:,:) :: nbpvegrow
        real, pointer, dimension(:,:,:) :: nppvegrow
        real, pointer, dimension(:,:,:) :: hetroresvegrow
        real, pointer, dimension(:,:,:) :: autoresvegrow
        real, pointer, dimension(:,:,:) :: litresvegrow
        real, pointer, dimension(:,:,:) :: soilcresvegrow
        real, pointer, dimension(:,:,:) :: rmlvegaccrow
        real, pointer, dimension(:,:,:) :: rmsvegrow
        real, pointer, dimension(:,:,:) :: rmrvegrow
        real, pointer, dimension(:,:,:) :: rgvegrow
        real, pointer, dimension(:,:,:) :: litrfallvegrow
        real, pointer, dimension(:,:,:) :: humiftrsvegrow

        real, pointer, dimension(:,:,:) :: rothrlosrow
        real, pointer, dimension(:,:,:) :: pfcancmxrow
        real, pointer, dimension(:,:,:) :: nfcancmxrow
        real, pointer, dimension(:,:,:) :: alvsctmrow
        real, pointer, dimension(:,:,:) :: paicrow
        real, pointer, dimension(:,:,:) :: slaicrow
        real, pointer, dimension(:,:,:) :: alirctmrow
        real, pointer, dimension(:,:) :: cfluxcgrow
        real, pointer, dimension(:,:) :: cfluxcsrow
        real, pointer, dimension(:,:) :: dstcemls3row
        real, pointer, dimension(:,:,:) :: anvegrow
        real, pointer, dimension(:,:,:) :: rmlvegrow

        real, pointer, dimension(:,:) :: twarmmrow
        real, pointer, dimension(:,:) :: tcoldmrow
        real, pointer, dimension(:,:) :: gdd5row
        real, pointer, dimension(:,:) :: aridityrow
        real, pointer, dimension(:,:) :: srplsmonrow
        real, pointer, dimension(:,:) :: defctmonrow
        real, pointer, dimension(:,:) :: anndefctrow
        real, pointer, dimension(:,:) :: annsrplsrow
        real, pointer, dimension(:,:) :: annpcprow
        real, pointer, dimension(:,:) :: dry_season_lengthrow


        ! >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>.
        ! GAT version:

        logical, pointer, dimension(:,:) :: pftexistgat
        integer, pointer, dimension(:,:) :: colddaysgat
        integer, pointer, dimension(:) :: icountgat
        integer, pointer, dimension(:,:) :: lfstatusgat
        integer, pointer, dimension(:,:) :: pandaysgat
        integer, pointer, dimension(:) :: stdalngat
        real, pointer, dimension(:) :: lightng

        real, pointer, dimension(:,:) :: ailcmingat         !
        real, pointer, dimension(:,:) :: ailcmaxgat         !
        real, pointer, dimension(:,:) :: dvdfcangat         !
        real, pointer, dimension(:,:) :: gleafmasgat        !
        real, pointer, dimension(:,:) :: bleafmasgat        !
        real, pointer, dimension(:,:) :: stemmassgat        !
        real, pointer, dimension(:,:) :: rootmassgat        !
        real, pointer, dimension(:,:) :: pstemmassgat       !
        real, pointer, dimension(:,:) :: pgleafmassgat      !
        real, pointer, dimension(:,:) :: fcancmxgat
        real, pointer, dimension(:) :: gavglaigat
        real, pointer, dimension(:,:) :: zolncgat
        real, pointer, dimension(:,:) :: ailcgat
        real, pointer, dimension(:,:) :: ailcggat
        real, pointer, dimension(:,:) :: ailcgsgat
        real, pointer, dimension(:,:) :: fcancsgat
        real, pointer, dimension(:,:) :: fcancgat
        real, pointer, dimension(:) :: co2concgat
        real, pointer, dimension(:) :: ch4concgat
        real, pointer, dimension(:,:) :: co2i1cggat
        real, pointer, dimension(:,:) :: co2i1csgat
        real, pointer, dimension(:,:) :: co2i2cggat
        real, pointer, dimension(:,:) :: co2i2csgat
        real, pointer, dimension(:,:) :: ancsveggat
        real, pointer, dimension(:,:) :: ancgveggat
        real, pointer, dimension(:,:) :: rmlcsveggat
        real, pointer, dimension(:,:) :: rmlcgveggat
        real, pointer, dimension(:,:) :: slaigat
        real, pointer, dimension(:,:) :: ailcbgat
        real, pointer, dimension(:) :: canresgat
        real, pointer, dimension(:,:) :: flhrlossgat

        real, pointer, dimension(:,:) :: grwtheffgat
        real, pointer, dimension(:,:) :: lystmmasgat
        real, pointer, dimension(:,:) :: lyrotmasgat
        real, pointer, dimension(:,:) :: tymaxlaigat
        real, pointer, dimension(:) :: vgbiomasgat
        real, pointer, dimension(:) :: gavgltmsgat
        real, pointer, dimension(:) :: gavgscmsgat
        real, pointer, dimension(:,:) :: stmhrlosgat
        real, pointer, dimension(:,:,:) :: rmatcgat
        real, pointer, dimension(:,:,:) :: rmatctemgat
        real, pointer, dimension(:,:) :: litrmassgat
        real, pointer, dimension(:,:) :: soilcmasgat
        real, pointer, dimension(:,:) :: vgbiomas_veggat

        real, pointer, dimension(:,:) :: emit_co2gat
        real, pointer, dimension(:,:) :: emit_cogat
        real, pointer, dimension(:,:) :: emit_ch4gat
        real, pointer, dimension(:,:) :: emit_nmhcgat
        real, pointer, dimension(:,:) :: emit_h2gat
        real, pointer, dimension(:,:) :: emit_noxgat
        real, pointer, dimension(:,:) :: emit_n2ogat
        real, pointer, dimension(:,:) :: emit_pm25gat
        real, pointer, dimension(:,:) :: emit_tpmgat
        real, pointer, dimension(:,:) :: emit_tcgat
        real, pointer, dimension(:,:) :: emit_ocgat
        real, pointer, dimension(:,:) :: emit_bcgat
        real, pointer, dimension(:) :: burnfracgat
        real, pointer, dimension(:,:) :: burnvegfgat
        real, pointer, dimension(:,:) :: smfuncveggat
        real, pointer, dimension(:) :: popdingat
        real, pointer, dimension(:,:) :: btermgat
        real, pointer, dimension(:) :: ltermgat
        real, pointer, dimension(:,:) :: mtermgat

        real, pointer, dimension(:) :: extnprobgat
        real, pointer, dimension(:) :: prbfrhucgat
        real, pointer, dimension(:,:) :: mlightnggat
        real, pointer, dimension(:) :: dayl_maxgat
        real, pointer, dimension(:) :: daylgat

        real, pointer, dimension(:,:) :: bmasveggat
        real, pointer, dimension(:,:) :: cmasvegcgat
        real, pointer, dimension(:,:) :: veghghtgat
        real, pointer, dimension(:,:) :: rootdpthgat
        real, pointer, dimension(:) :: rmlgat
        real, pointer, dimension(:) :: rmsgat
        real, pointer, dimension(:,:) :: tltrleafgat
        real, pointer, dimension(:,:) :: tltrstemgat
        real, pointer, dimension(:,:) :: tltrrootgat
        real, pointer, dimension(:,:) :: leaflitrgat
        real, pointer, dimension(:,:) :: roottempgat
        real, pointer, dimension(:,:) :: afrleafgat
        real, pointer, dimension(:,:) :: afrstemgat
        real, pointer, dimension(:,:) :: afrrootgat
        real, pointer, dimension(:,:) :: wtstatusgat
        real, pointer, dimension(:,:) :: ltstatusgat
        real, pointer, dimension(:) :: rmrgat

        real, pointer, dimension(:,:) :: slopefracgat
        real, pointer, dimension(:) :: wetfrac_presgat
        real, pointer, dimension(:,:) :: wetfrac_mongat
        real, pointer, dimension(:) :: ch4wet1gat
        real, pointer, dimension(:) :: ch4wet2gat
        real, pointer, dimension(:) :: wetfdyngat
        real, pointer, dimension(:) :: ch4dyn1gat
        real, pointer, dimension(:) :: ch4dyn2gat
        real, pointer, dimension(:) :: ch4soillsgat

        real, pointer, dimension(:) :: lucemcomgat
        real, pointer, dimension(:) :: lucltringat
        real, pointer, dimension(:) :: lucsocingat

        real, pointer, dimension(:) :: nppgat
        real, pointer, dimension(:) :: nepgat
        real, pointer, dimension(:) :: nbpgat
        real, pointer, dimension(:) :: gppgat
        real, pointer, dimension(:) :: hetroresgat
        real, pointer, dimension(:) :: autoresgat
        real, pointer, dimension(:) :: soilcrespgat
        real, pointer, dimension(:) :: rmgat
        real, pointer, dimension(:) :: rggat
        real, pointer, dimension(:) :: litresgat
        real, pointer, dimension(:) :: socresgat
        real, pointer, dimension(:) :: dstcemlsgat
        real, pointer, dimension(:) :: litrfallgat
        real, pointer, dimension(:) :: humiftrsgat

        real, pointer, dimension(:,:) :: gppveggat
        real, pointer, dimension(:,:) :: nepveggat
        real, pointer, dimension(:,:) :: nbpveggat
        real, pointer, dimension(:,:) :: nppveggat
        real, pointer, dimension(:,:) :: hetroresveggat
        real, pointer, dimension(:,:) :: autoresveggat
        real, pointer, dimension(:,:) :: litresveggat
        real, pointer, dimension(:,:) :: soilcresveggat
        real, pointer, dimension(:,:) :: rmlvegaccgat
        real, pointer, dimension(:,:) :: rmsveggat
        real, pointer, dimension(:,:) :: rmrveggat
        real, pointer, dimension(:,:) :: rgveggat
        real, pointer, dimension(:,:) :: litrfallveggat
        real, pointer, dimension(:,:) :: humiftrsveggat

        real, pointer, dimension(:,:) :: rothrlosgat
        real, pointer, dimension(:,:) :: pfcancmxgat
        real, pointer, dimension(:,:) :: nfcancmxgat
        real, pointer, dimension(:,:) :: alvsctmgat
        real, pointer, dimension(:,:) :: paicgat
        real, pointer, dimension(:,:) :: slaicgat
        real, pointer, dimension(:,:) :: alirctmgat
        real, pointer, dimension(:) :: cfluxcggat
        real, pointer, dimension(:) :: cfluxcsgat
        real, pointer, dimension(:) :: dstcemls3gat
        real, pointer, dimension(:,:) :: anveggat
        real, pointer, dimension(:,:) :: rmlveggat

        real, pointer, dimension(:) :: twarmmgat
        real, pointer, dimension(:) :: tcoldmgat
        real, pointer, dimension(:) :: gdd5gat
        real, pointer, dimension(:) :: ariditygat
        real, pointer, dimension(:) :: srplsmongat
        real, pointer, dimension(:) :: defctmongat
        real, pointer, dimension(:) :: anndefctgat
        real, pointer, dimension(:) :: annsrplsgat
        real, pointer, dimension(:) :: annpcpgat
        real, pointer, dimension(:) :: dry_season_lengthgat

        real, pointer, dimension(:) :: tcurm
        real, pointer, dimension(:) :: srpcuryr
        real, pointer, dimension(:) :: dftcuryr
        real, pointer, dimension(:,:) :: tmonth
        real, pointer, dimension(:) :: anpcpcur
        real, pointer, dimension(:) :: anpecur
        real, pointer, dimension(:) :: gdd5cur
        real, pointer, dimension(:) :: surmncur
        real, pointer, dimension(:) :: defmncur
        real, pointer, dimension(:) :: srplscur
        real, pointer, dimension(:) :: defctcur

        real, pointer, dimension(:,:) :: geremortgat
        real, pointer, dimension(:,:) :: intrmortgat
        real, pointer, dimension(:,:) :: lambdagat
        real, pointer, dimension(:,:) :: ccgat
        real, pointer, dimension(:,:) :: mmgat
        integer, pointer, dimension(:) :: altotcntr_d

        ! Mosaic level:

        real, pointer, dimension(:,:) :: PREACC_M
        real, pointer, dimension(:,:) :: GTACC_M
        real, pointer, dimension(:,:) :: QEVPACC_M
        real, pointer, dimension(:,:) :: HFSACC_M
        real, pointer, dimension(:,:) :: HMFNACC_M
        real, pointer, dimension(:,:) :: ROFACC_M
        real, pointer, dimension(:,:) :: SNOACC_M
        real, pointer, dimension(:,:) :: OVRACC_M
        real, pointer, dimension(:,:) :: WTBLACC_M
        real, pointer, dimension(:,:,:) :: TBARACC_M
        real, pointer, dimension(:,:,:) :: THLQACC_M
        real, pointer, dimension(:,:,:) :: THICACC_M
        real, pointer, dimension(:,:,:) :: THALACC_M
        real, pointer, dimension(:,:) :: ALVSACC_M
        real, pointer, dimension(:,:) :: ALIRACC_M
        real, pointer, dimension(:,:) :: RHOSACC_M
        real, pointer, dimension(:,:) :: TSNOACC_M
        real, pointer, dimension(:,:) :: WSNOACC_M
        real, pointer, dimension(:,:) :: SNOARE_M
        real, pointer, dimension(:,:) :: TCANACC_M
        real, pointer, dimension(:,:) :: RCANACC_M
        real, pointer, dimension(:,:) :: SCANACC_M
        real, pointer, dimension(:,:) :: GROACC_M
        real, pointer, dimension(:,:) :: FSINACC_M
        real, pointer, dimension(:,:) :: FLINACC_M
        real, pointer, dimension(:,:) :: TAACC_M
        real, pointer, dimension(:,:) :: UVACC_M
        real, pointer, dimension(:,:) :: PRESACC_M
        real, pointer, dimension(:,:) :: QAACC_M
        real, pointer, dimension(:,:) :: ALTOTACC_M
        real, pointer, dimension(:,:) :: EVAPACC_M
        real, pointer, dimension(:,:) :: FLUTACC_M

        !      Outputs

        real, pointer, dimension(:,:) :: tcanoaccrow_out
        real, pointer, dimension(:) :: tcanoaccgat_out
        real, pointer, dimension(:,:) :: qevpacc_m_save

        !     -----------------------
        !      Tile-level variables (denoted by an ending of "_t")

        real, pointer, dimension(:) :: fsnowacc_t
        real, pointer, dimension(:) :: tcansacc_t
        real, pointer, dimension(:) :: tcanoaccgat_t
        real, pointer, dimension(:) :: taaccgat_t
        real, pointer, dimension(:) :: uvaccgat_t
        real, pointer, dimension(:) :: vvaccgat_t
        real, pointer, dimension(:,:) :: tbaraccgat_t
        real, pointer, dimension(:,:) :: tbarcacc_t
        real, pointer, dimension(:,:) :: tbarcsacc_t
        real, pointer, dimension(:,:) :: tbargacc_t
        real, pointer, dimension(:,:) :: tbargsacc_t
        real, pointer, dimension(:,:) :: thliqcacc_t
        real, pointer, dimension(:,:) :: thliqgacc_t
        real, pointer, dimension(:,:) :: thliqacc_t
        real, pointer, dimension(:,:) :: thicecacc_t
        real, pointer, dimension(:,:) :: thicegacc_t
        real, pointer, dimension(:,:) :: ancsvgac_t
        real, pointer, dimension(:,:) :: ancgvgac_t
        real, pointer, dimension(:,:) :: rmlcsvga_t
        real, pointer, dimension(:,:) :: rmlcgvga_t

        !     -----------------------
        !     Grid-averaged variables (denoted with an ending of "_g")

        real, pointer, dimension(:) ::  fsstar_g
        real, pointer, dimension(:) ::  flstar_g
        real, pointer, dimension(:) ::  qh_g
        real, pointer, dimension(:) ::  qe_g
        real, pointer, dimension(:) ::  snomlt_g
        real, pointer, dimension(:) ::  beg_g
        real, pointer, dimension(:) ::  gtout_g
        real, pointer, dimension(:) ::  tpn_g
        real, pointer, dimension(:) ::  altot_g
        real, pointer, dimension(:) ::  tcn_g
        real, pointer, dimension(:) ::  tsn_g
        real, pointer, dimension(:) ::  zsn_g

        real, pointer, dimension(:) :: WSNOROT_g
        real, pointer, dimension(:) :: ROFSROT_g
        real, pointer, dimension(:) :: SNOROT_g
        real, pointer, dimension(:) :: RHOSROT_g
        real, pointer, dimension(:) :: ROFROT_g
        real, pointer, dimension(:) :: ZPNDROT_g
        real, pointer, dimension(:) :: RCANROT_g
        real, pointer, dimension(:) :: SCANROT_g
        real, pointer, dimension(:) :: TROFROT_g
        real, pointer, dimension(:) :: TROOROT_g
        real, pointer, dimension(:) :: TROBROT_g
        real, pointer, dimension(:) :: ROFOROT_g
        real, pointer, dimension(:) :: ROFBROT_g
        real, pointer, dimension(:) :: TROSROT_g
        real, pointer, dimension(:) :: FSGVROT_g
        real, pointer, dimension(:) :: FSGSROT_g
        real, pointer, dimension(:) :: FLGVROT_g
        real, pointer, dimension(:) :: FLGSROT_g
        real, pointer, dimension(:) :: HFSCROT_g
        real, pointer, dimension(:) :: HFSSROT_g
        real, pointer, dimension(:) :: HEVCROT_g
        real, pointer, dimension(:) :: HEVSROT_g
        real, pointer, dimension(:) :: HMFCROT_g
        real, pointer, dimension(:) :: HMFNROT_g
        real, pointer, dimension(:) :: HTCSROT_g
        real, pointer, dimension(:) :: HTCCROT_g
        real, pointer, dimension(:) :: FSGGROT_g
        real, pointer, dimension(:) :: FLGGROT_g
        real, pointer, dimension(:) :: HFSGROT_g
        real, pointer, dimension(:) :: HEVGROT_g
        real, pointer, dimension(:) :: CDHROT_g
        real, pointer, dimension(:) :: CDMROT_g
        real, pointer, dimension(:) :: SFCUROT_g
        real, pointer, dimension(:) :: SFCVROT_g
        real, pointer, dimension(:) :: ACTLYR_g
        real, pointer, dimension(:) :: FTABLE_g
        real, pointer, dimension(:) :: fc_g
        real, pointer, dimension(:) :: fg_g
        real, pointer, dimension(:) :: fcs_g
        real, pointer, dimension(:) :: fgs_g
        real, pointer, dimension(:) :: PCFCROT_g
        real, pointer, dimension(:) :: PCLCROT_g
        real, pointer, dimension(:) :: PCPGROT_g
        real, pointer, dimension(:) :: QFCFROT_g
        real, pointer, dimension(:) :: QFGROT_g
        real, pointer, dimension(:,:) :: QFCROT_g
        real, pointer, dimension(:) :: ROFCROT_g
        real, pointer, dimension(:) :: ROFNROT_g
        real, pointer, dimension(:) :: WTRSROT_g
        real, pointer, dimension(:) :: WTRGROT_g
        real, pointer, dimension(:) :: PCPNROT_g
        real, pointer, dimension(:) :: QFCLROT_g
        real, pointer, dimension(:) :: QFNROT_g
        real, pointer, dimension(:) :: WTRCROT_g
        real, pointer, dimension(:,:) :: rmlvegrow_g
        real, pointer, dimension(:,:) :: anvegrow_g
        real, pointer, dimension(:,:) :: HMFGROT_g
        real, pointer, dimension(:,:) :: HTCROT_g
        real, pointer, dimension(:,:) :: TBARROT_g
        real, pointer, dimension(:,:) :: THLQROT_g
        real, pointer, dimension(:,:) :: THICROT_g
        real, pointer, dimension(:,:) :: GFLXROT_g

        ! Model Switches (rarely changed ones only! The rest are in joboptions file):

        logical, parameter :: obslght = .false.  ! if true the observed lightning will be used. False means you will use the
                                               ! lightning climatology from the CTM file. This was brought in for FireMIP runs.

        ! If you intend to have LUC BETWEEN tiles then set this to true:
        logical, parameter ::  onetile_perPFT = .False. ! NOTE: This is usually not the behaviour desired unless you are
                                                     ! running with one PFT on each tile and want them to compete for space
                                                     ! across tiles. In general keep this as False. JM Feb 2016.
        !
        !============= CTEM array declaration done =============================/
        !
        !=======================================================================
        !     * PHYSICAL CONSTANTS.
        !     * PARAMETERS IN THE FOLLOWING COMMON BLOCKS ARE NORMALLY DEFINED
        !     * WITHIN THE GCM.

        COMMON /PARAMS/ X1,    X2,    X3,    X4,   G,GAS,   X5,&
            &                X6,    CPRES, GASV,  X7
        COMMON /PARAM1/ CPI,   X8,    CELZRO,X9,    X10,    X11
        COMMON /PARAM3/ X12,   X13,   X14,   X15,   SIGMA,  X16
        COMMON  /TIMES/ DELTIM,K1,    K2,    K3,    K4,     K5,&
            &                K6,    K7,    K8,    K9,    K10,    K11
        !
        !     * THE FOLLOWING COMMON BLOCKS ARE DEFINED SPECIFICALLY FOR USE
        !     * IN CLASS, VIA BLOCK DATA AND THE SUBROUTINE "CLASSD".
        !
        COMMON /CLASS1/ DELT,TFREZ
        COMMON /CLASS2/ RGAS,RGASV,GRAV,SBC,VKC,CT,VMIN
        COMMON /CLASS3/ TCW,TCICE,TCSAND,TCCLAY,TCOM,TCDRYS,&
            &                RHOSOL,RHOOM
        COMMON /CLASS4/ HCPW,HCPICE,HCPSOL,HCPOM,HCPSND,HCPCLY,&
            &                SPHW,SPHICE,SPHVEG,SPHAIR,RHOW,RHOICE,&
            &                TCGLAC,CLHMLT,CLHVAP
        COMMON /CLASS5/ THPORG,THRORG,THMORG,BORG,PSISORG,GRKSORG
        COMMON /CLASS6/ PI,GROWYR,ZOLNG,ZOLNS,ZOLNI,ZORAT,ZORATG
        COMMON /CLASS7/ CANEXT,XLEAF
        COMMON /CLASS8/ ALVSI,ALIRI,ALVSO,ALIRO,ALBRCK
        COMMON /PHYCON/ DELTA,CGRAV,CKARM,CPD
        COMMON /CLASSD2/ AS,ASX,CI,BS,BETA,FACTN,HMIN,ANGMAX
        !
        !===================== CTEM ==============================================\

        ! Point the CLASS pointers

        ILMOS   => class_gat%ILMOS
        JLMOS   => class_gat%JLMOS
        IWMOS   => class_gat%IWMOS
        JWMOS   => class_gat%JWMOS
        IGDRGAT => class_gat%IGDRGAT
        DELZ    => class_gat%DELZ
        ZBOT    => class_gat%ZBOT
        ALBSGAT => class_gat%ALBSGAT
        CMAIGAT => class_gat%CMAIGAT
        GROGAT  => class_gat%GROGAT
        QACGAT  => class_gat%QACGAT
        RCANGAT => class_gat%RCANGAT
        RHOSGAT=> class_gat%RHOSGAT
        SCANGAT=> class_gat%SCANGAT
        SNOGAT=> class_gat%SNOGAT
        TACGAT=> class_gat%TACGAT
        TBASGAT=> class_gat%TBASGAT
        TCANGAT=> class_gat%TCANGAT
        TPNDGAT=> class_gat%TPNDGAT
        TSNOGAT=> class_gat%TSNOGAT
        WSNOGAT=> class_gat%WSNOGAT
        ZPNDGAT=> class_gat%ZPNDGAT
        REFGAT=> class_gat%REFGAT
        BCSNGAT => class_gat%BCSNGAT
        AGIDGAT => class_gat%AGIDGAT
        AGVDGAT => class_gat%AGVDGAT
        ALGDGAT => class_gat%ALGDGAT
        ALGWGAT => class_gat%ALGWGAT
        ASIDGAT => class_gat%ASIDGAT
        ASVDGAT => class_gat%ASVDGAT
        DRNGAT => class_gat%DRNGAT
        GRKFGAT => class_gat%GRKFGAT
        WFCIGAT => class_gat%WFCIGAT
        WFSFGAT => class_gat%WFSFGAT
        XSLPGAT => class_gat%XSLPGAT
        ZPLGGAT => class_gat%ZPLGGAT
        ZPLSGAT => class_gat%ZPLSGAT
        ZSNLGAT => class_gat%ZSNLGAT
        ALGWVGAT => class_gat%ALGWVGAT
        ALGWNGAT => class_gat%ALGWNGAT
        ALGDVGAT => class_gat%ALGDVGAT
        ALGDNGAT => class_gat%ALGDNGAT
        EMISGAT => class_gat%EMISGAT
        CSZGAT => class_gat%CSZGAT
        DLONGAT => class_gat%DLONGAT
        DLATGAT => class_gat%DLATGAT
        FCLOGAT => class_gat%FCLOGAT
        FDLGAT => class_gat%FDLGAT
        FSIHGAT => class_gat%FSIHGAT
        FSVHGAT => class_gat%FSVHGAT
        GGEOGAT => class_gat%GGEOGAT
        PADRGAT => class_gat%PADRGAT
        PREGAT => class_gat%PREGAT
        PRESGAT => class_gat%PRESGAT
        QAGAT => class_gat%QAGAT
        RADJGAT => class_gat%RADJGAT
        RHOAGAT => class_gat%RHOAGAT
        RHSIGAT => class_gat%RHSIGAT
        RPCPGAT => class_gat%RPCPGAT
        SPCPGAT => class_gat%SPCPGAT
        TAGAT => class_gat%TAGAT
        TADPGAT => class_gat%TADPGAT
        TRPCGAT => class_gat%TRPCGAT
        TSPCGAT => class_gat%TSPCGAT
        ULGAT => class_gat%ULGAT
        VLGAT => class_gat%VLGAT
        VMODGAT => class_gat%VMODGAT
        VPDGAT => class_gat%VPDGAT
        Z0ORGAT => class_gat%Z0ORGAT
        ZBLDGAT => class_gat%ZBLDGAT
        ZDHGAT => class_gat%ZDHGAT
        ZDMGAT => class_gat%ZDMGAT
        ZRFHGAT => class_gat%ZRFHGAT
        ZRFMGAT => class_gat%ZRFMGAT
        FSGGAT => class_gat%FSGGAT
        FLGGAT => class_gat%FLGGAT
        GUSTGAT => class_gat%GUSTGAT
        DEPBGAT => class_gat%DEPBGAT
        GTBS => class_gat%GTBS
        SFCUBS => class_gat%SFCUBS
        SFCVBS => class_gat%SFCVBS
        USTARBS => class_gat%USTARBS
        TCSNOW => class_gat%TCSNOW
        GSNOW => class_gat%GSNOW
        ALIRGAT => class_gat%ALIRGAT
        ALVSGAT => class_gat%ALVSGAT
        CDHGAT => class_gat%CDHGAT
        CDMGAT => class_gat%CDMGAT
        DRGAT => class_gat%DRGAT
        EFGAT => class_gat%EFGAT
        FLGGGAT => class_gat%FLGGGAT
        FLGSGAT => class_gat%FLGSGAT
        FLGVGAT => class_gat%FLGVGAT
        FSGGGAT => class_gat%FSGGGAT
        FSGSGAT => class_gat%FSGSGAT
        FSGVGAT => class_gat%FSGVGAT
        FSNOGAT => class_gat%FSNOGAT
        GAGAT => class_gat%GAGAT
        GTGAT => class_gat%GTGAT
        HBLGAT => class_gat%HBLGAT
        HEVCGAT => class_gat%HEVCGAT
        HEVGGAT => class_gat%HEVGGAT
        HEVSGAT => class_gat%HEVSGAT
        HFSGAT => class_gat%HFSGAT
        HFSCGAT => class_gat%HFSCGAT
        HFSGGAT => class_gat%HFSGGAT
        HFSSGAT => class_gat%HFSSGAT
        HMFCGAT => class_gat%HMFCGAT
        HMFNGAT => class_gat%HMFNGAT
        HTCCGAT => class_gat%HTCCGAT
        HTCSGAT => class_gat%HTCSGAT
        ILMOGAT => class_gat%ILMOGAT
        PCFCGAT => class_gat%PCFCGAT
        PCLCGAT => class_gat%PCLCGAT
        PCPGGAT => class_gat%PCPGGAT
        PCPNGAT => class_gat%PCPNGAT
        PETGAT => class_gat%PETGAT
        QEVPGAT => class_gat%QEVPGAT
        QFCFGAT => class_gat%QFCFGAT
        QFCLGAT => class_gat%QFCLGAT
        QFGGAT => class_gat%QFGGAT
        QFNGAT => class_gat%QFNGAT
        QFSGAT => class_gat%QFSGAT
        QFXGAT => class_gat%QFXGAT
        QGGAT => class_gat%QGGAT
        ROFGAT => class_gat%ROFGAT
        ROFBGAT => class_gat%ROFBGAT
        ROFCGAT => class_gat%ROFCGAT
        ROFNGAT => class_gat%ROFNGAT
        ROFOGAT => class_gat%ROFOGAT
        ROFSGAT => class_gat%ROFSGAT
        ROVGGAT => class_gat%ROVGGAT
        SFCQGAT => class_gat%SFCQGAT
        SFCTGAT => class_gat%SFCTGAT
        SFCUGAT => class_gat%SFCUGAT
        SFCVGAT => class_gat%SFCVGAT
        TFXGAT => class_gat%TFXGAT
        TROBGAT => class_gat%TROBGAT
        TROFGAT => class_gat%TROFGAT
        TROOGAT => class_gat%TROOGAT
        TROSGAT => class_gat%TROSGAT
        UEGAT => class_gat%UEGAT
        WTABGAT => class_gat%WTABGAT
        WTRCGAT => class_gat%WTRCGAT
        WTRGGAT => class_gat%WTRGGAT
        WTRSGAT => class_gat%WTRSGAT
        QLWOGAT => class_gat%QLWOGAT
        SFRHGAT => class_gat%SFRHGAT
        FTEMP => class_gat%FTEMP
        FVAP => class_gat%FVAP
        RIB => class_gat%RIB
        FC => class_gat%FC
        FG => class_gat%FG
        FCS => class_gat%FCS
        FGS => class_gat%FGS
        RBCOEF => class_gat%RBCOEF
        ZSNOW => class_gat%ZSNOW
        FSVF => class_gat%FSVF
        FSVFS => class_gat%FSVFS
        ALVSCN => class_gat%ALVSCN
        ALIRCN => class_gat%ALIRCN
        ALVSG => class_gat%ALVSG
        ALIRG => class_gat%ALIRG
        ALVSCS => class_gat%ALVSCS
        ALIRCS => class_gat%ALIRCS
        ALVSSN => class_gat%ALVSSN
        ALIRSN => class_gat%ALIRSN
        ALVSGC => class_gat%ALVSGC
        ALIRGC => class_gat%ALIRGC
        ALVSSC => class_gat%ALVSSC
        ALIRSC => class_gat%ALIRSC
        TRVSCN => class_gat%TRVSCN
        TRIRCN => class_gat%TRIRCN
        TRVSCS => class_gat%TRVSCS
        TRIRCS => class_gat%TRIRCS
        RC => class_gat%RC
        RCS => class_gat%RCS
        FRAINC => class_gat%FRAINC
        FSNOWC => class_gat%FSNOWC
        FRAICS => class_gat%FRAICS
        FSNOCS => class_gat%FSNOCS
        CMASSC => class_gat%CMASSC
        CMASCS => class_gat%CMASCS
        DISP => class_gat%DISP
        DISPS => class_gat%DISPS
        ZOMLNC => class_gat%ZOMLNC
        ZOELNC => class_gat%ZOELNC
        ZOMLNG => class_gat%ZOMLNG
        ZOELNG => class_gat%ZOELNG
        ZOMLCS => class_gat%ZOMLCS
        ZOELCS => class_gat%ZOELCS
        ZOMLNS => class_gat%ZOMLNS
        ZOELNS => class_gat%ZOELNS
        TRSNOWC => class_gat%TRSNOWC
        CHCAP => class_gat%CHCAP
        CHCAPS => class_gat%CHCAPS
        GZEROC => class_gat%GZEROC
        GZEROG => class_gat%GZEROG
        GZROCS => class_gat%GZROCS
        GZROGS => class_gat%GZROGS
        G12C => class_gat%G12C
        G12G => class_gat%G12G
        G12CS => class_gat%G12CS
        G12GS => class_gat%G12GS
        G23C => class_gat%G23C
        G23G => class_gat%G23G
        G23CS => class_gat%G23CS
        G23GS => class_gat%G23GS
        QFREZC => class_gat%QFREZC
        QFREZG => class_gat%QFREZG
        QMELTC => class_gat%QMELTC
        QMELTG => class_gat%QMELTG
        EVAPC => class_gat%EVAPC
        EVAPCG => class_gat%EVAPCG
        EVAPG => class_gat%EVAPG
        EVAPCS => class_gat%EVAPCS
        EVPCSG => class_gat%EVPCSG
        EVAPGS => class_gat%EVAPGS
        TCANO => class_gat%TCANO
        TCANS => class_gat%TCANS
        RAICAN => class_gat%RAICAN
        SNOCAN => class_gat%SNOCAN
        RAICNS => class_gat%RAICNS
        SNOCNS => class_gat%SNOCNS
        CWLCAP => class_gat%CWLCAP
        CWFCAP => class_gat%CWFCAP
        CWLCPS => class_gat%CWLCPS
        CWFCPS => class_gat%CWFCPS
        TSNOCS => class_gat%TSNOCS
        TSNOGS => class_gat%TSNOGS
        RHOSCS => class_gat%RHOSCS
        RHOSGS => class_gat%RHOSGS
        WSNOCS => class_gat%WSNOCS
        WSNOGS => class_gat%WSNOGS
        TPONDC => class_gat%TPONDC
        TPONDG => class_gat%TPONDG
        TPNDCS => class_gat%TPNDCS
        TPNDGS => class_gat%TPNDGS
        ZPLMCS => class_gat%ZPLMCS
        ZPLMGS => class_gat%ZPLMGS
        ZPLIMC => class_gat%ZPLIMC
        ZPLIMG => class_gat%ZPLIMG
        CTVSTP => class_gat%CTVSTP
        CTSSTP => class_gat%CTSSTP
        CT1STP => class_gat%CT1STP
        CT2STP => class_gat%CT2STP
        CT3STP => class_gat%CT3STP
        WTVSTP => class_gat%WTVSTP
        WTSSTP => class_gat%WTSSTP
        WTGSTP => class_gat%WTGSTP
        ISNDGAT => class_gat%ISNDGAT
        TBARGAT => class_gat%TBARGAT
        THICGAT => class_gat%THICGAT
        THLQGAT => class_gat%THLQGAT
        BIGAT => class_gat%BIGAT
        DLZWGAT => class_gat%DLZWGAT
        GRKSGAT => class_gat%GRKSGAT
        HCPSGAT => class_gat%HCPSGAT
        PSISGAT => class_gat%PSISGAT
        PSIWGAT => class_gat%PSIWGAT
        TCSGAT => class_gat%TCSGAT
        THFCGAT => class_gat%THFCGAT
        THMGAT => class_gat%THMGAT
        THPGAT => class_gat%THPGAT
        THRGAT => class_gat%THRGAT
        THRAGAT => class_gat%THRAGAT
        ZBTWGAT => class_gat%ZBTWGAT
        THLWGAT => class_gat%THLWGAT
        GFLXGAT => class_gat%GFLXGAT
        HMFGGAT => class_gat%HMFGGAT
        HTCGAT => class_gat%HTCGAT
        QFCGAT => class_gat%QFCGAT
        TBARC => class_gat%TBARC
        TBARG => class_gat%TBARG
        TBARCS => class_gat%TBARCS
        TBARGS => class_gat%TBARGS
        THLIQC => class_gat%THLIQC
        THLIQG => class_gat%THLIQG
        THICEC => class_gat%THICEC
        THICEG => class_gat%THICEG
        FROOT => class_gat%FROOT
        HCPC => class_gat%HCPC
        HCPG => class_gat%HCPG
        FROOTS => class_gat%FROOTS
        TCTOPC => class_gat%TCTOPC
        TCBOTC => class_gat%TCBOTC
        TCTOPG => class_gat%TCTOPG
        TCBOTG => class_gat%TCBOTG
        ACIDGAT => class_gat%ACIDGAT
        ACVDGAT => class_gat%ACVDGAT
        CMASGAT => class_gat%CMASGAT
        HGTDGAT => class_gat%HGTDGAT
        PAIDGAT => class_gat%PAIDGAT
        PAMNGAT => class_gat%PAMNGAT
        PAMXGAT => class_gat%PAMXGAT
        PSGAGAT => class_gat%PSGAGAT
        PSGBGAT => class_gat%PSGBGAT
        QA50GAT => class_gat%QA50GAT
        ROOTGAT => class_gat%ROOTGAT
        RSMNGAT => class_gat%RSMNGAT
        VPDAGAT => class_gat%VPDAGAT
        VPDBGAT => class_gat%VPDBGAT
        ALICGAT => class_gat%ALICGAT
        ALVCGAT => class_gat%ALVCGAT
        FCANGAT => class_gat%FCANGAT
        LNZ0GAT => class_gat%LNZ0GAT
        FSDBGAT => class_gat%FSDBGAT
        FSFBGAT => class_gat%FSFBGAT
        FSSBGAT => class_gat%FSSBGAT
        SALBGAT => class_gat%SALBGAT
        CSALGAT => class_gat%CSALGAT
        ALTG => class_gat%ALTG
        ALSNO => class_gat%ALSNO
        TRSNOWG => class_gat%TRSNOWG
        TSFSGAT => class_gat%TSFSGAT
        ITCTGAT => class_gat%ITCTGAT

        ALIRACC => class_rot%ALIRACC
        ALVSACC => class_rot%ALVSACC
        EVAPACC => class_rot%EVAPACC
        FLINACC => class_rot%FLINACC
        FLUTACC => class_rot%FLUTACC
        FSINACC => class_rot%FSINACC
        GROACC => class_rot%GROACC
        GTACC => class_rot%GTACC
        HFSACC => class_rot%HFSACC
        HMFNACC => class_rot%HMFNACC
        OVRACC => class_rot%OVRACC
        PREACC => class_rot%PREACC
        PRESACC => class_rot%PRESACC
        QAACC => class_rot%QAACC
        QEVPACC => class_rot%QEVPACC
        RCANACC => class_rot%RCANACC
        RHOSACC => class_rot%RHOSACC
        ROFACC => class_rot%ROFACC
        SCANACC => class_rot%SCANACC
        SNOACC => class_rot%SNOACC
        TAACC => class_rot%TAACC
        TCANACC => class_rot%TCANACC
        TSNOACC => class_rot%TSNOACC
        UVACC => class_rot%UVACC
        WSNOACC => class_rot%WSNOACC
        WTBLACC => class_rot%WTBLACC
        ALTOTACC => class_rot%ALTOTACC
        CANARE => class_rot%CANARE
        SNOARE => class_rot%SNOARE
        CSZROW => class_rot%CSZROW
        DLONROW => class_rot%DLONROW
        DLATROW => class_rot%DLATROW
        FCLOROW => class_rot%FCLOROW
        FDLROW => class_rot%FDLROW
        FSIHROW => class_rot%FSIHROW
        FSVHROW => class_rot%FSVHROW
        GCROW => class_rot%GCROW
        GGEOROW => class_rot%GGEOROW
        PADRROW => class_rot%PADRROW
        PREROW => class_rot%PREROW
        PRESROW => class_rot%PRESROW
        QAROW => class_rot%QAROW
        RADJROW => class_rot%RADJROW
        RHOAROW => class_rot%RHOAROW
        RHSIROW => class_rot%RHSIROW
        RPCPROW => class_rot%RPCPROW
        RPREROW => class_rot%RPREROW
        SPCPROW => class_rot%SPCPROW
        SPREROW => class_rot%SPREROW
        TAROW => class_rot%TAROW
        TADPROW => class_rot%TADPROW
        TRPCROW => class_rot%TRPCROW
        TSPCROW => class_rot%TSPCROW
        ULROW => class_rot%ULROW
        VLROW => class_rot%VLROW
        VMODROW => class_rot%VMODROW
        VPDROW => class_rot%VPDROW
        ZBLDROW => class_rot%ZBLDROW
        ZDHROW => class_rot%ZDHROW
        ZDMROW => class_rot%ZDMROW
        ZRFHROW => class_rot%ZRFHROW
        ZRFMROW => class_rot%ZRFMROW
        UVROW => class_rot%UVROW
        XDIFFUS => class_rot%XDIFFUS
        Z0ORROW => class_rot%Z0ORROW
        FSSROW => class_rot%FSSROW
        PRENROW => class_rot%PRENROW
        CLDTROW => class_rot%CLDTROW
        FSGROL => class_rot%FSGROL
        FLGROL => class_rot%FLGROL
        GUSTROL => class_rot%GUSTROL
        DEPBROW => class_rot%DEPBROW
        ALIRROW => class_rot%ALIRROW
        ALVSROW => class_rot%ALVSROW
        CDHROW => class_rot%CDHROW
        CDMROW => class_rot%CDMROW
        DRROW => class_rot%DRROW
        EFROW => class_rot%EFROW
        FLGGROW => class_rot%FLGGROW
        FLGSROW => class_rot%FLGSROW
        FLGVROW => class_rot%FLGVROW
        FSGGROW => class_rot%FSGGROW
        FSGSROW => class_rot%FSGSROW
        FSGVROW => class_rot%FSGVROW
        FSNOROW => class_rot%FSNOROW
        GAROW => class_rot%GAROW
        GTROW => class_rot%GTROW
        HBLROW => class_rot%HBLROW
        HEVCROW => class_rot%HEVCROW
        HEVGROW => class_rot%HEVGROW
        HEVSROW => class_rot%HEVSROW
        HFSROW => class_rot%HFSROW
        HFSCROW => class_rot%HFSCROW
        HFSGROW => class_rot%HFSGROW
        HFSSROW => class_rot%HFSSROW
        HMFCROW => class_rot%HMFCROW
        HMFNROW => class_rot%HMFNROW
        HTCCROW => class_rot%HTCCROW
        HTCSROW => class_rot%HTCSROW
        ILMOROW => class_rot%ILMOROW
        PCFCROW => class_rot%PCFCROW
        PCLCROW => class_rot%PCLCROW
        PCPGROW => class_rot%PCPGROW
        PCPNROW => class_rot%PCPNROW
        PETROW => class_rot%PETROW
        QEVPROW => class_rot%QEVPROW
        QFCFROW => class_rot%QFCFROW
        QFCLROW => class_rot%QFCLROW
        QFGROW => class_rot%QFGROW
        QFNROW => class_rot%QFNROW
        QFSROW => class_rot%QFSROW
        QFXROW => class_rot%QFXROW
        QGROW => class_rot%QGROW
        ROFROW => class_rot%ROFROW
        ROFBROW => class_rot%ROFBROW
        ROFCROW => class_rot%ROFCROW
        ROFNROW => class_rot%ROFNROW
        ROFOROW => class_rot%ROFOROW
        ROFSROW => class_rot%ROFSROW
        ROVGROW => class_rot%ROVGROW
        SFCQROW => class_rot%SFCQROW
        SFCTROW => class_rot%SFCTROW
        SFCUROW => class_rot%SFCUROW
        SFCVROW => class_rot%SFCVROW
        TFXROW => class_rot%TFXROW
        UEROW => class_rot%UEROW
        WTABROW => class_rot%WTABROW
        WTRCROW => class_rot%WTRCROW
        WTRGROW => class_rot%WTRGROW
        WTRSROW => class_rot%WTRSROW
        SFRHROW => class_rot%SFRHROW
        IGDRROT => class_rot%IGDRROT
        MIDROT => class_rot%MIDROT
        ALBSROT => class_rot%ALBSROT
        CMAIROT => class_rot%CMAIROT
        GROROT => class_rot%GROROT
        QACROT => class_rot%QACROT
        RCANROT => class_rot%RCANROT
        RHOSROT => class_rot%RHOSROT
        SCANROT => class_rot%SCANROT
        SNOROT => class_rot%SNOROT
        TACROT => class_rot%TACROT
        TBASROT => class_rot%TBASROT
        TCANROT => class_rot%TCANROT
        TPNDROT => class_rot%TPNDROT
        TSNOROT => class_rot%TSNOROT
        WSNOROT => class_rot%WSNOROT
        ZPNDROT => class_rot%ZPNDROT
        REFROT => class_rot%REFROT
        BCSNROT => class_rot%BCSNROT
        AGIDROT => class_rot%AGIDROT
        AGVDROT => class_rot%AGVDROT
        ALGDROT => class_rot%ALGDROT
        ALGWROT => class_rot%ALGWROT
        ASIDROT => class_rot%ASIDROT
        ASVDROT => class_rot%ASVDROT
        DRNROT => class_rot%DRNROT
        FAREROT => class_rot%FAREROT
        GRKFROT => class_rot%GRKFROT
        WFCIROT => class_rot%WFCIROT
        WFSFROT => class_rot%WFSFROT
        XSLPROT => class_rot%XSLPROT
        ZPLGROT => class_rot%ZPLGROT
        ZPLSROT => class_rot%ZPLSROT
        ZSNLROT => class_rot%ZSNLROT
        ZSNOROT => class_rot%ZSNOROT
        ALGWVROT => class_rot%ALGWVROT
        ALGWNROT => class_rot%ALGWNROT
        ALGDVROT => class_rot%ALGDVROT
        ALGDNROT => class_rot%ALGDNROT
        EMISROT => class_rot%EMISROT
        ALIRROT => class_rot%ALIRROT
        ALVSROT => class_rot%ALVSROT
        CDHROT => class_rot%CDHROT
        CDMROT => class_rot%CDMROT
        DRROT => class_rot%DRROT
        EFROT => class_rot%EFROT
        FLGGROT => class_rot%FLGGROT
        FLGSROT => class_rot%FLGSROT
        FLGVROT => class_rot%FLGVROT
        FSGGROT => class_rot%FSGGROT
        FSGSROT => class_rot%FSGSROT
        FSGVROT => class_rot%FSGVROT
        FSNOROT => class_rot%FSNOROT
        GAROT => class_rot%GAROT
        GTROT => class_rot%GTROT
        HBLROT => class_rot%HBLROT
        HEVCROT => class_rot%HEVCROT
        HEVGROT => class_rot%HEVGROT
        HEVSROT => class_rot%HEVSROT
        HFSROT => class_rot%HFSROT
        HFSCROT => class_rot%HFSCROT
        HFSGROT => class_rot%HFSGROT
        HFSSROT => class_rot%HFSSROT
        HMFCROT => class_rot%HMFCROT
        HMFNROT => class_rot%HMFNROT
        HTCCROT => class_rot%HTCCROT
        SDEPROT => class_rot%SDEPROT
        SOCIROT => class_rot%SOCIROT
        HTCSROT => class_rot%HTCSROT
        ILMOROT => class_rot%ILMOROT
        PCFCROT => class_rot%PCFCROT
        PCLCROT => class_rot%PCLCROT
        PCPGROT => class_rot%PCPGROT
        PCPNROT => class_rot%PCPNROT
        PETROT => class_rot%PETROT
        QEVPROT => class_rot%QEVPROT
        QFCFROT => class_rot%QFCFROT
        QFCLROT => class_rot%QFCLROT
        QFGROT => class_rot%QFGROT
        QFNROT => class_rot%QFNROT
        QFSROT => class_rot%QFSROT
        QFXROT => class_rot%QFXROT
        QGROT => class_rot%QGROT
        ROFROT => class_rot%ROFROT
        ROFBROT => class_rot%ROFBROT
        ROFCROT => class_rot%ROFCROT
        ROFNROT => class_rot%ROFNROT
        ROFOROT => class_rot%ROFOROT
        ROFSROT => class_rot%ROFSROT
        ROVGROT => class_rot%ROVGROT
        SFCQROT => class_rot%SFCQROT
        SFCTROT => class_rot%SFCTROT
        SFCUROT => class_rot%SFCUROT
        SFCVROT => class_rot%SFCVROT
        TFXROT => class_rot%TFXROT
        TROBROT => class_rot%TROBROT
        TROFROT => class_rot%TROFROT
        TROOROT => class_rot%TROOROT
        TROSROT => class_rot%TROSROT
        UEROT => class_rot%UEROT
        WTABROT => class_rot%WTABROT
        WTRCROT => class_rot%WTRCROT
        WTRGROT => class_rot%WTRGROT
        WTRSROT => class_rot%WTRSROT
        SFRHROT => class_rot%SFRHROT
        ISNDROT => class_rot%ISNDROT
        TBARROT => class_rot%TBARROT
        THICROT => class_rot%THICROT
        THLQROT => class_rot%THLQROT
        BIROT => class_rot%BIROT
        DLZWROT => class_rot%DLZWROT
        GRKSROT => class_rot%GRKSROT
        HCPSROT => class_rot%HCPSROT
        SANDROT => class_rot%SANDROT
        CLAYROT => class_rot%CLAYROT
        ORGMROT => class_rot%ORGMROT
        PSISROT => class_rot%PSISROT
        PSIWROT => class_rot%PSIWROT
        TCSROT => class_rot%TCSROT
        THFCROT => class_rot%THFCROT
        THMROT => class_rot%THMROT
        THPROT => class_rot%THPROT
        THRROT => class_rot%THRROT
        THRAROT => class_rot%THRAROT
        ZBTWROT => class_rot%ZBTWROT
        THLWROT => class_rot%THLWROT
        GFLXROT => class_rot%GFLXROT
        HMFGROT => class_rot%HMFGROT
        HTCROT => class_rot%HTCROT
        QFCROT => class_rot%QFCROT
        ACIDROT => class_rot%ACIDROT
        ACVDROT => class_rot%ACVDROT
        CMASROT => class_rot%CMASROT
        HGTDROT => class_rot%HGTDROT
        PAIDROT => class_rot%PAIDROT
        PAMNROT => class_rot%PAMNROT
        PAMXROT => class_rot%PAMXROT
        PSGAROT => class_rot%PSGAROT
        PSGBROT => class_rot%PSGBROT
        QA50ROT => class_rot%QA50ROT
        ROOTROT => class_rot%ROOTROT
        RSMNROT => class_rot%RSMNROT
        VPDAROT => class_rot%VPDAROT
        VPDBROT => class_rot%VPDBROT
        ALICROT => class_rot%ALICROT
        ALVCROT => class_rot%ALVCROT
        FCANROT => class_rot%FCANROT
        LNZ0ROT => class_rot%LNZ0ROT
        SALBROT => class_rot%SALBROT
        CSALROT => class_rot%CSALROT
        FSDBROL => class_rot%FSDBROL
        FSFBROL => class_rot%FSFBROL
        FSSBROL => class_rot%FSSBROL
        TBARACC => class_rot%TBARACC
        THALACC => class_rot%THALACC
        THICACC => class_rot%THICACC
        THLQACC => class_rot%THLQACC
        GFLXROW => class_rot%GFLXROW
        HMFGROW => class_rot%HMFGROW
        HTCROW => class_rot%HTCROW
        QFCROW => class_rot%QFCROW
        ITCTROT => class_rot%ITCTROT
        TSFSROT => class_rot%TSFSROT

        ! Point CTEM pointers

        ctem_on           => c_switch%ctem_on
        parallelrun       => c_switch%parallelrun
        cyclemet          => c_switch%cyclemet
        dofire            => c_switch%dofire
        run_model         => c_switch%run_model
        met_rewound       => c_switch%met_rewound
        reach_eof         => c_switch%reach_eof
        compete           => c_switch%compete
        start_bare        => c_switch%start_bare
        rsfile            => c_switch%rsfile
        lnduseon          => c_switch%lnduseon
        co2on             => c_switch%co2on
        ch4on             => c_switch%ch4on
        popdon            => c_switch%popdon
        inibioclim        => c_switch%inibioclim
        dowetlands        => c_switch%dowetlands
        obswetf           => c_switch%obswetf
        transient_run     => c_switch%transient_run
        use_netcdf        => c_switch%use_netcdf
        met_file          => c_switch%met_file
        init_file         => c_switch%init_file

        tcanrs            => vrot%tcanrs
        tsnors            => vrot%tsnors
        tpndrs            => vrot%tpndrs
        csum              => vrot%csum
        tbaraccrow_m      => vrot%tbaraccrow_m
        tcanoaccrow_m     => vrot%tcanoaccrow_m
        uvaccrow_m        => vrot%uvaccrow_m
        vvaccrow_m        => vrot%vvaccrow_m

        ! ROW:
        ailcminrow        => vrot%ailcmin
        ailcmaxrow        => vrot%ailcmax
        dvdfcanrow        => vrot%dvdfcan
        gleafmasrow       => vrot%gleafmas
        bleafmasrow       => vrot%bleafmas
        stemmassrow       => vrot%stemmass
        rootmassrow       => vrot%rootmass
        pstemmassrow      => vrot%pstemmass
        pgleafmassrow     => vrot%pgleafmass
        fcancmxrow        => vrot%fcancmx
        gavglairow        => vrot%gavglai
        zolncrow          => vrot%zolnc
        ailcrow           => vrot%ailc
        ailcgrow          => vrot%ailcg
        ailcgsrow         => vrot%ailcgs
        fcancsrow         => vrot%fcancs
        fcancrow          => vrot%fcanc
        co2concrow        => vrot%co2conc
        ch4concrow        => vrot%ch4conc
        co2i1cgrow        => vrot%co2i1cg
        co2i1csrow        => vrot%co2i1cs
        co2i2cgrow        => vrot%co2i2cg
        co2i2csrow        => vrot%co2i2cs
        ancsvegrow        => vrot%ancsveg
        ancgvegrow        => vrot%ancgveg
        rmlcsvegrow       => vrot%rmlcsveg
        rmlcgvegrow       => vrot%rmlcgveg
        slairow           => vrot%slai
        ailcbrow          => vrot%ailcb
        canresrow         => vrot%canres
        flhrlossrow       => vrot%flhrloss

        tcanoaccrow_out   => vrot%tcanoaccrow_out
        qevpacc_m_save    => vrot%qevpacc_m_save

        grwtheffrow       => vrot%grwtheff
        lystmmasrow       => vrot%lystmmas
        lyrotmasrow       => vrot%lyrotmas
        tymaxlairow       => vrot%tymaxlai
        vgbiomasrow       => vrot%vgbiomas
        gavgltmsrow       => vrot%gavgltms
        gavgscmsrow       => vrot%gavgscms
        stmhrlosrow       => vrot%stmhrlos
        rmatcrow          => vrot%rmatc
        rmatctemrow       => vrot%rmatctem
        litrmassrow       => vrot%litrmass
        soilcmasrow       => vrot%soilcmas
        vgbiomas_vegrow   => vrot%vgbiomas_veg

        emit_co2row       => vrot%emit_co2
        emit_corow        => vrot%emit_co
        emit_ch4row       => vrot%emit_ch4
        emit_nmhcrow      => vrot%emit_nmhc
        emit_h2row        => vrot%emit_h2
        emit_noxrow       => vrot%emit_nox
        emit_n2orow       => vrot%emit_n2o
        emit_pm25row      => vrot%emit_pm25
        emit_tpmrow       => vrot%emit_tpm
        emit_tcrow        => vrot%emit_tc
        emit_ocrow        => vrot%emit_oc
        emit_bcrow        => vrot%emit_bc
        burnfracrow       => vrot%burnfrac
        burnvegfrow       => vrot%burnvegf
        smfuncvegrow      => vrot%smfuncveg
        popdinrow         => vrot%popdin
        btermrow          => vrot%bterm
        ltermrow          => vrot%lterm
        mtermrow          => vrot%mterm

        extnprobrow       => vrot%extnprob
        prbfrhucrow       => vrot%prbfrhuc
        mlightngrow       => vrot%mlightng
        daylrow           => vrot%dayl
        dayl_maxrow       => vrot%dayl_max

        bmasvegrow        => vrot%bmasveg
        cmasvegcrow       => vrot%cmasvegc
        veghghtrow        => vrot%veghght
        rootdpthrow       => vrot%rootdpth
        rmlrow            => vrot%rml
        rmsrow            => vrot%rms
        tltrleafrow       => vrot%tltrleaf
        tltrstemrow       => vrot%tltrstem
        tltrrootrow       => vrot%tltrroot
        leaflitrrow       => vrot%leaflitr
        roottemprow       => vrot%roottemp
        afrleafrow        => vrot%afrleaf
        afrstemrow        => vrot%afrstem
        afrrootrow        => vrot%afrroot
        wtstatusrow       => vrot%wtstatus
        ltstatusrow       => vrot%ltstatus
        rmrrow            => vrot%rmr

        slopefracrow      => vrot%slopefrac
        ch4wet1row        => vrot%ch4wet1
        ch4wet2row        => vrot%ch4wet2
        wetfdynrow        => vrot%wetfdyn
        ch4dyn1row        => vrot%ch4dyn1
        ch4dyn2row        => vrot%ch4dyn2
        wetfrac_monrow    => vrot%wetfrac_mon
        ch4soillsrow      => vrot%ch4_soills

        lucemcomrow       => vrot%lucemcom
        lucltrinrow       => vrot%lucltrin
        lucsocinrow       => vrot%lucsocin

        npprow            => vrot%npp
        neprow            => vrot%nep
        nbprow            => vrot%nbp
        gpprow            => vrot%gpp
        hetroresrow       => vrot%hetrores
        autoresrow        => vrot%autores
        soilcresprow      => vrot%soilcresp
        rmrow             => vrot%rm
        rgrow             => vrot%rg
        litresrow         => vrot%litres
        socresrow         => vrot%socres
        dstcemlsrow       => vrot%dstcemls
        litrfallrow       => vrot%litrfall
        humiftrsrow       => vrot%humiftrs

        gppvegrow         => vrot%gppveg
        nepvegrow         => vrot%nepveg
        nbpvegrow         => vrot%nbpveg
        nppvegrow         => vrot%nppveg
        hetroresvegrow    => vrot%hetroresveg
        autoresvegrow     => vrot%autoresveg
        litresvegrow      => vrot%litresveg
        soilcresvegrow    => vrot%soilcresveg
        rmlvegaccrow      => vrot%rmlvegacc
        rmsvegrow         => vrot%rmsveg
        rmrvegrow         => vrot%rmrveg
        rgvegrow          => vrot%rgveg
        litrfallvegrow    => vrot%litrfallveg
        humiftrsvegrow    => vrot%humiftrsveg

        rothrlosrow       => vrot%rothrlos
        pfcancmxrow       => vrot%pfcancmx
        nfcancmxrow       => vrot%nfcancmx
        alvsctmrow        => vrot%alvsctm
        paicrow           => vrot%paic
        slaicrow          => vrot%slaic
        alirctmrow        => vrot%alirctm
        cfluxcgrow        => vrot%cfluxcg
        cfluxcsrow        => vrot%cfluxcs
        dstcemls3row      => vrot%dstcemls3
        anvegrow          => vrot%anveg
        rmlvegrow         => vrot%rmlveg

        pftexistrow       => vrot%pftexist
        colddaysrow       => vrot%colddays
        icountrow         => vrot%icount
        lfstatusrow       => vrot%lfstatus
        pandaysrow        => vrot%pandays
        stdalnrow         => vrot%stdaln

        twarmmrow            => vrot%twarmm
        tcoldmrow            => vrot%tcoldm
        gdd5row              => vrot%gdd5
        aridityrow           => vrot%aridity
        srplsmonrow          => vrot%srplsmon
        defctmonrow          => vrot%defctmon
        anndefctrow          => vrot%anndefct
        annsrplsrow          => vrot%annsrpls
        annpcprow            => vrot%annpcp
        dry_season_lengthrow => vrot%dry_season_length

        altotcntr_d       => vrot%altotcntr_d

        ! >>>>>>>>>>>>>>>>>>>>>>>>>>
        ! GAT:

        grclarea          => vgat%grclarea
        lightng           => vgat%lightng
        tcanoaccgat_out   => vgat%tcanoaccgat_out

        ailcmingat        => vgat%ailcmin
        ailcmaxgat        => vgat%ailcmax
        dvdfcangat        => vgat%dvdfcan
        gleafmasgat       => vgat%gleafmas
        bleafmasgat       => vgat%bleafmas
        stemmassgat       => vgat%stemmass
        rootmassgat       => vgat%rootmass
        pstemmassgat      => vgat%pstemmass
        pgleafmassgat     => vgat%pgleafmass
        fcancmxgat        => vgat%fcancmx
        gavglaigat        => vgat%gavglai
        zolncgat          => vgat%zolnc
        ailcgat           => vgat%ailc
        ailcggat          => vgat%ailcg
        ailcgsgat         => vgat%ailcgs
        fcancsgat         => vgat%fcancs
        fcancgat          => vgat%fcanc
        co2concgat        => vgat%co2conc
        ch4concgat        => vgat%ch4conc
        co2i1cggat        => vgat%co2i1cg
        co2i1csgat        => vgat%co2i1cs
        co2i2cggat        => vgat%co2i2cg
        co2i2csgat        => vgat%co2i2cs
        ancsveggat        => vgat%ancsveg
        ancgveggat        => vgat%ancgveg
        rmlcsveggat       => vgat%rmlcsveg
        rmlcgveggat       => vgat%rmlcgveg
        slaigat           => vgat%slai
        ailcbgat          => vgat%ailcb
        canresgat         => vgat%canres
        flhrlossgat       => vgat%flhrloss

        grwtheffgat       => vgat%grwtheff
        lystmmasgat       => vgat%lystmmas
        lyrotmasgat       => vgat%lyrotmas
        tymaxlaigat       => vgat%tymaxlai
        vgbiomasgat       => vgat%vgbiomas
        gavgltmsgat       => vgat%gavgltms
        gavgscmsgat       => vgat%gavgscms
        stmhrlosgat       => vgat%stmhrlos
        rmatcgat          => vgat%rmatc
        rmatctemgat       => vgat%rmatctem
        litrmassgat       => vgat%litrmass
        soilcmasgat       => vgat%soilcmas
        vgbiomas_veggat   => vgat%vgbiomas_veg
        litrfallveggat    => vgat%litrfallveg
        humiftrsveggat    => vgat%humiftrsveg

        emit_co2gat       => vgat%emit_co2
        emit_cogat        => vgat%emit_co
        emit_ch4gat       => vgat%emit_ch4
        emit_nmhcgat      => vgat%emit_nmhc
        emit_h2gat        => vgat%emit_h2
        emit_noxgat       => vgat%emit_nox
        emit_n2ogat       => vgat%emit_n2o
        emit_pm25gat      => vgat%emit_pm25
        emit_tpmgat       => vgat%emit_tpm
        emit_tcgat        => vgat%emit_tc
        emit_ocgat        => vgat%emit_oc
        emit_bcgat        => vgat%emit_bc
        burnfracgat       => vgat%burnfrac
        burnvegfgat       => vgat%burnvegf
        popdingat         => vgat%popdin
        smfuncveggat      => vgat%smfuncveg
        btermgat          => vgat%bterm
        ltermgat          => vgat%lterm
        mtermgat          => vgat%mterm

        extnprobgat       => vgat%extnprob
        prbfrhucgat       => vgat%prbfrhuc
        mlightnggat       => vgat%mlightng
        daylgat           => vgat%dayl
        dayl_maxgat       => vgat%dayl_max

        bmasveggat        => vgat%bmasveg
        cmasvegcgat       => vgat%cmasvegc
        veghghtgat        => vgat%veghght
        rootdpthgat       => vgat%rootdpth
        rmlgat            => vgat%rml
        rmsgat            => vgat%rms
        tltrleafgat       => vgat%tltrleaf
        tltrstemgat       => vgat%tltrstem
        tltrrootgat       => vgat%tltrroot
        leaflitrgat       => vgat%leaflitr
        roottempgat       => vgat%roottemp
        afrleafgat        => vgat%afrleaf
        afrstemgat        => vgat%afrstem
        afrrootgat        => vgat%afrroot
        wtstatusgat       => vgat%wtstatus
        ltstatusgat       => vgat%ltstatus
        rmrgat            => vgat%rmr

        slopefracgat      => vgat%slopefrac
        wetfrac_presgat   => vgat%wetfrac_pres
        wetfrac_mongat    => vgat%wetfrac_mon
        ch4wet1gat        => vgat%ch4wet1
        ch4wet2gat        => vgat%ch4wet2
        wetfdyngat        => vgat%wetfdyn
        ch4dyn1gat        => vgat%ch4dyn1
        ch4dyn2gat        => vgat%ch4dyn2
        ch4soillsgat      => vgat%ch4_soills

        lucemcomgat       => vgat%lucemcom
        lucltringat       => vgat%lucltrin
        lucsocingat       => vgat%lucsocin

        nppgat            => vgat%npp
        nepgat            => vgat%nep
        nbpgat            => vgat%nbp
        gppgat            => vgat%gpp
        hetroresgat       => vgat%hetrores
        autoresgat        => vgat%autores
        soilcrespgat      => vgat%soilcresp
        rmgat             => vgat%rm
        rggat             => vgat%rg
        litresgat         => vgat%litres
        socresgat         => vgat%socres
        dstcemlsgat       => vgat%dstcemls
        litrfallgat       => vgat%litrfall
        humiftrsgat       => vgat%humiftrs

        gppveggat         => vgat%gppveg
        nepveggat         => vgat%nepveg
        nbpveggat         => vgat%nbpveg
        nppveggat         => vgat%nppveg
        hetroresveggat    => vgat%hetroresveg
        autoresveggat     => vgat%autoresveg
        litresveggat      => vgat%litresveg
        soilcresveggat    => vgat%soilcresveg
        rmlvegaccgat      => vgat%rmlvegacc
        rmsveggat         => vgat%rmsveg
        rmrveggat         => vgat%rmrveg
        rgveggat          => vgat%rgveg

        rothrlosgat       => vgat%rothrlos
        pfcancmxgat       => vgat%pfcancmx
        nfcancmxgat       => vgat%nfcancmx
        alvsctmgat        => vgat%alvsctm
        paicgat           => vgat%paic
        slaicgat          => vgat%slaic
        alirctmgat        => vgat%alirctm
        cfluxcggat        => vgat%cfluxcg
        cfluxcsgat        => vgat%cfluxcs
        dstcemls3gat      => vgat%dstcemls3
        anveggat          => vgat%anveg
        rmlveggat         => vgat%rmlveg

        twarmmgat            => vgat%twarmm
        tcoldmgat            => vgat%tcoldm
        gdd5gat              => vgat%gdd5
        ariditygat           => vgat%aridity
        srplsmongat          => vgat%srplsmon
        defctmongat          => vgat%defctmon
        anndefctgat          => vgat%anndefct
        annsrplsgat          => vgat%annsrpls
        annpcpgat            => vgat%annpcp
        dry_season_lengthgat => vgat%dry_season_length

        tcurm             => vgat%tcurm
        srpcuryr          => vgat%srpcuryr
        dftcuryr          => vgat%dftcuryr
        tmonth            => vgat%tmonth
        anpcpcur          => vgat%anpcpcur
        anpecur           => vgat%anpecur
        gdd5cur           => vgat%gdd5cur
        surmncur          => vgat%surmncur
        defmncur          => vgat%defmncur
        srplscur          => vgat%srplscur
        defctcur          => vgat%defctcur

        geremortgat       => vgat%geremort
        intrmortgat       => vgat%intrmort
        lambdagat         => vgat%lambda
        ccgat             => vgat%cc
        mmgat             => vgat%mm

        pftexistgat       => vgat%pftexist
        colddaysgat       => vgat%colddays
        icountgat         => vgat%icount
        lfstatusgat       => vgat%lfstatus
        pandaysgat        => vgat%pandays
        stdalngat         => vgat%stdaln

        ! Mosaic-level (CLASS vars):

        PREACC_M          => vrot%PREACC_M
        GTACC_M           => vrot%GTACC_M
        QEVPACC_M         => vrot%QEVPACC_M
        HFSACC_M          => vrot%HFSACC_M
        HMFNACC_M         => vrot%HMFNACC_M
        ROFACC_M          => vrot%ROFACC_M
        SNOACC_M          => vrot%SNOACC_M
        OVRACC_M          => vrot%OVRACC_M
        WTBLACC_M         => vrot%WTBLACC_M
        TBARACC_M         => vrot%TBARACC_M
        THLQACC_M         => vrot%THLQACC_M
        THICACC_M         => vrot%THICACC_M
        THALACC_M         => vrot%THALACC_M
        ALVSACC_M         => vrot%ALVSACC_M
        ALIRACC_M         => vrot%ALIRACC_M
        RHOSACC_M         => vrot%RHOSACC_M
        TSNOACC_M         => vrot%TSNOACC_M
        WSNOACC_M         => vrot%WSNOACC_M
        SNOARE_M          => vrot%SNOARE_M
        TCANACC_M         => vrot%TCANACC_M
        RCANACC_M         => vrot%RCANACC_M
        SCANACC_M         => vrot%SCANACC_M
        GROACC_M          => vrot%GROACC_M
        FSINACC_M         => vrot%FSINACC_M
        FLINACC_M         => vrot%FLINACC_M
        TAACC_M           => vrot%TAACC_M
        UVACC_M           => vrot%UVACC_M
        PRESACC_M         => vrot%PRESACC_M
        QAACC_M           => vrot%QAACC_M
        ALTOTACC_M        => vrot%ALTOTACC_M
        EVAPACC_M         => vrot%EVAPACC_M
        FLUTACC_M         => vrot%FLUTACC_M

        ! grid-averaged (CLASS vars)

        ! Allocate the ctem structure ctem_grd
        !allocate(ctem_grd)

        WSNOROT_g         => ctem_grd%WSNOROT_g
        ROFSROT_g         => ctem_grd%ROFSROT_g
        SNOROT_g          => ctem_grd%SNOROT_g
        RHOSROT_g         => ctem_grd%RHOSROT_g
        ROFROT_g          => ctem_grd%ROFROT_g
        ZPNDROT_g         => ctem_grd%ZPNDROT_g
        RCANROT_g         => ctem_grd%RCANROT_g
        SCANROT_g         => ctem_grd%SCANROT_g
        TROFROT_g         => ctem_grd%TROFROT_g
        TROOROT_g         => ctem_grd%TROOROT_g
        TROBROT_g         => ctem_grd%TROBROT_g
        ROFOROT_g         => ctem_grd%ROFOROT_g
        ROFBROT_g         => ctem_grd%ROFBROT_g
        TROSROT_g         => ctem_grd%TROSROT_g
        FSGVROT_g         => ctem_grd%FSGVROT_g
        FSGSROT_g         => ctem_grd%FSGSROT_g
        FLGVROT_g         => ctem_grd%FLGVROT_g
        FLGSROT_g         => ctem_grd%FLGSROT_g
        HFSCROT_g         => ctem_grd%HFSCROT_g
        HFSSROT_g         => ctem_grd%HFSSROT_g
        HEVCROT_g         => ctem_grd%HEVCROT_g
        HEVSROT_g         => ctem_grd%HEVSROT_g
        HMFCROT_g         => ctem_grd%HMFCROT_g
        HMFNROT_g         => ctem_grd%HMFNROT_g
        HTCSROT_g         => ctem_grd%HTCSROT_g
        HTCCROT_g         => ctem_grd%HTCCROT_g
        FSGGROT_g         => ctem_grd%FSGGROT_g
        FLGGROT_g         => ctem_grd%FLGGROT_g
        HFSGROT_g         => ctem_grd%HFSGROT_g
        HEVGROT_g         => ctem_grd%HEVGROT_g
        CDHROT_g          => ctem_grd%CDHROT_g
        CDMROT_g          => ctem_grd%CDMROT_g
        SFCUROT_g         => ctem_grd%SFCUROT_g
        SFCVROT_g         => ctem_grd%SFCVROT_g
        ACTLYR_g          => ctem_grd%ACTLYR_g
        FTABLE_g          => ctem_grd%FTABLE_g
        fc_g              => ctem_grd%fc_g
        fg_g              => ctem_grd%fg_g
        fcs_g             => ctem_grd%fcs_g
        fgs_g             => ctem_grd%fgs_g
        PCFCROT_g         => ctem_grd%PCFCROT_g
        PCLCROT_g         => ctem_grd%PCLCROT_g
        PCPGROT_g         => ctem_grd%PCPGROT_g
        QFCFROT_g         => ctem_grd%QFCFROT_g
        QFGROT_g          => ctem_grd%QFGROT_g
        QFCROT_g          => ctem_grd%QFCROT_g
        ROFCROT_g         => ctem_grd%ROFCROT_g
        ROFNROT_g         => ctem_grd%ROFNROT_g
        WTRSROT_g         => ctem_grd%WTRSROT_g
        WTRGROT_g         => ctem_grd%WTRGROT_g
        PCPNROT_g         => ctem_grd%PCPNROT_g
        QFCLROT_g         => ctem_grd%QFCLROT_g
        QFNROT_g          => ctem_grd%QFNROT_g
        WTRCROT_g         => ctem_grd%WTRCROT_g
        rmlvegrow_g       => ctem_grd%rmlvegrow_g
        anvegrow_g        => ctem_grd%anvegrow_g
        HMFGROT_g         => ctem_grd%HMFGROT_g
        HTCROT_g          => ctem_grd%HTCROT_g
        TBARROT_g         => ctem_grd%TBARROT_g
        THLQROT_g         => ctem_grd%THLQROT_g
        THICROT_g         => ctem_grd%THICROT_g
        GFLXROT_g         => ctem_grd%GFLXROT_g

        fsstar_g         => ctem_grd%fsstar_g
        flstar_g         => ctem_grd%flstar_g
        qh_g             => ctem_grd%qh_g
        qe_g             => ctem_grd%qe_g
        snomlt_g         => ctem_grd%snomlt_g
        beg_g            => ctem_grd%beg_g
        gtout_g          => ctem_grd%gtout_g
        tpn_g            => ctem_grd%tpn_g
        altot_g          => ctem_grd%altot_g
        tcn_g            => ctem_grd%tcn_g
        tsn_g            => ctem_grd%tsn_g
        zsn_g            => ctem_grd%zsn_g

        ! mosaic level variables (CLASS):

        ! Allocate the ctem structure ctem_tile
        !allocate(ctem_tile)

        fsnowacc_t        => ctem_tile%fsnowacc_t
        tcansacc_t        => ctem_tile%tcansacc_t
        tcanoaccgat_t     => ctem_tile%tcanoaccgat_t
        taaccgat_t        => ctem_tile%taaccgat_t
        uvaccgat_t        => ctem_tile%uvaccgat_t
        vvaccgat_t        => ctem_tile%vvaccgat_t
        tbaraccgat_t      => ctem_tile%tbaraccgat_t
        tbarcacc_t        => ctem_tile%tbarcacc_t
        tbarcsacc_t       => ctem_tile%tbarcsacc_t
        tbargacc_t        => ctem_tile%tbargacc_t
        tbargsacc_t       => ctem_tile%tbargsacc_t
        thliqcacc_t       => ctem_tile%thliqcacc_t
        thliqgacc_t       => ctem_tile%thliqgacc_t
        thliqacc_t        => ctem_tile%thliqacc_t
        thicecacc_t       => ctem_tile%thicecacc_t
        thicegacc_t       => ctem_tile%thicegacc_t
        ancsvgac_t        => ctem_tile%ancsvgac_t
        ancgvgac_t        => ctem_tile%ancgvgac_t
        rmlcsvga_t        => ctem_tile%rmlcsvga_t
        rmlcgvga_t        => ctem_tile%rmlcgvga_t

        !    =================================================================================
        !    =================================================================================

        ! Put the lat and long arguments that were passed from the main
        ! program into the row structure.
        DLATROW(1) = latitude
        JLAT=NINT(DLATROW(1))
        DLONROW(1) = longitude

        ! Prepare CLASS parameters
        CALL CLASSD

        ! Initialize the CTEM parameters, this reads them in from a namelist file.
        call readin_params(compete)

        ! Allocate the local variables that rely on nlat, ilg, etc.
        allocate(curlatno(ilg),&
            altotcount_ctm(nlat),&
            todfrac(ilg,icc),&
            barf(nlat,nmos),&
            currlat(ilg),&
            fsinacc_gat(ilg),&
            flutacc_gat(ilg),&
            flinacc_gat(ilg),&
            alswacc_gat(ilg),&
            allwacc_gat(ilg),&
            pregacc_gat(ilg),&
            altotacc_gat(ilg),&
            netrad_gat(ilg),&
            preacc_gat(ilg),&
            sdepgat(ilg),&
            rgmgat(ilg,ignd),&
            sandgat(ilg,ignd),&
            claygat(ilg,ignd),&
            orgmgat(ilg,ignd),&
            xdiffusgat(ilg),& ! the corresponding ROW is CLASS's XDIFFUS
            faregat(ilg),&    ! the ROT is FAREROT
            FTABLE(nlat,nmos),&
            ACTLYR(nlat,nmos))

        !>    Read in the initial model conditions from the restart file
        !!    (replacing the INI and CTM files).
        call read_initialstate()

        print *,'after readinitialstate'

        ! #ED - ignore after this.
        !>     Open the met netcdf file. This also sets up the run boundaries
        !!     based on the metadata in the netcdf. It is important to ensure the
        !!     netcdf is of the same dimensions as the intended output files.
        !!     Based upon the bounds used to call the model, this will figure out how
        !!     big the NLAT vector is.
        !      call openmet()
        !      write(*,*)'done openmet'

        !call readin_met(1,dlatgat,dlongat)
        !
        !     checking the time spent for running model
        !
        !      call idate(today)
        !      call itime(now)
        !      write(*,1000)   today(2), today(1), 2000+today(3), now
        ! 1000 format( 'start date: ', i2.2, '/', i2.2, '/', i4.4,
        !     &      '; start time: ', i2.2, ':', i2.2, ':', i2.2 )
        !
        !     INITIALIZATION FOR COUPLING CLASS AND CTEM
        !
        call initrowvars()
        call resetclassaccum(nltest,nmtest)
!
!         IMONTH = 0
!         lopcount = 1   ! initialize loop count to 1.
!         ZDMROW(1)=10.0
!         ZDHROW(1)=2.0
!         NTLD=NMOS
!         CUMSNO = 0.0
!
!         do 11 i=1,nlat
!             do 11 m=1,nmos
!                 barf(i,m)                = 1.0
!                 TCANOACCROW_M(I,M)       = 0.0
!                 UVACCROW_M(I,M)          = 0.0
!                 VVACCROW_M(I,M)          = 0.0
!                 TCANOACCROW_OUT(I,M)     = 0.0
! 11          continue
!
!             !     do some initializations for the reading in of data from files. these
!             !     initializations primarily affect how the model does a spinup or transient
!             !     simulation and which years of the input data are being read.
!
!             if (.not. cyclemet .and. transient_run) then !transient simulation, set to dummy values
!                 metcylyrst=trans_startyr ! this will make it skip to the trans_startyr
!                 metcycendyr=9999
!             else
!                 !       find the final year of the cycling met
!                 !       metcylyrst is defined in the joboptions file
!                 metcycendyr = metcylyrst + nummetcylyrs - 1
!             endif
!
!             !     if cycling met (and not doing a transient run), find the popd and luc year to cycle with.
!             !     it is assumed that you always want to cycle the popd and luc
!             !     on the same year to be consistent. so if you are cycling the
!             !     met data, you can set a popd year (first case), or if cycling
!             !     the met data you can let the popcycleyr default to the met cycling
!             !     year by setting popcycleyr to -9999 (second case). if not cycling
!             !     the met data or you are doing a transient run that cycles the MET
!             !     at the start, cypopyr and cylucyr will default to a dummy value
!             !     (last case). (See example at bottom of read_from_job_options.f90
!             !     if confused)
!             !
!             if (cyclemet .and. popcycleyr .ne. -9999 .and.&
!                 &.not. transient_run) then
!                 cypopyr = popcycleyr
!                 cylucyr = popcycleyr
!             else if (cyclemet .and. .not. transient_run) then
!                 cypopyr = metcylyrst
!                 cylucyr = metcylyrst
!             else  ! give dummy value
!                 cypopyr = popcycleyr !-9999
!                 cylucyr = popcycleyr !-9999
!             end if
!
!             !     CTEM initialization done
!             !
!             ! #ED - Eventually we will remove all of this since we will be using only netcdf files...
!
!             !     open files for reading and writing. these are for coupled model (class_ctem)
!             !     we added both grid and mosaic output files
!             !
!             !     * input files
!
!             !         If we wish to restart from the .CTM_RS and .INI_RS files, then
!             !         we move the original RS files into place and start from them.
!             if (start_from_rs) then
!                 command='mv '//argbuff(1:strlen(argbuff))//'.INI_RS '&
!                     &                    //argbuff(1:strlen(argbuff))//'.INI'
!                 call system(command)
!                 command='mv '//argbuff(1:strlen(argbuff))//'.CTM_RS '&
!                     &                    //argbuff(1:strlen(argbuff))//'.CTM'
!                 call system(command)
!             end if
!
!
!             open(unit=10,file=argbuff(1:strlen(argbuff))//'.INI',&
!                 &       status='old')
!
!             open(unit=12,file=argbuff(1:strlen(argbuff))//'.MET',&
!                 &      status='old')
!
!             !     luc file is opened in initialize_luc subroutine
!
!             if (popdon) then
!                 open(unit=13,file=argbuff(1:strlen(argbuff))//'.POPD',&
!                     &       status='old')
!                 read(13,*)  !Skip 3 lines of header
!                 read(13,*)
!                 read(13,*)
!             endif
!             if (co2on .or. ch4on) then
!                 open(unit=14,file=argbuff(1:strlen(argbuff))//'.CO2',&
!                     &         status='old')
!             endif
!
!             !
!             if (obswetf) then
!                 open(unit=16,file=argbuff(1:strlen(argbuff))//'.WET',&
!                     &         status='old')
!             endif
!
!             if (obslght) then ! this was brought in for FireMIP
!                 open(unit=17,file=argbuff(1:strlen(argbuff))//'.LGHT',&
!                     &         status='old')
!             endif
!             !
!             !     * CLASS daily and half-hourly output files (monthly and annual are done in io_driver)
!             !
!             if (.not. parallelrun) then ! stand alone mode, includes half-hourly and daily output
!                 OPEN(UNIT=61,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF1_G')  ! GRID-LEVEL DAILY OUTPUT FROM CLASS
!                 OPEN(UNIT=62,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF2_G')
!                 OPEN(UNIT=63,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF3_G')
!
!                 OPEN(UNIT=611,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF1_M') ! MOSAIC DAILY OUTPUT FROM CLASS
!                 OPEN(UNIT=621,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF2_M')
!                 OPEN(UNIT=631,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF3_M')
!
!                 OPEN(UNIT=64,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF4_M')  ! MOSAIC HALF-HOURLY OUTPUT FROM CLASS
!                 OPEN(UNIT=65,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF5_M')
!                 OPEN(UNIT=66,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF6_M')
!                 OPEN(UNIT=67,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF7_M')
!                 OPEN(UNIT=68,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF8_M')
!                 OPEN(UNIT=69,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF9_M')
!
!                 OPEN(UNIT=641,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF4_G') ! GRID-LEVEL HALF-HOURLY OUTPUT FROM CLASS
!                 OPEN(UNIT=651,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF5_G')
!                 OPEN(UNIT=661,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF6_G')
!                 OPEN(UNIT=671,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF7_G')
!                 OPEN(UNIT=681,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF8_G')
!                 OPEN(UNIT=691,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.OF9_G')
!             end if
!
!             !     * READ AND PROCESS INITIALIZATION AND BACKGROUND INFORMATION.
!             !     * FIRST, MODEL RUN SPECIFICATIONS.
!
!             READ (10,5010) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!             READ (10,5010) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!             READ (10,5010) PLACE1,PLACE2,PLACE3,PLACE4,PLACE5,PLACE6
!             !
!             !      the ctem output file suffix naming convention is as follows:
!             !                       ".CT##{time}"
!             !      where the ## is a numerical identifier, {time} is any of H, D, M,
!             !      or Y for half hourly, daily, monthly, or yearly, respectively.
!             !
!             ! Set up the CTEM half-hourly, daily, monthly and yearly files (if any needed), also
!             ! setup the CLASS monthly and annual output files:
!
!             call create_outfiles(argbuff,title1, title2, title3, title4,&
!                 &                     title5,title6,name1, name2, name3, name4,&
!                 &                     name5, name6, place1,place2, place3,&
!                 &                     place4, place5, place6)
!
!             IF(CTEM_ON) THEN
!
!                 if(obswetf) then
!                     read(16,*) TITLEC1
!                 end if
!             ENDIF
!             !
!             IF (.NOT. PARALLELRUN) THEN ! STAND ALONE MODE, INCLUDES HALF-HOURLY AND DAILY OUTPUT
!                 !
!                 WRITE(61,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(61,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!                 WRITE(61,6011)
! 6011            FORMAT(2X,'DAY  YEAR  K*  L*  QH  QE  SM  QG  ',&
!                     &          'TR  SWE  DS  WS  AL  ROF  CUMS')
!
!                 WRITE(62,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(62,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!
!                 IF(IGND.GT.3) THEN
!                     WRITE(62,6012)
! 6012                FORMAT(2X,'DAY  YEAR  TG1  THL1  THI1  TG2  THL2  THI2  ',&
!                         &    'TG3  THL3  THI3  TG4  THL4  THI4  TG5  THL5  ',&
!                         &    'THI5 TG6  THL6  THI6 TG7  THL7  THI7',&
!                         &    'TG8  THL8  THI8 TG9  THL9  THI9 TG10  THL10  THI10',&
!                         &    'TG11  THL11  THI11 TG12  THL12  THI12 TG13  THL13  THI13',&
!                         &    'TG14  THL14  THI14 TG15  THL15  THI15 TG16  THL16  THI16',&
!                         &    'TG17  THL17  THI17 TG18  THL18  THI18 TG19  THL19  THI19',&
!                         &    'TG20  THL20  THI20 ACTLYR FTABLE')
!
!                 ELSE
!                     WRITE(62,6212)
! 6212                FORMAT(2X,'DAY  YEAR  TG1  THL1  THI1  TG2  THL2  THI2  ',&
!                         &              'TG3  THL3  THI3  TCN  RCAN  SCAN  TSN  ZSN',&
!                         &              'ACTLYR FTABLE')
!
!                 ENDIF
!
!                 WRITE(63,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(63,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!                 WRITE(63,6313)
! 6313            FORMAT(2X,'DAY YEAR KIN LIN TA UV PRES QA PCP EVAP')
!                 !
!                 WRITE(64,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(64,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!                 WRITE(64,6014)
! 6014            FORMAT(2X,'HOUR  MIN  DAY  YEAR  K*  L*  QH  QE  SM  QG  ',&
!                     &          'TR  SWE  DS  WS  AL  ROF  TPN  ZPN  CDH  CDM  ',&
!                     &          'SFCU  SFCV  UV')
!
!                 WRITE(65,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(65,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!
!                 WRITE(65,6515)
! 6515            FORMAT(2X,'HOUR  MIN  DAY  YEAR  TG1  THL1  THI1  TG2  ',&
!                     &           'THL2  THI2  TG3  THL3  THI3  TCN  RCAN  SCAN  ',&
!                     &           'TSN  ZSN  TCN-TA  TCANO  TAC  ACTLYR  FTABLE')
!
!                 WRITE(66,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(66,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!
!                 IF(IGND.GT.3) THEN
!                     WRITE(66,6016)
! 6016                FORMAT(2X,'HOUR  MIN  DAY  YEAR  TG6  THL6  THI6  TG7  ',&
!                         &          'THL7  THI7  TG8  THL8  THI8  TG9  THL9  THI9  ',&
!                         &          'TG10  THL10  THI10  TG11  THL11  THI11  TG12  ',&
!                         &          'THL12  THI12  TG13  THL13  THI13  TG14  THL14  ',&
!                         &          'THI14  TG15  THL15  THI15  TG16  THL16  THI16  ',&
!                         &          'TG17  THL17  THI17  TG18  THL18  THI18  TG19  ' ,&
!                         &          'THL19  THI19  TG20  THL20  THI20  TG21  THL21  ',&
!                         &          'THI21  TG22  THL22 THI22  TG23  THL23  THI23  ',&
!                         &          'TG24  THL24  THI24  TG25  THL25  THI25  TG26  ',&
!                         &          'THL26  THI26  G0  G1  G2  G3  G4  G5  G6  ',&
!                         &          'G7  G8  G9')
!
!                 ELSE
!                     WRITE(66,6616)
!                     WRITE(66,6615)
! 6616                FORMAT(2X,'HOUR  MIN  DAY  SWIN  LWIN  PCP  TA  VA  PA  QA')
! 6615                FORMAT(2X,'IF IGND <= 3, THIS FILE IS EMPTY')
!                 ENDIF
!
!                 WRITE(67,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(67,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!                 WRITE(67,6017)
!                 !     6017  FORMAT(2X,'WCAN SCAN CWLCAP CWFCAP FC FG FCS FGS CDH ', !runclass formatted.
!                 !     1          'TCANO TCANS ALBS')
! 6017            FORMAT(2X,'HOUR  MIN  DAY  YEAR  ',&
!                     &  'TROF     TROO     TROS     TROB      ROF     ROFO   ',&
!                     &  '  ROFS        ROFB         FCS        FGS        FC       FG')
!
!                 WRITE(68,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(68,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!                 WRITE(68,6018)
! 6018            FORMAT(2X,'HOUR  MIN  DAY  YEAR  ',&
!                     &          'FSGV FSGS FSGG FLGV FLGS FLGG HFSC HFSS HFSG ',&
!                     &          'HEVC HEVS HEVG HMFC HMFS HMFG1 HMFG2 HMFG3 ',&
!                     &          'HTCC HTCS HTC1 HTC2 HTC3')
!
!                 WRITE(69,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(69,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!                 WRITE(69,6019)
! 6019            FORMAT(2X,'HOUR  MIN  DAY  YEAR  ',&
!                     &   'PCFC PCLC PCPN PCPG QFCF QFCL QFN QFG QFC1 ',&
!                     &          'QFC2 QFC3 ROFC ROFN ROFO ROF WTRC WTRS WTRG')
!                 !       runclass also has: EVDF ','CTV CTS CT1 CT2 CT3')
!                 !
!                 WRITE(611,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(611,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!                 WRITE(611,6011)
!                 WRITE(621,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(621,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!                 !
!                 IF(IGND.GT.3) THEN
!                     WRITE(621,6012)
!                 ELSE
!                     WRITE(621,6212)
!                 ENDIF
!                 !
!                 WRITE(631,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(631,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!                 WRITE(631,6313)
!                 !
!                 WRITE(641,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(641,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!                 WRITE(641,6008)
!
!                 WRITE(651,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(651,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!                 WRITE(651,6515)
!                 !
!                 WRITE(661,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(661,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!                 !
!                 IF(IGND.GT.3) THEN
!                     WRITE(661,6016)
!                 ELSE
!                     WRITE(661,6616)
!                 ENDIF
!                 !
!                 WRITE(671,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(671,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!                 WRITE(671,6017)
!                 WRITE(681,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(681,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!                 WRITE(681,6018)
!                 WRITE(691,6001) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                 WRITE(691,6002) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!                 WRITE(691,6019)
!                 !
! 6008            FORMAT(2X,'HOUR  MIN  DAY  YEAR  K*  L*  QH  QE  SM  QG  ',&
!                     &          'TR  SWE  DS  WS  AL  ROF  TPN  ZPN  CDH  CDM  ',&
!                     &          'SFCU  SFCV  UV')
!
!             !
!             ENDIF !IF NOT PARALLELRUN
!
!             !     CTEM FILE TITLES DONE
!             !======================= CTEM ========================================== /
!             ! #ED here is the info the initialization nc file contains. This below is
!             ! what we will comment out once we have it working for netcdf alone until the
!             ! #DE
!             !     BEGIN READ IN OF THE .INI FILE
!
!             READ(10,5020) DLATROW(1),DEGLON,ZRFMROW(1),ZRFHROW(1),ZBLDROW(1),&
!                 &              GCROW(1),NLTEST,NMTEST
!
!             JLAT=NINT(DLATROW(1))
!             RADJROW(1)=DLATROW(1)*PI/180.
!             DLONROW(1)=DEGLON
!             Z0ORROW(1)=0.0
!             GGEOROW(1)=0.0
!             !     GGEOROW(1)=-0.035
!
!             DO 50 I=1,NLTEST !This should go above the first read(10 but offline nltest is always 1.
!                 DO 50 M=1,NMTEST
!                     READ(10,5040) (FCANROT(I,M,J),J=1,ICAN+1),(PAMXROT(I,M,J),&
!                         &                  J=1,ICAN)
!                     READ(10,5040) (LNZ0ROT(I,M,J),J=1,ICAN+1),(PAMNROT(I,M,J),&
!                         &                  J=1,ICAN)
!                     READ(10,5040) (ALVCROT(I,M,J),J=1,ICAN+1),(CMASROT(I,M,J),&
!                         &                  J=1,ICAN)
!                     READ(10,5040) (ALICROT(I,M,J),J=1,ICAN+1),(ROOTROT(I,M,J),&
!                         &                  J=1,ICAN)
!                     READ(10,5030) (RSMNROT(I,M,J),J=1,ICAN),&
!                         &                  (QA50ROT(I,M,J),J=1,ICAN)
!                     READ(10,5030) (VPDAROT(I,M,J),J=1,ICAN),&
!                         &                  (VPDBROT(I,M,J),J=1,ICAN)
!                     READ(10,5030) (PSGAROT(I,M,J),J=1,ICAN),&
!                         &                  (PSGBROT(I,M,J),J=1,ICAN)
!                     READ(10,5040) DRNROT(I,M),SDEPROT(I,M),FAREROT(I,M)
!                     ! Error check:
!                     if (FAREROT(I,M) .gt. 1.0) then
!                         write(*,*)'FAREROT > 1',FAREROT(I,M)
!                         call XIT('runclass36ctem', -2)
!                     end if
!                     READ(10,5090) XSLPROT(I,M),GRKFROT(I,M),WFSFROT(I,M),&
!                         &                  WFCIROT(I,M),MIDROT(I,M)
!                     DO 25 J=1,IGND
!                         READ(10,5080) ZBOT(J),DELZ(J),SANDROT(I,M,J),&
!                             &        CLAYROT(I,M,J),ORGMROT(I,M,J),TBARROT(I,M,J),&
!                             &        THLQROT(I,M,J),THICROT(I,M,J)
! 25                  CONTINUE
!                     READ(10,5050)TCANROT(I,M),TSNOROT(I,M),TPNDROT(I,M),&
!                         &        ZPNDROT(I,M)
!                     READ(10,5070) RCANROT(I,M),SCANROT(I,M),SNOROT(I,M),&
!                         &                  ALBSROT(I,M),RHOSROT(I,M),GROROT(I,M)
! 50              CONTINUE
!                 !
!                 !     the output year ranges can be read in from the job options file, or not.
!                 !     if the values should be read in from the .ini file, and not
!                 !     from the job options file, the job options file values are set to
!                 !     -9999 thus triggering the read in of the .ini file values below
!                 if (jhhstd .eq. -9999) then
!                     read(10,5200) jhhstd,jhhendd,jdstd,jdendd
!                     read(10,5200) jhhsty,jhhendy,jdsty,jdendy
!                 end if
!
!                 CLOSE(10)
!                 !
!                 !====================== CTEM =========================================== \
!                 !
!                 !     read from ctem initialization file (.CTM)
!
!                 if (ctem_on) then
!                     call read_from_ctm(nltest,nmtest,FCANROT,FAREROT,&
!                         &                   RSMNROT,QA50ROT,VPDAROT,VPDBROT,PSGAROT,&
!                         &                   PSGBROT,DRNROT,SDEPROT, XSLPROT,GRKFROT,&
!                         &                   WFSFROT,WFCIROT,MIDROT,SANDROT, CLAYROT,&
!                         &                   ORGMROT,TBARROT,THLQROT,THICROT,TCANROT,&
!                         &                   TSNOROT,TPNDROT,ZPNDROT,RCANROT,SCANROT,&
!                         &                   SNOROT, ALBSROT,RHOSROT,GROROT,argbuff,&
!                         &                   onetile_perPFT)
!                 end if
!                 !
!                 ! #DE
!                 !===================== CTEM =============================================== /
!
!                 !     Complete some initial set up work:
!
!                 DO 100 I=1,NLTEST
!                     DO 100 M=1,NMTEST
!
!                         DO J=1,IGND
!                             TBARROT(I,M,J)=TBARROT(I,M,J)+TFREZ
!                         ENDDO
!                         TSNOROT(I,M)=TSNOROT(I,M)+TFREZ
!                         TCANROT(I,M)=TCANROT(I,M)+TFREZ
!
!                         TPNDROT(I,M)=TPNDROT(I,M)+TFREZ
!                         TBASROT(I,M)=TBARROT(I,M,IGND)
!                         CMAIROT(I,M)=0.
!                         WSNOROT(I,M)=0.
!                         ZSNLROT(I,M)=0.10
!                         TSFSROT(I,M,1)=TFREZ
!                         TSFSROT(I,M,2)=TFREZ
!
!                         TSFSROT(I,M,3)=TBARROT(I,M,1)
!                         TSFSROT(I,M,4)=TBARROT(I,M,1)
!                         TACROT (I,M)=TCANROT(I,M)
!                         QACROT (I,M)=0.5E-2
!
!                         ! FLAG!!! THIS NEEDS TO CHANGE FOR PERMAFROST WORK!! These values will be provided and written out!! JM Jan 82016.
!                         !           IF(IGND.GT.3)                                 THEN
!                         !               DO 65 J=4,IGND
!                         !                   TBARROT(I,M,J)=TBARROT(I,M,3)
!                         !                   IF(SDEPROT(I,M).LT.(ZBOT(J-1)+0.001) .AND.
!                         !      1                  SANDROT(I,M,3).GT.-2.5)     THEN
!                         !                       SANDROT(I,M,J)=-3.0
!                         !                       CLAYROT(I,M,J)=-3.0
!                         !                       ORGMROT(I,M,J)=-3.0
!                         !                       THLQROT(I,M,J)=0.0
!                         !                       THICROT(I,M,J)=0.0
!                         !                   ELSE
!                         !                       SANDROT(I,M,J)=SANDROT(I,M,3)
!                         !                       CLAYROT(I,M,J)=CLAYROT(I,M,3)
!                         !                       ORGMROT(I,M,J)=ORGMROT(I,M,3)
!                         !                       THLQROT(I,M,J)=THLQROT(I,M,3)
!                         !                       THICROT(I,M,J)=THICROT(I,M,3)
!                         !                   ENDIF
!                         ! 65            CONTINUE
!                         !           ENDIF
!
!                         DO 75 K=1,6
!                             DO 75 L=1,50
!                                 ITCTROT(I,M,K,L)=0
! 75                          CONTINUE
! 100                     CONTINUE
!
!                         DO 150 I=1,NLTEST
!                             PREACC(I)=0.
!                             GTACC(I)=0.
!                             QEVPACC(I)=0.
!                             EVAPACC(I)=0.
!                             HFSACC(I)=0.
!                             HMFNACC(I)=0.
!                             ROFACC(I)=0.
!                             ALTOTACC(I)=0.
!                             OVRACC(I)=0.
!                             WTBLACC(I)=0.
!                             ALVSACC(I)=0.
!                             ALIRACC(I)=0.
!                             RHOSACC(I)=0.
!                             SNOACC(I)=0.
!                             WSNOACC(I)=0.
!                             CANARE(I)=0.
!                             SNOARE(I)=0.
!                             TSNOACC(I)=0.
!                             TCANACC(I)=0.
!                             RCANACC(I)=0.
!                             SCANACC(I)=0.
!                             GROACC(I)=0.
!                             FSINACC(I)=0.
!                             FLINACC(I)=0.
!                             FLUTACC(I)=0.
!                             TAACC(I)=0.
!                             UVACC(I)=0.
!                             PRESACC(I)=0.
!                             QAACC(I)=0.
!                             altotcount_ctm(i)=0
!                             DO 125 J=1,IGND
!                                 TBARACC(I,J)=0.
!                                 THLQACC(I,J)=0.
!                                 THICACC(I,J)=0.
!                                 THALACC(I,J)=0.
! 125                         CONTINUE
! 150                     CONTINUE
!
!                         alswacc_gat(:)=0.
!                         allwacc_gat(:)=0.
!                         fsinacc_gat(:)=0.
!                         flinacc_gat(:)=0.
!                         flutacc_gat(:)=0.
!                         pregacc_gat(:)=0.
!                         altotacc_gat(:)=0.
!
!
!                         !     initialize accumulated array for monthly & yearly output for class
!
!                         call resetclassmon(nltest)
!                         call resetclassyr(nltest)
!
!                         !ALAVG=0.0
!                         !ALMAX=0.0
!                         !ACTLYR=0.0
!                         !FTAVG=0.0
!                         !FTMAX=0.0
!                         !FTABLE=0.0
!
!                         CALL CLASSB(THPROT,THRROT,THMROT,BIROT,PSISROT,GRKSROT,&
!                             &            THRAROT,HCPSROT,TCSROT,THFCROT,THLWROT,PSIWROT,&
!                             &            DLZWROT,ZBTWROT,ALGWROT,ALGDROT,&
!                             &            ALGWVROT,ALGWNROT,ALGDVROT,ALGDNROT,&
!                             &            SANDROT,CLAYROT,ORGMROT,SOCIROT,DELZ,ZBOT,&
!                             &            SDEPROT,ISNDROT,IGDRROT,&
!                             &            NLAT,NMOS,1,NLTEST,NMTEST,IGND,IGRALB)
!
! 5010                    FORMAT(2X,6A4)
! 5020                    FORMAT(5F10.2,F7.1,3I5)
! 5030                    FORMAT(4F8.3,8X,4F8.3)
! 5040                    FORMAT(9F8.3)
! 5050                    FORMAT(4F10.2)
! 5070                    FORMAT(2F10.4,F10.2,F10.3,F10.4,F10.3)
! 5080                    FORMAT(2F8.2,3F10.1,3F10.3)
! 5090                    FORMAT(4E8.1,I8)
! 5200                    FORMAT(4I10)
! 5300                    FORMAT(1X,I2,I3,I5,I6,2F9.2,E14.4,F9.2,E12.3,F8.2,F12.2,3F9.2,&
!                             &       F9.4)
! 5301                    FORMAT(I5,F10.4)
! 6001                    FORMAT('#CLASS TEST RUN:     ',6A4)
! 6002                    FORMAT('#RESEARCHER:         ',6A4)
! 6003                    FORMAT('#INSTITUTION:        ',6A4)
!                         !
!                         !===================== CTEM =============================================== \
!                         !
!                         !     ctem initializations.
!                         !
!                         if (ctem_on) then
!                             !
!                             !     calculate number of level 2 pfts using modelpft
!                             !
!                             do 101 j = 1, ican
!                                 isumc = 0
!                                 k1c = (j-1)*l2max + 1
!                                 k2c = k1c + (l2max - 1)
!                                 do n = k1c, k2c
!                                     if(modelpft(n).eq.1) isumc = isumc + 1
!                                 enddo
!                                 nol2pfts(j)=isumc  ! number of level 2 pfts
! 101                         continue
!                             !
!                             do 110 i=1,nltest
!                                 do 110 m=1,nmtest
!                                     do 111 j = 1, icc
!                                         co2i1csrow(i,m,j)=0.0     !intercellular co2 concentrations
!                                         co2i1cgrow(i,m,j)=0.0
!                                         co2i2csrow(i,m,j)=0.0
!                                         co2i2cgrow(i,m,j)=0.0
!                                         slairow(i,m,j)=0.0        !if bio2str is not called we need to initialize this to zero
! 111                                 continue
! 110                             continue
!                                 !
!                                 do 123 i =1, ilg
!                                     fsnowacc_t(i)=0.0         !daily accu. fraction of snow
!                                     tcansacc_t(i)=0.0         !daily accu. canopy temp. over snow
!                                     taaccgat_t(i)=0.0
!                                     !
!                                     do 128 j = 1, icc
!                                         ancsvgac_t(i,j)=0.0    !daily accu. net photosyn. for canopy over snow subarea
!                                         ancgvgac_t(i,j)=0.0    !daily accu. net photosyn. for canopy over ground subarea
!                                         rmlcsvga_t(i,j)=0.0    !daily accu. leaf respiration for canopy over snow subarea
!                                         rmlcgvga_t(i,j)=0.0    !daily accu. leaf respiration for canopy over ground subarea
!                                         todfrac(i,j)=0.0
! 128                                 continue
!                                     !
!                                     do 112 j = 1,ignd       !soil temperature and moisture over different subareas
!                                         tbarcacc_t (i,j)=0.0
!                                         tbarcsacc_t(i,j)=0.0
!                                         tbargacc_t (i,j)=0.0
!                                         tbargsacc_t(i,j)=0.0
!                                         thliqcacc_t(i,j)=0.0
!                                         thliqgacc_t(i,j)=0.0
!                                         thliqacc_t(i,j)=0.0
!                                         thicecacc_t(i,j)=0.0
! 112                                 continue
! 123                             continue
!                                 !
!                                 !     find fcancmx with class' fcanmxs and dvdfcans read from ctem's
!                                 !     initialization file. this is to divide needle leaf and broad leaf
!                                 !     into dcd and evg, and crops and grasses into c3 and c4.
!                                 !
!                                 do 113 j = 1, ican
!                                     do 114 i=1,nltest
!                                         do 114 m=1,nmtest
!                                             !
!                                             k1c = (j-1)*l2max + 1
!                                             k2c = k1c + (l2max - 1)
!                                             !
!                                             do n = k1c, k2c
!                                                 if(modelpft(n).eq.1)then
!                                                     icountrow(i,m) = icountrow(i,m) + 1
!                                                     csum(i,m,j) = csum(i,m,j) +&
!                                                         &         dvdfcanrow(i,m,icountrow(i,m))
!
!                                                     !              Added in seed here to prevent competition from getting
!                                                     !              pfts with no seed fraction.  JM Feb 202014.
!                                                     if (compete .and. .not. onetile_perPFT) then
!                                                         fcancmxrow(i,m,icountrow(i,m))=max(seed,FCANROT(i,m,j)*&
!                                                             &         dvdfcanrow(i,m,icountrow(i,m)))
!                                                         barf(i,m) = barf(i,m) - fcancmxrow(i,m,icountrow(i,m))
!                                                     else
!                                                         fcancmxrow(i,m,icountrow(i,m))=FCANROT(i,m,j)*&
!                                                             &         dvdfcanrow(i,m,icountrow(i,m))
!                                                     end if
!                                                 endif
!                                             enddo
!                                         !
!                                         !           if( abs(csum(i,m,j)-1.0).gt.abszero ) then
!                                         !            write(6,1130)i,m,j
!                                         ! 1130       format('dvdfcans for (',i1,',',i1,',',i1,') must add to 1.0')
!                                         !             call xit('runclass36ctem', -3)
!                                         !           endif
!                                         !
! 114                                     continue
! 113                                 continue
!
!                                     !     Now make sure that you aren´t over 1.0 for a tile (i.e. with a negative
!                                     !     bare ground fraction due to the seed fractions being added in.) JM Mar 92016
!                                     do i=1,nltest
!                                         do m = 1,nmtest
!                                             if (barf(i,m) .lt. 0.) then
!                                                 bigpftc=maxloc(fcancmxrow(i,m,:))
!                                                 ! reduce the most predominant PFT by barf and 1.0e-5,
!                                                 ! which ensures that our barefraction is non-zero to avoid
!                                                 ! problems later.
!                                                 fcancmxrow(i,m,bigpftc(1))=fcancmxrow&
!                                                     &                (i,m,bigpftc(1))+barf(i,m) - 1.0e-5
!                                             end if
!                                         end do
!                                     end do
!                                     !
!                                     !     ----------
!
!                                     !     preparation with the input datasets prior to launching run:
!
!                                     if(obswetf) then
!                                         obswetyr=-99999
!                                         do while (obswetyr .lt. metcylyrst)
!                                             do i=1,nltest
!                                                 ! Read the values into the first tile
!                                                 read(16,*) obswetyr,(wetfrac_monrow(i,1,j),j=1,12)
!                                                 if (nmtest > 1) then
!                                                     do m = 2,nmtest !spread grid values over all tiles for easier use in model
!                                                         wetfrac_monrow(i,m,:) = wetfrac_monrow(i,1,:)
!                                                     end do
!                                                 end if
!                                             end do
!                                         end do
!                                         backspace(16)
!                                     else !not needed, just set to 0 and move on.
!                                         wetfrac_monrow(:,:,:) = 0.0
!                                     end if
!
!                                     if(obslght) then
!                                         obslghtyr=-99999
!                                         do while (obslghtyr .lt. metcylyrst)
!                                             do i=1,nltest
!                                                 read(17,*) obslghtyr,(mlightngrow(i,1,j),j=1,12) ! read into the first tile
!                                                 if (nmtest > 1) then
!                                                     do m = 2,nmtest !spread grid values over all tiles for easier use in model
!                                                         mlightngrow(i,m,:) = mlightngrow(i,1,:)
!                                                     end do
!                                                 end if
!                                             end do
!                                         end do
!                                         backspace(17)
!                                     end if
!
!                                     !      find the popd data to cycle over, popd is only cycled over when the met is cycled.
!
!                                     if (cyclemet .and. popdon) then
!                                         popyr=-99999  ! initialization, forces entry to loop below
!                                         do while (popyr .lt. cypopyr)
!                                             do i = 1, nltest
!                                                 read(13,5301) popyr,popdinrow(i,1) !place it in the first tile
!                                                 if (nmtest > 1) then
!                                                     do m = 2, nmtest
!                                                         popdinrow(i,m) = popdinrow(i,1) !spread this value over all tiles
!                                                     end do
!                                                 end if
!                                             enddo
!                                         enddo
!                                     endif
!                                 !
!                                 end if ! ctem_on
!
!                                 iyear=-99999  ! initialization, forces entry to loop below
!
!                                 !     find the first year of met data
!                                 do while (iyear .lt. metcylyrst)
!                                     !
!                                     do i=1,nltest
!                                         read(12,5300) ihour,imin,iday,iyear,FSSROW(I),FDLROW(i),&
!                                             &         PREROW(i),TAROW(i),QAROW(i),UVROW(i),PRESROW(i)
!                                     enddo
!                                 enddo
!
!                                 !      back up one space in the met file so it is ready for the next readin
!                                 backspace(12)
!
!                                 !      If you are not cycling over the MET, you can still specify to end on a
!                                 !      year that is shorter than the total climate file length.
!                                 if (.not. cyclemet) endyr = iyear + ncyear
!
!                                 if (ctem_on) then
!
!                                     !       if land use change switch is on then read the fractional coverages
!                                     !       of ctem's 9 pfts for the first year.
!                                     !
!                                     if (lnduseon .and. transient_run) then
!
!                                         reach_eof=.false.  !flag for when read to end of luc input file
!
!                                         call initialize_luc(iyear,argbuff,nmtest,nltest,&
!                                             &                     nol2pfts,cyclemet,&
!                                             &                     cylucyr,lucyr,FCANROT,FAREROT,nfcancmxrow,&
!                                             &                     pfcancmxrow,fcancmxrow,reach_eof,start_bare,&
!                                             &                     compete,onetile_perPFT)
!
!                                         if (reach_eof) goto 999
!
!                                     endif ! if (lnduseon)
!                                     !
!                                     !     with fcancmx calculated above and initialized values of all ctem pools,
!                                     !     find mosaic tile (grid) average vegetation biomass, litter mass, and soil c mass.
!                                     !     also initialize additional variables which are used by ctem.
!                                     !
!                                     do 115 i = 1,nltest
!                                         do 115 m = 1,nmtest
!                                             vgbiomasrow(i,m)=0.0
!                                             gavglairow(i,m)=0.0
!                                             gavgltmsrow(i,m)=0.0
!                                             gavgscmsrow(i,m)=0.0
!                                             lucemcomrow(i,m)=0.0      !land use change combustion emission losses
!                                             lucltrinrow(i,m)=0.0      !land use change inputs to litter pool
!                                             lucsocinrow(i,m)=0.0      !land use change inputs to soil c pool
!                                             colddaysrow(i,m,1)=0      !cold days counter for ndl dcd
!                                             colddaysrow(i,m,2)=0      !cold days counter for crops
!
!                                             do 116 j = 1, icc
!                                                 vgbiomasrow(i,m)=vgbiomasrow(i,m)+fcancmxrow(i,m,j)*&
!                                                     &        (gleafmasrow(i,m,j)+stemmassrow(i,m,j)+&
!                                                     &         rootmassrow(i,m,j)+bleafmasrow(i,m,j))
!                                                 gavgltmsrow(i,m)=gavgltmsrow(i,m)+fcancmxrow(i,m,j)*&
!                                                     &                       litrmassrow(i,m,j)
!                                                 gavgscmsrow(i,m)=gavgscmsrow(i,m)+fcancmxrow(i,m,j)*&
!                                                     &         soilcmasrow(i,m,j)
!                                                 grwtheffrow(i,m,j)=100.0   !set growth efficiency to some large number
!                                                 !                                      !so that no growth related mortality occurs in
!                                                 !                                      !first year
!                                                 flhrlossrow(i,m,j)=0.0     !fall/harvest loss
!                                                 stmhrlosrow(i,m,j)=0.0     !stem harvest loss for crops
!                                                 rothrlosrow(i,m,j)=0.0     !root death for crops
!                                                 lystmmasrow(i,m,j)=stemmassrow(i,m,j)
!                                                 lyrotmasrow(i,m,j)=rootmassrow(i,m,j)
!                                                 tymaxlairow(i,m,j)=0.0
!
! 116                                         continue
!
!                                             !
!                                             ! *     initialize accumulated array for monthly and yearly output for ctem
!                                             !
!                                             call resetmonthend(nltest,nmtest)
!                                             call resetyearend(nltest,nmtest)
!                                         !
! 115                                     continue
!                                         !
!                                         do 117 i = 1,nltest
!                                             do 117 m = 1,nmtest
!                                                 gavgltmsrow(i,m)=gavgltmsrow(i,m)+ (1.0-FCANROT(i,m,1)-&
!                                                     &       FCANROT(i,m,2)-&
!                                                     &    FCANROT(i,m,3)-FCANROT(i,m,4))*litrmassrow(i,m,icc+1)
!                                                 gavgscmsrow(i,m)=gavgscmsrow(i,m)+ (1.0-FCANROT(i,m,1)-&
!                                                     &   FCANROT(i,m,2)-&
!                                                     &    FCANROT(i,m,3)-FCANROT(i,m,4))*soilcmasrow(i,m,icc+1)
!                                             !
! 117                                         continue
!                                             !
!
!                                             CALL GATPREP(ILMOS,JLMOS,IWMOS,JWMOS,&
!                                                 &             NML,NMW,GCROW,FAREROT,MIDROT,&
!                                                 &             NLAT,NMOS,ILG,1,NLTEST,NMTEST)
!
!                                             call ctemg1(gleafmasgat,bleafmasgat,stemmassgat,rootmassgat,&
!                                                 &      fcancmxgat,zbtwgat,dlzwgat,sdepgat,ailcggat,ailcbgat,&
!                                                 &      ailcgat,zolncgat,rmatcgat,rmatctemgat,slaigat,&
!                                                 &      bmasveggat,cmasvegcgat,veghghtgat,&
!                                                 &      rootdpthgat,alvsctmgat,alirctmgat,&
!                                                 &      paicgat,    slaicgat, faregat,&
!                                                 &      ilmos,jlmos,iwmos,jwmos,&
!                                                 &      nml,&
!                                                 &      gleafmasrow,bleafmasrow,stemmassrow,rootmassrow,&
!                                                 &      fcancmxrow,ZBTWROT,DLZWROT,SDEPROT,ailcgrow,ailcbrow,&
!                                                 &      ailcrow,zolncrow,rmatcrow,rmatctemrow,slairow,&
!                                                 &      bmasvegrow,cmasvegcrow,veghghtrow,&
!                                                 &      rootdpthrow,alvsctmrow,alirctmrow,&
!                                                 &      paicrow,    slaicrow, FAREROT)
!
!                                             call bio2str( gleafmasgat,bleafmasgat,stemmassgat,rootmassgat,&
!                                                 &                           1,      nml,    fcancmxgat, zbtwgat,&
!                                                 &                        dlzwgat, nol2pfts,   sdepgat,&
!                                                 &                       ailcggat, ailcbgat,  ailcgat, zolncgat,&
!                                                 &                       rmatcgat, rmatctemgat,slaigat,bmasveggat,&
!                                                 &                 cmasvegcgat,veghghtgat, rootdpthgat,alvsctmgat,&
!                                                 &                     alirctmgat, paicgat,  slaicgat )
!
!                                             call ctems1(gleafmasrow,bleafmasrow,stemmassrow,rootmassrow,&
!                                                 &      fcancmxrow,ZBTWROT,DLZWROT,SDEPROT,ailcgrow,ailcbrow,&
!                                                 &      ailcrow,zolncrow,rmatcrow,rmatctemrow,slairow,&
!                                                 &      bmasvegrow,cmasvegcrow,veghghtrow,&
!                                                 &      rootdpthrow,alvsctmrow,alirctmrow,&
!                                                 &      paicrow,    slaicrow,&
!                                                 &      ilmos,jlmos,iwmos,jwmos,&
!                                                 &      nml,&
!                                                 &      gleafmasgat,bleafmasgat,stemmassgat,rootmassgat,&
!                                                 &      fcancmxgat,zbtwgat,dlzwgat,sdepgat,ailcggat,ailcbgat,&
!                                                 &      ailcgat,zolncgat,rmatcgat,rmatctemgat,slaigat,&
!                                                 &      bmasveggat,cmasvegcgat,veghghtgat,&
!                                                 &      rootdpthgat,alvsctmgat,alirctmgat,&
!                                                 &      paicgat,    slaicgat)
!!
!                                             !
!                                             !       ! FLAG test JM Dec 182015
!                                             !     Find the maximum daylength at this location for day 172 = June 21st - summer solstice.
!                                             do i = 1, nltest
!                                                 if (radjrow(1) > 0.) then
!                                                     call finddaylength(172.0, radjrow(1),dayl_maxrow(i)) !following rest of code, radjrow is always given index of 1 offline.
!                                                 else ! S. Hemi so do N.Hemi winter solstice Dec 21
!                                                     call finddaylength(355.0, radjrow(1),dayl_maxrow(i)) !following rest of code, radjrow is always given index of 1 offline.
!                                                 end if
!                                             end do
!                                         ! end FLAG test JM Dec 182015
!
!                                         endif   ! if (ctem_on)
!
!                                         !     ctem initial preparation done
!
!                                         !===================== CTEM ============================================ /
!
!                                         !     **** LAUNCH RUN. ****
!
!                                         N=0
!                                         NCOUNT=1
!                                         NDAY=86400/NINT(DELT)
!
!                                         !===================== CTEM ============================================ \
!
!                                         run_model=.true.
!                                         met_rewound=.false.
!
! 200                                 continue
!
!                                     !     start up the main model loop
!
!                                     do while (run_model)
!
!                                         !     if the met file has been rewound (due to cycling over the met data)
!                                         !     then we need to find the proper year in the file before we continue
!                                         !     on with the run
!                                         if (met_rewound) then
!                                             do while (iyear .lt. metcylyrst)
!                                                 do i=1,nltest
!                                                     !         this reads in one 30 min slice of met data, when it reaches
!                                                     !         the end of file it will go to label 999.
!                                                     read(12,5300,end=999) ihour,imin,iday,iyear,FSSROW(I),&
!                                                         &         FDLROW(i),PREROW(i),TAROW(i),QAROW(i),UVROW(i),PRESROW(i)
!                                                 enddo
!                                             enddo
!
!                                             !       back up one space in the met file so it is ready for the next readin
!                                             !       but only if it was read in during the loop above.
!                                             if (metcylyrst .ne. -9999) backspace(12)
!
!                                             ! Find the correct years of the accessory input files (wetlands, lightning...)
!                                             ! if needed
!                                             if (ctem_on) then
!                                                 if (obswetf) then
!                                                     do while (obswetyr .lt. metcylyrst)
!                                                         do i = 1,nltest ! Read into the first tile position
!                                                             read(16,*) obswetyr,(wetfrac_monrow(i,1,j),j=1,12)
!                                                             if (nmtest > 1) then
!                                                                 do m = 1,nmtest !spread grid values over all tiles for easier use in model
!                                                                     wetfrac_monrow(i,m,:) = wetfrac_monrow(i,1,:)
!                                                                 end do
!                                                             end if
!                                                         enddo
!                                                     enddo
!                                                     if (metcylyrst .ne. -9999) backspace(16)
!                                                 else
!                                                     wetfrac_monrow(:,:,:) = 0.0
!                                                 endif !obswetf
!
!                                                 if(obslght) then
!                                                     do while (obslghtyr .lt. metcylyrst)
!                                                         do i=1,nltest
!                                                             read(17,*) obslghtyr,(mlightngrow(i,1,j),j=1,12) ! read into the first tile
!                                                             if (nmtest > 1) then
!                                                                 do m = 2,nmtest !spread grid values over all tiles for easier use in model
!                                                                     mlightngrow(i,m,:) = mlightngrow(i,1,:)
!                                                                 end do
!                                                             end if
!                                                         end do
!                                                     end do
!                                                     if (metcylyrst .ne. -9999) backspace(17)
!                                                 end if
!
!                                             endif ! ctem_on
!
!                                             met_rewound = .false.
!
!                                         endif !met_rewound
!
!                                         !===================== CTEM ============================================ /
!                                         !
!                                         !     * READ IN METEOROLOGICAL FORCING DATA FOR CURRENT TIME STEP;
!                                         !     * CALCULATE SOLAR ZENITH ANGLE AND COMPONENTS OF INCOMING SHORT-
!                                         !     * WAVE RADIATION FLUX; ESTIMATE FLUX PARTITIONS IF NECESSARY.
!                                         !
!                                         N=N+1
!
!                                         DO 250 I=1,NLTEST
!                                             !         THIS READS IN ONE 30 MIN SLICE OF MET DATA, WHEN IT REACHES
!                                             !         THE END OF FILE IT WILL GO TO 999.
!                                             READ(12,5300,END=999) IHOUR,IMIN,IDAY,IYEAR,FSSROW(I),&
!                                                 &        FDLROW(I),PREROW(I),TAROW(I),QAROW(I),UVROW(I),PRESROW(I)
!
!                                             !===================== CTEM ============================================ \
!                                             !         Assign the met climate year to climiyear
!                                             climiyear = iyear
!
!                                             !         If in a transient_run that has to cycle over MET then change
!                                             !         the iyear here:
!                                             if (transient_run .and. cyclemet) then
!                                                 iyear = iyear - (metcylyrst - trans_startyr)
!                                             end if
!                                             !
!                                             if(lopcount .gt. 1) then
!                                                 if (cyclemet) then
!                                                     iyear=iyear + nummetcylyrs*(lopcount-1)
!                                                 else
!                                                     iyear=iyear + ncyear*(lopcount-1)
!                                                 end if
!                                             endif   ! lopcount .gt. 1
!
!                                             !         write(*,*)'year=',iyear,'day=',iday,' hour=',ihour,' min=',imin
!                                             !===================== CTEM ============================================ /
!
!                                             FSVHROW(I)=0.5*FSSROW(I)
!                                             FSIHROW(I)=0.5*FSSROW(I)
!                                             TAROW(I)=TAROW(I)+TFREZ
!                                             ULROW(I)=UVROW(I)
!                                             VLROW(I)=0.0
!                                             VMODROW(I)=UVROW(I)
!
!                                             !In the new four-band albedo calculation for snow, the incoming
!                                             ! radiation for snow or bare soil is now passed into TSOLVE via this new array:
!                                             FSSBROL(I,1)=FSVHROW(I)
!                                             FSSBROL(I,2)=FSIHROW(I)
!
! 250                                     CONTINUE
!
!                                         !
!                                         DAY=REAL(IDAY)+(REAL(IHOUR)+REAL(IMIN)/60.)/24.
!                                         DECL=SIN(2.*PI*(284.+DAY)/365.)*23.45*PI/180.
!                                         HOUR=(REAL(IHOUR)+REAL(IMIN)/60.)*PI/12.-PI
!                                         COSZ=SIN(RADJROW(1))*SIN(DECL)+COS(RADJROW(1))*COS(DECL)*COS(HOUR)
!
!                                         DO 300 I=1,NLTEST
!                                             CSZROW(I)=SIGN(MAX(ABS(COSZ),1.0E-3),COSZ)
!                                             IF(PREROW(I).GT.0.) THEN
!                                                 XDIFFUS(I)=1.0
!                                             ELSE
!                                                 XDIFFUS(I)=MAX(0.0,MIN(1.0-0.9*COSZ,1.0))
!                                             ENDIF
!                                             FCLOROW(I)=XDIFFUS(I)
! 300                                     CONTINUE
!                                         !
!                                         !===================== CTEM ============================================ \
!                                         !
!                                         ! If needed, read in the accessory input files (popd, wetlands, lightining...)
!                                         if (iday.eq.1.and.ihour.eq.0.and.imin.eq.0) then
!
!                                             if (ctem_on) then
!                                                 do i=1,nltest
!                                                     if (obswetf) then
!                                                         ! FLAG note that this will be read in, regardless of the iyear, if the
!                                                         ! obswetf flag is true. This means you have to be restarting from a run
!                                                         ! that ends the year prior to the first year in this file.
!                                                         ! Read into the first tile position
!                                                         read(16,*,end=1001) obswetyr,&
!                                                             &                               (wetfrac_monrow(i,1,j),j=1,12)
!                                                         if (nmtest > 1) then
!                                                             do m = 2,nmtest !spread grid values over all tiles for easier use in model
!                                                                 wetfrac_monrow(i,m,:) = wetfrac_monrow(i,1,:)
!                                                             end do
!                                                         end if
!                                                     else
!                                                         wetfrac_monrow(:,:,:) = 0.0
!                                                     endif !obswetf
!
!                                                     if(obslght) then
!                                                         ! FLAG note that this will be read in, regardless of the iyear, if the
!                                                         ! obswetf flag is true. This means you have to be restarting from a run
!                                                         ! that ends the year prior to the first year in this file.
!                                                         read(17,*,end=312) obslghtyr,(mlightngrow(i,1,j),j=1,12) ! read into the first tile
!                                                         if (nmtest > 1) then
!                                                             do m = 2,nmtest !spread grid values over all tiles for easier use in model
!                                                                 mlightngrow(i,m,:) = mlightngrow(i,1,:)
!                                                             end do
!                                                         end if
! 312                                                 continue !if end of file, just keep using the last year of lighting data.
!                                                 end if !obslight
!                                             end do
!                                         endif ! ctem_on
!
!                                         !         If popdon=true, calculate fire extinguishing probability and
!                                         !         probability of fire due to human causes from population density
!                                         !         input data. In disturb.f90 this will overwrite extnprobrow
!                                         !         and prbfrhucgrd that are read in from the .ctm file. Set
!                                         !         cypopyr = -9999 when we don't want to cycle over the popd data
!                                         !         so this allows us to grab a new value each year.
!
!                                         if(popdon .and. transient_run) then
!                                             do while (popyr .lt. iyear)
!                                                 do i=1,nltest
!                                                     read(13,5301,end=999) popyr,popdinrow(i,1) !place it in the first tile
!                                                     if (nmtest > 1) then
!                                                         do m = 2, nmtest
!                                                             popdinrow(i,m) = popdinrow(i,1) !spread this value over all tiles
!                                                         end do
!                                                     end if
!                                                 enddo
!                                             enddo
!                                         endif
!
!                                         !         If co2on is true, read co2concin from input datafile and
!                                         !         overwrite co2concrow, otherwise set to constant value.
!                                         !         Same applies to CH4.
!
!                                         if(co2on .or. ch4on) then
!                                             if (transient_run) then
!                                                 testyr = iyear
!                                                 do while (co2yr .lt. testyr)
!                                                     do i=1,nltest
!                                                         read(14,*,end=999) co2yr,co2concin,ch4concin
!                                                         do m=1,nmtest
!                                                             if (co2on) co2concrow(i,m)=co2concin
!                                                             if (ch4on) ch4concrow(i,m)=ch4concin
!                                                         enddo
!                                                     enddo
!                                                 enddo !co2yr < testyr
!                                             else ! still spinning but you apparently want the CO2 to move forward with time
!                                                 ! we assume the year you want to start from here is trans_startyr
!                                                 testyr = trans_startyr
!                                                 ! Now make sure we end up starting from the testyr
!                                                 if (co2yr .lt. testyr) then
!                                                     do while (co2yr .lt. testyr)
!                                                         do i=1,nltest
!                                                             read(14,*,end=999) co2yr,co2concin,ch4concin
!                                                             do m=1,nmtest
!                                                                 if (co2on) co2concrow(i,m)=co2concin
!                                                                 if (ch4on) ch4concrow(i,m)=ch4concin
!                                                             enddo
!                                                         enddo
!                                                     enddo !co2yr < testyr
!                                                 else ! years beyond the first, just go up in years without paying attention to iyear (since it is cycling)
!                                                     do i=1,nltest
!                                                         read(14,*,end=999) co2yr,co2concin,ch4concin
!                                                         do m=1,nmtest
!                                                             if (co2on) co2concrow(i,m)=co2concin
!                                                             if (ch4on) ch4concrow(i,m)=ch4concin
!                                                         enddo
!                                                     enddo
!                                                 end if
!                                             end if !transient_run or not
!                                         end if !co2 or ch4on
!
!                                         if (.not. co2on .or. .not. ch4on) then !constant co2 or ch4
!                                             do i=1,nltest
!                                                 do m=1,nmtest
!                                                     if (.not. co2on) co2concrow(i,m)=setco2conc
!                                                     if (.not. co2on) ch4concrow(i,m)=setch4conc
!                                                 enddo
!                                             enddo
!                                         endif
!
!                                         !         If lnduseon is true, read in the luc data now
!
!                                         if (ctem_on .and. lnduseon .and. transient_run) then
!
!                                             call readin_luc(iyear,nmtest,nltest,lucyr,&
!                                                 &                   nfcancmxrow,pfcancmxrow,reach_eof,compete,&
!                                                 &                   onetile_perPFT)
!                                             if (reach_eof) goto 999
!
!                                         else ! lnduseon = false or met is cycling in a spin up run
!
!                                             !         Land use is not on or the met data is being cycled, so the
!                                             !         pfcancmx value is also the nfcancmx value.
!
!                                             nfcancmxrow=pfcancmxrow
!
!                                         endif ! lnduseon/cyclemet
!
!                                     endif   ! at the first day of each year i.e.
!                                     !             ! if (iday.eq.1.and.ihour.eq.0.and.imin.eq.0)
!
!                                     !       ! FLAG test JM Dec 182015
!                                     if (ihour.eq.0.and.imin.eq.0) then ! first time step of the day
!                                         ! Find the daylength of this day
!                                         do i = 1, nltest
!                                             call finddaylength(real(iday), radjrow(1), daylrow(i)) !following rest of code, radjrow is always given index of 1 offline.
!                                         end do
!                                     end if
!                                     ! end FLAG test JM Dec 182015
!
!
!                                     !===================== CTEM ============================================ /
!                                     !
!                                     CALL CLASSI(VPDROW,TADPROW,PADRROW,RHOAROW,RHSIROW,&
!                                         &            RPCPROW,TRPCROW,SPCPROW,TSPCROW,TAROW,QAROW,&
!                                         &            PREROW,RPREROW,SPREROW,PRESROW,&
!                                         &            IPCP,NLAT,1,NLTEST)
!
!                                     !
!                                     CUMSNO=CUMSNO+SPCPROW(1)*RHSIROW(1)*DELT
!                                     !
!                                     CALL GATPREP(ILMOS,JLMOS,IWMOS,JWMOS,&
!                                         &             NML,NMW,GCROW,FAREROT,MIDROT,&
!                                         &             NLAT,NMOS,ILG,1,NLTEST,NMTEST)
!                                     !
!                                     CALL CLASSG (TBARGAT,THLQGAT,THICGAT,TPNDGAT,ZPNDGAT,&
!                                         &             TBASGAT,ALBSGAT,TSNOGAT,RHOSGAT,SNOGAT,&
!                                         &             TCANGAT,RCANGAT,SCANGAT,GROGAT, CMAIGAT,&
!                                         &             FCANGAT,LNZ0GAT,ALVCGAT,ALICGAT,PAMXGAT,&
!                                         &             PAMNGAT,CMASGAT,ROOTGAT,RSMNGAT,QA50GAT,&
!                                         &             VPDAGAT,VPDBGAT,PSGAGAT,PSGBGAT,PAIDGAT,&
!                                         &             HGTDGAT,ACVDGAT,ACIDGAT,TSFSGAT,WSNOGAT,&
!                                         &             THPGAT, THRGAT, THMGAT, BIGAT,  PSISGAT,&
!                                         &             GRKSGAT,THRAGAT,HCPSGAT,TCSGAT, IGDRGAT,&
!                                         &             THFCGAT,THLWGAT,PSIWGAT,DLZWGAT,ZBTWGAT,&
!                                         &             VMODGAT,ZSNLGAT,ZPLGGAT,ZPLSGAT,TACGAT,&
!                                         &             QACGAT,DRNGAT, XSLPGAT,GRKFGAT,WFSFGAT,&
!                                         &             WFCIGAT,ALGWVGAT,ALGWNGAT,ALGDVGAT,ALGDNGAT,&
!                                         &             ALGWGAT,ALGDGAT,ASVDGAT,ASIDGAT,AGVDGAT,&
!                                         &             AGIDGAT,ISNDGAT,RADJGAT,ZBLDGAT,Z0ORGAT,&
!                                         &             ZRFMGAT,ZRFHGAT,ZDMGAT, ZDHGAT, FSVHGAT,&
!                                         &             FSIHGAT,FSDBGAT,FSFBGAT,FSSBGAT,CSZGAT,&
!                                         &             FSGGAT, FLGGAT, FDLGAT, ULGAT,  VLGAT,&
!                                         &             TAGAT,  QAGAT,  PRESGAT,PREGAT, PADRGAT,&
!                                         &             VPDGAT, TADPGAT,RHOAGAT,RPCPGAT,TRPCGAT,&
!                                         &             SPCPGAT,TSPCGAT,RHSIGAT,FCLOGAT,DLONGAT,&
!                                         &             GGEOGAT,GUSTGAT,REFGAT, BCSNGAT,DEPBGAT,&
!                                         &             DLATGAT,&
!                                         &             ILMOS,JLMOS,&
!                                         &             NML,NLAT,NTLD,NMOS,ILG,IGND,ICAN,ICAN+1,NBS,&
!                                         &             TBARROT,THLQROT,THICROT,TPNDROT,ZPNDROT,&
!                                         &             TBASROT,ALBSROT,TSNOROT,RHOSROT,SNOROT,&
!                                         &             TCANROT,RCANROT,SCANROT,GROROT, CMAIROT,&
!                                         &             FCANROT,LNZ0ROT,ALVCROT,ALICROT,PAMXROT,&
!                                         &             PAMNROT,CMASROT,ROOTROT,RSMNROT,QA50ROT,&
!                                         &             VPDAROT,VPDBROT,PSGAROT,PSGBROT,PAIDROT,&
!                                         &             HGTDROT,ACVDROT,ACIDROT,TSFSROT,WSNOROT,&
!                                         &             THPROT, THRROT, THMROT, BIROT,  PSISROT,&
!                                         &             GRKSROT,THRAROT,HCPSROT,TCSROT, IGDRROT,&
!                                         &             THFCROT,THLWROT,PSIWROT,DLZWROT,ZBTWROT,&
!                                         &             VMODROW,ZSNLROT,ZPLGROT,ZPLSROT,TACROT,&
!                                         &             QACROT,DRNROT, XSLPROT,GRKFROT,WFSFROT,&
!                                         &             WFCIROT,ALGWVROT,ALGWNROT,ALGDVROT,ALGDNROT,&
!                                         &             ALGWROT,ALGDROT,ASVDROT,ASIDROT,AGVDROT,&
!                                         &             AGIDROT,ISNDROT,RADJROW,ZBLDROW,Z0ORROW,&
!                                         &             ZRFMROW,ZRFHROW,ZDMROW, ZDHROW, FSVHROW,&
!                                         &             FSIHROW,FSDBROL,FSFBROL,FSSBROL,CSZROW,&
!                                         &             FSGROL, FLGROL, FDLROW, ULROW,  VLROW,&
!                                         &             TAROW,  QAROW,  PRESROW,PREROW, PADRROW,&
!                                         &             VPDROW, TADPROW,RHOAROW,RPCPROW,TRPCROW,&
!                                         &             SPCPROW,TSPCROW,RHSIROW,FCLOROW,DLONROW,&
!                                         &             GGEOROW,GUSTROL,REFROT, BCSNROT,DEPBROW,&
!                                         &             DLATROW)
!                                     !
!                                     !    * INITIALIZATION OF DIAGNOSTIC VARIABLES SPLIT OUT OF CLASSG
!                                     !    * FOR CONSISTENCY WITH GCM APPLICATIONS.
!                                     !
!                                     DO 330 K=1,ILG
!                                         CDHGAT (K)=0.0
!                                         CDMGAT (K)=0.0
!                                         HFSGAT (K)=0.0
!                                         TFXGAT (K)=0.0
!                                         QEVPGAT(K)=0.0
!                                         QFSGAT (K)=0.0
!                                         QFXGAT (K)=0.0
!                                         PETGAT (K)=0.0
!                                         GAGAT  (K)=0.0
!                                         EFGAT  (K)=0.0
!                                         GTGAT  (K)=0.0
!                                         QGGAT  (K)=0.0
!                                         ALVSGAT(K)=0.0
!                                         ALIRGAT(K)=0.0
!                                         SFCTGAT(K)=0.0
!                                         SFCUGAT(K)=0.0
!                                         SFCVGAT(K)=0.0
!                                         SFCQGAT(K)=0.0
!                                         FSNOGAT(K)=0.0
!                                         FSGVGAT(K)=0.0
!                                         FSGSGAT(K)=0.0
!                                         FSGGGAT(K)=0.0
!                                         FLGVGAT(K)=0.0
!                                         FLGSGAT(K)=0.0
!                                         FLGGGAT(K)=0.0
!                                         HFSCGAT(K)=0.0
!                                         HFSSGAT(K)=0.0
!                                         HFSGGAT(K)=0.0
!                                         HEVCGAT(K)=0.0
!                                         HEVSGAT(K)=0.0
!                                         HEVGGAT(K)=0.0
!                                         HMFCGAT(K)=0.0
!                                         HMFNGAT(K)=0.0
!                                         HTCCGAT(K)=0.0
!                                         HTCSGAT(K)=0.0
!                                         PCFCGAT(K)=0.0
!                                         PCLCGAT(K)=0.0
!                                         PCPNGAT(K)=0.0
!                                         PCPGGAT(K)=0.0
!                                         QFGGAT (K)=0.0
!                                         QFNGAT (K)=0.0
!                                         QFCFGAT(K)=0.0
!                                         QFCLGAT(K)=0.0
!                                         ROFGAT (K)=0.0
!                                         ROFOGAT(K)=0.0
!                                         ROFSGAT(K)=0.0
!                                         ROFBGAT(K)=0.0
!                                         TROFGAT(K)=0.0
!                                         TROOGAT(K)=0.0
!                                         TROSGAT(K)=0.0
!                                         TROBGAT(K)=0.0
!                                         ROFCGAT(K)=0.0
!                                         ROFNGAT(K)=0.0
!                                         ROVGGAT(K)=0.0
!                                         WTRCGAT(K)=0.0
!                                         WTRSGAT(K)=0.0
!                                         WTRGGAT(K)=0.0
!                                         DRGAT  (K)=0.0
! 330                                 CONTINUE
!                                     !
!                                     DO 334 L=1,IGND
!                                         DO 332 K=1,ILG
!                                             HMFGGAT(K,L)=0.0
!                                             HTCGAT (K,L)=0.0
!                                             QFCGAT (K,L)=0.0
!                                             GFLXGAT(K,L)=0.0
! 332                                     CONTINUE
! 334                                 CONTINUE
!                                     !
!                                     DO 340 M=1,50
!                                         DO 338 L=1,6
!                                             DO 336 K=1,NML
!                                                 ITCTGAT(K,L,M)=0
! 336                                         CONTINUE
! 338                                     CONTINUE
! 340                                 CONTINUE
!                                     !
!                                     !========================================================================
!                                     !
!                                     CALL CLASSZ (0,      CTVSTP, CTSSTP, CT1STP, CT2STP, CT3STP,&
!                                         &             WTVSTP, WTSSTP, WTGSTP,&
!                                         &             FSGVGAT,FLGVGAT,HFSCGAT,HEVCGAT,HMFCGAT,HTCCGAT,&
!                                         &             FSGSGAT,FLGSGAT,HFSSGAT,HEVSGAT,HMFNGAT,HTCSGAT,&
!                                         &             FSGGGAT,FLGGGAT,HFSGGAT,HEVGGAT,HMFGGAT,HTCGAT,&
!                                         &             PCFCGAT,PCLCGAT,QFCFGAT,QFCLGAT,ROFCGAT,WTRCGAT,&
!                                         &             PCPNGAT,QFNGAT, ROFNGAT,WTRSGAT,PCPGGAT,QFGGAT,&
!                                         &             QFCGAT, ROFGAT, WTRGGAT,CMAIGAT,RCANGAT,SCANGAT,&
!                                         &             TCANGAT,SNOGAT, WSNOGAT,TSNOGAT,THLQGAT,THICGAT,&
!                                         &             HCPSGAT,THPGAT, DLZWGAT,TBARGAT,ZPNDGAT,TPNDGAT,&
!                                         &             DELZ,   FCS,    FGS,    FC,     FG,&
!                                         &             1,      NML,    ILG,    IGND,   N    )
!                                     !
!                                     !========================================================================
!                                     !
!                                     !===================== CTEM ============================================ \
!                                     !
!                                     call ctemg2(fcancmxgat,rmatcgat,zolncgat,paicgat,&
!                                         &      ailcgat,     ailcggat,    cmasvegcgat,  slaicgat,&
!                                         &      ailcgsgat,   fcancsgat,   fcancgat,     rmatctemgat,&
!                                         &      co2concgat,  co2i1cggat,  co2i1csgat,   co2i2cggat,&
!                                         &      co2i2csgat,  xdiffusgat,  slaigat,      cfluxcggat,&
!                                         &      cfluxcsgat,  ancsveggat,  ancgveggat,   rmlcsveggat,&
!                                         &      rmlcgveggat, canresgat,   sdepgat,      ch4concgat,&
!                                         &      sandgat,     claygat,     orgmgat,&
!                                         &      anveggat,    rmlveggat,   tcanoaccgat_t,tbaraccgat_t,&
!                                         &      uvaccgat_t,  vvaccgat_t,  mlightnggat,  prbfrhucgat,&
!                                         &      extnprobgat, stdalngat,   pfcancmxgat,  nfcancmxgat,&
!                                         &      stemmassgat, rootmassgat, litrmassgat,  gleafmasgat,&
!                                         &      bleafmasgat, soilcmasgat, ailcbgat,     flhrlossgat,&
!                                         &      pandaysgat,  lfstatusgat, grwtheffgat,  lystmmasgat,&
!                                         &      lyrotmasgat, tymaxlaigat, vgbiomasgat,  gavgltmsgat,&
!                                         &      stmhrlosgat, bmasveggat,  colddaysgat,  rothrlosgat,&
!                                         &      alvsctmgat,  alirctmgat,  gavglaigat,   nppgat,&
!                                         &      nepgat,      hetroresgat, autoresgat,   soilcrespgat,&
!                                         &      rmgat,       rggat,       nbpgat,       litresgat,&
!                                         &      socresgat,   gppgat,      dstcemlsgat,  litrfallgat,&
!                                         &      humiftrsgat, veghghtgat,  rootdpthgat,  rmlgat,&
!                                         &      rmsgat,      rmrgat,      tltrleafgat,  tltrstemgat,&
!                                         &      tltrrootgat, leaflitrgat, roottempgat,  afrleafgat,&
!                                         &      afrstemgat,  afrrootgat,  wtstatusgat,  ltstatusgat,&
!                                         &      burnfracgat, smfuncveggat, lucemcomgat,  lucltringat,&
!                                         &      lucsocingat, nppveggat,   dstcemls3gat, popdingat,&
!                                         &      faregat,     gavgscmsgat, rmlvegaccgat, pftexistgat,&
!                                         &      rmsveggat,   rmrveggat,   rgveggat,    vgbiomas_veggat,&
!                                         &      gppveggat,   nepveggat,   ailcmingat,   ailcmaxgat,&
!                                         &      emit_co2gat,  emit_cogat, emit_ch4gat,  emit_nmhcgat,&
!                                         &      emit_h2gat,   emit_noxgat,emit_n2ogat,  emit_pm25gat,&
!                                         &      emit_tpmgat,  emit_tcgat, emit_ocgat,   emit_bcgat,&
!                                         &      btermgat,     ltermgat,   mtermgat, daylgat,dayl_maxgat,&
!                                         &      nbpveggat,    hetroresveggat, autoresveggat,litresveggat,&
!                                         &      soilcresveggat, burnvegfgat, pstemmassgat, pgleafmassgat,&
!                                         &      ch4wet1gat, ch4wet2gat,  slopefracgat, wetfrac_mongat,&
!                                         &      wetfdyngat, ch4dyn1gat,  ch4dyn2gat, ch4soillsgat,&
!                                         &      twarmmgat,    tcoldmgat,     gdd5gat,&
!                                         &      ariditygat, srplsmongat,  defctmongat, anndefctgat,&
!                                         &      annsrplsgat,   annpcpgat,  dry_season_lengthgat,&
!                                         &      !
!                                         &      ilmos,       jlmos,       iwmos,        jwmos,&
!                                         &      nml,      fcancmxrow,  rmatcrow,    zolncrow,  paicrow,&
!                                         &      ailcrow,     ailcgrow,    cmasvegcrow,  slaicrow,&
!                                         &      ailcgsrow,   fcancsrow,   fcancrow,     rmatctemrow,&
!                                         &      co2concrow,  co2i1cgrow,  co2i1csrow,   co2i2cgrow,&
!                                         &      co2i2csrow,  xdiffus,     slairow,      cfluxcgrow,&
!                                         &      cfluxcsrow,  ancsvegrow,  ancgvegrow,   rmlcsvegrow,&
!                                         &      rmlcgvegrow, canresrow,   SDEPROT,      ch4concrow,&
!                                         &      SANDROT,     CLAYROT,     ORGMROT,&
!                                         &      anvegrow,    rmlvegrow,   tcanoaccrow_m,tbaraccrow_m,&
!                                         &      uvaccrow_m,  vvaccrow_m,  mlightngrow,  prbfrhucrow,&
!                                         &      extnprobrow, stdalnrow,   pfcancmxrow,  nfcancmxrow,&
!                                         &      stemmassrow, rootmassrow, litrmassrow,  gleafmasrow,&
!                                         &      bleafmasrow, soilcmasrow, ailcbrow,     flhrlossrow,&
!                                         &      pandaysrow,  lfstatusrow, grwtheffrow,  lystmmasrow,&
!                                         &      lyrotmasrow, tymaxlairow, vgbiomasrow,  gavgltmsrow,&
!                                         &      stmhrlosrow, bmasvegrow,  colddaysrow,  rothrlosrow,&
!                                         &      alvsctmrow,  alirctmrow,  gavglairow,   npprow,&
!                                         &      neprow,      hetroresrow, autoresrow,   soilcresprow,&
!                                         &      rmrow,       rgrow,       nbprow,       litresrow,&
!                                         &      socresrow,   gpprow,      dstcemlsrow,  litrfallrow,&
!                                         &      humiftrsrow, veghghtrow,  rootdpthrow,  rmlrow,&
!                                         &      rmsrow,      rmrrow,      tltrleafrow,  tltrstemrow,&
!                                         &      tltrrootrow, leaflitrrow, roottemprow,  afrleafrow,&
!                                         &      afrstemrow,  afrrootrow,  wtstatusrow,  ltstatusrow,&
!                                         &      burnfracrow, smfuncvegrow, lucemcomrow,  lucltrinrow,&
!                                         &      lucsocinrow, nppvegrow,   dstcemls3row, popdinrow,&
!                                         &      FAREROT,     gavgscmsrow, rmlvegaccrow, pftexistrow,&
!                                         &      rmsvegrow,   rmrvegrow,   rgvegrow,    vgbiomas_vegrow,&
!                                         &      gppvegrow,   nepvegrow,   ailcminrow,   ailcmaxrow,&
!                                         &      emit_co2row,  emit_corow, emit_ch4row,  emit_nmhcrow,&
!                                         &      emit_h2row,   emit_noxrow,emit_n2orow,  emit_pm25row,&
!                                         &      emit_tpmrow,  emit_tcrow, emit_ocrow,   emit_bcrow,&
!                                         &      btermrow,     ltermrow,   mtermrow, daylrow, dayl_maxrow,&
!                                         &      nbpvegrow,    hetroresvegrow, autoresvegrow,litresvegrow,&
!                                         &      soilcresvegrow, burnvegfrow, pstemmassrow, pgleafmassrow,&
!                                         &      ch4wet1row, ch4wet2row,  slopefracrow, wetfrac_monrow,&
!                                         &      wetfdynrow, ch4dyn1row, ch4dyn2row, ch4soillsrow,&
!                                         &      twarmmrow,    tcoldmrow,     gdd5row,&
!                                         &      aridityrow, srplsmonrow,  defctmonrow, anndefctrow,&
!                                         &      annsrplsrow,   annpcprow,  dry_season_lengthrow)
!                                     !
!                                     !===================== CTEM ============================================ /
!                                     !
!                                     !-----------------------------------------------------------------------
!                                     !     * ALBEDO AND TRANSMISSIVITY CALCULATIONS; GENERAL VEGETATION
!                                     !     * CHARACTERISTICS.
!
!                                     !     * ADAPTED TO COUPLING OF CLASS3.6 AND CTEM by including: zolnc,
!                                     !     * cmasvegc, alvsctm, alirctm in the arguments.
!                                     !
!                                     CALL CLASSA    (FC,     FG,     FCS,    FGS,    ALVSCN, ALIRCN,&
!                                         &                ALVSG,  ALIRG,  ALVSCS, ALIRCS, ALVSSN, ALIRSN,&
!                                         &                ALVSGC, ALIRGC, ALVSSC, ALIRSC, TRVSCN, TRIRCN,&
!                                         &                TRVSCS, TRIRCS, FSVF,   FSVFS,&
!                                         &                RAICAN, RAICNS, SNOCAN, SNOCNS, FRAINC, FSNOWC,&
!                                         &                FRAICS, FSNOCS, DISP,   DISPS,  ZOMLNC, ZOMLCS,&
!                                         &                ZOELNC, ZOELCS, ZOMLNG, ZOMLNS, ZOELNG, ZOELNS,&
!                                         &                CHCAP,  CHCAPS, CMASSC, CMASCS, CWLCAP, CWFCAP,&
!                                         &                CWLCPS, CWFCPS, RC,     RCS,    RBCOEF, FROOT,&
!                                         &                FROOTS, ZPLIMC, ZPLIMG, ZPLMCS, ZPLMGS, ZSNOW,&
!                                         &                WSNOGAT,ALVSGAT,ALIRGAT,HTCCGAT,HTCSGAT,HTCGAT,&
!                                         &                ALTG,   ALSNO,  TRSNOWC,TRSNOWG,&
!                                         &                WTRCGAT,WTRSGAT,WTRGGAT,CMAIGAT,FSNOGAT,&
!                                         &                FCANGAT,LNZ0GAT,ALVCGAT,ALICGAT,PAMXGAT,PAMNGAT,&
!                                         &                CMASGAT,ROOTGAT,RSMNGAT,QA50GAT,VPDAGAT,VPDBGAT,&
!                                         &                PSGAGAT,PSGBGAT,PAIDGAT,HGTDGAT,ACVDGAT,ACIDGAT,&
!                                         &                ASVDGAT,ASIDGAT,AGVDGAT,AGIDGAT,ALGWGAT,ALGDGAT,&
!                                         &                ALGWVGAT,ALGWNGAT,ALGDVGAT,ALGDNGAT,&
!                                         &                THLQGAT,THICGAT,TBARGAT,RCANGAT,SCANGAT,TCANGAT,&
!                                         &                GROGAT, SNOGAT, TSNOGAT,RHOSGAT,ALBSGAT,ZBLDGAT,&
!                                         &                Z0ORGAT,ZSNLGAT,ZPLGGAT,ZPLSGAT,&
!                                         &                FCLOGAT,TAGAT,  VPDGAT, RHOAGAT,CSZGAT,&
!                                         &                FSDBGAT,FSFBGAT,REFGAT, BCSNGAT,&
!                                         &                FSVHGAT,RADJGAT,DLONGAT,RHSIGAT,DELZ,   DLZWGAT,&
!                                         &                ZBTWGAT,THPGAT, THMGAT, PSISGAT,BIGAT,  PSIWGAT,&
!                                         &                HCPSGAT,ISNDGAT,&
!                                         &                FCANCMXGAT,ICC,ctem_on,RMATCGAT,ZOLNCGAT,&
!                                         &                CMASVEGCGAT,AILCGAT,PAICGAT,L2MAX, NOL2PFTS,&
!                                         &                SLAICGAT,AILCGGAT,AILCGSGAT,FCANCGAT,FCANCSGAT,&
!                                         &                IDAY,   ILG,    1,      NML,  NBS,&
!                                         &                JLAT,N, ICAN,   ICAN+1, IGND,   IDISP,  IZREF,&
!                                         &                IWF,    IPAI,   IHGT,   IALC,   IALS,   IALG,&
!                                         &                ISNOALB,IGRALB, alvsctmgat,alirctmgat )
!                                     !
!                                     !-----------------------------------------------------------------------
!                                     !          * SURFACE TEMPERATURE AND FLUX CALCULATIONS.
!
!                                     !          * ADAPTED TO COUPLING OF CLASS3.6 AND CTEM
!                                     !          * by including in the arguments: lfstatus
!                                     !
!                                     CALL CLASST     (TBARC,  TBARG,  TBARCS, TBARGS, THLIQC, THLIQG,&
!                                         &  THICEC, THICEG, HCPC,   HCPG,   TCTOPC, TCBOTC, TCTOPG, TCBOTG,&
!                                         &  GZEROC, GZEROG, GZROCS, GZROGS, G12C,   G12G,   G12CS,  G12GS,&
!                                         &  G23C,   G23G,   G23CS,  G23GS,  QFREZC, QFREZG, QMELTC, QMELTG,&
!                                         &  EVAPC,  EVAPCG, EVAPG,  EVAPCS, EVPCSG, EVAPGS, TCANO,  TCANS,&
!                                         &  RAICAN, SNOCAN, RAICNS, SNOCNS, CHCAP,  CHCAPS, TPONDC, TPONDG,&
!                                         &  TPNDCS, TPNDGS, TSNOCS, TSNOGS, WSNOCS, WSNOGS, RHOSCS, RHOSGS,&
!                                         &  ITCTGAT,CDHGAT, CDMGAT, HFSGAT, TFXGAT, QEVPGAT,QFSGAT,&
!                                         &  PETGAT, GAGAT,  EFGAT,  GTGAT,  QGGAT,&
!                                         &  SFCTGAT,SFCUGAT,SFCVGAT,SFCQGAT,SFRHGAT,&
!                                         &  GTBS,   SFCUBS, SFCVBS, USTARBS,&
!                                         &  FSGVGAT,FSGSGAT,FSGGGAT,FLGVGAT,FLGSGAT,FLGGGAT,&
!                                         &  HFSCGAT,HFSSGAT,HFSGGAT,HEVCGAT,HEVSGAT,HEVGGAT,HMFCGAT,HMFNGAT,&
!                                         &  HTCCGAT,HTCSGAT,HTCGAT, QFCFGAT,QFCLGAT,DRGAT,  WTABGAT,ILMOGAT,&
!                                         &  UEGAT,  HBLGAT, TACGAT, QACGAT, ZRFMGAT,ZRFHGAT,ZDMGAT, ZDHGAT,&
!                                         &  VPDGAT, TADPGAT,RHOAGAT,FSVHGAT,FSIHGAT,FDLGAT, ULGAT,  VLGAT,&
!                                         &  TAGAT,  QAGAT,  PADRGAT,FC,     FG,     FCS,    FGS,    RBCOEF,&
!                                         &  FSVF,   FSVFS,  PRESGAT,VMODGAT,ALVSCN, ALIRCN, ALVSG,  ALIRG,&
!                                         &  ALVSCS, ALIRCS, ALVSSN, ALIRSN, ALVSGC, ALIRGC, ALVSSC, ALIRSC,&
!                                         &  TRVSCN, TRIRCN, TRVSCS, TRIRCS, RC,     RCS,    WTRGGAT,QLWOGAT,&
!                                         &  FRAINC, FSNOWC, FRAICS, FSNOCS, CMASSC, CMASCS, DISP,   DISPS,&
!                                         &  ZOMLNC, ZOELNC, ZOMLNG, ZOELNG, ZOMLCS, ZOELCS, ZOMLNS, ZOELNS,&
!                                         &  TBARGAT,THLQGAT,THICGAT,TPNDGAT,ZPNDGAT,TBASGAT,TCANGAT,TSNOGAT,&
!                                         &  ZSNOW,  RHOSGAT,WSNOGAT,THPGAT, THRGAT, THMGAT, THFCGAT,THLWGAT,&
!                                         &  TRSNOWC,TRSNOWG,ALSNO,  FSSBGAT, FROOT, FROOTS,&
!                                         &  RADJGAT,PREGAT, HCPSGAT,TCSGAT, TSFSGAT,DELZ,   DLZWGAT,ZBTWGAT,&
!                                         &  FTEMP,  FVAP,   RIB,    ISNDGAT,&
!                                         &  AILCGGAT,  AILCGSGAT, FCANCGAT,FCANCSGAT,CO2CONCGAT,CO2I1CGGAT,&
!                                         &  CO2I1CSGAT,CO2I2CGGAT,CO2I2CSGAT,CSZGAT,XDIFFUSGAT,SLAIGAT,ICC,&
!                                         &  ctem_on,RMATCTEMGAT,FCANCMXGAT,L2MAX,  NOL2PFTS,CFLUXCGGAT,&
!                                         &  CFLUXCSGAT,ANCSVEGGAT,ANCGVEGGAT,RMLCSVEGGAT,RMLCGVEGGAT,&
!                                         &  TCSNOW,GSNOW,ITC,ITCG,ITG,    ILG,    1,NML,  JLAT,N, ICAN,&
!                                         &  IGND,   IZREF,  ISLFD,  NLANDCS,NLANDGS,NLANDC, NLANDG, NLANDI,&
!                                         &  NBS,    ISNOALB,lfstatusgat,daylgat, dayl_maxgat)
!                                     !
!                                     !-----------------------------------------------------------------------
!                                     !          * WATER BUDGET CALCULATIONS.
!                                     !
!
!                                     CALL CLASSW  (THLQGAT,THICGAT,TBARGAT,TCANGAT,RCANGAT,SCANGAT,&
!                                         &                  ROFGAT, TROFGAT,SNOGAT, TSNOGAT,RHOSGAT,ALBSGAT,&
!                                         &                  WSNOGAT,ZPNDGAT,TPNDGAT,GROGAT, TBASGAT,GFLXGAT,&
!                                         &                  PCFCGAT,PCLCGAT,PCPNGAT,PCPGGAT,QFCFGAT,QFCLGAT,&
!                                         &                  QFNGAT, QFGGAT, QFCGAT, HMFCGAT,HMFGGAT,HMFNGAT,&
!                                         &                  HTCCGAT,HTCSGAT,HTCGAT, ROFCGAT,ROFNGAT,ROVGGAT,&
!                                         &                  WTRSGAT,WTRGGAT,ROFOGAT,ROFSGAT,ROFBGAT,&
!                                         &                  TROOGAT,TROSGAT,TROBGAT,QFSGAT, QFXGAT, RHOAGAT,&
!                                         &                  TBARC,  TBARG,  TBARCS, TBARGS, THLIQC, THLIQG,&
!                                         &                  THICEC, THICEG, HCPC,   HCPG,   RPCPGAT,TRPCGAT,&
!                                         &                  SPCPGAT,TSPCGAT,PREGAT, TAGAT,  RHSIGAT,GGEOGAT,&
!                                         &                  FC,     FG,     FCS,    FGS,    TPONDC, TPONDG,&
!                                         &                  TPNDCS, TPNDGS, EVAPC,  EVAPCG, EVAPG,  EVAPCS,&
!                                         &                  EVPCSG, EVAPGS, QFREZC, QFREZG, QMELTC, QMELTG,&
!                                         &                  RAICAN, SNOCAN, RAICNS, SNOCNS, FSVF,    FSVFS,&
!                                         &                  CWLCAP, CWFCAP, CWLCPS, CWFCPS, TCANO,&
!                                         &                  TCANS,  CHCAP,  CHCAPS, CMASSC, CMASCS, ZSNOW,&
!                                         &                  GZEROC, GZEROG, GZROCS, GZROGS, G12C,   G12G,&
!                                         &                  G12CS,  G12GS,  G23C,   G23G,   G23CS,  G23GS,&
!                                         &                  TSNOCS, TSNOGS, WSNOCS, WSNOGS, RHOSCS, RHOSGS,&
!                                         &                  ZPLIMC, ZPLIMG, ZPLMCS, ZPLMGS, TSFSGAT,&
!                                         &                  TCTOPC, TCBOTC, TCTOPG, TCBOTG, FROOT,   FROOTS,&
!                                         &                  THPGAT, THRGAT, THMGAT, BIGAT,  PSISGAT,GRKSGAT,&
!                                         &                  THRAGAT,THFCGAT,DRNGAT, HCPSGAT,DELZ,&
!                                         &                  DLZWGAT,ZBTWGAT,XSLPGAT,GRKFGAT,WFSFGAT,WFCIGAT,&
!                                         &                  ISNDGAT,IGDRGAT,&
!                                         &                  IWF,    ILG,    1,      NML,    N,&
!                                         &                  JLAT,   ICAN,   IGND,   IGND+1, IGND+2,&
!                                         &                  NLANDCS,NLANDGS,NLANDC, NLANDG, NLANDI )
!
!                                     !========================================================================
!                                     !
!                                     CALL CLASSZ (1,      CTVSTP, CTSSTP, CT1STP, CT2STP, CT3STP,&
!                                         &             WTVSTP, WTSSTP, WTGSTP,&
!                                         &             FSGVGAT,FLGVGAT,HFSCGAT,HEVCGAT,HMFCGAT,HTCCGAT,&
!                                         &             FSGSGAT,FLGSGAT,HFSSGAT,HEVSGAT,HMFNGAT,HTCSGAT,&
!                                         &             FSGGGAT,FLGGGAT,HFSGGAT,HEVGGAT,HMFGGAT,HTCGAT,&
!                                         &             PCFCGAT,PCLCGAT,QFCFGAT,QFCLGAT,ROFCGAT,WTRCGAT,&
!                                         &             PCPNGAT,QFNGAT, ROFNGAT,WTRSGAT,PCPGGAT,QFGGAT,&
!                                         &             QFCGAT, ROFGAT, WTRGGAT,CMAIGAT,RCANGAT,SCANGAT,&
!                                         &             TCANGAT,SNOGAT, WSNOGAT,TSNOGAT,THLQGAT,THICGAT,&
!                                         &             HCPSGAT,THPGAT, DLZWGAT,TBARGAT,ZPNDGAT,TPNDGAT,&
!                                         &             DELZ,   FCS,    FGS,    FC,     FG,&
!                                         &             1,      NML,    ILG,    IGND,   N    )
!                                     !
!                                     !=======================================================================
!
!                                     !===================== CTEM ============================================ \
!                                     !
!                                     !     accumulate variables not already accumulated but which are required by
!                                     !     ctem.
!                                     !
!                                     if (ctem_on) then
!                                         do 700 i = 1, nml
!                                             !
!                                             alswacc_gat(i)=alswacc_gat(i)+alvsgat(i)*fsvhgat(i)
!                                             allwacc_gat(i)=allwacc_gat(i)+alirgat(i)*fsihgat(i)
!                                             fsinacc_gat(i)=fsinacc_gat(i)+FSSROW(1) ! FLAG! Do this offline only (since all tiles
!                                                                                     ! are the same in a gridcell and we run
!                                                                                     ! only one gridcell at a time. JM Feb 42016.
!                                             flinacc_gat(i)=flinacc_gat(i)+fdlgat(i)
!                                             flutacc_gat(i)=flutacc_gat(i)+sbc*gtgat(i)**4
!                                             pregacc_gat(i)=pregacc_gat(i)+pregat(i)*delt
!                                             !
!                                             fsnowacc_t(i)=fsnowacc_t(i)+fsnogat(i)
!                                             tcanoaccgat_t(i)=tcanoaccgat_t(i)+tcano(i)
!                                             tcansacc_t(i)=tcansacc_t(i)+tcans(i)
!                                             taaccgat_t(i)=taaccgat_t(i)+tagat(i)
!                                             vvaccgat_t(i)=vvaccgat_t(i)+ vlgat(i)
!                                             uvaccgat_t(i)=uvaccgat_t(i)+ulgat(i)
!                                             if (FSSROW(I) .gt. 0.) then
!                                                 altotacc_gat(i) = altotacc_gat(i) + (FSSROW(I)-&
!                                                     &                (FSGVGAT(I)+FSGSGAT(I)+FSGGGAT(I)))&
!                                                     &                /FSSROW(I)
!                                                 altotcount_ctm = altotcount_ctm + 1
!                                             end if
!                                             !
!                                             do 710 j=1,ignd
!                                                 tbaraccgat_t(i,j)=tbaraccgat_t(i,j)+tbargat(i,j)
!                                                 tbarcacc_t(i,j)=tbarcacc_t(i,j)+tbarc(i,j)
!                                                 tbarcsacc_t(i,j)=tbarcsacc_t(i,j)+tbarcs(i,j)
!                                                 tbargacc_t(i,j)=tbargacc_t(i,j)+tbarg(i,j)
!                                                 tbargsacc_t(i,j)=tbargsacc_t(i,j)+tbargs(i,j)
!                                                 thliqcacc_t(i,j)=thliqcacc_t(i,j)+thliqc(i,j)
!                                                 thliqgacc_t(i,j)=thliqgacc_t(i,j)+thliqg(i,j)
!                                                 thliqacc_t(i,j) = thliqacc_t(i,j) + THLQGAT(i,j)
!                                                 thicecacc_t(i,j)=thicecacc_t(i,j)+thicec(i,j)
! 710                                         continue
!                                             !
!                                             do 713 j = 1, icc
!                                                 ancsvgac_t(i,j)=ancsvgac_t(i,j)+ancsveggat(i,j)
!                                                 ancgvgac_t(i,j)=ancgvgac_t(i,j)+ancgveggat(i,j)
!                                                 rmlcsvga_t(i,j)=rmlcsvga_t(i,j)+rmlcsveggat(i,j)
!                                                 rmlcgvga_t(i,j)=rmlcgvga_t(i,j)+rmlcgveggat(i,j)
! 713                                         continue
!                                         !
! 700                                     continue
!                                     endif !if (ctem_on)
!                                     !
!                                     if(ncount.eq.nday) then
!                                         !
!                                         !         daily averages of accumulated variables for ctem
!                                         !
!                                         if (ctem_on) then
!
!                                             do 855 i=1,nml
!                                                 !
!                                                 !           net radiation and precipitation estimates for ctem's bioclim
!                                                 !
!                                                 if(fsinacc_gat(i).gt.0.0) then
!                                                     alswacc_gat(i)=alswacc_gat(i)/(fsinacc_gat(i)*0.5)
!                                                     allwacc_gat(i)=allwacc_gat(i)/(fsinacc_gat(i)*0.5)
!                                                 else
!                                                     alswacc_gat(i)=0.0
!                                                     allwacc_gat(i)=0.0
!                                                 endif
!                                                 !
!                                                 uvaccgat_t(i)=uvaccgat_t(i)/real(nday)
!                                                 vvaccgat_t(i)=vvaccgat_t(i)/real(nday)
!                                                 fsinacc_gat(i)=fsinacc_gat(i)/real(nday)
!                                                 flinacc_gat(i)=flinacc_gat(i)/real(nday)
!                                                 flutacc_gat(i)=flutacc_gat(i)/real(nday)
!                                                 !
!                                                 if (altotcount_ctm(i) > 0) then
!                                                     altotacc_gat(i)=altotacc_gat(i)/real(altotcount_ctm(i))
!                                                 else
!                                                     altotacc_gat(i)=0.
!                                                 end if
!                                                 fsstar_gat=fsinacc_gat(i)*(1.-altotacc_gat(i))
!                                                 flstar_gat=flinacc_gat(i)-flutacc_gat(i)
!                                                 netrad_gat(i)=fsstar_gat+flstar_gat
!                                                 preacc_gat(i)=pregacc_gat(i)
!                                                 !
!                                                 fsnowacc_t(i)=fsnowacc_t(i)/real(nday)
!                                                 tcanoaccgat_t(i)=tcanoaccgat_t(i)/real(nday)
!                                                 tcansacc_t(i)=tcansacc_t(i)/real(nday)
!                                                 taaccgat_t(i)=taaccgat_t(i)/real(nday)
!                                                 !
!                                                 do 831 j=1,ignd
!                                                     tbaraccgat_t(i,j)=tbaraccgat_t(i,j)/real(nday)
!                                                     tbarcacc_t(i,j) = tbaraccgat_t(i,j)
!                                                     tbarcsacc_t(i,j) = tbaraccgat_t(i,j)
!                                                     tbargacc_t(i,j) = tbaraccgat_t(i,j)
!                                                     tbargsacc_t(i,j) = tbaraccgat_t(i,j)
!                                                     !
!                                                     thliqcacc_t(i,j)=thliqcacc_t(i,j)/real(nday)
!                                                     thliqgacc_t(i,j)=thliqgacc_t(i,j)/real(nday)
!                                                     thliqacc_t(i,j)=thliqacc_t(i,j)/real(nday)
!                                                     thicecacc_t(i,j)=thicecacc_t(i,j)/real(nday)
! 831                                             continue
!                                                 !
!                                                 do 832 j = 1, icc
!                                                     ancsvgac_t(i,j)=ancsvgac_t(i,j)/real(nday)
!                                                     ancgvgac_t(i,j)=ancgvgac_t(i,j)/real(nday)
!                                                     rmlcsvga_t(i,j)=rmlcsvga_t(i,j)/real(nday)
!                                                     rmlcgvga_t(i,j)=rmlcgvga_t(i,j)/real(nday)
! 832                                             continue
!                                                 !
!                                                 !           pass on mean monthly lightning for the current month to ctem
!                                                 !           lightng(i)=mlightng(i,month)
!                                                 !
!                                                 !           in a very simple way try to interpolate monthly lightning to
!                                                 !           daily lightning
!                                                 !
!                                                 if(iday.ge.15.and.iday.le.45)then ! mid jan - mid feb
!                                                     month1=1
!                                                     month2=2
!                                                     xday=iday-15
!                                                 else if(iday.ge.46.and.iday.le.74)then ! mid feb - mid mar
!                                                     month1=2
!                                                     month2=3
!                                                     xday=iday-46
!                                                 else if(iday.ge.75.and.iday.le.105)then ! mid mar - mid apr
!                                                     month1=3
!                                                     month2=4
!                                                     xday=iday-75
!                                                 else if(iday.ge.106.and.iday.le.135)then ! mid apr - mid may
!                                                     month1=4
!                                                     month2=5
!                                                     xday=iday-106
!                                                 else if(iday.ge.136.and.iday.le.165)then ! mid may - mid june
!                                                     month1=5
!                                                     month2=6
!                                                     xday=iday-136
!                                                 else if(iday.ge.166.and.iday.le.196)then ! mid june - mid july
!                                                     month1=6
!                                                     month2=7
!                                                     xday=iday-166
!                                                 else if(iday.ge.197.and.iday.le.227)then ! mid july - mid aug
!                                                     month1=7
!                                                     month2=8
!                                                     xday=iday-197
!                                                 else if(iday.ge.228.and.iday.le.258)then ! mid aug - mid sep
!                                                     month1=8
!                                                     month2=9
!                                                     xday=iday-228
!                                                 else if(iday.ge.259.and.iday.le.288)then ! mid sep - mid oct
!                                                     month1=9
!                                                     month2=10
!                                                     xday=iday-259
!                                                 else if(iday.ge.289.and.iday.le.319)then ! mid oct - mid nov
!                                                     month1=10
!                                                     month2=11
!                                                     xday=iday-289
!                                                 else if(iday.ge.320.and.iday.le.349)then ! mid nov - mid dec
!                                                     month1=11
!                                                     month2=12
!                                                     xday=iday-320
!                                                 else if(iday.ge.350.or.iday.lt.14)then ! mid dec - mid jan
!                                                     month1=12
!                                                     month2=1
!                                                     xday=iday-350
!                                                     if(xday.lt.0)xday=iday
!                                                 endif
!                                                 !
!                                                 lightng(i)=mlightnggat(i,month1)+(real(xday)/30.0)*&
!                                                     &                 (mlightnggat(i,month2)-mlightnggat(i,month1))
!                                                 !
!                                                 if (obswetf) then
!                                                     wetfrac_presgat(i)=wetfrac_mongat(i,month1)+&
!                                                         &                 (real(xday)/30.0)*&
!                                                         &                 (wetfrac_mongat(i,month2)-&
!                                                         &                  wetfrac_mongat(i,month1))
!                                                 endif !obswetf
!
!                                             !
! 855                                         continue
!                                             !
!                                             !     Call Canadian Terrestrial Ecosystem Model which operates at a
!                                             !     daily time step, and uses daily accumulated values of variables
!                                             !     simulated by CLASS.
!                                             !
!                                             call ctem ( fcancmxgat, fsnowacc_t,    sandgat,    claygat,&
!                                                 &                      1,        nml,        iday,    radjgat,&
!                                                 &          tcanoaccgat_t,  tcansacc_t, tbarcacc_t,tbarcsacc_t,&
!                                                 &             tbargacc_t, tbargsacc_t, taaccgat_t,    dlzwgat,&
!                                                 &             ancsvgac_t,  ancgvgac_t, rmlcsvga_t, rmlcgvga_t,&
!                                                 &                zbtwgat, thliqcacc_t,thliqgacc_t,     deltat,&
!                                                 &             uvaccgat_t,  vvaccgat_t,    lightng,prbfrhucgat,&
!                                                 &            extnprobgat,   stdalngat,tbaraccgat_t,  popdon,&
!                                                 &               nol2pfts, pfcancmxgat, nfcancmxgat,  lnduseon,&
!                                                 &            thicecacc_t,     sdepgat,    spinfast,   todfrac,&
!                                                 &          compete,  netrad_gat,  preacc_gat,PSISGAT,grclarea,&
!                                                 &              popdingat,  dofire, dowetlands,obswetf, isndgat,&
!                                                 &          faregat,onetile_perPFT,wetfrac_presgat,slopefracgat,&
!                                                 &                  BIGAT,    THPGAT, thicegacc_t,currlat,&
!                                                 &             ch4concgat,      GRAV, RHOW, RHOICE,&
!                                                 &            !    -------------- inputs used by ctem are above this line ---------
!                                                 &            stemmassgat, rootmassgat, litrmassgat, gleafmasgat,&
!                                                 &            bleafmasgat, soilcmasgat,    ailcggat,    ailcgat,&
!                                                 &               zolncgat,  rmatctemgat,   rmatcgat,  ailcbgat,&
!                                                 &            flhrlossgat,  pandaysgat, lfstatusgat, grwtheffgat,&
!                                                 &            lystmmasgat, lyrotmasgat, tymaxlaigat, vgbiomasgat,&
!                                                 &            gavgltmsgat, gavgscmsgat, stmhrlosgat,     slaigat,&
!                                                 &             bmasveggat, cmasvegcgat,  colddaysgat, rothrlosgat,&
!                                                 &                fcangat,  alvsctmgat,   alirctmgat,  gavglaigat,&
!                                                 &                  tcurm,    srpcuryr,     dftcuryr,  inibioclim,&
!                                                 &                 tmonth,    anpcpcur,      anpecur,     gdd5cur,&
!                                                 &               surmncur,    defmncur,     srplscur,    defctcur,&
!                                                 &            geremortgat, intrmortgat,    lambdagat,&
!                                                 &            pftexistgat,   twarmmgat,    tcoldmgat,     gdd5gat,&
!                                                 &             ariditygat, srplsmongat,  defctmongat, anndefctgat,&
!                                                 &            annsrplsgat,   annpcpgat,  dry_season_lengthgat,&
!                                                 &              burnvegfgat, pstemmassgat, pgleafmassgat,&
!                                                 &                 !    -------------- inputs updated by ctem are above this line ------
!                                                 &                 nppgat,      nepgat, hetroresgat, autoresgat,&
!                                                 &            soilcrespgat,       rmgat,       rggat,      nbpgat,&
!                                                 &              litresgat,    socresgat,     gppgat, dstcemlsgat,&
!                                                 &            litrfallgat,  humiftrsgat, veghghtgat, rootdpthgat,&
!                                                 &            litrfallveggat,  humiftrsveggat,&
!                                                 &                 rmlgat,      rmsgat,     rmrgat,  tltrleafgat,&
!                                                 &            tltrstemgat, tltrrootgat, leaflitrgat, roottempgat,&
!                                                 &             afrleafgat,  afrstemgat,  afrrootgat, wtstatusgat,&
!                                                 &            ltstatusgat, burnfracgat, smfuncveggat, lucemcomgat,&
!                                                 &            lucltringat, lucsocingat,   nppveggat,&
!                                                 &            dstcemls3gat,    paicgat,    slaicgat,&
!                                                 &            emit_co2gat,  emit_cogat,  emit_ch4gat, emit_nmhcgat,&
!                                                 &             emit_h2gat, emit_noxgat,  emit_n2ogat, emit_pm25gat,&
!                                                 &            emit_tpmgat,  emit_tcgat,   emit_ocgat,   emit_bcgat,&
!                                                 &               btermgat,    ltermgat,     mtermgat,&
!                                                 &            ccgat,             mmgat,&
!                                                 &          rmlvegaccgat,    rmsveggat,  rmrveggat,  rgveggat,&
!                                                 &       vgbiomas_veggat, gppveggat,  nepveggat, nbpveggat,&
!                                                 &        hetroresveggat, autoresveggat, litresveggat,&
!                                                 &           soilcresveggat, nml, ilmos, jlmos, ch4wet1gat,&
!                                                 &          ch4wet2gat, wetfdyngat, ch4dyn1gat, ch4dyn2gat,&
!                                                 &          ch4soillsgat)
!                                             !    ---------------- outputs are listed above this line ------------
!                                             !
!
!                                             !     reset mosaic accumulator arrays. These are scattered in ctems2 so we need
!                                             !     to reset here, prior to ctems2.
!                                             do i = 1, nml
!                                                 vvaccgat_t(i)=0.0  !
!                                                 uvaccgat_t(i)=0.0  !
!                                                 do j=1,ignd
!                                                     tbaraccgat_t(i,j)=0.0 !
!                                                 end do
!                                             end do
!
!                                         endif  ! if(ctem_on)
!
!                                     endif  ! if(ncount.eq.nday)
!
!                                     !===================== CTEM ============================================ /
!                                     !
!                                     CALL CLASSS (TBARROT,THLQROT,THICROT,TSFSROT,TPNDROT,&
!                                         &             ZPNDROT,TBASROT,ALBSROT,TSNOROT,RHOSROT,&
!                                         &             SNOROT, GTROT, TCANROT,RCANROT,SCANROT,&
!                                         &             GROROT, CMAIROT,TACROT, QACROT, WSNOROT,&
!                                         &             REFROT, BCSNROT,EMISROT,SALBROT,CSALROT,&
!                                         &             ILMOS,JLMOS,NML,NLAT,NTLD,NMOS,&
!                                         &             ILG,IGND,ICAN,ICAN+1,NBS,&
!                                         &             TBARGAT,THLQGAT,THICGAT,TSFSGAT,TPNDGAT,&
!                                         &             ZPNDGAT,TBASGAT,ALBSGAT,TSNOGAT,RHOSGAT,&
!                                         &             SNOGAT, GTGAT, TCANGAT,RCANGAT,SCANGAT,&
!                                         &             GROGAT, CMAIGAT,TACGAT, QACGAT, WSNOGAT,&
!                                         &             REFGAT, BCSNGAT,EMISGAT,SALBGAT,CSALGAT)
!
!                                     !
!                                     !    * SCATTER OPERATION ON DIAGNOSTIC VARIABLES SPLIT OUT OF
!                                     !    * CLASSS FOR CONSISTENCY WITH GCM APPLICATIONS.
!                                     !
!                                     DO 380 K=1,NML
!                                         CDHROT (ILMOS(K),JLMOS(K))=CDHGAT (K)
!                                         CDMROT (ILMOS(K),JLMOS(K))=CDMGAT (K)
!                                         HFSROT (ILMOS(K),JLMOS(K))=HFSGAT (K)
!                                         TFXROT (ILMOS(K),JLMOS(K))=TFXGAT (K)
!                                         QEVPROT(ILMOS(K),JLMOS(K))=QEVPGAT(K)
!                                         QFSROT (ILMOS(K),JLMOS(K))=QFSGAT (K)
!                                         QFXROT (ILMOS(K),JLMOS(K))=QFXGAT (K)
!                                         PETROT (ILMOS(K),JLMOS(K))=PETGAT (K)
!                                         GAROT  (ILMOS(K),JLMOS(K))=GAGAT  (K)
!                                         EFROT  (ILMOS(K),JLMOS(K))=EFGAT  (K)
!                                         QGROT  (ILMOS(K),JLMOS(K))=QGGAT  (K)
!                                         ALVSROT(ILMOS(K),JLMOS(K))=ALVSGAT(K)
!                                         ALIRROT(ILMOS(K),JLMOS(K))=ALIRGAT(K)
!                                         SFCTROT(ILMOS(K),JLMOS(K))=SFCTGAT(K)
!                                         SFCUROT(ILMOS(K),JLMOS(K))=SFCUGAT(K)
!                                         SFCVROT(ILMOS(K),JLMOS(K))=SFCVGAT(K)
!                                         SFCQROT(ILMOS(K),JLMOS(K))=SFCQGAT(K)
!                                         FSNOROT(ILMOS(K),JLMOS(K))=FSNOGAT(K)
!                                         FSGVROT(ILMOS(K),JLMOS(K))=FSGVGAT(K)
!                                         FSGSROT(ILMOS(K),JLMOS(K))=FSGSGAT(K)
!                                         FSGGROT(ILMOS(K),JLMOS(K))=FSGGGAT(K)
!                                         FLGVROT(ILMOS(K),JLMOS(K))=FLGVGAT(K)
!                                         FLGSROT(ILMOS(K),JLMOS(K))=FLGSGAT(K)
!                                         FLGGROT(ILMOS(K),JLMOS(K))=FLGGGAT(K)
!                                         HFSCROT(ILMOS(K),JLMOS(K))=HFSCGAT(K)
!                                         HFSSROT(ILMOS(K),JLMOS(K))=HFSSGAT(K)
!                                         HFSGROT(ILMOS(K),JLMOS(K))=HFSGGAT(K)
!                                         HEVCROT(ILMOS(K),JLMOS(K))=HEVCGAT(K)
!                                         HEVSROT(ILMOS(K),JLMOS(K))=HEVSGAT(K)
!                                         HEVGROT(ILMOS(K),JLMOS(K))=HEVGGAT(K)
!                                         HMFCROT(ILMOS(K),JLMOS(K))=HMFCGAT(K)
!                                         HMFNROT(ILMOS(K),JLMOS(K))=HMFNGAT(K)
!                                         HTCCROT(ILMOS(K),JLMOS(K))=HTCCGAT(K)
!                                         HTCSROT(ILMOS(K),JLMOS(K))=HTCSGAT(K)
!                                         PCFCROT(ILMOS(K),JLMOS(K))=PCFCGAT(K)
!                                         PCLCROT(ILMOS(K),JLMOS(K))=PCLCGAT(K)
!                                         PCPNROT(ILMOS(K),JLMOS(K))=PCPNGAT(K)
!                                         PCPGROT(ILMOS(K),JLMOS(K))=PCPGGAT(K)
!                                         QFGROT (ILMOS(K),JLMOS(K))=QFGGAT (K)
!                                         QFNROT (ILMOS(K),JLMOS(K))=QFNGAT (K)
!                                         QFCLROT(ILMOS(K),JLMOS(K))=QFCLGAT(K)
!                                         QFCFROT(ILMOS(K),JLMOS(K))=QFCFGAT(K)
!                                         ROFROT (ILMOS(K),JLMOS(K))=ROFGAT (K)
!                                         ROFOROT(ILMOS(K),JLMOS(K))=ROFOGAT(K)
!                                         ROFSROT(ILMOS(K),JLMOS(K))=ROFSGAT(K)
!                                         ROFBROT(ILMOS(K),JLMOS(K))=ROFBGAT(K)
!                                         TROFROT(ILMOS(K),JLMOS(K))=TROFGAT(K)
!                                         TROOROT(ILMOS(K),JLMOS(K))=TROOGAT(K)
!                                         TROSROT(ILMOS(K),JLMOS(K))=TROSGAT(K)
!                                         TROBROT(ILMOS(K),JLMOS(K))=TROBGAT(K)
!                                         ROFCROT(ILMOS(K),JLMOS(K))=ROFCGAT(K)
!                                         ROFNROT(ILMOS(K),JLMOS(K))=ROFNGAT(K)
!                                         ROVGROT(ILMOS(K),JLMOS(K))=ROVGGAT(K)
!                                         WTRCROT(ILMOS(K),JLMOS(K))=WTRCGAT(K)
!                                         WTRSROT(ILMOS(K),JLMOS(K))=WTRSGAT(K)
!                                         WTRGROT(ILMOS(K),JLMOS(K))=WTRGGAT(K)
!                                         DRROT  (ILMOS(K),JLMOS(K))=DRGAT  (K)
!                                         WTABROT(ILMOS(K),JLMOS(K))=WTABGAT(K)
!                                         ILMOROT(ILMOS(K),JLMOS(K))=ILMOGAT(K)
!                                         UEROT  (ILMOS(K),JLMOS(K))=UEGAT(K)
!                                         HBLROT (ILMOS(K),JLMOS(K))=HBLGAT(K)
! 380                                 CONTINUE
!                                     !
!                                     DO 390 L=1,IGND
!                                         DO 390 K=1,NML
!                                             HMFGROT(ILMOS(K),JLMOS(K),L)=HMFGGAT(K,L)
!                                             HTCROT (ILMOS(K),JLMOS(K),L)=HTCGAT (K,L)
!                                             QFCROT (ILMOS(K),JLMOS(K),L)=QFCGAT (K,L)
!                                             GFLXROT(ILMOS(K),JLMOS(K),L)=GFLXGAT(K,L)
! 390                                     CONTINUE
!                                         !
!                                         DO 430 M=1,50
!                                             DO 420 L=1,6
!                                                 DO 410 K=1,NML
!                                                     ITCTROT(ILMOS(K),JLMOS(K),L,M)=ITCTGAT(K,L,M)
! 410                                             CONTINUE
! 420                                         CONTINUE
! 430                                     CONTINUE
!                                         !
!
!                                         !
!                                         !===================== CTEM ============================================ \
!                                         !
!                                         call ctems2(fcancmxrow,rmatcrow,zolncrow,paicrow,&
!                                             &      ailcrow,     ailcgrow,    cmasvegcrow,  slaicrow,&
!                                             &      ailcgsrow,   fcancsrow,   fcancrow,     rmatctemrow,&
!                                             &      co2concrow,  co2i1cgrow,  co2i1csrow,   co2i2cgrow,&
!                                             &      co2i2csrow,  xdiffus,     slairow,      cfluxcgrow,&
!                                             &      cfluxcsrow,  ancsvegrow,  ancgvegrow,   rmlcsvegrow,&
!                                             &      rmlcgvegrow, canresrow,   SDEPROT,      ch4concrow,&
!                                             &      SANDROT,     CLAYROT,     ORGMROT,&
!                                             &      anvegrow,    rmlvegrow,   tcanoaccrow_m,tbaraccrow_m,&
!                                             &      uvaccrow_m,  vvaccrow_m,  prbfrhucrow,&
!                                             &      extnprobrow, pfcancmxrow,  nfcancmxrow,&
!                                             &      stemmassrow, rootmassrow, litrmassrow,  gleafmasrow,&
!                                             &      bleafmasrow, soilcmasrow, ailcbrow,     flhrlossrow,&
!                                             &      pandaysrow,  lfstatusrow, grwtheffrow,  lystmmasrow,&
!                                             &      lyrotmasrow, tymaxlairow, vgbiomasrow,  gavgltmsrow,&
!                                             &      stmhrlosrow, bmasvegrow,  colddaysrow,  rothrlosrow,&
!                                             &      alvsctmrow,  alirctmrow,  gavglairow,   npprow,&
!                                             &      neprow,      hetroresrow, autoresrow,   soilcresprow,&
!                                             &      rmrow,       rgrow,       nbprow,       litresrow,&
!                                             &      socresrow,   gpprow,      dstcemlsrow,  litrfallrow,&
!                                             &      humiftrsrow, veghghtrow,  rootdpthrow,  rmlrow,&
!                                             &      litresvegrow, humiftrsvegrow,&
!                                             &      rmsrow,      rmrrow,      tltrleafrow,  tltrstemrow,&
!                                             &      tltrrootrow, leaflitrrow, roottemprow,  afrleafrow,&
!                                             &      afrstemrow,  afrrootrow,  wtstatusrow,  ltstatusrow,&
!                                             &      burnfracrow, smfuncvegrow, lucemcomrow,  lucltrinrow,&
!                                             &      lucsocinrow, nppvegrow,   dstcemls3row,&
!                                             &      FAREROT,     gavgscmsrow, tcanoaccrow_out,&
!                                             &      rmlvegaccrow, rmsvegrow,  rmrvegrow,    rgvegrow,&
!                                             &      vgbiomas_vegrow,gppvegrow,nepvegrow,ailcminrow,ailcmaxrow,&
!                                             &      FCANROT,      pftexistrow,&
!                                             &      emit_co2row,  emit_corow, emit_ch4row,  emit_nmhcrow,&
!                                             &      emit_h2row,   emit_noxrow,emit_n2orow,  emit_pm25row,&
!                                             &      emit_tpmrow,  emit_tcrow, emit_ocrow,   emit_bcrow,&
!                                             &      btermrow,     ltermrow,   mtermrow,&
!                                             &      nbpvegrow,   hetroresvegrow, autoresvegrow,litresvegrow,&
!                                             &      soilcresvegrow, burnvegfrow, pstemmassrow, pgleafmassrow,&
!                                             &      ch4wet1row, ch4wet2row,&
!                                             &      wetfdynrow, ch4dyn1row, ch4dyn2row, ch4soillsrow,&
!                                             &      twarmmrow,    tcoldmrow,     gdd5row,&
!                                             &      aridityrow, srplsmonrow,  defctmonrow, anndefctrow,&
!                                             &      annsrplsrow,   annpcprow,  dry_season_lengthrow,&
!                                             &      !    ----
!                                             &      ilmos,       jlmos,       iwmos,        jwmos,&
!                                             &      nml,     fcancmxgat,  rmatcgat,    zolncgat,     paicgat,&
!                                             &      ailcgat,     ailcggat,    cmasvegcgat,  slaicgat,&
!                                             &      ailcgsgat,   fcancsgat,   fcancgat,     rmatctemgat,&
!                                             &      co2concgat,  co2i1cggat,  co2i1csgat,   co2i2cggat,&
!                                             &      co2i2csgat,  xdiffusgat,  slaigat,      cfluxcggat,&
!                                             &      cfluxcsgat,  ancsveggat,  ancgveggat,   rmlcsveggat,&
!                                             &      rmlcgveggat, canresgat,   sdepgat,      ch4concgat,&
!                                             &      sandgat,     claygat,     orgmgat,&
!                                             &      anveggat,    rmlveggat,   tcanoaccgat_t,tbaraccgat_t,&
!                                             &      uvaccgat_t,  vvaccgat_t,  prbfrhucgat,&
!                                             &      extnprobgat, pfcancmxgat,  nfcancmxgat,&
!                                             &      stemmassgat, rootmassgat, litrmassgat,  gleafmasgat,&
!                                             &      bleafmasgat, soilcmasgat, ailcbgat,     flhrlossgat,&
!                                             &      pandaysgat,  lfstatusgat, grwtheffgat,  lystmmasgat,&
!                                             &      lyrotmasgat, tymaxlaigat, vgbiomasgat,  gavgltmsgat,&
!                                             &      stmhrlosgat, bmasveggat,  colddaysgat,  rothrlosgat,&
!                                             &      alvsctmgat,  alirctmgat,  gavglaigat,   nppgat,&
!                                             &      nepgat,      hetroresgat, autoresgat,   soilcrespgat,&
!                                             &      rmgat,       rggat,       nbpgat,       litresgat,&
!                                             &      socresgat,   gppgat,      dstcemlsgat,  litrfallgat,&
!                                             &      humiftrsgat, veghghtgat,  rootdpthgat,  rmlgat,&
!                                             &      litresveggat, humiftrsveggat,&
!                                             &      rmsgat,      rmrgat,      tltrleafgat,  tltrstemgat,&
!                                             &      tltrrootgat, leaflitrgat, roottempgat,  afrleafgat,&
!                                             &      afrstemgat,  afrrootgat,  wtstatusgat,  ltstatusgat,&
!                                             &      burnfracgat, smfuncveggat, lucemcomgat,  lucltringat,&
!                                             &      lucsocingat, nppveggat,   dstcemls3gat,&
!                                             &      faregat,     gavgscmsgat, tcanoaccgat_out,&
!                                             &      rmlvegaccgat, rmsveggat,  rmrveggat,    rgveggat,&
!                                             &      vgbiomas_veggat,gppveggat,nepveggat,ailcmingat,ailcmaxgat,&
!                                             &      fcangat,      pftexistgat,&
!                                             &      emit_co2gat,  emit_cogat, emit_ch4gat,  emit_nmhcgat,&
!                                             &      emit_h2gat,   emit_noxgat,emit_n2ogat,  emit_pm25gat,&
!                                             &      emit_tpmgat,  emit_tcgat, emit_ocgat,   emit_bcgat,&
!                                             &      btermgat,     ltermgat,   mtermgat,&
!                                             &      nbpveggat, hetroresveggat, autoresveggat,litresveggat,&
!                                             &      soilcresveggat, burnvegfgat, pstemmassgat, pgleafmassgat,&
!                                             &      ch4wet1gat, ch4wet2gat,&
!                                             &      wetfdyngat, ch4dyn1gat, ch4dyn2gat,ch4soillsgat,&
!                                             &      twarmmgat,    tcoldmgat,     gdd5gat,&
!                                             &      ariditygat, srplsmongat,  defctmongat, anndefctgat,&
!                                             &      annsrplsgat,   annpcpgat,  dry_season_lengthgat)
!
!                                         if(ncount.eq.nday) then
!
!                                             !     reset mosaic accumulator arrays.
!
!                                             if (ctem_on) then
!                                                 do 705 i = 1, nml
!
!                                                     fsinacc_gat(i)=0.
!                                                     flinacc_gat(i)=0.
!                                                     flutacc_gat(i)=0.
!                                                     alswacc_gat(i)=0.
!                                                     allwacc_gat(i)=0.
!                                                     pregacc_gat(i)=0.
!                                                     fsnowacc_t(i)=0.0
!                                                     tcanoaccgat_out(i)=tcanoaccgat_t(i)
!                                                     tcanoaccgat_t(i)=0.0
!                                                     tcansacc_t(i)=0.0
!                                                     taaccgat_t(i)=0.0
!                                                     altotacc_gat(i) = 0.0
!                                                     altotcount_ctm(i)=0
!
!                                                     do 715 j=1,ignd
!                                                         tbarcacc_t(i,j)=0.0
!                                                         tbarcsacc_t(i,j)=0.0
!                                                         tbargacc_t(i,j)=0.0
!                                                         tbargsacc_t(i,j)=0.0
!                                                         thliqcacc_t(i,j)=0.0
!                                                         thliqgacc_t(i,j)=0.0
!                                                         thliqacc_t(i,j)=0.0
!                                                         thicecacc_t(i,j)=0.0
!                                                         thicegacc_t(i,j)=0.0
! 715                                                 continue
!
!                                                     do 716 j = 1, icc
!                                                         ancsvgac_t(i,j)=0.0
!                                                         ancgvgac_t(i,j)=0.0
!                                                         rmlcsvga_t(i,j)=0.0
!                                                         rmlcgvga_t(i,j)=0.0
! 716                                                 continue
!
! 705                                             continue
!                                             endif  ! if(ctem_on)
!                                         end if
!
!                                         !===================== CTEM ============================================ /
!                                         !
!                                         !=======================================================================
!                                         !     * WRITE FIELDS FROM CURRENT TIME STEP TO OUTPUT FILES.
!
! 6100                                    FORMAT(1X,I4,I5,9F8.2,2F8.3,F12.4,F8.2,2(A6,I2))
! 6200                                    FORMAT(1X,I4,I5,3(F8.2,2F6.3),F8.2,2F8.4,F8.2,F8.3,2(A6,I2))
! 6201                                    FORMAT(1X,I4,I5,20(F7.2,2F6.3),2F8.3,2(A6,I2))
! 6300                                    FORMAT(1X,I4,I5,3F9.2,F8.2,F10.2,E12.3,2F12.3,A6,I2)
! 6400                                    FORMAT(1X,I2,I3,I5,I6,9F8.2,2F7.3,E11.3,F8.2,F12.4,5F9.5,2(A6,I2))
! 6500                                    FORMAT(1X,I2,I3,I5,I6,3(F7.2,2F6.3),F8.2,2F8.4,F8.2,4F8.3,&
!                                             &       2F7.3,2(A6,I2))
! 6600                                    FORMAT(1X,I2,I3,I5,2F10.2,E12.3,F10.2,F8.2,F10.2,E12.3,2(A6,I2))
! 6501                                    FORMAT(1X,I2,I3,I5,I6,5(F7.2,2F6.3),2(A6,I2))
! 6601                                    FORMAT(1X,I2,I3,I5,I6,26(F7.2,2F6.3),26F9.4,2(A6,I2))
! 6700                                    FORMAT(1X,I2,I3,I5,I6,2X,12E11.4,2(A6,I2))
! 6800                                    FORMAT(1X,I2,I3,I5,I6,2X,22(F10.4,2X),2(A6,I2))
! 6900                                    FORMAT(1X,I2,I3,I5,I6,2X,18(E12.4,2X),2(A6,I2))
!                                         !
!                                         !===================== CTEM ============================================ \
!                                         !
!                                         !  fc,fg,fcs and fgs are one_dimensional in class subroutines
!                                         !  the transformations here to grid_cell mean fc_g,fg_g,fcs_g and fgs_g
!                                         !  are only applicable when nltest=1 (e.g., one grid cell)
!                                         !
!                                         do i=1,nltest
!                                             fc_g(i)=0.0
!                                             fg_g(i)=0.0
!                                             fcs_g(i)=0.0
!                                             fgs_g(i)=0.0
!                                             do m=1,nmtest
!                                                 fc_g(i)=fc_g(i)+fc(m)
!                                                 fg_g(i)=fg_g(i)+fg(m)
!                                                 fcs_g(i)=fcs_g(i)+fcs(m)
!                                                 fgs_g(i)=fgs_g(i)+fgs(m)
!                                             enddo
!                                         enddo
!                                         !
!                                         !===================== CTEM =====================================/
!                                         !
!
!                                         ! Find the active layer depth and depth to the frozen water table.
!                                         ACTLYR=0.0
!                                         FTABLE=0.0
!                                         DO 440 J=1,IGND
!                                             DO I = 1, NLTEST
!                                                 DO M = 1,NMTEST
!                                                     IF(ABS(TBARROT(I,M,J)-TFREZ).LT.0.0001) THEN
!                                                         IF(ISNDROT(I,M,J).GT.-3) THEN
!                                                             ACTLYR(I,M)=ACTLYR(I,M)+(THLQROT(I,M,J)/(THLQROT(I,M,J)+&
!                                                                 &               THICROT(I,M,J)))*DLZWROT(I,M,J)
!                                                           !ELSEIF(ISNDGAT(1,J).EQ.-3) THEN
!                                                           !    ACTLYR=ACTLYR+DELZ(J)
!                                                         ENDIF
!                                                     ELSEIF(TBARROT(I,M,J).GT.TFREZ) THEN
!                                                         ACTLYR(I,M)=ACTLYR(I,M)+DELZ(J)
!                                                     ENDIF
!                                                     IF(ABS(TBARROT(I,M,J)-TFREZ).LT.0.0001) THEN
!                                                         IF(ISNDROT(I,M,J).GT.-3) THEN
!                                                             FTABLE(I,M)=FTABLE(I,M)+(THICROT(I,M,J)/(THLQROT(I,M,J)+&
!                                                                 &              THICROT(I,M,J)-THMROT(I,M,J)))*DLZWROT(I,M,J)
!                                                           !ELSE
!                                                           !    FTABLE=FTABLE+DELZ(J)
!                                                         ENDIF
!                                                     ELSEIF(TBARROT(I,M,J).LT.TFREZ) THEN
!                                                         FTABLE(I,M)=FTABLE(I,M)+DELZ(J)
!                                                     ENDIF
!                                                 END DO
!                                             END DO
! 440                                     CONTINUE
!
!                                         !
!                                         !      IF(IDAY.GE.182 .AND. IDAY.LE.243)  THEN ! July 1st and Aug 31
!                                         !          ALAVG=ALAVG+ACTLYR
!                                         !          NAL=NAL+1
!                                         !          IF(ACTLYR.GT.ALMAX) ALMAX=ACTLYR
!                                         !      ENDIF
!                                         !
!                                         !      IF(IDAY.GE.1 .AND. IDAY.LE.59)   THEN  ! Jan 1st and Feb 28th
!                                         !          FTAVG=FTAVG+FTABLE
!                                         !          NFT=NFT+1
!                                         !          IF(FTABLE.GT.FTMAX) FTMAX=FTABLE
!                                         !      ENDIF
!
!                                         if (.not. parallelrun) then ! stand alone mode, include half-hourly
!                                             !                                 ! output for CLASS & CTEM
!                                             !
!                                             DO 450 I=1,NLTEST
!
!                                                 !       initialization of various grid-averaged variables
!                                                 call resetgridavg(nltest)
!
!                                                 DO 425 M=1,NMTEST
!                                                     IF(FSSROW(I).GT.0.0) THEN
!                                                         ALTOT=(FSSROW(I)-(FSGVROT(I,M)+FSGSROT(I,M)&
!                                                             &              +FSGGROT(I,M)))/FSSROW(I)
!                                                     ELSE
!                                                         ALTOT=0.0
!                                                     ENDIF
!                                                     FSSTAR=FSSROW(I)*(1.0-ALTOT)
!                                                     FLSTAR=FDLROW(I)-SBC*GTROT(I,M)**4
!                                                     QH=HFSROT(I,M)
!                                                     QE=QEVPROT(I,M)
!                                                     !          BEG=FSSTAR+FLSTAR-QH-QE !(commented out in runclass.fieldsite)
!                                                     BEG=GFLXGAT(1,1)  !FLAG!
!                                                     !          USTARBS=UVROW(1)*SQRT(CDMROT(I,M)) !FLAG (commented out in runclass.fieldsite)
!                                                     SNOMLT=HMFNROT(I,M)
!                                                     IF(RHOSROT(I,M).GT.0.0) THEN
!                                                         ZSN=SNOROT(I,M)/RHOSROT(I,M)
!                                                     ELSE
!                                                         ZSN=0.0
!                                                     ENDIF
!                                                     IF(TCANROT(I,M).GT.0.01) THEN
!                                                         TCN=TCANROT(I,M)-TFREZ
!                                                     ELSE
!                                                         TCN=0.0
!                                                     ENDIF
!                                                     TSURF=FCS(I)*TSFSGAT(I,1)+FGS(I)*TSFSGAT(I,2)+&
!                                                         &           FC(I)*TSFSGAT(I,3)+FG(I)*TSFSGAT(I,4)
!                                                     !          IF(FSSROW(I).GT.0.0 .AND. (FCS(I)+FC(I)).GT.0.0) THEN
!                                                     !          IF(FSSROW(I).GT.0.0) THEN
!                                                     NFS=NFS+1
!                                                     ITA=NINT(TAROW(I)-TFREZ)
!                                                     ITCAN=NINT(TCN)
!                                                     ITAC=NINT(TACGAT(I)-TFREZ)
!                                                     ITSCR=NINT(SFCTGAT(I)-TFREZ)
!                                                     ITS=NINT(TSURF-TFREZ)
!                                                     !              ITD=ITS-ITA
!                                                     ITD=ITCAN-ITA
!                                                     ITD2=ITCAN-ITSCR
!                                                     ITD3=ITCAN-ITAC
!                                                     ITD4=ITAC-ITA
!                                                     !          ENDIF
!                                                     IF(FC(I).GT.0.1 .AND. RC(I).GT.1.0E5) NDRY=NDRY+1
!                                                     !           IF((ITCAN-ITA).GE.10) THEN
!                                                     !               WRITE(6,6070) IHOUR,IMIN,IDAY,IYEAR,FSSTAR,FLSTAR,QH,QE,
!                                                     !      1                      BEG,TAROW(I)-TFREZ,TCN,TCN-(TAROW(I)-TFREZ),
!                                                     !      2                      PAICAN(I),FSVF(I),UVROW(I),RC(I)
!                                                     ! 6070          FORMAT(2X,2I2,I4,I5,9F6.1,F6.3,F6.1,F8.1)
!                                                     !           ENDIF
!                                                     !
!                                                     IF(TSNOROT(I,M).GT.0.01) THEN
!                                                         TSN=TSNOROT(I,M)-TFREZ
!                                                     ELSE
!                                                         TSN=0.0
!                                                     ENDIF
!                                                     IF(TPNDROT(I,M).GT.0.01) THEN
!                                                         TPN=TPNDROT(I,M)-TFREZ
!                                                     ELSE
!                                                         TPN=0.0
!                                                     ENDIF
!                                                     GTOUT=GTROT(I,M)-TFREZ
!                                                     EVAPSUM=QFCFROT(I,M)+QFCLROT(I,M)+QFNROT(I,M)+QFGROT(I,M)+&
!                                                         &                   QFCROT(I,M,1)+QFCROT(I,M,2)+QFCROT(I,M,3)
!                                                     !
!                                                     !===================== CTEM =====================================\
!                                                     !         start writing output
!                                                     !
!                                                     if ((iyear .ge. jhhsty) .and. (iyear .le. jhhendy)) then
!                                                         if ((iday .ge. jhhstd) .and. (iday .le. jhhendd)) then
!                                                             !===================== CTEM =====================================/
!                                                             WRITE(64,6400) IHOUR,IMIN,IDAY,IYEAR,FSSTAR,FLSTAR,QH,QE,&
!                                                                 &                   SNOMLT,BEG,GTOUT,SNOROT(I,M),RHOSROT(I,M),&
!                                                                 &                   WSNOROT(I,M),ALTOT,ROFROT(I,M),&
!                                                                 &                   TPN,ZPNDROT(I,M),CDHROT(I,M),CDMROT(I,M),&
!                                                                 &                   SFCUROT(I,M),SFCVROT(I,M),UVROW(I),' TILE ',m
!                                                             IF(IGND.GT.3) THEN
!                                                                 !===================== CTEM =====================================\
!                                                                 write(66,6601) ihour,imin,iday,iyear,(TBARROT(i,m,j)-&
!                                                                     &                 tfrez,THLQROT(i,m,j),THICROT(i,m,j),j=1,IGND),&
!                                                                     &                 (GFLXROT(i,m,j),j=1,IGND),' TILE ',m
!                                                             end if
!
!                                                             write(65,6500) ihour,imin,iday,iyear,(TBARROT(i,m,j)-&
!                                                                 &                   tfrez,THLQROT(i,m,j),THICROT(i,m,j),j=1,3),&
!                                                                 &                  tcn,RCANROT(i,m),SCANROT(i,m),tsn,zsn,&
!                                                                 &                   TCN-(TAROW(I)-TFREZ),TCANO(I)-TFREZ,&
!                                                                 &                   TACGAT(I)-TFREZ,' TILE ',m
!
!                                                             !===================== CTEM =====================================/
!
!                                                             !
!                                                             WRITE(67,6700) IHOUR,IMIN,IDAY,IYEAR,&
!                                                                 &                   TROFROT(I,M),TROOROT(I,M),TROSROT(I,M),&
!                                                                 &                   TROBROT(I,M),ROFROT(I,M),ROFOROT(I,M),&
!                                                                 &                   ROFSROT(I,M),ROFBROT(I,M),&
!                                                                 &                   FCS(M),FGS(M),FC(M),FG(M),' TILE ',M
!                                                             WRITE(68,6800) IHOUR,IMIN,IDAY,IYEAR,&
!                                                                 &                   FSGVROT(I,M),FSGSROT(I,M),FSGGROT(I,M),&
!                                                                 &                   FLGVROT(I,M),FLGSROT(I,M),FLGGROT(I,M),&
!                                                                 &                   HFSCROT(I,M),HFSSROT(I,M),HFSGROT(I,M),&
!                                                                 &                   HEVCROT(I,M),HEVSROT(I,M),HEVGROT(I,M),&
!                                                                 &                   HMFCROT(I,M),HMFNROT(I,M),&
!                                                                 &                   (HMFGROT(I,M,J),J=1,3),&
!                                                                 &                   HTCCROT(I,M),HTCSROT(I,M),&
!                                                                 &                   (HTCROT(I,M,J),J=1,3),' TILE ',M
!                                                             WRITE(69,6900) IHOUR,IMIN,IDAY,IYEAR,&
!                                                                 &                   PCFCROT(I,M),PCLCROT(I,M),PCPNROT(I,M),&
!                                                                 &                   PCPGROT(I,M),QFCFROT(I,M),QFCLROT(I,M),&
!                                                                 &                   QFNROT(I,M),QFGROT(I,M),(QFCROT(I,M,J),J=1,3),&
!                                                                 &                   ROFCROT(I,M),ROFNROT(I,M),ROFOROT(I,M),&
!                                                                 &                   ROFROT(I,M),WTRCROT(I,M),WTRSROT(I,M),&
!                                                                 &                   WTRGROT(I,M),' TILE ',M
!                                                         !===================== CTEM =====================================\
!                                                         !
!                                                         endif
!                                                     endif ! half hourly output loop.
!                                                     !
!                                                     !         Write half-hourly CTEM results to file *.CT01H
!                                                     !
!                                                     !         Net photosynthetic rates and leaf maintenance respiration for
!                                                     !         each pft. however, if ctem_on then physyn subroutine
!                                                     !         is using storage lai while actual lai is zero. if actual lai is
!                                                     !         zero then we make anveg and rmlveg zero as well because these
!                                                     !         are imaginary just like storage lai. note that anveg and rmlveg
!                                                     !         are not passed to ctem. rather ancsveg, ancgveg, rmlcsveg, and
!                                                     !         rmlcgveg are passed.
!                                                     !
!                                                     if (ctem_on) then
!
!                                                         do 760 j = 1,icc
!                                                             if(ailcgrow(i,m,j).le.0.0) then
!                                                                 anvegrow(i,m,j)=0.0
!                                                                 rmlvegrow(i,m,j)=0.0
!                                                             else
!                                                                 anvegrow(i,m,j)=ancsvegrow(i,m,j)*FSNOROT(i,m) +&
!                                                                     &                          ancgvegrow(i,m,j)*(1. - FSNOROT(i,m))
!                                                                 rmlvegrow(i,m,j)=rmlcsvegrow(i,m,j)*FSNOROT(i,m) +&
!                                                                     &                         rmlcgvegrow(i,m,j)*(1. - FSNOROT(i,m))
!                                                             endif
! 760                                                     continue
!                                                         !
!                                                         if ((iyear .ge. jhhsty) .and. (iyear .le. jhhendy)) then
!                                                             if ((iday .ge. jhhstd) .and. (iday .le. jhhendd)) then
!
!                                                                 write(71,7200)ihour,imin,iday,iyear,(anvegrow(i,m,j),&
!                                                                     &                    j=1,icc),(rmlvegrow(i,m,j),j=1,icc),&
!                                                                     &                    ' TILE ',m
!                                                             endif
!                                                         end if
!
!                                                         do j = 1,icc
!                                                             anvegrow_g(i,j)=anvegrow_g(i,j)+anvegrow(i,m,j)&
!                                                                 &                                        *FAREROT(i,m)
!                                                             rmlvegrow_g(i,j)=rmlvegrow_g(i,j)+rmlvegrow(i,m,j)&
!                                                                 &                                         *FAREROT(i,m)
!                                                         enddo
!
!                                                     endif   ! ctem_on
!
! 7200                                                format(1x,i2,1x,i2,i5,i5,9f11.3,9f11.3,2(a6,i2))
!                                                     !
!                                                     fsstar_g(i)    =fsstar_g(i) + fsstar*FAREROT(i,m)
!                                                     flstar_g(i)    =flstar_g(i) + flstar*FAREROT(i,m)
!                                                     qh_g(i)        =qh_g(i)     + qh*FAREROT(i,m)
!                                                     qe_g(i)        =qe_g(i)     + qe*FAREROT(i,m)
!                                                     snomlt_g(i)    =snomlt_g(i) + snomlt*FAREROT(i,m)
!                                                     beg_g(i)       =beg_g(i)    + beg*FAREROT(i,m)
!                                                     gtout_g(i)     =gtout_g(i)  + gtout*FAREROT(i,m)
!                                                     tcn_g(i)       =tcn_g(i)    + tcn*FAREROT(i,m)
!                                                     tsn_g(i)       =tsn_g(i)    + tsn*FAREROT(i,m)
!                                                     zsn_g(i)       =zsn_g(i)    + zsn*FAREROT(i,m)
!                                                     altot_g(i)     =altot_g(i)  + altot*FAREROT(i,m)
!                                                     tpn_g(i)       =tpn_g(i)    + tpn*FAREROT(i,m)
!                                                     !
!                                                     do j=1,ignd
!                                                         TBARROT_g(i,j)=TBARROT_g(i,j) + TBARROT(i,m,j)*FAREROT(i,m)
!                                                         THLQROT_g(i,j)=THLQROT_g(i,j) + THLQROT(i,m,j)*FAREROT(i,m)
!                                                         THICROT_g(i,j)=THICROT_g(i,j) + THICROT(i,m,j)*FAREROT(i,m)
!                                                         GFLXROT_g(i,j)=GFLXROT_g(i,j) + GFLXROT(i,m,j)*FAREROT(i,m)
!                                                         HMFGROT_g(i,j)=HMFGROT_g(i,j) + HMFGROT(i,m,j)*FAREROT(i,m)
!                                                         HTCROT_g(i,j)=HTCROT_g(i,j) + HTCROT(i,m,j)*FAREROT(i,m)
!                                                         QFCROT_g(i,j)=QFCROT_g(i,j) + QFCROT(i,m,j)*FAREROT(i,m)
!                                                     enddo
!                                                     !
!                                                     ZPNDROT_g(i)=ZPNDROT_g(i) + ZPNDROT(i,m)*FAREROT(i,m)
!                                                     RHOSROT_g(i)=RHOSROT_g(i) + RHOSROT(i,m)*FAREROT(i,m)
!                                                     WSNOROT_g(i)=WSNOROT_g(i) + WSNOROT(i,m)*FAREROT(i,m)
!                                                     RCANROT_g(i)=RCANROT_g(i) + RCANROT(i,m)*FAREROT(i,m)
!                                                     SCANROT_g(i)=SCANROT_g(i) + SCANROT(i,m)*FAREROT(i,m)
!                                                     TROFROT_g(i)=TROFROT_g(i) + TROFROT(i,m)*FAREROT(i,m)
!                                                     TROOROT_g(i)=TROOROT_g(i) + TROOROT(i,m)*FAREROT(i,m)
!                                                     TROSROT_g(i)=TROSROT_g(i) + TROSROT(i,m)*FAREROT(i,m)
!                                                     TROBROT_g(i)=TROBROT_g(i) + TROBROT(i,m)*FAREROT(i,m)
!                                                     ROFOROT_g(i)=ROFOROT_g(i) + ROFOROT(i,m)*FAREROT(i,m)
!                                                     ROFSROT_g(i)=ROFSROT_g(i) + ROFSROT(i,m)*FAREROT(i,m)
!                                                     ROFBROT_g(i)=ROFBROT_g(i) + ROFBROT(i,m)*FAREROT(i,m)
!                                                     FSGVROT_g(i)=FSGVROT_g(i) + FSGVROT(i,m)*FAREROT(i,m)
!                                                     FSGSROT_g(i)=FSGSROT_g(i) + FSGSROT(i,m)*FAREROT(i,m)
!                                                     FSGGROT_g(i)=FSGGROT_g(i) + FSGGROT(i,m)*FAREROT(i,m)
!                                                     FLGVROT_g(i)=FLGVROT_g(i) + FLGVROT(i,m)*FAREROT(i,m)
!                                                     FLGSROT_g(i)=FLGSROT_g(i) + FLGSROT(i,m)*FAREROT(i,m)
!                                                     FLGGROT_g(i)=FLGGROT_g(i) + FLGGROT(i,m)*FAREROT(i,m)
!                                                     HFSCROT_g(i)=HFSCROT_g(i) + HFSCROT(i,m)*FAREROT(i,m)
!                                                     HFSSROT_g(i)=HFSSROT_g(i) + HFSSROT(i,m)*FAREROT(i,m)
!                                                     HFSGROT_g(i)=HFSGROT_g(i) + HFSGROT(i,m)*FAREROT(i,m)
!                                                     HEVCROT_g(i)=HEVCROT_g(i) + HEVCROT(i,m)*FAREROT(i,m)
!                                                     HEVSROT_g(i)=HEVSROT_g(i) + HEVSROT(i,m)*FAREROT(i,m)
!                                                     HEVGROT_g(i)=HEVGROT_g(i) + HEVGROT(i,m)*FAREROT(i,m)
!                                                     HMFCROT_g(i)=HMFCROT_g(i) + HMFCROT(i,m)*FAREROT(i,m)
!                                                     HMFNROT_g(i)=HMFNROT_g(i) + HMFNROT(i,m)*FAREROT(i,m)
!                                                     HTCCROT_g(i)=HTCCROT_g(i) + HTCCROT(i,m)*FAREROT(i,m)
!                                                     HTCSROT_g(i)=HTCSROT_g(i) + HTCSROT(i,m)*FAREROT(i,m)
!                                                     PCFCROT_g(i)=PCFCROT_g(i) + PCFCROT(i,m)*FAREROT(i,m)
!                                                     PCLCROT_g(i)=PCLCROT_g(i) + PCLCROT(i,m)*FAREROT(i,m)
!                                                     PCPNROT_g(i)=PCPNROT_g(i) + PCPNROT(i,m)*FAREROT(i,m)
!                                                     PCPGROT_g(i)=PCPGROT_g(i) + PCPGROT(i,m)*FAREROT(i,m)
!                                                     QFCFROT_g(i)=QFCFROT_g(i) + QFCFROT(i,m)*FAREROT(i,m)
!                                                     QFCLROT_g(i)=QFCLROT_g(i) + QFCLROT(i,m)*FAREROT(i,m)
!                                                     ROFCROT_g(i)=ROFCROT_g(i) + ROFCROT(i,m)*FAREROT(i,m)
!                                                     ROFNROT_g(i)=ROFNROT_g(i) + ROFNROT(i,m)*FAREROT(i,m)
!                                                     WTRCROT_g(i)=WTRCROT_g(i) + WTRCROT(i,m)*FAREROT(i,m)
!                                                     WTRSROT_g(i)=WTRSROT_g(i) + WTRSROT(i,m)*FAREROT(i,m)
!                                                     WTRGROT_g(i)=WTRGROT_g(i) + WTRGROT(i,m)*FAREROT(i,m)
!                                                     QFNROT_g(i) =QFNROT_g(i) + QFNROT(i,m)*FAREROT(i,m)
!                                                     QFGROT_g(i) =QFGROT_g(i) + QFGROT(i,m)*FAREROT(i,m)
!                                                     ROFROT_g(i) =ROFROT_g(i) + ROFROT(i,m)*FAREROT(i,m)
!                                                     SNOROT_g(i) =SNOROT_g(i) + SNOROT(i,m)*FAREROT(i,m)
!                                                     CDHROT_g(i) =CDHROT_g(i) + CDHROT(i,m)*FAREROT(i,m)
!                                                     CDMROT_g(i) =CDMROT_g(i) + CDMROT(i,m)*FAREROT(i,m)
!                                                     SFCUROT_g(i) =SFCUROT_g(i) + SFCUROT(i,m)*FAREROT(i,m)
!                                                     SFCVROT_g(i) =SFCVROT_g(i) + SFCVROT(i,m)*FAREROT(i,m)
!                                                     ACTLYR_g(i) = ACTLYR_g(i) + ACTLYR(i,m) * FAREROT(i,m)
!                                                     FTABLE_g(i) = FTABLE_g(i) + FTABLE(i,m) * FAREROT(i,m)
!                                                 !
!                                                 !======================== CTEM =====================================/
! 425                                             CONTINUE
!                                                 !===================== CTEM =====================================\
!                                                 !      WRITE CTEM OUTPUT FILES
!                                                 !
!                                                 if ((iyear .ge. jhhsty) .and. (iyear .le. jhhendy)) then
!                                                     if ((iday .ge. jhhstd) .and. (iday .le. jhhendd)) then
!
!                                                         IF (CTEM_ON) THEN
!                                                             WRITE(711,7200)IHOUR,IMIN,IDAY,IYEAR,(ANVEGROW_G(I,J),&
!                                                                 &                 J=1,ICC),(RMLVEGROW_G(I,J),J=1,ICC)
!                                                         ENDIF !CTEM_ON
!
!                                                         WRITE(641,6400) IHOUR,IMIN,IDAY,IYEAR,FSSTAR_G(i),FLSTAR_G(i),&
!                                                             &                  QH_G(i),QE_G(i),SNOMLT_G(i),BEG_G(i),GTOUT_G(i),&
!                                                             &                  SNOROT_G(I),RHOSROT_G(I),WSNOROT_G(I),&
!                                                             &                  ALTOT_G(i),ROFROT_G(I),TPN_G(i),ZPNDROT_G(I),&
!                                                             &                  CDHROT_G(I),CDMROT_G(I),SFCUROT_G(I),&
!                                                             &                  SFCVROT_G(I),UVROW(I)
!                                                         WRITE(651,6500) IHOUR,IMIN,IDAY,IYEAR,(TBARROT_G(I,J)-&
!                                                             &                   TFREZ,THLQROT_G(I,J),THICROT_G(I,J),J=1,3),&
!                                                             &                   TCN_G(i),RCANROT_G(I),SCANROT_G(I),TSN_G(i),&
!                                                             &                   ZSN_G(i),TCN_G(i)-(TAROW(I)-TFREZ),&
!                                                             &                   TCANO(I)-TFREZ,TACGAT(I)-TFREZ
!                                                         !
!                                                         IF(IGND.GT.3) THEN
!                                                             WRITE(661,6601) IHOUR,IMIN,IDAY,IYEAR,(TBARROT_G(I,J)-&
!                                                                 &                   TFREZ,THLQROT_G(I,J),THICROT_G(I,J),J=1,IGND),&
!                                                                 &                   (GFLXROT_G(I,J),J=1,IGND)
!                                                         ELSE
!                                                             WRITE(661,6600) IHOUR,IMIN,IDAY,FSSROW(I),FDLROW(I),PREROW(I),&
!                                                                 &                   TAROW(I)-TFREZ,UVROW(I),PRESROW(I),QAROW(I)
!                                                         ENDIF
!                                                         !
!                                                         WRITE(671,6700) IHOUR,IMIN,IDAY,IYEAR,&
!                                                             &                   TROFROT_G(I),TROOROT_G(I),TROSROT_G(I),&
!                                                             &                   TROBROT_G(I),ROFROT_G(I),ROFOROT_G(I),&
!                                                             &                   ROFSROT_G(I),ROFBROT_G(I),&
!                                                             &                   FCS_G(I),FGS_G(I),FC_G(I),FG_G(I)
!                                                         WRITE(681,6800) IHOUR,IMIN,IDAY,IYEAR,&
!                                                             &                   FSGVROT_G(I),FSGSROT_G(I),FSGGROT_G(I),&
!                                                             &                   FLGVROT_G(I),FLGSROT_G(I),FLGGROT_G(I),&
!                                                             &                   HFSCROT_G(I),HFSSROT_G(I),HFSGROT_G(I),&
!                                                             &                   HEVCROT_G(I),HEVSROT_G(I),HEVGROT_G(I),&
!                                                             &                   HMFCROT_G(I),HMFNROT_G(I),&
!                                                             &                   (HMFGROT_G(I,J),J=1,3),&
!                                                             &                   HTCCROT_G(I),HTCSROT_G(I),&
!                                                             &                   (HTCROT_G(I,J),J=1,3)
!                                                         WRITE(691,6900) IHOUR,IMIN,IDAY,IYEAR,&
!                                                             &                   PCFCROT_G(I),PCLCROT_G(I),PCPNROT_G(I),&
!                                                             &                   PCPGROT_G(I),QFCFROT_G(I),QFCLROT_G(I),&
!                                                             &                   QFNROT_G(I),QFGROT_G(I),(QFCROT_G(I,J),J=1,3),&
!                                                             &                   ROFCROT_G(I),ROFNROT_G(I),ROFOROT_G(I),&
!                                                             &                   ROFROT_G(I),WTRCROT_G(I),WTRSROT_G(I),&
!                                                             &                   WTRGROT_G(I)
!                                                     !
!                                                     endif
!                                                 ENDIF ! if write half-hourly
!                                             !===================== CTEM =====================================/
! 450                                         CONTINUE
!                                         !
!                                         !===================== CTEM =====================================\
!
!                                         endif ! not parallelrun
!                                         !===================== CTEM =====================================/
!                                         !
!                                         !=======================================================================
!                                         !     * CALCULATE GRID CELL AVERAGE DIAGNOSTIC FIELDS.
!                                         !
!                                         !===================== CTEM =====================================\
!
!                                         if(.not.parallelrun) then ! stand alone mode, includes
!                                             !                               ! diagnostic fields
!                                             !===================== CTEM =====================================/
!                                             !
!                                             DO 525 I=1,NLTEST
!                                                 CDHROW(I)=0.
!                                                 CDMROW(I)=0.
!                                                 HFSROW(I)=0.
!                                                 TFXROW(I)=0.
!                                                 QEVPROW(I)=0.
!                                                 QFSROW(I)=0.
!                                                 QFXROW(I)=0.
!                                                 PETROW(I)=0.
!                                                 GAROW(I)=0.
!                                                 EFROW(I)=0.
!                                                 GTROW(I)=0.
!                                                 QGROW(I)=0.
!                                                 ALVSROW(I)=0.
!                                                 ALIRROW(I)=0.
!                                                 SFCTROW(I)=0.
!                                                 SFCUROW(I)=0.
!                                                 SFCVROW(I)=0.
!                                                 SFCQROW(I)=0.
!                                                 SFRHROW(I)=0.
!                                                 FSNOROW(I)=0.
!                                                 FSGVROW(I)=0.
!                                                 FSGSROW(I)=0.
!                                                 FSGGROW(I)=0.
!                                                 FLGVROW(I)=0.
!                                                 FLGSROW(I)=0.
!                                                 FLGGROW(I)=0.
!                                                 HFSCROW(I)=0.
!                                                 HFSSROW(I)=0.
!                                                 HFSGROW(I)=0.
!                                                 HEVCROW(I)=0.
!                                                 HEVSROW(I)=0.
!                                                 HEVGROW(I)=0.
!                                                 HMFCROW(I)=0.
!                                                 HMFNROW(I)=0.
!                                                 HTCCROW(I)=0.
!                                                 HTCSROW(I)=0.
!                                                 PCFCROW(I)=0.
!                                                 PCLCROW(I)=0.
!                                                 PCPNROW(I)=0.
!                                                 PCPGROW(I)=0.
!                                                 QFGROW(I)=0.
!                                                 QFNROW(I)=0.
!                                                 QFCLROW(I)=0.
!                                                 QFCFROW(I)=0.
!                                                 ROFROW(I)=0.
!                                                 ROFOROW(I)=0.
!                                                 ROFSROW(I)=0.
!                                                 ROFBROW(I)=0.
!                                                 ROFCROW(I)=0.
!                                                 ROFNROW(I)=0.
!                                                 ROVGROW(I)=0.
!                                                 WTRCROW(I)=0.
!                                                 WTRSROW(I)=0.
!                                                 WTRGROW(I)=0.
!                                                 DRROW(I)=0.
!                                                 WTABROW(I)=0.
!                                                 ILMOROW(I)=0.
!                                                 UEROW(I)=0.
!                                                 HBLROW(I)=0.
!                                                 DO 500 J=1,IGND
!                                                     HMFGROW(I,J)=0.
!                                                     HTCROW(I,J)=0.
!                                                     QFCROW(I,J)=0.
!                                                     GFLXROW(I,J)=0.
! 500                                             CONTINUE
! 525                                         CONTINUE
!                                             !
!                                             DO 600 I=1,NLTEST
!                                                 DO 575 M=1,NMTEST
!                                                     CDHROW(I)=CDHROW(I)+CDHROT(I,M)*FAREROT(I,M)
!                                                     CDMROW(I)=CDMROW(I)+CDMROT(I,M)*FAREROT(I,M)
!                                                     HFSROW(I)=HFSROW(I)+HFSROT(I,M)*FAREROT(I,M)
!                                                     TFXROW(I)=TFXROW(I)+TFXROT(I,M)*FAREROT(I,M)
!                                                     QEVPROW(I)=QEVPROW(I)+QEVPROT(I,M)*FAREROT(I,M)
!                                                     QFSROW(I)=QFSROW(I)+QFSROT(I,M)*FAREROT(I,M)
!                                                     QFXROW(I)=QFXROW(I)+QFXROT(I,M)*FAREROT(I,M)
!                                                     PETROW(I)=PETROW(I)+PETROT(I,M)*FAREROT(I,M)
!                                                     GAROW(I)=GAROW(I)+GAROT(I,M)*FAREROT(I,M)
!                                                     EFROW(I)=EFROW(I)+EFROT(I,M)*FAREROT(I,M)
!                                                     GTROW(I)=GTROW(I)+GTROT(I,M)*FAREROT(I,M)
!                                                     QGROW(I)=QGROW(I)+QGROT(I,M)*FAREROT(I,M)
!                                                     ALVSROW(I)=ALVSROW(I)+ALVSROT(I,M)*FAREROT(I,M)
!                                                     ALIRROW(I)=ALIRROW(I)+ALIRROT(I,M)*FAREROT(I,M)
!                                                     SFCTROW(I)=SFCTROW(I)+SFCTROT(I,M)*FAREROT(I,M)
!                                                     SFCUROW(I)=SFCUROW(I)+SFCUROT(I,M)*FAREROT(I,M)
!                                                     SFCVROW(I)=SFCVROW(I)+SFCVROT(I,M)*FAREROT(I,M)
!                                                     SFCQROW(I)=SFCQROW(I)+SFCQROT(I,M)*FAREROT(I,M)
!                                                     SFRHROW(I)=SFRHROW(I)+SFRHROT(I,M)*FAREROT(I,M)
!                                                     FSNOROW(I)=FSNOROW(I)+FSNOROT(I,M)*FAREROT(I,M)
!                                                     FSGVROW(I)=FSGVROW(I)+FSGVROT(I,M)*FAREROT(I,M)
!                                                     FSGSROW(I)=FSGSROW(I)+FSGSROT(I,M)*FAREROT(I,M)
!                                                     FSGGROW(I)=FSGGROW(I)+FSGGROT(I,M)*FAREROT(I,M)
!                                                     FLGVROW(I)=FLGVROW(I)+FLGVROT(I,M)*FAREROT(I,M)
!                                                     FLGSROW(I)=FLGSROW(I)+FLGSROT(I,M)*FAREROT(I,M)
!                                                     FLGGROW(I)=FLGGROW(I)+FLGGROT(I,M)*FAREROT(I,M)
!                                                     HFSCROW(I)=HFSCROW(I)+HFSCROT(I,M)*FAREROT(I,M)
!                                                     HFSSROW(I)=HFSSROW(I)+HFSSROT(I,M)*FAREROT(I,M)
!                                                     HFSGROW(I)=HFSGROW(I)+HFSGROT(I,M)*FAREROT(I,M)
!                                                     HEVCROW(I)=HEVCROW(I)+HEVCROT(I,M)*FAREROT(I,M)
!                                                     HEVSROW(I)=HEVSROW(I)+HEVSROT(I,M)*FAREROT(I,M)
!                                                     HEVGROW(I)=HEVGROW(I)+HEVGROT(I,M)*FAREROT(I,M)
!                                                     HMFCROW(I)=HMFCROW(I)+HMFCROT(I,M)*FAREROT(I,M)
!                                                     HMFNROW(I)=HMFNROW(I)+HMFNROT(I,M)*FAREROT(I,M)
!                                                     HTCCROW(I)=HTCCROW(I)+HTCCROT(I,M)*FAREROT(I,M)
!                                                     HTCSROW(I)=HTCSROW(I)+HTCSROT(I,M)*FAREROT(I,M)
!                                                     PCFCROW(I)=PCFCROW(I)+PCFCROT(I,M)*FAREROT(I,M)
!                                                     PCLCROW(I)=PCLCROW(I)+PCLCROT(I,M)*FAREROT(I,M)
!                                                     PCPNROW(I)=PCPNROW(I)+PCPNROT(I,M)*FAREROT(I,M)
!                                                     PCPGROW(I)=PCPGROW(I)+PCPGROT(I,M)*FAREROT(I,M)
!                                                     QFGROW(I)=QFGROW(I)+QFGROT(I,M)*FAREROT(I,M)
!                                                     QFNROW(I)=QFNROW(I)+QFNROT(I,M)*FAREROT(I,M)
!                                                     QFCLROW(I)=QFCLROW(I)+QFCLROT(I,M)*FAREROT(I,M)
!                                                     QFCFROW(I)=QFCFROW(I)+QFCFROT(I,M)*FAREROT(I,M)
!                                                     ROFROW(I)=ROFROW(I)+ROFROT(I,M)*FAREROT(I,M)
!                                                     ROFOROW(I)=ROFOROW(I)+ROFOROT(I,M)*FAREROT(I,M)
!                                                     ROFSROW(I)=ROFSROW(I)+ROFSROT(I,M)*FAREROT(I,M)
!                                                     ROFBROW(I)=ROFBROW(I)+ROFBROT(I,M)*FAREROT(I,M)
!                                                     ROFCROW(I)=ROFCROW(I)+ROFCROT(I,M)*FAREROT(I,M)
!                                                     ROFNROW(I)=ROFNROW(I)+ROFNROT(I,M)*FAREROT(I,M)
!                                                     ROVGROW(I)=ROVGROW(I)+ROVGROT(I,M)*FAREROT(I,M)
!                                                     WTRCROW(I)=WTRCROW(I)+WTRCROT(I,M)*FAREROT(I,M)
!                                                     WTRSROW(I)=WTRSROW(I)+WTRSROT(I,M)*FAREROT(I,M)
!                                                     WTRGROW(I)=WTRGROW(I)+WTRGROT(I,M)*FAREROT(I,M)
!                                                     DRROW(I)=DRROW(I)+DRROT(I,M)*FAREROT(I,M)
!                                                     WTABROW(I)=WTABROW(I)+WTABROT(I,M)*FAREROT(I,M)
!                                                     ILMOROW(I)=ILMOROW(I)+ILMOROT(I,M)*FAREROT(I,M)
!                                                     UEROW(I)=UEROW(I)+UEROT(I,M)*FAREROT(I,M)
!                                                     HBLROW(I)=HBLROW(I)+HBLROT(I,M)*FAREROT(I,M)
!                                                     DO 550 J=1,IGND
!                                                         HMFGROW(I,J)=HMFGROW(I,J)+HMFGROT(I,M,J)*FAREROT(I,M)
!                                                         HTCROW(I,J)=HTCROW(I,J)+HTCROT(I,M,J)*FAREROT(I,M)
!                                                         QFCROW(I,J)=QFCROW(I,J)+QFCROT(I,M,J)*FAREROT(I,M)
!                                                         GFLXROW(I,J)=GFLXROW(I,J)+GFLXROT(I,M,J)*FAREROT(I,M)
! 550                                                 CONTINUE
! 575                                             CONTINUE
! 600                                         CONTINUE
!                                         !
!                                         !===================== CTEM =====================================\
!
!                                         endif ! not parallelrun, for diagnostic fields
!                                         !
!                                         if(.not.parallelrun) then ! stand alone mode, includes daily output for class
!                                             !===================== CTEM =====================================/
!                                             !
!                                             !     * ACCUMULATE OUTPUT DATA FOR DIURNALLY AVERAGED FIELDS. BOTH GRID
!                                             !       MEAN AND MOSAIC MEAN
!                                             !
!                                             DO 675 I=1,NLTEST
!
!                                                 IF (FSSROW(I) .gt. 0.) then
!                                                     ALTOTACC(I)=ALTOTACC(I) + (FSSROW(I)-(FSGVROW(I)&
!                                                         &                   +FSGSROW(I)+FSGGROW(I)))/FSSROW(I)
!                                                     altotcntr_d(i)=altotcntr_d(i) + 1
!                                                 END IF
!
!                                                 DO 650 M=1,NMTEST
!                                                     PREACC(I)=PREACC(I)+PREROW(I)*FAREROT(I,M)*DELT
!                                                     GTACC(I)=GTACC(I)+GTROT(I,M)*FAREROT(I,M)
!                                                     QEVPACC(I)=QEVPACC(I)+QEVPROT(I,M)*FAREROT(I,M)
!                                                     EVAPACC(I)=EVAPACC(I)+QFSROT(I,M)*FAREROT(I,M)*DELT
!                                                     HFSACC(I)=HFSACC(I)+HFSROT(I,M)*FAREROT(I,M)
!                                                     HMFNACC(I)=HMFNACC(I)+HMFNROT(I,M)*FAREROT(I,M)
!                                                     ROFACC(I)=ROFACC(I)+ROFROT(I,M)*FAREROT(I,M)*DELT
!                                                     OVRACC(I)=OVRACC(I)+ROFOROT(I,M)*FAREROT(I,M)*DELT
!                                                     WTBLACC(I)=WTBLACC(I)+WTABROT(I,M)*FAREROT(I,M)
!                                                     DO 625 J=1,IGND
!                                                         TBARACC(I,J)=TBARACC(I,J)+TBARROT(I,M,J)*FAREROT(I,M)
!                                                         THLQACC(I,J)=THLQACC(I,J)+THLQROT(I,M,J)*FAREROT(I,M)
!                                                         THICACC(I,J)=THICACC(I,J)+THICROT(I,M,J)*FAREROT(I,M)
!                                                         THALACC(I,J)=THALACC(I,J)+(THLQROT(I,M,J)+THICROT(I,M,J))&
!                                                             &                    *FAREROT(I,M)
! 625                                                 CONTINUE
!                                                     ALVSACC(I)=ALVSACC(I)+ALVSROT(I,M)*FAREROT(I,M)*FSVHROW(I)
!                                                     ALIRACC(I)=ALIRACC(I)+ALIRROT(I,M)*FAREROT(I,M)*FSIHROW(I)
!                                                     IF(SNOROT(I,M).GT.0.0) THEN
!                                                         RHOSACC(I)=RHOSACC(I)+RHOSROT(I,M)*FAREROT(I,M)
!                                                         TSNOACC(I)=TSNOACC(I)+TSNOROT(I,M)*FAREROT(I,M)
!                                                         WSNOACC(I)=WSNOACC(I)+WSNOROT(I,M)*FAREROT(I,M)
!                                                         SNOARE(I)=SNOARE(I)+FAREROT(I,M)
!                                                     ENDIF
!                                                     IF(TCANROT(I,M).GT.0.5) THEN
!                                                         TCANACC(I)=TCANACC(I)+TCANROT(I,M)*FAREROT(I,M)
!                                                         CANARE(I)=CANARE(I)+FAREROT(I,M)
!                                                     ENDIF
!                                                     SNOACC(I)=SNOACC(I)+SNOROT(I,M)*FAREROT(I,M)
!                                                     RCANACC(I)=RCANACC(I)+RCANROT(I,M)*FAREROT(I,M)
!                                                     SCANACC(I)=SCANACC(I)+SCANROT(I,M)*FAREROT(I,M)
!                                                     GROACC(I)=GROACC(I)+GROROT(I,M)*FAREROT(I,M)
!                                                     FSINACC(I)=FSINACC(I)+FSSROW(I)*FAREROT(I,M)
!                                                     FLINACC(I)=FLINACC(I)+FDLROW(I)*FAREROT(I,M)
!                                                     FLUTACC(I)=FLUTACC(I)+SBC*GTROT(I,M)**4*FAREROT(I,M)
!                                                     TAACC(I)=TAACC(I)+TAROW(I)*FAREROT(I,M)
!                                                     UVACC(I)=UVACC(I)+UVROW(I)*FAREROT(I,M)
!                                                     PRESACC(I)=PRESACC(I)+PRESROW(I)*FAREROT(I,M)
!                                                     QAACC(I)=QAACC(I)+QAROW(I)*FAREROT(I,M)
! 650                                             CONTINUE
! 675                                         CONTINUE
!                                             !
!                                             !     * CALCULATE AND PRINT DAILY AVERAGES.
!                                             !
!                                             IF(NCOUNT.EQ.NDAY) THEN
!
!                                                 DO 800 I=1,NLTEST
!                                                     PREACC(I)=PREACC(I)
!                                                     GTACC(I)=GTACC(I)/REAL(NDAY)
!                                                     QEVPACC(I)=QEVPACC(I)/REAL(NDAY)
!                                                     EVAPACC(I)=EVAPACC(I)
!                                                     HFSACC(I)=HFSACC(I)/REAL(NDAY)
!                                                     HMFNACC(I)=HMFNACC(I)/REAL(NDAY)
!                                                     ROFACC(I)=ROFACC(I)
!                                                     OVRACC(I)=OVRACC(I)
!                                                     WTBLACC(I)=WTBLACC(I)/REAL(NDAY)
!                                                     DO 725 J=1,IGND
!                                                         TBARACC(I,J)=TBARACC(I,J)/REAL(NDAY)
!                                                         THLQACC(I,J)=THLQACC(I,J)/REAL(NDAY)
!                                                         THICACC(I,J)=THICACC(I,J)/REAL(NDAY)
!                                                         THALACC(I,J)=THALACC(I,J)/REAL(NDAY)
! 725                                                 CONTINUE
!                                                     IF(FSINACC(I).GT.0.0) THEN
!                                                         ALVSACC(I)=ALVSACC(I)/(FSINACC(I)*0.5)
!                                                         ALIRACC(I)=ALIRACC(I)/(FSINACC(I)*0.5)
!                                                     ELSE
!                                                         ALVSACC(I)=0.0
!                                                         ALIRACC(I)=0.0
!                                                     ENDIF
!                                                     IF(SNOARE(I).GT.0.0) THEN
!                                                         RHOSACC(I)=RHOSACC(I)/SNOARE(I)
!                                                         TSNOACC(I)=TSNOACC(I)/SNOARE(I)
!                                                         WSNOACC(I)=WSNOACC(I)/SNOARE(I)
!                                                     ENDIF
!                                                     IF(CANARE(I).GT.0.0) THEN
!                                                         TCANACC(I)=TCANACC(I)/CANARE(I)
!                                                     ENDIF
!                                                     SNOACC(I)=SNOACC(I)/REAL(NDAY)
!                                                     RCANACC(I)=RCANACC(I)/REAL(NDAY)
!                                                     SCANACC(I)=SCANACC(I)/REAL(NDAY)
!                                                     GROACC(I)=GROACC(I)/REAL(NDAY)
!                                                     FSINACC(I)=FSINACC(I)/REAL(NDAY)
!                                                     FLINACC(I)=FLINACC(I)/REAL(NDAY)
!                                                     FLUTACC(I)=FLUTACC(I)/REAL(NDAY)
!                                                     TAACC(I)=TAACC(I)/REAL(NDAY)
!                                                     UVACC(I)=UVACC(I)/REAL(NDAY)
!                                                     PRESACC(I)=PRESACC(I)/REAL(NDAY)
!                                                     QAACC(I)=QAACC(I)/REAL(NDAY)
!                                                     if (altotcntr_d(i) > 0) then
!                                                         ALTOTACC(I)=ALTOTACC(I)/REAL(altotcntr_d(i))
!                                                     else
!                                                         ALTOTACC(I)=0.
!                                                     end if
!                                                     FSSTAR=FSINACC(I)*(1.-ALTOTACC(I))
!                                                     FLSTAR=FLINACC(I)-FLUTACC(I)
!                                                     QH=HFSACC(I)
!                                                     QE=QEVPACC(I)
!                                                     BEG=FSSTAR+FLSTAR-QH-QE
!                                                     SNOMLT=HMFNACC(I)
!                                                     IF(RHOSACC(I).GT.0.0) THEN
!                                                         ZSN=SNOACC(I)/RHOSACC(I)
!                                                     ELSE
!                                                         ZSN=0.0
!                                                     ENDIF
!                                                     IF(TCANACC(I).GT.0.01) THEN
!                                                         TCN=TCANACC(I)-TFREZ
!                                                     ELSE
!                                                         TCN=0.0
!                                                     ENDIF
!                                                     IF(TSNOACC(I).GT.0.01) THEN
!                                                         TSN=TSNOACC(I)-TFREZ
!                                                     ELSE
!                                                         TSN=0.0
!                                                     ENDIF
!                                                     GTOUT=GTACC(I)-TFREZ
!                                                     !
!                                                     if ((iyear .ge. jdsty) .and. (iyear .le. jdendy)) then
!                                                         if ((iday .ge. jdstd) .and. (iday .le. jdendd)) then
!
!                                                             WRITE(61,6100) IDAY,IYEAR,FSSTAR,FLSTAR,QH,QE,SNOMLT,&
!                                                                 &                       BEG,GTOUT,SNOACC(I),RHOSACC(I),&
!                                                                 &                       WSNOACC(I),ALTOTACC(I),ROFACC(I),CUMSNO
!                                                             IF(IGND.GT.3) THEN
!                                                                 WRITE(62,6201) IDAY,IYEAR,(TBARACC(I,J)-TFREZ,&
!                                                                     &                       THLQACC(I,J),THICACC(I,J),J=1,IGND),&
!                                                                     &                       ACTLYR_G(I),FTABLE_g(I)
!                                                             ELSE
!                                                                 WRITE(62,6200) IDAY,IYEAR,(TBARACC(I,J)-TFREZ,&
!                                                                     &                       THLQACC(I,J),THICACC(I,J),J=1,3),&
!                                                                     &                       TCN,RCANACC(I),SCANACC(I),TSN,ZSN,&
!                                                                     &                       ACTLYR_G(I),FTABLE_g(I)
!                                                             ENDIF
!                                                             WRITE(63,6300) IDAY,IYEAR,FSINACC(I),FLINACC(I),&
!                                                                 &                       TAACC(I)-TFREZ,UVACC(I),PRESACC(I),&
!                                                                 &                       QAACC(I),PREACC(I),EVAPACC(I)
!
!                                                         endif
!                                                     ENDIF
!                                                     !
!                                                     !     * RESET ACCUMULATOR ARRAYS.
!                                                     !
!                                                     PREACC(I)=0.
!                                                     GTACC(I)=0.
!                                                     QEVPACC(I)=0.
!                                                     HFSACC(I)=0.
!                                                     HMFNACC(I)=0.
!                                                     ROFACC(I)=0.
!                                                     SNOACC(I)=0.
!                                                     CANARE(I)=0.
!                                                     SNOARE(I)=0.
!                                                     OVRACC(I)=0.
!                                                     WTBLACC(I)=0.
!                                                     DO 750 J=1,IGND
!                                                         TBARACC(I,J)=0.
!                                                         THLQACC(I,J)=0.
!                                                         THICACC(I,J)=0.
!                                                         THALACC(I,J)=0.
! 750                                                 CONTINUE
!                                                     ALVSACC(I)=0.
!                                                     ALIRACC(I)=0.
!                                                     RHOSACC(I)=0.
!                                                     TSNOACC(I)=0.
!                                                     WSNOACC(I)=0.
!                                                     TCANACC(I)=0.
!                                                     RCANACC(I)=0.
!                                                     SCANACC(I)=0.
!                                                     GROACC(I)=0.
!                                                     FSINACC(I)=0.
!                                                     FLINACC(I)=0.
!                                                     TAACC(I)=0.
!                                                     UVACC(I)=0.
!                                                     PRESACC(I)=0.
!                                                     QAACC(I)=0.
!                                                     ALTOTACC(I) = 0.
!                                                     EVAPACC(I)=0.
!                                                     FLUTACC(I)=0.
! 800                                             CONTINUE
!
!                                             ENDIF ! IF(NCOUNT.EQ.NDAY)
!
!                                             !===================== CTEM =====================================\
!                                             !
!                                             !     CALCULATE AND PRINT MOSAIC DAILY AVERAGES.
!                                             !
!                                             !       start -> FLAG JM
!                                             DO 676 I=1,NLTEST
!                                                 DO 658 M=1,NMTEST
!                                                     PREACC_M(I,M)=PREACC_M(I,M)+PREROW(I)*DELT
!                                                     GTACC_M(I,M)=GTACC_M(I,M)+GTROT(I,M)
!                                                     QEVPACC_M(I,M)=QEVPACC_M(I,M)+QEVPROT(I,M)
!                                                     EVAPACC_M(I,M)=EVAPACC_M(I,M)+QFSROT(I,M)*DELT
!                                                     HFSACC_M(I,M)=HFSACC_M(I,M)+HFSROT(I,M)
!                                                     HMFNACC_M(I,M)=HMFNACC_M(I,M)+HMFNROT(I,M)
!                                                     ROFACC_M(I,M)=ROFACC_M(I,M)+ROFROT(I,M)*DELT
!                                                     OVRACC_M(I,M)=OVRACC_M(I,M)+ROFOROT(I,M)*DELT
!                                                     WTBLACC_M(I,M)=WTBLACC_M(I,M)+WTABROT(I,M)
!
!                                                     DO 626 J=1,IGND
!                                                         TBARACC_M(I,M,J)=TBARACC_M(I,M,J)+TBARROT(I,M,J)
!                                                         THLQACC_M(I,M,J)=THLQACC_M(I,M,J)+THLQROT(I,M,J)
!                                                         THICACC_M(I,M,J)=THICACC_M(I,M,J)+THICROT(I,M,J)
!                                                         THALACC_M(I,M,J)=THALACC_M(I,M,J)+(THLQROT(I,M,J)+&
!                                                             &           THICROT(I,M,J))
! 626                                                 CONTINUE
!
!                                                     ALVSACC_M(I,M)=ALVSACC_M(I,M)+ALVSROT(I,M)*FSVHROW(I)
!                                                     ALIRACC_M(I,M)=ALIRACC_M(I,M)+ALIRROT(I,M)*FSIHROW(I)
!                                                     IF(SNOROT(I,M).GT.0.0) THEN
!                                                         RHOSACC_M(I,M)=RHOSACC_M(I,M)+RHOSROT(I,M)
!                                                         TSNOACC_M(I,M)=TSNOACC_M(I,M)+TSNOROT(I,M)
!                                                         WSNOACC_M(I,M)=WSNOACC_M(I,M)+WSNOROT(I,M)
!                                                         SNOARE_M(I,M) = SNOARE_M(I,M) + 1.0 !FLAG test.
!                                                     ENDIF
!                                                     IF(TCANROT(I,M).GT.0.5) THEN
!                                                         TCANACC_M(I,M)=TCANACC_M(I,M)+TCANROT(I,M)
!                                                     !              CANARE(I)=CANARE(I)+FAREROT(I,M)
!                                                     ENDIF
!                                                     SNOACC_M(I,M)=SNOACC_M(I,M)+SNOROT(I,M)
!                                                     RCANACC_M(I,M)=RCANACC_M(I,M)+RCANROT(I,M)
!                                                     SCANACC_M(I,M)=SCANACC_M(I,M)+SCANROT(I,M)
!                                                     GROACC_M(I,M)=GROACC_M(I,M)+GROROT(I,M)
!                                                     IF (FSSROW(I) .gt. 0.) THEN ! we will reuse the altotcntr_d counter values so don't need to do again.
!                                                         ALTOTACC_M(I,M)=ALTOTACC_M(I,M) + (FSSROW(I)-&
!                                                             &                    (FSGVROT(I,M)+FSGSROT(I,M)+&
!                                                             &                     FSGGROT(I,M)))/FSSROW(I)
!                                                     END IF
!                                                     FSINACC_M(I,M)=FSINACC_M(I,M)+FSSROW(I)
!                                                     FLINACC_M(I,M)=FLINACC_M(I,M)+FDLROW(I)
!                                                     FLUTACC_M(I,M)=FLUTACC_M(I,M)+SBC*GTROT(I,M)**4
!                                                     TAACC_M(I,M)=TAACC_M(I,M)+TAROW(I)
!                                                     UVACC_M(I,M)=UVACC_M(I,M)+UVROW(I)
!                                                     PRESACC_M(I,M)=PRESACC_M(I,M)+PRESROW(I)
!                                                     QAACC_M(I,M)=QAACC_M(I,M)+QAROW(I)
! 658                                             CONTINUE
! 676                                         CONTINUE
!                                             !
!                                             !     CALCULATE AND PRINT DAILY AVERAGES.
!                                             !
!                                             IF(NCOUNT.EQ.NDAY) THEN
!
!                                                 DO 808 I=1,NLTEST
!                                                     DO 809 M=1,NMTEST
!                                                         PREACC_M(I,M)=PREACC_M(I,M)     !became [kg m-2 day-1] instead of [kg m-2 s-1]
!                                                         GTACC_M(I,M)=GTACC_M(I,M)/REAL(NDAY)
!                                                         QEVPACC_M(I,M)=QEVPACC_M(I,M)/REAL(NDAY)
!                                                         EVAPACC_M(I,M)=EVAPACC_M(I,M)   !became [kg m-2 day-1] instead of [kg m-2 s-1]
!                                                         HFSACC_M(I,M)=HFSACC_M(I,M)/REAL(NDAY)
!                                                         HMFNACC_M(I,M)=HMFNACC_M(I,M)/REAL(NDAY)
!                                                         ROFACC_M(I,M)=ROFACC_M(I,M)   !became [kg m-2 day-1] instead of [kg m-2 s-1
!                                                         OVRACC_M(I,M)=OVRACC_M(I,M)   !became [kg m-2 day-1] instead of [kg m-2 s-1]
!                                                         WTBLACC_M(I,M)=WTBLACC_M(I,M)/REAL(NDAY)
!                                                         DO 726 J=1,IGND
!                                                             TBARACC_M(I,M,J)=TBARACC_M(I,M,J)/REAL(NDAY)
!                                                             THLQACC_M(I,M,J)=THLQACC_M(I,M,J)/REAL(NDAY)
!                                                             THICACC_M(I,M,J)=THICACC_M(I,M,J)/REAL(NDAY)
!                                                             THALACC_M(I,M,J)=THALACC_M(I,M,J)/REAL(NDAY)
! 726                                                     CONTINUE
!                                                         !
!                                                         IF(FSINACC_M(I,M).GT.0.0) THEN
!                                                             ALVSACC_M(I,M)=ALVSACC_M(I,M)/(FSINACC_M(I,M)*0.5)
!                                                             ALIRACC_M(I,M)=ALIRACC_M(I,M)/(FSINACC_M(I,M)*0.5)
!                                                         ELSE
!                                                             ALVSACC_M(I,M)=0.0
!                                                             ALIRACC_M(I,M)=0.0
!                                                         ENDIF
!                                                         !
!                                                         SNOACC_M(I,M)=SNOACC_M(I,M)/REAL(NDAY)
!                                                         if (SNOARE_M(I,M) .GT. 0.) THEN
!                                                             RHOSACC_M(I,M)=RHOSACC_M(I,M)/SNOARE_M(I,M)
!                                                             TSNOACC_M(I,M)=TSNOACC_M(I,M)/SNOARE_M(I,M)
!                                                             WSNOACC_M(I,M)=WSNOACC_M(I,M)/SNOARE_M(I,M)
!                                                         END IF
!                                                         TCANACC_M(I,M)=TCANACC_M(I,M)/REAL(NDAY)
!                                                         RCANACC_M(I,M)=RCANACC_M(I,M)/REAL(NDAY)
!                                                         SCANACC_M(I,M)=SCANACC_M(I,M)/REAL(NDAY)
!                                                         GROACC_M(I,M)=GROACC_M(I,M)/REAL(NDAY)
!                                                         FSINACC_M(I,M)=FSINACC_M(I,M)/REAL(NDAY)
!                                                         FLINACC_M(I,M)=FLINACC_M(I,M)/REAL(NDAY)
!                                                         FLUTACC_M(I,M)=FLUTACC_M(I,M)/REAL(NDAY)
!                                                         TAACC_M(I,M)=TAACC_M(I,M)/REAL(NDAY)
!                                                         UVACC_M(I,M)=UVACC_M(I,M)/REAL(NDAY)
!                                                         PRESACC_M(I,M)=PRESACC_M(I,M)/REAL(NDAY)
!                                                         QAACC_M(I,M)=QAACC_M(I,M)/REAL(NDAY)
!                                                         ALTOTACC_M(I,M)=ALTOTACC_M(I,M)/REAL(altotcntr_d(i))
!                                                         FSSTAR=FSINACC_M(I,M)*(1.-ALTOTACC_M(I,M))
!                                                         FLSTAR=FLINACC_M(I,M)-FLUTACC_M(I,M)
!                                                         QH=HFSACC_M(I,M)
!                                                         QE=QEVPACC_M(I,M)
!                                                         QEVPACC_M_SAVE(I,M)=QEVPACC_M(I,M)   !FLAG! What is the point of this? JM Apr 12015
!                                                         BEG=FSSTAR+FLSTAR-QH-QE
!                                                         SNOMLT=HMFNACC_M(I,M)
!                                                         !
!                                                         IF(RHOSACC_M(I,M).GT.0.0) THEN
!                                                             ZSN=SNOACC_M(I,M)/RHOSACC_M(I,M)
!                                                         ELSE
!                                                             ZSN=0.0
!                                                         ENDIF
!                                                         !
!                                                         IF(TCANACC_M(I,M).GT.0.01) THEN
!                                                             TCN=TCANACC_M(I,M)-TFREZ
!                                                         ELSE
!                                                             TCN=0.0
!                                                         ENDIF
!                                                         !
!                                                         IF(TSNOACC_M(I,M).GT.0.01) THEN
!                                                             TSN=TSNOACC_M(I,M)-TFREZ
!                                                         ELSE
!                                                             TSN=0.0
!                                                         ENDIF
!                                                         !
!                                                         GTOUT=GTACC_M(I,M)-TFREZ
!                                                         !
!                                                         if ((iyear .ge. jdsty) .and. (iyear .le. jdendy)) then
!                                                             if ((iday .ge. jdstd) .and. (iday .le. jdendd)) then
!                                                                 !
!                                                                 !         WRITE TO OUTPUT FILES
!                                                                 !
!                                                                 WRITE(611,6100) IDAY,IYEAR,FSSTAR,FLSTAR,QH,QE,SNOMLT,&
!                                                                     &                    BEG,GTOUT,SNOACC_M(I,M),RHOSACC_M(I,M),&
!                                                                     &                    WSNOACC_M(I,M),ALTOTACC_M(I,M),ROFACC_M(I,M),&
!                                                                     &                    CUMSNO,' TILE ',M
!                                                                 IF(IGND.GT.3) THEN
!                                                                     WRITE(621,6201) IDAY,IYEAR,(TBARACC_M(I,M,J)-TFREZ,&
!                                                                         &                  THLQACC_M(I,M,J),THICACC_M(I,M,J),J=1,IGND)&
!                                                                         &                  ,ACTLYR(I,M), FTABLE(I,M),' TILE ',M
!                                                                 ELSE
!                                                                     WRITE(621,6200) IDAY,IYEAR,(TBARACC_M(I,M,J)-TFREZ,&
!                                                                         &                  THLQACC_M(I,M,J),THICACC_M(I,M,J),J=1,3),&
!                                                                         &                  TCN,RCANACC_M(I,M),SCANACC_M(I,M),TSN,ZSN,&
!                                                                         &                  ' TILE ',M
!                                                                 ENDIF
!                                                                 WRITE(631,6300) IDAY,IYEAR,FSINACC_M(I,M),FLINACC_M(I,M),&
!                                                                     &                  TAACC_M(I,M)-TFREZ,UVACC_M(I,M),PRESACC_M(I,M),&
!                                                                     &                  QAACC_M(I,M),PREACC_M(I,M),EVAPACC_M(I,M),&
!                                                                     &                  ' TILE ',M
!                                                             !
!                                                             endif
!                                                         ENDIF ! IF write daily
!                                                         !
!                                                         !          INITIALIZATION FOR MOSAIC TILE AND GRID VARIABLES
!                                                         !
!                                                         call resetclassaccum(nltest,nmtest)
!                                                     !
! 809                                                 CONTINUE
! 808                                             CONTINUE
!
!                                             ENDIF ! IF(NCOUNT.EQ.NDAY)
!                                         !
!                                         ENDIF !  IF(.NOT.PARALLELRUN)
!
!                                         !=======================================================================
!
!                                         !     Only bother with monthly calculations if we desire those outputs to be written out.
!                                         if (iyear .ge. jmosty) then
!
!                                             call class_monthly_aw(IDAY,IYEAR,NCOUNT,NDAY,SBC,DELT,&
!                                                 &                       nltest,nmtest,ALVSROT,FAREROT,FSVHROW,&
!                                                 &                       ALIRROT,FSIHROW,GTROT,FSSROW,FDLROW,&
!                                                 &                       HFSROT,ROFROT,PREROW,QFSROT,QEVPROT,&
!                                                 &                       SNOROT,TAROW,WSNOROT,TBARROT,THLQROT,&
!                                                 &                       THICROT,TFREZ,QFCROT,QFGROT,QFNROT,&
!                                                 &                       QFCLROT,QFCFROT,FSGVROT,FSGSROT,&
!                                                 &                       FSGGROT,ACTLYR,FTABLE)
!
!                                             DO NT=1,NMON
!                                                 IF(IDAY.EQ.monthend(NT+1).AND.NCOUNT.EQ.NDAY)THEN
!                                                     IMONTH=NT
!                                                 ENDIF
!                                             ENDDO
!
!                                         end if !skip the monthly calculations/writing unless iyear>=jmosty
!
!                                         call class_annual_aw(IDAY,IYEAR,NCOUNT,NDAY,SBC,DELT,&
!                                             &                       nltest,nmtest,ALVSROT,FAREROT,FSVHROW,&
!                                             &                       ALIRROT,FSIHROW,GTROT,FSSROW,FDLROW,&
!                                             &                       HFSROT,ROFROT,PREROW,QFSROT,QEVPROT,&
!                                             &                       TAROW,QFCROT,FSGVROT,FSGSROT,FSGGROT,&
!                                             &                       ACTLYR,FTABLE)
!
!                                         !     CTEM output and write out
!
!                                         if(.not.parallelrun) then ! stand alone mode, includes daily and yearly mosaic-mean output for ctem
!
!                                             !     calculate daily outputs from ctem
!
!                                             if (ctem_on) then
!                                                 if(ncount.eq.nday) then
!                                                     call ctem_daily_aw(nltest,nmtest,iday,FAREROT,&
!                                                         &                      iyear,jdstd,jdsty,jdendd,jdendy,grclarea,&
!                                                         &                      onetile_perPFT)
!                                                 endif ! if(ncount.eq.nday)
!                                             endif ! if(ctem_on)
!
!                                         endif ! if(not.parallelrun)
!
!                                         !=======================================================================
!                                         !     Calculate monthly & yearly output for ctem
!
!
!                                         !     First initialize some output variables
!                                         !     initialization is done just before use.
!
!                                         if (ctem_on) then
!                                             if(ncount.eq.nday) then
!
!                                                 !     Only bother with monthly calculations if we desire those outputs to be written out.
!                                                 if (iyear .ge. jmosty) then
!
!                                                     call ctem_monthly_aw(nltest,nmtest,iday,FAREROT,iyear,nday,&
!                                                         &                        onetile_perPFT)
!
!                                                 end if !to write out the monthly outputs or not
!
!                                                 !       Accumulate and possibly write out yearly outputs
!                                                 call ctem_annual_aw(nltest,nmtest,iday,FAREROT,iyear,&
!                                                     &                           onetile_perPFT)
!
!                                             endif ! if(ncount.eq.nday)
!                                         endif ! if(ctem_on)
!
!                                         !     OPEN AND WRITE TO THE RESTART FILES
!
!
!                                         IF (IDAY.EQ.365.AND.NCOUNT.EQ.NDAY) THEN
!
!                                             WRITE(*,*)'IYEAR=',IYEAR,'CLIMATE YEAR=',CLIMIYEAR,'CO2YEAR =',co2yr,'LUCYR=',lucyr
!
!                                             IF (RSFILE) THEN
!                                                 !       WRITE .INI_RS FOR CLASS RESTART DATA
!
!                                                 OPEN(UNIT=100,FILE=ARGBUFF(1:STRLEN(ARGBUFF))//'.INI_RS')
!
!                                                 WRITE(100,5010) TITLE1,TITLE2,TITLE3,TITLE4,TITLE5,TITLE6
!                                                 WRITE(100,5010) NAME1,NAME2,NAME3,NAME4,NAME5,NAME6
!                                                 WRITE(100,5010) PLACE1,PLACE2,PLACE3,PLACE4,PLACE5,PLACE6
!                                                 WRITE(100,5020)DLATROW(1),DEGLON,ZRFMROW(1),ZRFHROW(1),&
!                                                     &                 ZBLDROW(1),GCROW(1),NLTEST,NMTEST
!                                                 DO I=1,NLTEST
!                                                     DO M=1,NMTEST
!
!                                                         !         IF START_BARE (SO EITHER COMPETE OR LNDUSEON), THEN WE NEED TO CREATE
!                                                         !         THE FCANROT FOR THE RS FILE.
!                                                         IF (START_BARE .AND. onetile_perPFT) THEN
!                                                             IF (M .LE. 2) THEN                     !NDL
!                                                                 FCANROT(I,M,1)=1.0
!                                                             ELSEIF (M .GE. 3 .AND. M .LE. 5) THEN  !BDL
!                                                                 FCANROT(I,M,2)=1.0
!                                                             ELSEIF (M .EQ. 6 .OR. M .EQ. 7) THEN  !CROP
!                                                                 FCANROT(I,M,3)=1.0
!                                                             ELSEIF (M .EQ. 8 .OR. M .EQ. 9) THEN  !GRASSES
!                                                                 FCANROT(I,M,4)=1.0
!                                                             ELSE                                  !BARE
!                                                                 FCANROT(I,M,5)=1.0
!                                                             ENDIF
!                                                         ENDIF !START_BARE/onetile_perPFT
!
!                                                         WRITE(100,5040) (FCANROT(I,M,J),J=1,ICAN+1),(PAMXROT(I,M,J),&
!                                                             &                      J=1,ICAN)
!                                                         WRITE(100,5040) (LNZ0ROT(I,M,J),J=1,ICAN+1),(PAMNROT(I,M,J),&
!                                                             &                      J=1,ICAN)
!                                                         WRITE(100,5040) (ALVCROT(I,M,J),J=1,ICAN+1),(CMASROT(I,M,J),&
!                                                             &                      J=1,ICAN)
!                                                         WRITE(100,5040) (ALICROT(I,M,J),J=1,ICAN+1),(ROOTROT(I,M,J),&
!                                                             &                      J=1,ICAN)
!                                                         WRITE(100,5030) (RSMNROT(I,M,J),J=1,ICAN),&
!                                                             &                      (QA50ROT(I,M,J),J=1,ICAN)
!                                                         WRITE(100,5030) (VPDAROT(I,M,J),J=1,ICAN),&
!                                                             &                      (VPDBROT(I,M,J),J=1,ICAN)
!                                                         WRITE(100,5030) (PSGAROT(I,M,J),J=1,ICAN),&
!                                                             &                      (PSGBROT(I,M,J),J=1,ICAN)
!                                                         WRITE(100,5040) DRNROT(I,M),SDEPROT(I,M),FAREROT(I,M)
!                                                         WRITE(100,5090) XSLPROT(I,M),GRKFROT(I,M),WFSFROT(I,M),&
!                                                             &                      WFCIROT(I,M),MIDROT(I,M)
!                                                         DO J=1,IGND
!                                                             WRITE(100,5080) ZBOT(J),DELZ(J),SANDROT(I,M,J),&
!                                                                 &         CLAYROT(I,M,J),ORGMROT(I,M,J),TBARROT(I,M,J)-273.16,&
!                                                                 &         THLQROT(I,M,J),THICROT(I,M,J)
!                                                         END DO
!                                                         !           Temperatures are in degree C
!                                                         IF (TCANROT(I,M).NE.0.0) TCANRS(I,M)=TCANROT(I,M)-273.16
!                                                         IF (TSNOROT(I,M).NE.0.0) TSNORS(I,M)=TSNOROT(I,M)-273.16
!                                                         IF (TPNDROT(I,M).NE.0.0) TPNDRS(I,M)=TPNDROT(I,M)-273.16
!                                                         WRITE(100,5050)TCANRS(I,M),TSNORS(I,M),TPNDRS(I,M),&
!                                                             &         ZPNDROT(I,M)
!                                                         WRITE(100,5070) RCANROT(I,M),SCANROT(I,M),SNOROT(I,M),&
!                                                             &                      ALBSROT(I,M),RHOSROT(I,M),GROROT(I,M)
!                                                     ENDDO
!                                                 ENDDO
!
!                                                 WRITE(100,5200) JHHSTD,JHHENDD,JDSTD,JDENDD
!                                                 WRITE(100,5200) JHHSTY,JHHENDY,JDSTY,JDENDY
!                                                 CLOSE(100)
!                                                 !
!                                                 !       write .CTM_RS for ctem restart data
!                                                 !
!                                                 if (ctem_on) then
!                                                     call write_ctm_rs(nltest,nmtest,FCANROT,argbuff)
!                                                 endif ! ctem_on
!                                             !
!                                             endif ! if iday=365
!                                         endif ! if generate restart files
!                                         !
!                                         !      check if the model is done running.
!                                         if (iday.eq.365.and.ncount.eq.nday) then
!
!                                             if (cyclemet .and. climiyear .ge. metcycendyr) then
!
!                                                 lopcount = lopcount+1
!
!                                                 if(lopcount.le.ctemloop .and. .not. transient_run)then
!
!                                                     rewind(12)   ! rewind met file
!
!                                                     if(obswetf) then
!                                                         rewind(16) !rewind obswetf file
!                                                         read(16,*) ! read in the header
!                                                     endif
!                                                     if (obslght) then
!                                                         obslghtyr=-9999
!                                                         rewind(17)
!                                                     endif
!
!                                                     met_rewound = .true.
!                                                     iyear=-9999
!                                                     obswetyr=-9999
!
!                                                     if(popdon) then
!                                                         rewind(13) !rewind popd file
!                                                         read(13,*) ! skip header (3 lines)
!                                                         read(13,*) ! skip header (3 lines)
!                                                         read(13,*) ! skip header (3 lines)
!                                                     endif
!                                                     if((co2on .or. ch4on) .and. trans_startyr < 0) then
!                                                         rewind(14) !rewind co2 file
!                                                     endif
!
!                                                 else if (lopcount.le.ctemloop .and. transient_run)then
!                                                     ! rewind only the MET file (since we are looping over the MET  while
!                                                     ! the other inputs continue on.
!                                                     rewind(12)   ! rewind met file
!
!                                                     if (obslght) then ! FLAG
!                                                         obslghtyr=-999
!                                                         rewind(17)
!                                                         do while (obslghtyr .lt. metcylyrst)
!                                                             do i=1,nltest
!                                                                 read(17,*) obslghtyr,(mlightngrow(i,1,j),j=1,12) ! read into the first tile
!                                                                 if (nmtest > 1) then
!                                                                     do m = 2,nmtest !spread grid values over all tiles for easier use in model
!                                                                         mlightngrow(i,m,:) = mlightngrow(i,1,:)
!                                                                     end do
!                                                                 end if
!                                                             end do
!                                                         end do
!                                                         backspace(17)
!                                                     endif
!                                                 else
!
!                                                     if (transient_run .and. cyclemet) then
!                                                         ! Now switch from cycling over the MET to running through the file
!                                                         rewind(12)   ! rewind met file
!                                                         if (obslght) then !FLAG
!                                                             obslghtyr=-999
!                                                             rewind(17)
!                                                             do while (obslghtyr .lt. metcylyrst)
!                                                                 do i=1,nltest
!                                                                     read(17,*) obslghtyr,(mlightngrow(i,1,j),j=1,12) ! read into the first tile
!                                                                     if (nmtest > 1) then
!                                                                         do m = 2,nmtest !spread grid values over all tiles for easier use in model
!                                                                             mlightngrow(i,m,:) = mlightngrow(i,1,:)
!                                                                         end do
!                                                                     end if
!                                                                 end do
!                                                             end do
!                                                             backspace(17)
!                                                         endif
!                                                         cyclemet = .false.
!                                                         lopcount = 1
!                                                         endyr = iyear + ncyear  !set the new end year
!
!                                                     else
!                                                         run_model = .false.
!                                                     endif
!
!                                                 endif
!
!                                             else if (iyear .eq. endyr .and. .not. cyclemet) then
!
!                                                 run_model = .false.
!
!                                             endif !if cyclemet and iyear > metcycendyr
!                                         endif !last day of year check
!
!                                         !===================== CTEM =====================================/
!                                         !
!                                         NCOUNT=NCOUNT+1
!                                         IF(NCOUNT.GT.NDAY) THEN
!                                             NCOUNT=1
!                                         ENDIF
!
!                                     ENDDO !MAIN MODEL LOOP
!
!                                     !     MODEL RUN HAS COMPLETED SO NOW CLOSE OUTPUT FILES AND EXIT
!                                     !==================================================================
!                                     !
!                                     !      checking the time spent for running model
!                                     !
!                                     !      call idate(today)
!                                     !      call itime(now)
!                                     !      write(*,1001) today(2), today(1), 2000+today(3), now
!                                     ! 1001 format( 'end date: ', i2.2, '/', i2.2, '/', i4.4,
!                                     !     &      '; end time: ', i2.2, ':', i2.2, ':', i2.2 )
!                                     !
!                                     IF (.NOT. PARALLELRUN) THEN
!                                         !       FIRST ANY CLASS OUTPUT FILES
!                                         CLOSE(61)
!                                         CLOSE(62)
!                                         CLOSE(63)
!                                         CLOSE(64)
!                                         CLOSE(65)
!                                         CLOSE(66)
!                                         CLOSE(67)
!                                         CLOSE(68)
!                                         CLOSE(69)
!                                         CLOSE(611)
!                                         CLOSE(621)
!                                         CLOSE(631)
!                                         CLOSE(641)
!                                         CLOSE(651)
!                                         CLOSE(661)
!                                         CLOSE(671)
!                                         CLOSE(681)
!                                         CLOSE(691)
!                                     end if ! moved this up from below so it calls the close subroutine. JRM.
!
!                                     !       then ctem ones
!
!                                     call close_outfiles()
!                                     !
!                                     !     close the input files too
!                                     close(12)
!                                     close(13)
!                                     close(14)
!                                     if (obswetf) then
!                                         close(16)  !*.WET
!                                     end if
!                                     if (obslght) then
!                                         close(17)
!                                     end if
!                                     call exit
!                                 !
!                                 !         the 999 label below is hit when an input file reaches its end.
! 999                             continue
!
!                                 lopcount = lopcount+1
!
!                                 if(lopcount.le.ctemloop)then
!
!                                     rewind(12)   ! rewind met file
!
!                                     if(obswetf) then
!                                         rewind(16) !rewind obswetf file
!                                         read(16,*) ! read in the header
!                                     endif
!
!                                     met_rewound = .true.
!                                     iyear=-9999
!                                     obswetyr=-9999   !Rudra
!
!                                     if(popdon) then
!                                         rewind(13) !rewind popd file
!                                         read(13,*) ! skip header (3 lines)
!                                         read(13,*) ! skip header
!                                         read(13,*) ! skip header
!                                     endif
!                                     if((co2on .or. ch4on) .and. trans_startyr < 0) then
!                                         rewind(14) !rewind co2 file
!                                     endif
!                                     if (obslght) then
!                                         rewind(17)
!                                     endif
!
!                                 else
!
!                                     run_model = .false.
!
!                                 endif
!
!                                 !     return to the time stepping loop
!                                 if (run_model) then
!                                     goto 200
!                                 else
!
!                                     !     close the output files
!                                     !
!                                     !     FIRST ANY CLASS OUTPUT FILES
!                                     IF (.NOT. PARALLELRUN) THEN
!
!                                         CLOSE(61)
!                                         CLOSE(62)
!                                         CLOSE(63)
!                                         CLOSE(64)
!                                         CLOSE(65)
!                                         CLOSE(66)
!                                         CLOSE(67)
!                                         CLOSE(68)
!                                         CLOSE(69)
!                                         CLOSE(611)
!                                         CLOSE(621)
!                                         CLOSE(631)
!                                         CLOSE(641)
!                                         CLOSE(651)
!                                         CLOSE(661)
!                                         CLOSE(671)
!                                         CLOSE(681)
!                                         CLOSE(691)
!                                     end if
!
!                                     !     Then the CTEM ones
!                                     call close_outfiles()
!
!                                     !     CLOSE THE INPUT FILES TOO
!                                     CLOSE(12)
!                                     CLOSE(13)
!                                     CLOSE(14)
!
!                                     CALL EXIT
!                                 END IF
!
! 1001                        continue
!
!                             write(*,*)'Error while reading WETF file'
!                             run_model=.false.


    end subroutine CLASSIC_driver

end module main_driver

