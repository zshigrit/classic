!> \file
!> This xml parser is derived, in part, from xml-fortran (http://xml-fortran.sourceforge.net)
!! Please see the LICENCE.txt for the licencing information. 
!> @author Ed Wisernig 
!ignoreLint(1050) ! do not lint this file; too many string literals that can be damaged
module xmlparser

  implicit none

  integer, parameter :: XML_BUFFER_LENGTH = 10000

  !===============================================================================
  ! XML_PARSE defines the data type that holds the parser information
  !===============================================================================

  type XML_PARSE
    integer          :: lun                ! LU-number of the XML-file
    integer          :: level              ! Indentation level (output)
    integer          :: lineno             ! Line in file
    logical          :: ignore_whitespace  ! Ignore leading blanks etc.
    logical          :: no_data_truncation ! Do not allow data truncation
    logical          :: too_many_attribs   ! More attributes than could be stored?
    logical          :: too_many_data      ! More lines of data than could be stored?
    logical          :: eof                ! End of file?
    logical          :: error              ! Invalid XML file or other error?
    character(len = XML_BUFFER_LENGTH) :: line  ! Buffer
  end type XML_PARSE

  !===============================================================================
  ! Global options
  !===============================================================================

  integer, parameter    :: XML_STDOUT       = -1
  integer, private      :: report_lun_      = XML_STDOUT
  logical, private      :: report_errors_   = .false.
  logical, private      :: report_details_  = .false.

  !===============================================================================
  ! Global data (the ampersand must come first)
  !===============================================================================

  character(len=10), dimension(2,3), save, private :: entities = &
                                                      reshape( (/ '&    ', '&amp;', &
                                                      '>    ', '&gt; ',  &
                                                      '<    ', '&lt; ' /), (/2,3/) )

  !===============================================================================
  ! Auxiliary routines - private
  !===============================================================================

  private               :: xml_compress_
  private               :: xml_put_open_tag_
  private               :: xml_put_element_
  private               :: xml_put_close_tag_
  private               :: xml_replace_entities_
  private               :: xml_remove_tabs_

  !===============================================================================
  ! Interfaces to reporting routines
  !===============================================================================

  private               :: xml_report_details_int_
  private               :: xml_report_details_string_
  private               :: xml_report_errors_int_
  private               :: xml_report_errors_string_

  interface xml_report_details
    module procedure xml_report_details_int_
    module procedure xml_report_details_string_
  end interface
  interface xml_report_errors
    module procedure xml_report_errors_int_
    module procedure xml_report_errors_string_
    module procedure xml_report_errors_extern_
  end interface

contains

  !===============================================================================
  ! XML_REPORT_DETAILS_INT_ --
  !    Routine to write a text with an integer value
  ! Arguments:
  !    text        Text to be written
  !    int         Integer value to be added
  !===============================================================================

  subroutine xml_report_details_int_ ( text, int )
    implicit none
    character(len=*), intent(in)     :: text
    integer,          intent(in)     :: int

    if ( report_details_ ) then
      if ( report_lun_ == XML_STDOUT ) then
        write(*,*) trim(text), int
      else
        write(report_lun_,*) trim(text), int
      end if
    end if
  end subroutine xml_report_details_int_

  !===============================================================================
  ! XML_REPORT_DETAILS_STRING_ --
  !    Routine to write a text with a string value
  ! Arguments:
  !    text        Text to be written
  !    string      String to be added
  !===============================================================================

  subroutine xml_report_details_string_ ( text, string )
    implicit none
    character(len=*), intent(in)     :: text
    character(len=*), intent(in)     :: string

    if ( report_details_ ) then
      if ( report_lun_ == XML_STDOUT ) then
        write(*,*) trim(text), ' ', trim(string)
      else
        write(report_lun_,*) trim(text), ' ', trim(string)
      end if
    end if
  end subroutine xml_report_details_string_

  !===============================================================================
  ! XML_REPORT_ERRORS_INT_ --
  !    Routine to write an error message text with an integer value
  ! Arguments:
  !    text        Text to be written
  !    int         Integer value to be added
  !    lineno      Line number in the file
  !===============================================================================

  subroutine xml_report_errors_int_ ( text, int, lineno )
    implicit none
    character(len=*),  intent(in)     :: text
    integer,           intent(in)     :: int
    integer, optional, intent(in)     :: lineno

    if ( report_errors_ .or. report_details_ ) then
      if ( report_lun_ == XML_STDOUT ) then
        write(*,*) trim(text), int
        if ( present(lineno) ) then
          write(*,*) '   At or near line', lineno
        end if
      else
        write(report_lun_,*) trim(text), int
        if ( present(lineno) ) then
          write(report_lun_,*) '   At or near line', lineno
        end if
      end if
    end if
  end subroutine xml_report_errors_int_

  !===============================================================================
  ! XML_REPORT_ERRORS_STRING_ --
  !    Routine to write an error message text with a string value
  ! Arguments:
  !    text        Text to be written
  !    string      String to be added
  !    lineno      Line number in the file
  !===============================================================================

  subroutine xml_report_errors_string_ ( text, string, lineno )
    implicit none
    character(len=*),  intent(in)     :: text
    character(len=*),  intent(in)     :: string
    integer, optional, intent(in)     :: lineno

    if ( report_errors_ .or. report_details_ ) then
      if ( report_lun_ == XML_STDOUT ) then
        write(*,*) trim(text), ' ', trim(string)
        if ( present(lineno) ) then
          write(*,*) '   At or near line', lineno
        end if
      else
        write(report_lun_,*) trim(text), ' ', trim(string)
        if ( present(lineno) ) then
          write(report_lun_,*) '   At or near line', lineno
        end if
      end if
    end if
  end subroutine xml_report_errors_string_

  !===============================================================================
  ! XML_REPORT_ERRORS_EXTERN_ --
  !    Routine to write an error message text with a string value
  ! Arguments:
  !    info        Structure holding information on the XML-file
  !    text        Text to be written
  ! Note:
  !    This routine is meant for use by routines outside
  !    this module
  !===============================================================================

  subroutine xml_report_errors_extern_ ( info, text )
    implicit none
    type(XML_PARSE),   intent(in)     :: info
    character(len=*),  intent(in)     :: text

    if ( report_errors_ .or. report_details_ ) then
      if ( report_lun_ == XML_STDOUT ) then
        write(*,*) trim(text), ' - at or near line', info%lineno
      else
        write(report_lun_,*) trim(text), ' - at or near line', info%lineno
      end if
    end if

  end subroutine xml_report_errors_extern_

  !===============================================================================
  ! XML_OPEN --
  !    Routine to open an XML file for reading or writing
  ! Arguments:
  !    info        Structure holding information on the XML-file
  !    fname       Name of the file
  !    mustread    The file will be read (.true.) or written (.false.)
  !===============================================================================

  subroutine xml_open (info, fname, mustread)
    implicit none
    character(len=*), intent(in)     :: fname
    logical,          intent(in)     :: mustread
    type(XML_PARSE),  intent(out)    :: info

    integer                          :: i
    integer                          :: k
    integer                          :: kend
    integer                          :: ierr
    logical                          :: opend
    logical                          :: exists

    info%lun = 10
    info%ignore_whitespace  = .false.
    info%no_data_truncation = .false.
    info%too_many_attribs   = .false.
    info%too_many_data      = .false.
    info%eof                = .false.
    info%error              = .false.
    info%level              = -1
    info%lineno             =  0

    do i = 10,99
      inquire( unit = i, opened = opend )
      if ( .not. opend ) then
        info%lun = i
        inquire( file = fname, exist = exists )
        if ( .not. exists .and. mustread ) then
          call xml_report_errors( 'XML_OPEN: file does not exist:', trim(fname))
          info%lun   = -1
          info%error = .true.
        else
          open( unit = info%lun, file = fname )
          call xml_report_details( 'XML_OPEN: opened file ', trim(fname) )
          call xml_report_details( 'at LU-number: ', info%lun )
        end if
        exit
      end if
    end do
    if ( .not. info%error .and. mustread ) then
      k = 1
      do while ( k >= 1 )
        read( info%lun, '(a)', iostat = ierr ) info%line

        ! If we encounter a blank line, skip it and read the next line
        if (len_trim(info%line) == 0) cycle

        call xml_remove_tabs_(info%line)
        if ( ierr == 0 ) then
          info%line = adjustl(  info%line )
          k         = index( info%line, '<?' )
          !
          ! Assume (for now at least) that <?xml ... ?> appears on a single line!
          !
          if ( k >= 1 ) then
            kend = index( info%line, '?>' )
            if ( kend <= 0 ) then
              call xml_report_errors( 'XML_OPEN: error reading file with LU-number: ', info%lun )
              call xml_report_errors( 'Line starting with "<?xml" should end with "?>"', ' ' )
              info%error = .true.
              exit
            end if
          end if
        else
          call xml_report_errors( 'XML_OPEN: error reading file with LU-number: ', info%lun )
          call xml_report_errors( 'Possibly no line starting with "<?xml"', ' ' )
          call xml_close( info )
          info%error = .true.
          exit
        end if
      end do
    end if
    if ( .not. info%error .and. .not. mustread ) then
      write( info%lun, '(a)' ) '<?xml version="1.0"?>'
    end if
  end subroutine xml_open

  !===============================================================================
  ! XML_CLOSE --
  !    Routine to close an XML file
  ! Arguments:
  !    info        Structure holding information on the XML-file
  !===============================================================================

  subroutine xml_close (info)
    implicit none
    type(XML_PARSE),  intent(inout)    :: info

    close( info%lun )

    !
    ! Only clean up the LU-number, so that the calling program
    ! can examine the last condition
    !
    call xml_report_details( 'XML_CLOSE: Closing file with LU-number ', info%lun )
    info%lun              = -1
  end subroutine xml_close

  !===============================================================================
  ! XML_GET --
  !    Routine to get the next bit of information from an XML file
  ! Arguments:
  !    info        Structure holding information on the XML-file
  !    tag         Tag that was encountered
  !    endtag      Whether the end of the element was encountered
  !    attribs     List of attribute-value pairs
  !    no_attribs  Number of pairs in the list
  !    data        Lines of character data found
  !    no_data     Number of lines of character data
  !===============================================================================

  subroutine xml_get (info, tag, endtag, attribs, no_attribs, data, no_data)
    implicit none
    type(XML_PARSE),  intent(inout)               :: info
    character(len=*), intent(out)                 :: tag
    logical,          intent(out)                 :: endtag
    character(len=*), intent(out), dimension(:,:) :: attribs
    integer,          intent(out)                 :: no_attribs
    character(len=*), intent(out), dimension(:)   :: data
    integer,          intent(out)                 :: no_data

    integer         :: kspace
    integer         :: kend
    integer         :: kcend
    integer         :: keq
    integer         :: kfirst
    integer         :: ksecond
    integer         :: idxat
    integer         :: idxdat
    integer         :: ierr
    logical         :: close_bracket
    logical         :: comment_tag
    character(len=XML_BUFFER_LENGTH) :: nextline

    !
    ! Initialise the output
    !
    endtag     = .false.
    no_attribs = 0
    no_data    = 0

    info%too_many_attribs = .false.
    info%too_many_data    = .false.

    if ( info%lun < 0 ) then
      call xml_report_details( 'XML_GET on closed file ', ' ' )
      return
    end if

    !
    ! From the previous call or the call to xmlopen we have
    ! the line that we need to parse already in memory:
    ! <tag attrib1="..." attrib2="..." />
    !
    comment_tag   = .false.
    close_bracket = .false.
    kspace        = index( info%line, ' ' )
    kend          = index( info%line, '>' )
    kcend         = index( info%line, '-->' )
    do while ( kend <= 0 )
      read( info%lun, '(a)', iostat = ierr ) nextline
      call xml_remove_tabs_(nextline)
      info%lineno = info%lineno + 1

      if ( ierr == 0 ) then
        info%line = trim(info%line) // ' ' // adjustl(nextline)
      else
        info%error = .true.
        call xml_report_errors( 'XML_GET - end of tag not found ', &
                               '(buffer too small?)', info%lineno )
        call xml_close( info )
        return
      end if
      kend = index( info%line, '>' )
    end do
    if ( kend > kspace ) then
      kend = kspace
    else if (info%line(1:4) == '<!--' .and. kend > kcend) then
      kend = kcend-1
    else
      close_bracket = .true.
    end if

    !
    ! Check for the end of an ordianry tag and of
    ! a comment tag
    !
    if ( info%line(1:3) == '-->' ) then
      endtag = .true.
      tag    = info%line(4:kend-1)
    else if ( info%line(1:2) == '</' ) then
      endtag = .true.
      tag    = info%line(3:kend-1)
    else
      if ( info%line(1:1) == '<' ) then
        tag    = info%line(2:kend-1)
        call xml_report_details( 'XML_GET - tag found: ', trim(tag) )
      else
        kend   = 0 ! Beginning of data!
      end if
    end if

    info%line = adjustl( info%line(kend+1:) )

    idxat     = 0
    idxdat    = 0

    if ( tag(1:3) == '!--' ) comment_tag = .true.

    do while ( info%line /= ' ' .and. .not. close_bracket .and. .not. comment_tag )

      keq  = index( info%line, '=' )
      kend = index( info%line, '>' )
      if ( keq > kend ) keq = 0 ! Guard against multiple tags
      ! with attributes on one line

      !
      ! No attributes any more?
      !
      if ( keq < 1 ) then
        kend = index( info%line, '/>' )
        if ( kend >= 1 ) then
          kend   = kend + 1 ! To go beyond the ">" character
          endtag = .true.
        else
          kend = index( info%line, '>' )
          if ( kend < 1 ) then
            call xml_report_errors( 'XML_GET - wrong ending of tag ', &
                                   trim(info%line), info%lineno  )
            info%error = .true. ! Wrong ending of line!
            call xml_close( info )
            return
          else
            close_bracket = .true.
          end if
        end if
        if ( kend >= 1 ) then
          info%line = adjustl( info%line(kend+1:) )
        end if
        exit
      end if

      idxat = idxat + 1
      if ( idxat <= size(attribs,2) ) then
        no_attribs = idxat
        attribs(1,idxat) = adjustl(info%line(1:keq-1)) ! Use adjustl() to avoid
        ! multiple spaces, etc
        info%line = adjustl( info%line(keq+1:) )

        !
        ! We have almost found the start of the attribute's value
        !
        kfirst  = index( info%line, '"' )
        if ( kfirst < 1 ) then
          call xml_report_errors( 'XML_GET - malformed attribute-value pair: ', &
                                 trim(info%line), info%lineno  )
          info%error = .true. ! Wrong form of attribute-value pair
          call xml_close( info )
          return
        end if

        ksecond = index( info%line(kfirst+1:), '"' ) + kfirst
        if ( ksecond < 1 ) then
          call xml_report_errors( 'XML_GET - malformed attribute-value pair: ', &
                                 trim(info%line), info%lineno  )
          info%error = .true. ! Wrong form of attribute-value pair
          call xml_close( info )
          return
        end if

        attribs(2,idxat) = info%line(kfirst+1:ksecond-1)
        info%line = adjustl( info%line(ksecond+1:) )
      end if

      if ( idxat > size(attribs,2) ) then
        call xml_report_errors( 'XML_GET - more attributes than could be stored: ', &
                               trim(info%line), info%lineno  )
        info%too_many_attribs = .true.
        info%line             = ' '
        exit
      end if
    end do

    !
    ! Now read the data associated with the current tag
    ! - all the way to the next "<" character
    !
    ! To do: reduce the number of data lines - empty ones
    ! at the end should not count.
    !
    do
      if ( comment_tag ) then
        kend   = index( info%line, '-->' )
      else
        kend   = index( info%line, '<' )
      end if
      idxdat = idxdat + 1
      if ( idxdat <= size(data) ) then
        no_data = idxdat
        if ( kend >= 1 ) then
          data(idxdat) = info%line(1:kend-1)
          info%line    = info%line(kend:)
        else
          data(idxdat) = info%line
        end if
      else
        call xml_report_errors( 'XML_GET - more data lines than could be stored: ', &
                               trim(info%line), info%lineno  )
        info%too_many_data = .true.
        exit
      end if

      !
      ! No more data? Otherwise, read on
      !
      if ( kend >= 1 ) then
        exit
      else
        read( info%lun, '(a)', iostat = ierr ) info%line
        call xml_remove_tabs_(info%line)
        info%lineno = info%lineno + 1

        if ( ierr < 0 ) then
          call xml_report_details( 'XML_GET - end of file found - LU-number: ', &
                                  info%lun )
          info%eof = .true.
          elseif ( ierr > 0 ) then
          call xml_report_errors( 'XML_GET - error reading file with LU-number ', &
                                 info%lun, info%lineno  )
          info%error = .true.
        end if
        if ( ierr /= 0 ) then
          exit
        end if
      end if
    end do

    !
    ! Compress the data?
    !
    if ( info%ignore_whitespace ) then
      call xml_compress_( data, no_data )
    end if

    !
    ! Replace the entities, if any
    !
    call xml_replace_entities_( data, no_data )

    call xml_report_details( 'XML_GET - number of attributes: ', no_attribs )
    call xml_report_details( 'XML_GET - number of data lines: ', no_data    )

  end subroutine xml_get

  !===============================================================================
  ! XML_PUT --
  !    Routine to write a tag with the associated data to an XML file
  ! Arguments:
  !    info        Structure holding information on the XML-file
  !    tag         Tag that was encountered
  !    endtag      Whether the end of the element was encountered
  !    attribs     List of attribute-value pairs
  !    no_attribs  Number of pairs in the list
  !    data        Lines of character data found
  !    no_data     Number of lines of character data
  !    type        Type of action:
  !                open - just the opening tag with attributes
  !                elem - complete element
  !                close - just the closing tag
  !===============================================================================

  subroutine xml_put (info, tag, attribs, no_attribs, data, no_data, type)
    implicit none
    type(XML_PARSE),  intent(inout)               :: info
    character(len=*), intent(in)                  :: tag
    character(len=*), intent(in), dimension(:,:)  :: attribs
    integer,          intent(in)                  :: no_attribs
    character(len=*), intent(in), dimension(:)    :: data
    integer,          intent(in)                  :: no_data
    character(len=*)                              :: type

    select case(type)
    case('open')
      call xml_put_open_tag_(info, tag, attribs, no_attribs)
    case('elem')
      call xml_put_element_(info, tag, attribs, no_attribs, &
                            data, no_data)
    case('close')
      call xml_put_close_tag_(info, tag)
    end select

  end subroutine xml_put

  !===============================================================================
  ! XML_PUT_OPEN_TAG_ --
  !    Routine to write the opening tag with the attributes
  ! Arguments:
  !    info        Structure holding information on the XML-file
  !    tag         Tag that was encountered
  !    endtag      Whether the end of the element was encountered
  !    attribs     List of attribute-value pairs
  !    no_attribs  Number of pairs in the list
  !    data        Lines of character data found
  !    no_data     Number of lines of character data
  !===============================================================================

  subroutine xml_put_open_tag_ (info, tag, attribs, no_attribs)
    implicit none
    type(XML_PARSE),  intent(inout)               :: info
    character(len=*), intent(in)                  :: tag
    character(len=*), intent(in), dimension(:,:)  :: attribs
    integer,          intent(in)                  :: no_attribs

    integer         :: i
    character(len=300), parameter :: indent = ' '

    write( info%lun, '(3a)', advance = 'no' ) &
        indent(1:3*info%level), '<', adjustl(tag)
    do i=1,no_attribs
      if (attribs(2,i)/='') then
        write( info%lun, '(5a)', advance = 'no' ) &
                ' ',trim(attribs(1,i)),'="', trim(attribs(2,i)),'"'
      end if
    end do
    write( info%lun, '(a)' ) '>'
    info%level = info%level + 1

  end subroutine xml_put_open_tag_

  !===============================================================================
  ! XML_PUT_ELEMENT_ --
  !    Routine to write the complete element
  ! Arguments:
  !    info        Structure holding information on the XML-file
  !    tag         Tag that was encountered
  !    endtag      Whether the end of the element was encountered
  !    attribs     List of attribute-value pairs
  !    no_attribs  Number of pairs in the list
  !    data        Lines of character data found
  !    no_data     Number of lines of character data
  !===============================================================================

  subroutine xml_put_element_ (info, tag, attribs, no_attribs, data, no_data)
    implicit none
    type(XML_PARSE),  intent(inout)               :: info
    character(len=*), intent(in)                  :: tag
    character(len=*), intent(in), dimension(:,:)  :: attribs
    integer,          intent(in)                  :: no_attribs
    character(len=*), intent(in), dimension(:)    :: data
    integer,          intent(in)                  :: no_data

    logical          :: logic
    character(len=1) :: aa
    integer          :: i, ii

    character(len=300), parameter :: indent = ' '

    if ( (no_attribs==0 .and. no_data==0) ) then
      return
    else
      logic = .true.
      do ii = 1,no_attribs
        logic = logic .and. (attribs(2,ii)=='')
      end do
      do ii = 1,no_data
        logic = logic .and. (data(ii)=='')
      end do
      if ( logic ) then
        return
      else
        write( info%lun, '(3a)', advance = 'no' ) &
                indent(1:3*info%level), '<', adjustl(tag)
        do i = 1,no_attribs
          if (attribs(2,i)/='') then
            write( info%lun, '(5a)', advance = 'no' ) &
                        ' ',trim(attribs(1,i)),'="', trim(attribs(2,i)),'"'
          end if
        end do
        if ( no_attribs>0 .and. no_data==0 ) then
          aa='a'
          elseif ( (no_attribs>0 .and. no_data>0) .or. &
                (no_attribs==0 .and. no_data>0) ) then
          aa='b'
        else
          write(*,*) no_attribs, no_data
        end if
      end if
    end if

    select case(aa)
    case('a')
      write( info%lun, '(a)' ) '/>'
    case('b')
      write( info%lun, '(a)',advance='no' ) '>'
      write( info%lun, '(2a)', advance='no') ( ' ', trim(data(i)), i=1,no_data )
      write( info%lun, '(4a)' ) ' ','</', tag, '>'
    end select

  end subroutine xml_put_element_

  !===============================================================================
  ! XML_PUT_CLOSE_TAG_ --
  !    Routine to write the closing tag
  ! Arguments:
  !    info        Structure holding information on the XML-file
  !    tag         Tag that was encountered
  !    endtag      Whether the end of the element was encountered
  !    attribs     List of attribute-value pairs
  !    no_attribs  Number of pairs in the list
  !    data        Lines of character data found
  !    no_data     Number of lines of character data
  !===============================================================================

  subroutine xml_put_close_tag_ (info, tag)
    implicit none

    type(XML_PARSE),  intent(inout) :: info
    character(len=*), intent(in)    :: tag

    character(len=300), parameter :: indent = ' '

    info%level = info%level - 1
    write(info%lun, '(4a)') indent(1:3*info%level), '</', adjustl(tag), '>'

  end subroutine xml_put_close_tag_

  !===============================================================================
  ! XML_COMPRESS_ --
  !    Routine to remove empty lines from the character data
  ! Arguments:
  !    data        Lines of character data found
  !    no_data     (Nett) number of lines of character data
  !===============================================================================

  subroutine xml_compress_ (data, no_data)
    implicit none
    character(len=*), intent(inout), dimension(:)    :: data
    integer,          intent(inout)                  :: no_data

    integer :: i
    integer :: j
    logical :: empty

    j     = 0
    empty = .true.
    do i = 1,no_data
      if ( len_trim(data(i)) /= 0 .or. .not. empty ) then
        j       = j + 1
        data(j) = adjustl(data(i))
        empty = .false.
      end if
    end do

    no_data = j

    do i = no_data,1,-1
      if ( len_trim(data(i)) /= 0 ) then
        exit
      else
        no_data = no_data - 1
      end if
    end do

  end subroutine xml_compress_

  !===============================================================================
  ! XML_REPLACE_ENTITIES_ --
  !    Routine to replace entities such as &gt; by their
  !    proper character representation
  ! Arguments:d
  !    data        Lines of character data found
  !    no_data     (Nett) number of lines of character data
  !===============================================================================

  subroutine xml_replace_entities_ (data, no_data)
    implicit none
    character(len=*), intent(inout), dimension(:)    :: data
    integer,          intent(inout)                  :: no_data

    integer :: i
    integer :: j
    integer :: j2
    integer :: k
    integer :: pos
    logical :: found

    do i = 1,no_data
      j = 1
      do
        do k = 1,size(entities,2)
          found = .false.
          pos   = index( data(i)(j:), trim(entities(2,k)) )
          if ( pos > 0 ) then
            found = .true.
            j     = j + pos - 1
            j2    = j + len_trim(entities(2,k))
            data(i)(j:) = trim(entities(1,k)) // data(i)(j2:)
            j     = j2
          end if
        end do
        if ( .not. found ) exit
      end do
    end do

  end subroutine xml_replace_entities_

  !===============================================================================
  ! XML_OPTIONS --
  !    Routine to handle the parser options
  ! Arguments:
  !    info                Structure holding information on the XML-file
  !    ignore_whitespace   Ignore whitespace (leading blanks, empty lines) or not
  !    no_data_truncation  Consider truncation of strings an error or not
  !    report_lun          LU-number for reporting information
  !    report_errors       Write messages about errors or not
  !    report_details      Write messages about all kinds of actions or not
  !===============================================================================

  subroutine xml_options (info, ignore_whitespace, no_data_truncation, &
                          report_lun, report_errors, report_details)
    implicit none
    type(XML_PARSE),  intent(inout)               :: info
    logical, intent(in), optional                 :: ignore_whitespace
    logical, intent(in), optional                 :: no_data_truncation

    integer, intent(in), optional                 :: report_lun
    logical, intent(in), optional                 :: report_errors
    logical, intent(in), optional                 :: report_details

    if ( present(ignore_whitespace) ) then
      info%ignore_whitespace = ignore_whitespace
    end if
    if ( present(no_data_truncation) ) then
      info%no_data_truncation = no_data_truncation
    end if
    if ( present(report_lun) ) then
      report_lun_ = report_lun
    end if
    if ( present(report_errors) ) then
      report_errors_ = report_errors
    end if
    if ( present(report_details) ) then
      report_details_ = report_details
    end if
  end subroutine xml_options

  !===============================================================================
  ! XML_OK --
  !    Function that returns whether all was okay or not
  ! Arguments:
  !    info                Structure holding information on the XML-file
  ! Returns:
  !    .true. if there was no error, .false. otherwise
  !===============================================================================

  logical function xml_ok (info)
    implicit none
    type(XML_PARSE),  intent(in)               :: info

    xml_ok = info%eof .or. info%error .or. &
             ( info%no_data_truncation .and.    &
             ( info%too_many_attribs .or. info%too_many_data ) )
    xml_ok = .not. xml_ok
  end function xml_ok

  !===============================================================================
  ! XML_ERROR --
  !    Function that returns whether there was an error
  ! Arguments:
  !    info                Structure holding information on the XML-file
  ! Returns:
  !    .true. if there was an error, .false. if there was none
  !===============================================================================

  logical function xml_error (info)
    implicit none
    type(XML_PARSE),  intent(in)               :: info

    xml_error = info%error .or. &
                ( info%no_data_truncation .and.    &
                ( info%too_many_attribs .or. info%too_many_data ) )
  end function xml_error

  !===============================================================================
  ! XML_DATA_TRUNC --
  !    Function that returns whether data were truncated or not
  ! Arguments:
  !    info                Structure holding information on the XML-file
  ! Returns:
  !    .true. if data were truncated, .false. otherwise
  !===============================================================================

  logical function xml_data_trunc (info)
    implicit none
    type(XML_PARSE),  intent(in)               :: info

    xml_data_trunc = info%too_many_attribs .or. info%too_many_data
  end function xml_data_trunc

  !===============================================================================
  ! XML_FIND_ATTRIB
  !===============================================================================

  integer function xml_find_attrib (attribs, no_attribs, name, value)
    implicit none
    character(len=*), dimension(:,:), intent(in)  :: attribs
    integer, intent(in)                           :: no_attribs
    character(len=*), intent(in)                  :: name
    character(len=*), intent(out)                  :: value

    integer :: i

    xml_find_attrib = -1
    do i = 1,no_attribs
      if ( name == attribs(1,i) ) then
        value           = attribs(2,i)
        xml_find_attrib = i
        exit
      end if
    end do

  end function xml_find_attrib

  !===============================================================================
  ! XML_PROCESS --
  !    Routine to read the XML file as a whole and distribute processing
  !    the contents over three user-defined subroutines
  ! Arguments:
  !    filename            Name of the file to process
  !    attribs             Array for holding the attributes
  !    data                Array for holding the character data
  !    startfunc           Subroutine to handle the start of elements
  !    datafunc            Subroutine to handle the character data
  !    endfunc             Subroutine to handle the end of elements
  !    error               Indicates if there was an error or not
  ! Note:
  !    The routine is declared recursive to allow inclusion of XML files
  !    (common with XSD schemas). This extends to the auxiliary routines.
  !===============================================================================

  recursive subroutine xml_process (filename, attribs, data, startfunc, datafunc, endfunc, lunrep, error)
    implicit none
    character(len=*)                  :: filename
    character(len=*), dimension(:,:)  :: attribs
    character(len=*), dimension(:)    :: data
    integer                           :: lunrep
    logical                           :: error

    interface
      recursive subroutine startfunc (tag, attribs, error)
        character(len=*), intent(in)                 :: tag
        character(len=*), dimension(:,:), intent(in) :: attribs
        logical, intent(in)                          :: error
      end subroutine
    end interface

    interface
      recursive subroutine datafunc (tag, data, error)
        character(len=*), intent(in)               :: tag
        character(len=*), dimension(:), intent(in) :: data
        logical, intent(in)                        :: error
      end subroutine
    end interface

    interface
      recursive subroutine endfunc (tag, error)
        character(len=*), intent(in) :: tag
        logical, intent(in)          :: error
      end subroutine
    end interface

    type(XML_PARSE)                               :: info
    character(len=80)                             :: tag
    logical                                       :: endtag
    integer                                       :: noattribs
    integer                                       :: nodata

    call xml_options(info, report_lun = lunrep, report_details = .false.)
    call xml_open(info, filename, .true.)

    error = .false.
    do
      call xml_get(info, tag, endtag, attribs, noattribs, data, nodata)
      if ( .not. xml_ok(info) ) then
        exit
      end if

      if ( xml_error(info) ) then
        write(lunrep,*) 'Error reading XML file!'
        error = .true.
        exit
      end if

      if ( .not. endtag .or. noattribs /= 0 ) then
        call startfunc(tag, attribs(:,1:noattribs), error)
        if ( error ) exit

        call datafunc(tag, data(1:nodata), error)
        if ( error ) exit
      end if

      if ( endtag ) then
        call endfunc(tag, error)
        if ( error ) exit
      end if
    end do
    call xml_close(info)
  end subroutine xml_process

  !===============================================================================
  ! XML_REMOVE_TABS_ --
  !    Routine to change any horizontal tab characters to spaces when reading a
  !    new line of data
  ! Arguments:
  !    line        Line of character data to modify
  !===============================================================================

  subroutine xml_remove_tabs_ (line)
    implicit none
    character(len=*), intent(inout) :: line

    integer :: i

    do i = 1, len_trim(line)
      if (line(i:i) == achar(9)) then
        line(i:i) = ' '
      end if
    end do

  end subroutine xml_remove_tabs_
  !! \namespace xmlparser
end module xmlparser
