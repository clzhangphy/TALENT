SUBROUTINE REORDR! GIVE ASCENDING ORDER TO EIGEN ENERGY AND VECTOR
USE PARS
USE EIGENS
IMPLICIT NONE
 INTEGER::I,J,NTEMP
 REAL(DP)::ETEMP
!
 DO I=0,NUSE
    EIGORD(I)=I
 ENDDO
!
! IF(.FALSE.)THEN
! DO I=1,NUSE
!    DO J=I+1,NUSE+1
!       IF (EIGVAL(J)<EIGVAL(I))THEN
!          ETEMP=EIGVAL(I);NTEMP=EIGORD(I)
!          EIGVAL(I)=EIGVAL(J);EIGORD(I)=EIGORD(J)
!          EIGVAL(J)=ETEMP;EIGORD(J)=NTEMP
!       ENDIF
!    ENDDO
! ENDDO
! ENDIF
END SUBROUTINE REORDR 

SUBROUTINE HFDIAG(TFIX,ISPINC,EOLD,ENEW)!diagonalize h matrix and build new rho
USE PARS
USE HRHOMAT
USE EIGENS
IMPLICIT NONE
!INPUTS
 INTEGER::TFIX,ISPINC!PARTICLE NUMBER
 REAL(DP)::EOLD,ENEW
!VARIABLES FOR DIAGONALIZATION
 INTEGER::LWORK,NB,INFO
 REAL(DP),ALLOCATABLE::WORK(:)
 CHARACTER::JOBZ,UPLO
!
 INTEGER::I,BRA,KET,ILAENV
 REAL(DP)::SUMS
!
 JOBZ='V';UPLO='U'
 IF(.NOT.ALLOCATED(WORK))THEN
    !NB=ILAENV(1,'DSYEV','VU',NUSE+1,NUSE+1)
    !LWORK=(NB+2)*(NUSE+1)
    CALL DSYEV(JOBZ,UPLO,NUSE+1,HMAT(0:NUSE,0:NUSE),NUSE+1,&
               EIGVAL(0:NUSE),EIGVAL(0:NUSE),-1,INFO)
    LWORK=EIGVAL(0)
    ALLOCATE(WORK(LWORK))
 ENDIF
!DIAGONALIZATION
 CALL DSYEV(JOBZ,UPLO,NUSE+1,HMAT(0:NUSE,0:NUSE),NUSE+1,&
             EIGVAL(0:NUSE),WORK,LWORK,INFO)
 EIGVEC(:,:)=HMAT(:,:)

END SUBROUTINE HFDIAG

SUBROUTINE ENERGY_NEW(TFIX,ISPINC,EOLD,ENEW)
USE PARS
USE HRHOMAT
USE EIGENS
IMPLICIT NONE
 INTEGER::TFIX,ISPINC
 REAL(DP)::EOLD,ENEW
 REAL(DP)::SUMS,TUES
 INTEGER::I
! CALL REORDR!FIND THE ORDER
!UPDATE ENERGIES 
 EOLD=ENEW
!
 CALL TMEAN(ISPINC,TUES)!FIND KINETIC ENERGY
!
 SUMS=0.0D0
 DO I=0,TFIX-1         !FIND E
    SUMS=SUMS+EIGVAL(I)!WHEN ISPINC=1, TFIX=TREAL/2
 ENDDO
 ENEW=(TUES+SUMS)*(ISPINC+1)/2!DOUBLE THE ENERGY WHEN ISPINC=1
END SUBROUTINE ENERGY_NEW

SUBROUTINE ITERS(NFIX,ISPINC,EPSI,ITMAX,ITNOW,IFLAG,FLAGMAX,RMIX,EOLD,ENEW)
USE PARS
USE HRHOMAT
USE TVUMAT
USE EIGENS
IMPLICIT NONE
 REAL(DP)::EPSI,RMIX,ERROR
 INTEGER::NFIX,ISPINC,ITMAX,ITNOW,IFLAG,FLAGMAX
 REAL(DP)::EOLD,ENEW,TES
!
100 FORMAT(A4,5X,A9,3X,A10)
200 FORMAT(I4,5X,F9.5,3X,E10.3)
 WRITE(*,100)'ITER','ENERGY','DIFF'
 DO WHILE ((IFLAG<FLAGMAX).AND.(ITNOW<=ITMAX))!BEGIN THE ITERATION
    CALL MEANFIELD!CONSTRUCT H MATRIX
    CALL HFDIAG(NFIX,ISPINC,EOLD,ENEW)!DIAGONALIZE H MATRIX
    CALL ENERGY_NEW(NFIX,ISPINC,EOLD,ENEW)!GET ENERGY (T+E)/2 IN ITH ITERATION
    
    CALL RHOMAT(NFIX,ISPINC,RMIX)!UPDATE RHO TO I+1
    ERROR=ENEW-EOLD
    WRITE(*,200)ITNOW,ENEW,ERROR
    IF(ABS(ERROR)<EPSI) IFLAG=IFLAG+1
    IF(ABS(ERROR)>=EPSI.AND.IFLAG>0) IFLAG=0
    ITNOW=ITNOW+1
 ENDDO
 RETURN
END SUBROUTINE ITERS
    
    
