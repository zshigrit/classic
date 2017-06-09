!>\file
!! Principle driver program to run CLASSIC in stand-alone mode using specified boundary
!! conditions and atmospheric forcing.
!!
program CLASSIC

    use io_driver,          only : bounds,lonvect,latvect
    use model_state_drivers, only : read_modelsetup
    use netcdf_drivers, only : create_out_netcdf
    use readjobopts, only : read_from_job_options
    use main_driver, only : CLASSIC_driver
    use ctem_statevars, only : alloc_ctem_vars
    use class_statevars, only : alloc_class_vars

    implicit none

    ! Local variables
    real :: longitude, latitude

    ! ------------

    !> This parses the command line arguments. All model switches are read in from a
    !! namelist file. This sets up the run options and points to input files as needed.
    call read_from_job_options()

    !> Next we set up the run boundaries based on the metadata in the initialization netcdf file.
    !! The bounds given as an argument to CLASSIC are used to find the start points (srtx and srty)
    !! in the netcdf file, placing the gridcell on the domain of the input/output netcdfs. In
    !! read_modelsetup we use the netcdf to set the nmos, ignd,and ilg constants. It also opens
    !! the initial conditions file that is used below in read_initialstate.
    call read_modelsetup()

    !> Next we create all the output files for the model run based on options in the joboptions file
    !! and the parameters of the initilization netcdf file.
    call create_out_netcdf()

    !#ED - This is the material that goes in the MPI loop:

    ! From lonvect and latvect, each valid cell then has a longitude and latitude
    ! #######
    !> Set up the longitude and latitude of this gridcell based on the bounds
    ! Serial version can do this:
    longitude = bounds(1)
    latitude = bounds(3)

    print *,longitude,latitude

    !> Since we know the nlat, nmos, ignd, and ilg we can allocate the CLASS and
    !! CTEM variable structures. This has to be done outside of CLASSIC_driver.
    call alloc_class_vars()
    call alloc_ctem_vars()

    !> Then we call the main model driver. This performs read ins of model inputs, all model calculations,
    !! writes to output files, and writes to a model restart file.
    call CLASSIC_driver(longitude,latitude)
    ! #######

end program
