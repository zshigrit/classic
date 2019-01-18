!>\file
C!Prints the name of the subroutine and an error code when
C!an error condition is encountered.
!!@author J. D. Henderson, E. Chan
!
      SUBROUTINE XIT(NAME,N)

      use generalUtils, only : abandonCell

      implicit none
C
C     * OCT 01/92 - E.CHAN. (CHANGE STOP 1 TO STOP)
C     * JUN 10/91 - E.CHAN. (TRANSLATE HOLLERITH LITERALS AND
C     *                      DIMENSION STRINGS)
C
C     * OCT 10/78 - J.D.HENDERSON.
C     * TERMINATES A PROGRAM BY PRINTING THE PROGRAM NAME AND
C     * A LINE ACROSS THE PAGE FOLLOWED BY A NUMBER N.
C
C     * N.GE.0 IS FOR A NORMAL END. THE LINE IS DASHED.
C     * NORMAL ENDS TERMINATE WITH   STOP.
C
C     * N.LT.0 IS FOR AN ABNORMAL END. THE LINE IS DOTTED.
C     * IF N IS LESS THAN -100 THE PROGRAM SIMPLY TERMINATES.
C     * OTHERWISE IF N IS LESS THAN ZERO THE PROGRAM ABORTS.
C
      CHARACTER*(*) NAME    !<Name of the subroutine in which the error
                            !<was found
                            !<N: error code
      CHARACTER*8   NAME8, DASH, STAR
      integer :: i,N
C
      DATA DASH /'--------'/, STAR /'********'/
C---------------------------------------------------------------------
C
      !>
      !!In CLASS, this subroutine is called when a test of ambient values
      !!of selected variables is performed and an abnormal condition is
      !!encountered. The name of the subroutine in which the condition
      !!arose is passed in, and is printed together with an error code,
      !!flagging the location of the error in the subroutine. A call to
      !!abort is then executed.
      !!
      NAME8 = NAME
      IF(N.GE.0) WRITE(6,6010) DASH,NAME8,(DASH,I=1,9),N
C
      IF(N.LT.0) WRITE(6,6010) STAR,NAME8,(STAR,I=1,9),N
C
      IF ( N.GE.0 .OR. N.LT.-100 ) THEN
        !CALL EXIT
        call abandonCell
      ELSE
        !CALL ABORT
        call abandonCell
      ENDIF
C
C---------------------------------------------------------------------
 6010 FORMAT('0',A8,'  END  ',A8,9A8,I8)
      END
