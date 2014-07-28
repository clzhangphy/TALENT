MODULE Ho_basis
  USE types
  USE numerical_integration
  USE constants

  IMPLICIT NONE

 ! PRIVATE

  !PUBLIC :: RadHO, overlap_ho, Ho_b, init_ho_basis, init_ho_basis_old, h_sp

! not supported in gfortran
!!$  TYPE Ho_block(nmax)
!!$     INTEGER, len :: nmax
!!$     INTEGER :: l,s
!!$     COMPLEX(kind=r_kind) :: block(0:nmax,0:nmax)
!!$
!!$  END type Ho_block

  !Ho_block, allocatable, protected :: hf_transform(:,:)

  TYPE hf_state
     REAL(kind=r_kind) :: e
     INTEGER :: l,jindex
     INTEGER :: n
     REAL(kind=r_kind) :: occ
  END type hf_state

  REAL(kind=r_kind), protected :: Ho_b, Ho_hbaromega
  INTEGER, protected :: Ho_Nmax, Ho_lmax, Ho_size_all  
  ! Ho_Nmax means the major osc. qn from this version on!



  REAL(kind=r_kind), allocatable, protected:: h_sp(:,:) !used in testing/coulomb excersize

  ! 2j = 2l + (-1)**jindex

  COMPLEX(kind=r_kind), allocatable, protected :: hf_transform(:,:,:,:) !l,jindex, n,npr
  COMPLEX(kind=r_kind), allocatable, protected :: density_matrix(:,:,:,:) !l,jindex, n,npr
  COMPLEX(kind=r_kind), allocatable, protected :: density_matrix_old(:,:,:,:) !l,jindex, n,npr
  REAL(kind=r_kind), allocatable, protected :: hf_energies(:,:,:) !l,jindex,n 
  REAL(kind=r_kind), allocatable, protected :: hf_energies_old(:,:,:) !l,jindex,n 
  !INTEGER, allocatable, protected :: hf_energies_sort(:,:,:)

  type(hf_state), allocatable, protected :: hf_states_all(:) !1..total number of states
  REAL(kind=r_kind), allocatable, protected :: hf_energies_all(:)  
  REAL(kind=r_kind), allocatable, protected :: hf_energies_all_old(:) 
  INTEGER, allocatable, protected :: hf_energies_all_sort(:)

  INTEGER, allocatable, protected :: fermi_index_hfbasis(:,:) !l,jindex
  COMPLEX(kind=r_kind), allocatable, protected :: hf_hamiltonian(:,:,:,:) !l,jindex,n,npr
  

  COMPLEX(kind=r_kind), allocatable, protected :: Ho_two_body_matel(:,:,:,:,:,:) !l,jindex,n1,n2,n3,n4
  !Check the symmtetries of the two-body matrix elements, this form might be wrong. Should work in the case of l=0 j=0.5.

  !The symmetries of the rot invariant interaction gives that we need the following structure
  COMPLEX(kind=r_kind), allocatable, protected :: Ho_two_body_matels(:)
  INTEGER, protected :: Ho_size_TBME
  !Ho_two_body_matels(:,:,:,:,:,:,:,:) !l,jindex, lpr, jindexpr, n1,n2,n3,n4


  COMPLEX(kind=r_kind), allocatable, protected :: hf_gamma(:,:,:,:)
  INTEGER, protected :: hf_num_part_request

CONTAINS

!!$  !sorts the  columns of the hf_transformation according to hf energies  
!!$  SUBROUTINE sort_hf
!!$    
!!$  END SUBROUTINE sort_hf

  !as fortran does not support matrices with more than 7 dimensions this function
  !returns the index in the collapsed 8-dim array to where the matrix element is stored
  INTEGER FUNCTION TBME_index(l,jindex,lpr,jindexpr,n1,n2,n3,n4)
    IMPLICIT NONE
    INTEGER, intent(in) :: l,jindex,lpr,jindexpr,n1,n2,n3,n4

    INTEGER :: size_block, size_block_2, size_block_4

    TBME_index = 1

    !n1,n3 belong to l,j
    !n2,n4 belong to lpr,jpr

    size_block = Ho_Nmax/2+1
    size_block_2 = size_block**2
    size_block_4 = size_block_2**2

    TBME_index = TBME_index + l*2*(Ho_lmax+1)*2*size_block_4 &
         + jindex*(Ho_lmax+1)*2*size_block_4 &
         + lpr*2*size_block_4 + jindexpr*size_block_4 &
         + (n1 + size_block*n3)*size_block_2 &
         + n2 + size_block*n4
         
    


  END FUNCTION TBME_index



  SUBROUTINE hf_calculate_delta(delta)
    IMPLICIT NONE

    REAL(kind=r_kind), intent(out) :: delta
    
    INTEGER :: II
    REAL(kind=r_kind) :: e, e_old

    delta = 0.0_r_kind

     DO II = 0,Ho_size_all-1
       e = hf_energies_all(II)
       e_old = hf_energies_all_old(II)

       delta = delta + ABS(e-e_old)/hf_num_part_request

    END DO


  END SUBROUTINE hf_calculate_delta
  

  

  INTEGER FUNCTION Ho_degeneracy(l,jindex)
    IMPLICIT NONE
    INTEGER, intent(in) :: l,jindex
    INTEGER :: j2

    IF(jindex < 0 .or. jindex > 1) THEN
       WRITE(*,*) 'In function Ho_degenerace, incorrect jindex'
       STOP
    END IF

    IF(jindex == 0) j2 = 2*l + 1
    IF(jindex == 1) j2 = 2*l - 1

    Ho_degeneracy = j2+1

  END FUNCTION Ho_degeneracy

  SUBROUTINE hf_find_fermi_energy(N_request,e_fermi)

    USE sorting, only : sortrx

    IMPLICIT NONE

    INTEGER, intent(in) :: N_request !number of particles
    REAL(kind=r_kind), intent(out) :: e_fermi
    INTEGER :: particle_number, II, index !, fermi_index_tot
    INTEGER :: n,l,jindex
    REAL(kind=r_kind) :: e


    hf_energies_all_old = hf_energies_all


    !stores information on the eigenvectors
    II = 0

    DO l=0,Ho_lmax
       DO jindex = 0,1
          IF(l==0 .and. jindex==1) CYCLE

          DO n=0,(Ho_Nmax-l)/2
             hf_states_all(II)%l = l
             hf_states_all(II)%jindex = jindex
             hf_states_all(II)%n = II
             hf_states_all(II)%e = hf_energies(l,jindex,n)

             hf_energies_all(II) = hf_energies(l,jindex,n)
             II = II + 1

          END DO
       END DO

    END DO

    !The following assumes that the diagonalization sorts according to increasing energies in each lj block

    !sorts the energies
    CALL sortrx(Ho_size_all,hf_energies_all,hf_energies_all_sort)
    !indexing starts from 0
    hf_energies_all_sort = hf_energies_all_sort -1


    !finds the fermi indicies

    hf_states_all(:)%occ = 0.0_r_kind
    fermi_index_hfbasis(:,:) = 0
    particle_number = 0
    !fermi_index_tot = 0
    II = 0
    DO WHILE(particle_number < N_request)

       index = hf_energies_all_sort(II)
       
       n = hf_states_all(index)%n
       l = hf_states_all(index)%l
       jindex = hf_states_all(index)%jindex
       e = hf_states_all(index)%e
       
       particle_number = particle_number + Ho_degeneracy(l,jindex)
       hf_states_all(index)%occ = REAL(Ho_degeneracy(l,jindex),kind=r_kind)

       fermi_index_hfbasis(l,jindex) = n

       e_fermi = e
       !fermi_index_tot = fermi_index_tot + 1
       II = II + 1

    END DO

    IF(N_request-particle_number /= 0) THEN
       WRITE(*,*) 'ERROR: Cannot get correct particle number by filling degenerate shells'
       WRITE(*,*) 'Requested particle number',N,'Actual particle number',particle_number 
       STOP
    END IF

      


  END SUBROUTINE hf_find_fermi_energy

  SUBROUTINE print_hf_states
    IMPLICIT NONE

    INTEGER :: II, n, l , jindex, j2, index
    REAL(kind=r_kind) :: e, occ

    
    WRITE(*,*) 'Ho_b = ',Ho_b, 'Ho_hbaromega = ',Ho_hbaromega
    WRITE(*,*) 'Ho_lmax = ',Ho_lmax,'Ho_nmax = ',Ho_nmax
    WRITE(*,*) 'Ho_size_all = ',Ho_size_all


    WRITE(*,'(3A3,2A14)') 'n','l','2j','e','occ'
    DO II = 0,Ho_size_all-1
       index = hf_energies_all_sort(II)

       n = hf_states_all(index)%n
       l = hf_states_all(index)%l
       jindex = hf_states_all(index)%jindex
       j2 = l + (-1)**jindex
       e = hf_states_all(index)%e
       occ = hf_states_all(index)%occ

       WRITE(*,'(3I3,2F14.6)') n,l,j2,e,occ


    END DO
    

  END SUBROUTINE print_hf_states


  SUBROUTINE hf_init_dens(N_request)
    IMPLICIT NONE

    INTEGER, intent(in) :: N_request
    INTEGER :: n, l,jindex, particle_number
    INTEGER :: N_major, N_major_max
    

    INTEGER :: n1,n2

    hf_num_part_request = N_request


    particle_number = 0
    
    !N_major_max = 2*Ho_nmax + Ho_lmax !changed def of Ho_Nmax

    density_matrix = (0.0_r_kind,0.0_r_kind)

     
    WRITE(*,*) 'hf_init_dens: filling states'
    WRITE(*,'(A3,A3,A3)') 'n','l','2j'

    Ho_fill_shells :  DO l = 0,Ho_lmax
       DO jindex = 0,1
          IF(l==0 .and. jindex==1) CYCLE

          DO n = 0,(Ho_Nmax - l)/2

             !IF(n > Ho_nmax .or. l > Ho_lmax) CYCLE !unnencecary with changed def of Nmax

             density_matrix(l,jindex,n,n) = (1.0_r_kind,0.0_r_kind)
             particle_number = particle_number + Ho_degeneracy(l,jindex)

             WRITE(*,'(I3,I3,I3)') n,l,l+(-1)**jindex


             IF(particle_number >= N_request) THEN
                EXIT Ho_fill_shells
             END IF
          END DO

       END DO

    END DO Ho_fill_shells

    WRITE(*,*) 'hf_init_dens:'
    WRITE(*,*) 'Requested particle number',N_request
    WRITE(*,*) 'Particle number',particle_number

!!$
!!$    DO l=0,Ho_lmax
!!$       DO jindex = 0,1
!!$          IF(l==0 .and. jindex==1) CYCLE
!!$
!!$
!!$          DO n1 = 0,Ho_nmax
!!$             DO n2 = n1,Ho_nmax
!!$
!!$                WRITE(*,*) 'n1 = ',n1,'n2=',n2,'density_matrix(l,jindex,n1,n2)=',density_matrix(l,jindex,n1,n2)
!!$
!!$
!!$             END DO
!!$          END DO
!!$       END DO
!!$    END DO
    
    

  END SUBROUTINE hf_init_dens



  !rho(nljm,n'l'j'm') = rho(lj;nn')d_ll'd_jj'd_mm'
  !the reduced density rho(lj;nn') is stored, keep track of degeneracy!
  SUBROUTINE hf_update_density_matrix(mixing)
    IMPLICIT NONE

    REAL(kind=r_kind), intent(in) :: mixing
    
    INTEGER :: l,jindex,n1,n2,II

    COMPLEX(kind=r_kind), parameter :: zero_c = (0.0_r_kind,0.0_r_kind)
    COMPLEX(kind=r_kind) :: sum_occupied    
    

    density_matrix_old = density_matrix
    

    DO l=0,Ho_lmax
       DO jindex = 0,1
          IF(l==0 .and. jindex==1) CYCLE

          
          DO n1 = 0,(Ho_Nmax-l)/2
             DO n2 = n1,(Ho_Nmax-l)/2
             !DO n2 = 0,Ho_nmax
             
                sum_occupied = zero_c
                
!!$                WRITE(*,*) 'Update density: n1=',n1,'n2=',n2
!!$                WRITE(*,*) 'Update density: fermi_index =',fermi_index_hfbasis(l,jindex)  
!!$                WRITE(*,*) 'Update density: hf_transform(l,jindex,n1,n2) =',hf_transform(l,jindex,n1,n2) 

                DO II = 0,fermi_index_hfbasis(l,jindex)  !hf_transform should be sorted according to hf sp-energies in each block

                   sum_occupied = sum_occupied + hf_transform(l,jindex,n1,II)*CONJG(hf_transform(l,jindex,n2,II))

                END DO

!!$                WRITE(*,*) 'Update density: sum_occupied = ',sum_occupied
                
                density_matrix(l,jindex,n1,n2) = mixing*density_matrix_old(l,jindex,n1,n2) + (1.0_r_kind-mixing)*sum_occupied !Ho_degeneracy(l,jindex)*sum_occupied
                density_matrix(l,jindex,n2,n1) = CONJG(density_matrix(l,jindex,n1,n2))
                
             END DO
          END DO
       END DO
    END DO

    

  END SUBROUTINE hf_update_density_matrix


  SUBROUTINE hf_update_hamiltonian
    IMPLICIT NONE

    INTEGER :: l,jindex,n1,n2,n3,n4,lpr,jindexpr,deg
    COMPLEX(kind=r_kind), parameter :: zero_c = (0.0_r_kind,0.0_r_kind)
    COMPLEX(kind=r_kind) :: Gamma


    hf_hamiltonian = zero_c
    hf_gamma = zero_c

    DO l=0,Ho_lmax
       DO jindex = 0,1
          IF(l==0 .and. jindex==1) CYCLE

          DO n1 = 0,(Ho_Nmax-l)/2
             DO n2 = n1,(Ho_Nmax-l)/2
                !DO n2 = 0,Ho_nmax

                Gamma = zero_c
                DO lpr = 0,Ho_lmax
                   DO jindexpr = 0,1
                      IF(lpr==0 .and. jindexpr==1) CYCLE
                      deg = Ho_degeneracy(lpr,jindexpr)

                      DO n3 = 0,(Ho_Nmax-lpr)/2
                         DO n4 = 0,(Ho_Nmax-lpr)/2 

                            !for the l=0 subspace
                            !Gamma = Gamma + Ho_two_body_matel(l,jindex,n1,n4,n2,n3)*density_matrix(l,jindex,n3,n4) 
                            !General
                            Gamma = Gamma + deg*Ho_two_body_matels(TBME_index(l,jindex,lpr,jindexpr,n1,n4,n2,n3))*density_matrix(lpr,jindexpr,n3,n4) 

!!$                            !for debug
!!$                            WRITE(*,*) 'n1,n2,n3,n4 = ',n1,n2,n3,n4
!!$                            WRITE(*,*) TBME_index(l,jindex,lpr,jindexpr,n1,n2,n3,n4)
!!$                            WRITE(*,*) Ho_two_body_matel(l,jindex,n1,n2,n3,n4)
!!$                            WRITE(*,*) Ho_two_body_matels(TBME_index(l,jindex,lpr,jindexpr,n1,n2,n3,n4))
!!$                            !end for debug

                            !





                         END DO
                      END DO
                   END DO
                END DO

                !WRITE(*,*) 'Gamma = ',Gamma

                !
                hf_gamma(l,jindex,n1,n2) = Gamma
                hf_gamma(l,jindex,n2,n1) = CONJG(Gamma)
                !


                !hf_hamiltonian(l,jind,n1,n2) = Ho_one_body_matel(l,jind,n1,n2) + Gamma                
                hf_hamiltonian(l,jindex,n1,n2) = Gamma 
                hf_hamiltonian(l,jindex,n2,n1) = CONJG(Gamma)!CONJG(hf_hamiltonian(l,jindex,n1,n2))


             END DO

          END DO
       END DO
    END DO

    DO l=0,Ho_lmax
       DO jindex = 0,1
          IF(l==0 .and. jindex==1) CYCLE
          DO n1 = 0,(Ho_Nmax-l)/2
             hf_hamiltonian(l,jindex,n1,n1) = hf_hamiltonian(l,jindex,n1,n1) + Ho_hbaromega*(2*n1+l+1.5_r_kind)
          END DO
       END DO
    END DO

  END SUBROUTINE hf_update_hamiltonian


  SUBROUTINE hf_total_energy(Etot)
    IMPLICIT NONE

    REAL(kind=r_kind) :: Etot
    INTEGER :: l,jindex,n1,n2,j2    

    Etot = 0.0_r_kind

    DO l=0,Ho_lmax
       DO jindex = 0,1
          IF(l==0 .and. jindex==1) CYCLE
          j2 = 2*l + (-1)**jindex
          DO n1 = 0,(Ho_Nmax-l)/2
             Etot = Etot + Ho_hbaromega*(2.0_r_kind*n1+l+1.5_r_kind)*(j2+1)*density_matrix(l,jindex,n1,n1)

!!$             WRITE(*,*) 'n1=',n1,'density_matrix(l,jindex,n1,n1) = ',density_matrix(l,jindex,n1,n1)

             DO n2 = 0,(Ho_Nmax-l)/2

                Etot = Etot + 0.5_r_kind*(j2+1.0_r_kind)*density_matrix(l,jindex,n2,n1)*hf_gamma(l,jindex,n1,n2)


             END DO
          END DO
       END DO
    END DO


  END SUBROUTINE hf_total_energy

   SUBROUTINE hf_total_energy_v2(Etot)
    IMPLICIT NONE

    REAL(kind=r_kind) :: Etot
    INTEGER :: l,jindex,n1,n2,j2,n3,n4,lpr,jindexpr,j2pr    

    Etot = 0.0_r_kind
    
    DO l=0,Ho_lmax
       DO jindex = 0,1
          IF(l==0 .and. jindex==1) CYCLE
          j2 = 2*l + (-1)**jindex
          DO lpr=0,Ho_lmax
             DO jindexpr = 0,1
                IF(lpr==0 .and. jindexpr==1) CYCLE
                j2pr = 2*lpr + (-1)**jindexpr


                DO n1 = 0,(Ho_Nmax-l)/2
                   Etot = Etot + Ho_hbaromega*(2.0_r_kind*n1+l+1.5_r_kind)*(j2+1)*density_matrix(l,jindex,n1,n1)

!!$             WRITE(*,*) 'n1=',n1,'density_matrix(l,jindex,n1,n1) = ',density_matrix(l,jindex,n1,n1)

                   DO n2 = 0,(Ho_nmax-lpr)/2
                      DO n3 = 0,(Ho_nmax-l)/2
                         DO n4 = 0,(Ho_nmax-lpr)/2
                            ! l = 0 subspace
                            ! Etot = Etot + 0.5_r_kind*(j2+1.0_r_kind)*density_matrix(l,jindex,n3,n1)*Ho_two_body_matel(l,jindex,n1,n2,n3,n4)*density_matrix(l,jindex,n4,n2)

                            !general
                            Etot = Etot + 0.5_r_kind*(j2+1.0_r_kind)*(j2pr+1.0_r_kind)&
                                 *density_matrix(l,jindex,n3,n1)&
                                 *Ho_two_body_matels(TBME_index(l,jindex,lpr,jindexpr,n1,n2,n3,n4))&
                                 *density_matrix(l,jindex,n4,n2)


                         END DO
                      END DO
                   END DO
                END DO
             END DO
          END DO
       END DO
    END DO



  END SUBROUTINE hf_total_energy_v2


  SUBROUTINE hf_diagonalize
    IMPLICIT NONE

    INTEGER :: l,jindex
    COMPLEX(kind=r_kind), ALLOCATABLE :: work(:)
    REAL(kind=r_kind), ALLOCATABLE :: rwork(:)
    COMPLEX(kind=r_kind), ALLOCATABLE :: h_block(:,:)
    REAL(kind=r_kind), ALLOCATABLE :: e_block(:)
    INTEGER :: lwork, info, size_block
    !INTEGER :: count

    INTERFACE 
       SUBROUTINE zheev(jobz, uplo, n, a, lda, w, work, lwork, rw, info)
         CHARACTER(len=1) ::  jobz, uplo
         INTEGER          ::  info, lda, lwork, n
         REAL(KIND=8)     ::  rw(*), w(*)
         COMPLEX(8)   ::  a(lda, *), work(*)
       END SUBROUTINE zheev
    END INTERFACE

    !count = 1

    DO l=0,Ho_lmax
       DO jindex = 0,1
          IF(l==0 .and. jindex==1) CYCLE

          size_block = (Ho_Nmax-l)/2+1

          !ALLOCATE(h_block(Ho_nmax+1,Ho_nmax+1))
          !ALLOCATE(e_block(Ho_nmax+1))

          ALLOCATE(h_block(size_block,size_block),e_block(size_block))

          h_block(:,:) = hf_hamiltonian(l,jindex,0:size_block-1,0:size_block-1)
          

                ALLOCATE(work(1))
                ALLOCATE(rwork( max(1,3*size_block-2) ) )
                lwork = -1

                CALL zheev('V','U',size_block,h_block ,size_block,e_block,work,lwork,rwork,info)

                lwork = work(1)
                DEALLOCATE(work)
                ALLOCATE(work(lwork))

                CALL zheev('V','U',size_block, h_block,size_block,e_block,work,lwork,rwork,info)

                DEALLOCATE(work)
                DEALLOCATE(rwork)

                hf_transform(l,jindex,0:size_block-1,0:size_block-1) = h_block(:,:)
                hf_energies(l,jindex,0:size_block-1) = e_block(:)
                DEALLOCATE(h_block,e_block)

!!$                !debug
!!$                WRITE(*,*) 'In hf_diagonalize, the hf transformation matrix:'
!!$                CALL print_matrix(Ho_nmax+1,REAL(hf_transform(l,jindex,0:Ho_nmax,0:Ho_nmax),kind=r_kind))
!!$                !
                        
       END DO

       !count = count + 1
    END DO

  END SUBROUTINE hf_diagonalize


  SUBROUTINE init_Ho_basis(nmax,lmax,b,hbaromega)
    IMPLICIT NONE

    REAL(kind=r_kind), intent(in) :: b
    REAL(kind=r_kind), optional :: hbaromega
    INTEGER, intent(in) :: nmax, lmax

    WRITE(*,*) 'Initializing ho basis'

    !currently only allowing for lmax = 0, need to consider better structure for block diagonality for lmax>0
    IF(lmax > 0) THEN
       WRITE(*,*) 'Only lmax = 0 supportet ATM, quitting'
       STOP
    END IF

   
    Ho_lmax = lmax
    Ho_Nmax = 2*nmax+lmax
 
    IF(.not. present(hbaromega)) THEN

       IF(b<=0) THEN
          WRITE(*,*) 'b<=0 not allowed'
          STOP
       END IF
       Ho_b = b
       Ho_hbaromega = hbarc**2/(Ho_b**2*mnc2)

    END IF

    IF(present(hbaromega)) THEN
        IF(hbaromega<=0) THEN
          WRITE(*,*) 'hbaromega<=0 not allowed'
          STOP
       END IF

       Ho_hbaromega  = hbaromega
       Ho_b = hbarc/sqrt(hbaromega*mnc2)
    END IF
       
    WRITE(*,*) 'IN init_Ho_basis'
    WRITE(*,*) 'mnc2 = ',mnc2
    WRITE(*,*) 'hbarc = ',hbarc
    WRITE(*,*) 'Ho_b = ',Ho_b
    WRITE(*,*) 'Ho_hbaromega = ',Ho_hbaromega
    WRITE(*,*) 'init_Ho_basis, done'



  END SUBROUTINE init_Ho_basis

  SUBROUTINE hf_init
    IMPLICIT NONE

    INTEGER :: l,jindex,n1,n2,n3,n4,max_n

    COMPLEX(kind=r_kind) :: zero_c = (0.0_r_kind,0.0_r_kind)
    REAL(kind=r_kind) :: zero_r = 0.0_r_kind
    
    REAL(kind=r_kind), parameter :: kappa_R = 1.487_r_kind
    REAL(kind=r_kind), parameter :: V_0R = 200.00_r_kind
    REAL(kind=r_kind), parameter :: kappa_S = 0.465_r_kind
    REAL(kind=r_kind), parameter :: V_0S = -91.85_r_kind


    WRITE(*,*) 'Allocating matricies for HF'
    WRITE(*,*) 'Ho_lmax = ',Ho_lmax
    WRITE(*,*) 'Ho_nmax = ',Ho_nmax

    max_n = Ho_nmax/2

    ALLOCATE(hf_transform(0:Ho_lmax,0:1,0:max_n,0:max_n))
    hf_transform = zero_c
    ALLOCATE(density_matrix(0:Ho_lmax,0:1,0:max_n,0:max_n))
    density_matrix = zero_c
    ALLOCATE(density_matrix_old(0:Ho_lmax,0:1,0:max_n,0:max_n))
    density_matrix_old = zero_c
    ALLOCATE(hf_energies(0:Ho_lmax,0:1,0:max_n))
    hf_energies = zero_r
    ALLOCATE(hf_energies_old(0:Ho_lmax,0:1,0:max_n))
    hf_energies_old = zero_r

    Ho_size_all = 0

    DO l=0,Ho_lmax
        DO jindex = 0,1
           IF(l==0 .and. jindex==1) CYCLE

           Ho_size_all = Ho_size_all + (Ho_Nmax-l)/2 + 1

        END DO
     END DO

     ALLOCATE(hf_states_all(0:Ho_size_all-1)) 
     ALLOCATE(hf_energies_all(0:Ho_size_all-1))
     hf_energies_all = zero_r
     ALLOCATE(hf_energies_all_old(0:Ho_size_all-1))
     hf_energies_all_old = zero_r

     ALLOCATE(hf_energies_all_sort(0:Ho_size_all-1))

     ALLOCATE(fermi_index_hfbasis(0:Ho_lmax,0:1))
     ALLOCATE(hf_hamiltonian(0:Ho_lmax,0:1,0:max_n,0:max_n))
     hf_hamiltonian = zero_c
     ALLOCATE(hf_gamma(0:Ho_lmax,0:1,0:max_n,0:max_n))
     hf_gamma = zero_c
     ALLOCATE(Ho_two_body_matel(0:Ho_lmax,0:1,0:max_n,0:max_n,0:max_n,0:max_n))
     Ho_two_body_matel = zero_c



     Ho_size_TBME = (Ho_lmax+1)*2*(Ho_lmax+1)*2*(max_n+1)**4

     ALLOCATE(Ho_two_body_matels(Ho_size_TBME))
     Ho_two_body_matels = zero_c

     !should give 0,1,and 2 based on orthogonality of radial wfs
     !CALL calculate_two_body_matels_GL(1e-5_r_kind,1.0_r_kind)

     IF(Ho_lmax == 0) THEN     
        CALL calculate_two_body_matels_GL(kappa_R,0.5_r_kind*V_0R)
        CALL calculate_two_body_matels_GL(kappa_S,0.5_r_kind*V_0S)

!!$     Ho_two_body_matel = (0.0_r_kind,0.0_r_kind)
!!$      
!!$
!!$     CALL calculate_two_body_matels(kappa_R,0.5_r_kind*V_0R)
!!$     CALL calculate_two_body_matels(kappa_S,0.5_r_kind*V_0S)
!!$
!!$     !should give 0,1,and 2 based on orthogonality of radial wfs
!!$     !CALL calculate_two_body_matels(1e-5_r_kind,1.0_r_kind)


        !DO l=0,Ho_lmax
        !DO jindex = 0,1
        !IF(l==0 .and. jindex==1) CYCLE
        l = 0
        jindex = 0
        DO n1 = 0,Ho_nmax/2
           DO n2 = 0,Ho_nmax/2
              DO n3 = 0,Ho_nmax/2
                 DO n4 = 0,Ho_nmax/2


                    Ho_two_body_matels(TBME_index(l,jindex,l,jindex,n1,n2,n3,n4)) = 0.5_r_kind*Ho_two_body_matel(l,jindex,n1,n2,n3,n4)


                 END DO
              END DO
           END DO
        END DO

        !END DO
        !END DO
     END IF




  END SUBROUTINE hf_init

   SUBROUTINE calculate_two_body_matels(mu,V_0)
    IMPLICIT NONE

    REAL(kind=r_kind), intent(in) :: mu, V_0

    INTEGER :: n
    REAL(kind=r_kind) :: alpha

    REAL(kind=r_kind), ALLOCATABLE :: wf_1(:), wf_3(:)
    REAL(kind=r_kind), ALLOCATABLE :: wf_2(:), wf_4(:)
    REAL(kind=r_kind), ALLOCATABLE :: scaled_gp(:)
    INTEGER :: II, JJ, dim_dg
    INTEGER :: l, jindex

    INTEGER :: n1,n2,n3,n4
    COMPLEX(kind=r_kind) :: matel

    

    INTEGER :: term
    INTEGER, parameter :: no_terms = 1
    REAL(kind=r_kind) :: prefactor(no_terms)
    
    
    REAL(kind=r_kind) :: xII,xJJ,pf,norm

    

    n = 100
    alpha = 0.0_r_kind

    WRITE(*,*) 'Calculating matix elements'

    WRITE(*,*) 'Initializing grid'
    CALL init_grid_GLag(n,alpha)
    WRITE(*,*) '  Done'

    ALLOCATE(wf_1(n),wf_2(n),wf_3(n),wf_4(n),scaled_gp(n))

    !only s-wave implemented
    l = 0
    jindex = 0

    !scaling   
    prefactor = (/ 1.0_r_kind/(Ho_b**2*16.0_r_kind*mu*(Ho_b**2*mu+1.0_r_kind)**2) /)
    prefactor = V_0*prefactor
    
    
    WRITE(*,*) 'Perfoming sums'

    WRITE(*,*) 'mu = ',mu,'V_0 = ',V_0,'Ho_b = ', Ho_b

    scaled_gp = (Ho_b**2*mu+1.0_r_kind)**(-0.5_r_kind)*sqrt(grid_points_GLag)
  
    DO term = 1,no_terms
       pf = prefactor(term)
       DO n1 = 0,Ho_Nmax/2
          DO n2 = 0,Ho_Nmax/2
             DO n3 = 0,Ho_Nmax/2
                DO n4 = 0,Ho_Nmax/2

!!$                   !for debug
!!$                   WRITE(*,*) 'n1=',n1,'n2=',n2,'n3=',n3,'n4=',n4
!!$                   
!!$
!!$                    norm = 0.0_r_kind
!!$                    CALL RadHO_poly(n1,0,1.0_r_kind,sqrt(grid_points_GLag),wf_1,n)
!!$                    CALL RadHO_poly(n2,0,1.0_r_kind,sqrt(grid_points_GLag),wf_2,n)
!!$                     DO II = 1,n
!!$                        xII = sqrt(grid_points_GLag(II))
!!$                        norm = norm + grid_weights_GLag(II)*xII*wf_1(II)*wf_2(II)                       
!!$
!!$                     END DO
!!$                     norm = norm/2.0
!!$                     !norm = Ho_b**3/2.0*norm
!!$                     WRITE(*,*) 'norm n1,n2 =',norm
!!$
!!$                     !end for debug
                   
                   CALL RadHO_poly(n1,0,1.0,scaled_gp,wf_1,n)
                   CALL RadHO_poly(n3,0,1.0,scaled_gp,wf_3,n)
                   CALL RadHO_poly(n2,0,1.0,scaled_gp,wf_2,n)
                   CALL RadHO_poly(n4,0,1.0,scaled_gp,wf_4,n)

!!$                   wf_1 = 0.0
!!$                   wf_2 = 0.0
!!$                   wf_3 = 0.0
!!$                   wf_4 = 0.0
                   
                   matel = (0.0_r_kind,0.0_r_kind) 


                  

                   DO II = 1,n
                      DO JJ = 1,n
                         xII = scaled_gp(II)
                         xJJ = scaled_gp(JJ)
                         
                         !WRITE(*,*) 'II = ',II,'JJ = ',JJ,'xII = ',xII,'xJJ = ',xJJ 
                         
!!$                         matel = matel + grid_weights_GLag(II)*grid_weights_GLag(JJ)&
!!$                              *(wf_1(II)*wf_3(II)*wf_2(JJ)*wf_4(JJ) + wf_1(II)*wf_4(II)*wf_2(JJ)*wf_3(JJ))&
!!$                              *(EXP(2.0_r_kind*Ho_b**2*mu*xII*xJJ)-EXP(-2.0_r_kind*Ho_b**2*mu*xII*xJJ))   

                         matel = matel + EXP(LOG(grid_weights_GLag(II)*grid_weights_GLag(JJ)) + 2.0_r_kind*Ho_b**2*mu*xII*xJJ)*(wf_1(II)*wf_3(II)*wf_2(JJ)*wf_4(JJ) + wf_1(II)*wf_4(II)*wf_2(JJ)*wf_3(JJ))  - grid_weights_GLag(II)*grid_weights_GLag(JJ)&
                              *(wf_1(II)*wf_3(II)*wf_2(JJ)*wf_4(JJ) + wf_1(II)*wf_4(II)*wf_2(JJ)*wf_3(JJ))&
                              *EXP(-2.0_r_kind*Ho_b**2*mu*xII*xJJ)


                       

                         
!!$                         !
!!$                         WRITE(*,*) xII,grid_weights_GLag(II),xJJ,grid_weights_GLag(JJ),2.0_r_kind*Ho_b**2*mu*xII*xJJ
!!$                         WRITE(*,*) matel
!!$                         WRITE(*,*) pf*matel
!!$                         !
                         

                      END DO
                   END DO
                   
!!$                   !for debug
!!$                   WRITE(*,*) 'matel =',matel,'Ho_two_body_matel(l,jindex,n1,n2,n3,n4)=',Ho_two_body_matel(l,jindex,n1,n2,n3,n4)
!!$                   STOP
!!$                   !end for debug
                   
                   Ho_two_body_matel(l,jindex,n1,n2,n3,n4) = Ho_two_body_matel(l,jindex,n1,n2,n3,n4) +  pf*matel
                   !Ho_two_body_matel(l,jindex,n1,n2,n3,n4) =  pf*matel
                   
                END DO
             END DO
          END DO
       END DO
    END DO

    WRITE(*,*) 'Done'

    WRITE(*,*) 'Two-body matrix elements'
    
    DO n1 = 0,Ho_Nmax/2
       DO n2 = 0,Ho_Nmax/2
          DO n3 = 0,Ho_Nmax/2
             DO n4 = 0,Ho_Nmax/2
                
                WRITE(*,'(4I2,2F20.14)') n1,n2,n3,n4,REAL(Ho_two_body_matel(l,jindex,n1,n2,n3,n4),kind=r_kind),AIMAG(Ho_two_body_matel(l,jindex,n1,n2,n3,n4))

             END DO
          END DO
       END DO
    END DO



  END SUBROUTINE calculate_two_body_matels



  




   SUBROUTINE calculate_two_body_matels_GL(mu,V_0)
    IMPLICIT NONE

    REAL(kind=r_kind), intent(in) :: mu, V_0

    INTEGER :: n
    

    REAL(kind=r_kind), ALLOCATABLE :: wf_1(:), wf_3(:)
    REAL(kind=r_kind), ALLOCATABLE :: wf_2(:), wf_4(:)
    REAL(kind=r_kind), ALLOCATABLE :: scaled_gp(:)
    INTEGER :: II, JJ
    INTEGER :: l, jindex

    INTEGER :: n1,n2,n3,n4
    COMPLEX(kind=r_kind) :: matel

    

    INTEGER :: term
    INTEGER, parameter :: no_terms = 1
    REAL(kind=r_kind) :: prefactor(no_terms)
    
    
    REAL(kind=r_kind) :: xII,xJJ,pf,norm

    

    n = 100
    
    
    WRITE(*,*) 'Calculating matix elements'

    IF(.not. is_init_grid_GL .or. grid_size_GL /= n) THEN
       WRITE(*,*) 'Initializing grid'
       CALL init_grid_GL(n)
       WRITE(*,*) '  Done'
    END IF

    ALLOCATE(wf_1(n),wf_2(n),wf_3(n),wf_4(n),scaled_gp(n))

    !only s-wave implemented
    l = 0
    jindex = 0

    !scaling   
    prefactor = (/ pi**2/16.0_r_kind/(4.0_r_kind*mu) /)
    prefactor = V_0*prefactor
    
    
    WRITE(*,*) 'Perfoming sums'

    WRITE(*,*) 'mu = ',mu,'V_0 = ',V_0,'Ho_b = ', Ho_b

    scaled_gp = tan(pi/4.0_r_kind*(grid_points_GL+1.0_r_kind))
  
    DO term = 1,no_terms
       pf = prefactor(term)
       DO n1 = 0,Ho_Nmax/2
          DO n2 = 0,Ho_Nmax/2
             DO n3 = 0,Ho_Nmax/2
                DO n4 = 0,Ho_Nmax/2
!!$
!!$                   !for debug
!!$                   WRITE(*,*) 'n1=',n1,'n2=',n2,'n3=',n3,'n4=',n4
!!$                   
!!$
!!$                    norm = 0.0_r_kind
!!$                    CALL RadHO(n1,0,Ho_b,scaled_gp,wf_1,n)
!!$                    CALL RadHO(n2,0,Ho_b,scaled_gp,wf_2,n)
!!$                     DO II = 1,n
!!$                        xII = scaled_gp(II) ! tan(pi*grid_points_GL(II)/2.0_r_kind)
!!$                        norm = norm + grid_weights_GL(II)*(xII**2+1.0_r_kind)&
!!$                             *xII**2*wf_1(II)*wf_2(II)       
!!$
!!$                        !norm = norm + grid_weights_GL(II)*(xII**2+1.0_r_kind)*EXP(-xII)
!!$
!!$                        !xJJ = pi/4.0_r_kind*(grid_points_GL(II)+1.0_r_kind)
!!$                        !norm = norm + grid_weights_GL(II)/(cos(xJJ)**2)*EXP(-xII)
!!$
!!$                     END DO
!!$                     norm = pi*norm/4.0_r_kind
!!$                     !norm = Ho_b**3/2.0*norm
!!$                     WRITE(*,*) 'norm n1,n2 =',norm
!!$
!!$                     !end for debug
                   
                   CALL RadHO(n1,0,Ho_b,scaled_gp,wf_1,n)
                   CALL RadHO(n3,0,Ho_b,scaled_gp,wf_3,n)
                   CALL RadHO(n2,0,Ho_b,scaled_gp,wf_2,n)
                   CALL RadHO(n4,0,Ho_b,scaled_gp,wf_4,n)

!!$                   wf_1 = 0.0
!!$                   wf_2 = 0.0
!!$                   wf_3 = 0.0
!!$                   wf_4 = 0.0
                   
                   matel = (0.0_r_kind,0.0_r_kind) 


                  

                   DO II = 1,n
                      DO JJ = 1,n
                         xII = scaled_gp(II)
                         xJJ = scaled_gp(JJ)



                         matel = matel + grid_weights_GL(II)*grid_weights_GL(JJ)*(xII**2+1.0_r_kind)*(xJJ**2+1.0_r_kind)&
                              *(wf_1(II)*wf_3(II)*wf_2(JJ)*wf_4(JJ) + wf_1(II)*wf_4(II)*wf_2(JJ)*wf_3(JJ))&
                              *xII*xJJ*(EXP(-mu*(xII**2+xJJ**2)+2.0_r_kind*mu*xII*xJJ)-EXP(-mu*(xII**2+xJJ**2)-2.0_r_kind*mu*xII*xJJ))




                         !EXP(-mu*(xII**2+xJJ**2))*(EXP(2*mu*xII*xJJ)-EXP(-2*mu*xII*xJJ))



                         
!!$                         !
!!$                         WRITE(*,*) xII,grid_weights_GLag(II),xJJ,grid_weights_GLag(JJ),2.0_r_kind*Ho_b**2*mu*xII*xJJ
!!$                         WRITE(*,*) matel
!!$                         WRITE(*,*) pf*matel
!!$                         !
                         

                      END DO
                   END DO
                   
!!$                   !for debug
!!$                   WRITE(*,*) 'matel =',matel,'Ho_two_body_matel(l,jindex,n1,n2,n3,n4)=',Ho_two_body_matel(l,jindex,n1,n2,n3,n4)
!!$                   STOP
!!$                   !end for debug
                   
                   Ho_two_body_matel(l,jindex,n1,n2,n3,n4) = Ho_two_body_matel(l,jindex,n1,n2,n3,n4) +  pf*matel
                   !Ho_two_body_matel(l,jindex,n1,n2,n3,n4) =  pf*matel
                   
                END DO
             END DO
          END DO
       END DO
    END DO

    WRITE(*,*) 'Done'

    OPEN(unit=1,file='matels_hf.dat')

    WRITE(1,*) 'Two-body matrix elements'
    
    DO n1 = 0,Ho_Nmax/2!MIN(1,Ho_nmax)
       DO n2 = 0,Ho_Nmax/2!MIN(1,Ho_nmax)
          DO n3 = 0,Ho_Nmax/2!MIN(1,Ho_nmax)
             DO n4 = 0,Ho_Nmax/2!MIN(1,Ho_nmax)
                
                WRITE(1,'(4I2,2F20.12)') n1,n2,n3,n4,REAL(Ho_two_body_matel(l,jindex,n1,n2,n3,n4),kind=r_kind),AIMAG(Ho_two_body_matel(l,jindex,n1,n2,n3,n4))

             END DO
          END DO
       END DO
    END DO

    CLOSE(1)


  END SUBROUTINE calculate_two_body_matels_GL











  !the following was a failed attempt at calculating the two-body matrix elements
  !where the integration variables where changed. Might work with some more thought
  SUBROUTINE calculate_two_body_matels_incorrect(mu,V_0)
    IMPLICIT NONE

    REAL(kind=r_kind), intent(in) :: mu, V_0

    INTEGER :: n
    REAL(kind=r_kind) :: alpha

    REAL(kind=r_kind), ALLOCATABLE :: double_grid_1(:), wf_1(:), wf_3(:)
    REAL(kind=r_kind), ALLOCATABLE :: double_grid_2(:), wf_2(:), wf_4(:)
    INTEGER :: II, JJ, dim_dg
    INTEGER :: l, jindex

    INTEGER :: n1,n2,n3,n4
    COMPLEX(kind=r_kind) :: matel

    

    INTEGER :: term
    INTEGER, parameter :: no_terms = 2
    REAL(kind=r_kind) :: scaling_1(no_terms), scaling_2(no_terms), prefactor(no_terms)
    
    
    REAL(kind=r_kind) :: xII,xJJ,pf,s1,s2

    

    n = 100
    dim_dg = n**2
    alpha = -0.5_r_kind

    WRITE(*,*) 'Calculating matix elements'

    WRITE(*,*) 'Initializing grid'
    CALL init_grid_GLag(n,alpha)
    WRITE(*,*) '  Done'

    ALLOCATE(double_grid_1(n**2),double_grid_2(n**2),wf_1(n**2),wf_2(n**2),wf_3(n**2),wf_4(n**2))

    DO II = 1,n
       DO JJ = 1,n
          
          double_grid_1((II-1)*n + JJ) = grid_points_GLag(II)+0.5_r_kind*grid_points_GLag(JJ)
          double_grid_2((II-1)*n + JJ) = grid_points_GLag(II)-0.5_r_kind*grid_points_GLag(JJ)

       END DO
    END DO

  

    !only s-wave implemented
    l = 0
    jindex = 0

    !scaling
    scaling_1 = (/ 2.0_r_kind**(-0.5_r_kind),(4.0_r_kind*mu*Ho_b**2+2.0_r_kind)**(-0.5_r_kind)/)
    scaling_2 = (/ (mu*Ho_b**2+0.5_r_kind)**(-0.5_r_kind),2.0_r_kind**(-0.5_r_kind) /)
    prefactor = (/ Ho_b**4/(16.0_r_kind*mu*sqrt(2.0_r_kind*mu*Ho_b**2+1.0_r_kind)) &
         ,  -1.0_r_kind*Ho_b**4/(16.0_r_kind*mu*sqrt(8.0_r_kind*mu*Ho_b**2+4.0_r_kind)) /)
    prefactor = V_0*prefactor
    
    
    WRITE(*,*) 'Perfoming sums'

  
    DO term = 1,no_terms
       s1 = scaling_1(term)
       s2 = scaling_2(term)
       pf = prefactor(term)
       DO n1 = 0,Ho_Nmax/2
          DO n2 = 0,Ho_Nmax/2
             DO n3 = 0,Ho_Nmax/2
                DO n4 = 0,Ho_Nmax/2

                   WRITE(*,*) 'n1=',n1,'n2=',n2,'n3=',n3,'n4=',n4

                   CALL RadHO_poly(n1,0,1.0,s1*double_grid_1**(0.5_r_kind),wf_1,dim_dg)
                   CALL RadHO_poly(n3,0,1.0,s1*double_grid_1**(0.5_r_kind),wf_3,dim_dg)
                   CALL RadHO_poly(n2,0,1.0,s2*double_grid_2**(0.5_r_kind),wf_2,dim_dg)
                   CALL RadHO_poly(n4,0,1.0,s2*double_grid_2**(0.5_r_kind),wf_4,dim_dg)

!!$                   wf_1 = 0.0
!!$                   wf_2 = 0.0
!!$                   wf_3 = 0.0
!!$                   wf_4 = 0.0
                   
                   matel = (0.0_r_kind,0.0_r_kind) 

                   DO II = 1,n
                      DO JJ = 1,n
                         xII = s1*grid_weights_GLag(II)**(0.5_r_kind)
                         xJJ = s2*grid_weights_GLag(JJ)**(0.5_r_kind)
                         matel = matel + grid_weights_GLag(II)*grid_weights_GLag(JJ)&
                              *(xII**2 - xJJ**2/4.0_r_kind)&
                              *wf_1((II-1)*n + JJ)*wf_3((II-1)*n + JJ)&
                              *wf_2((II-1)*n + JJ)*wf_4((II-1)*n + JJ)

                      END DO
                   END DO
                   Ho_two_body_matel(l,jindex,n1,n2,n3,n4) = Ho_two_body_matel(l,jindex,n1,n2,n3,n4) +  pf*matel

                END DO
             END DO
          END DO
       END DO
    END DO

    WRITE(*,*) 'Done'




  END SUBROUTINE calculate_two_body_matels_incorrect



  SUBROUTINE init_ho_basis_old(b,nmax,lmax)
    IMPLICIT NONE
    
    REAL(kind=r_kind), intent(in) :: b
    INTEGER, intent(in) :: nmax, lmax

    INTEGER :: n1,n2,l1,l2

    WRITE(*,*) 'Initializing ho basis'

    !currently only allowing for lmax = 0, need to consider better structure for block diagonality for lmax>0
    IF(lmax > 0) THEN
       WRITE(*,*) 'Only lmax = 0 supportet ATM, quitting'
       STOP
    END IF

    CALL set_Ho_b(b)
    
    !TODO fix this
    Ho_hbaromega = 1.0_r_kind
    !


    Ho_nmax = nmax
    Ho_lmax = lmax

    IF(ALLOCATED(h_sp)) DEALLOCATE(h_sp)

    ALLOCATE(h_sp(0:nmax,0:nmax))    

    !
    l1 = 0
    l2 = 0
    !

   
    WRITE(*,*) 'Calculating matrix elements'
    WRITE(*,*) 'Ho_nmax =', Ho_nmax
    
    DO n1=0,Ho_nmax
       DO n2=n1,Ho_nmax

          h_sp(n1,n2) = one_body_radial_matel_GH(n1,l1,n2,l2,coulomb_pot)+kinetic_matel_analytic(n1,l1,n2,l2)
          h_sp(n2,n1) = h_sp(n1,n2)
          !WRITE(*,*) 'n1,n2 = ',n1,n2
       END DO
    END DO



  END SUBROUTINE init_ho_basis_old


  REAL(kind=r_kind) FUNCTION coulomb_pot(r)
    IMPLICIT NONE
    REAL(kind=r_kind), intent(in) :: r
    !fix units    
    coulomb_pot = -1/ABS(r)
  END FUNCTION coulomb_pot



  SUBROUTINE set_Ho_b(b)
    IMPLICIT NONE
    REAL(kind=r_kind) :: b

    IF(b<=0) THEN
       WRITE(*,*) 'b<=0 not allowed'
       STOP
    END IF
    Ho_b = b

    Ho_hbaromega = hbarc**2/(Ho_b**2*mnc2)

    WRITE(*,*) 'Ho_b = ',Ho_b
    WRITE(*,*) 'Ho_hbaromega = ',Ho_hbaromega

  END SUBROUTINE set_Ho_b

  !The prefactor for radial ho wave funciton with osc. lenght b = 1
  REAL(kind=r_kind) FUNCTION radial_wf_prefactor(n,l)

    IMPLICIT NONE

    INTEGER, intent(in) :: n,l
    REAL(kind=r_kind) :: lnfac

    IF (n == 0) THEN
      lnfac = 0.0_r_kind
    ELSE
      lnfac = gammln(DBLE(n)+1.0_r_kind)
    END IF

    !WRITE(*,*) 'lfac in function = ' , lnfac
    
    radial_wf_prefactor = sqrt(2.0_r_kind)&
         * EXP( 0.5_r_kind*(lnfac - gammln(DBLE(n)+DBLE(l)+ 1.5_r_kind)))
    
     !radial_wf_prefactor = 2.0_r_kind * EXP( 0.5_r_kind*(lnfac + lnfac - gammln(DBLE(n)+DBLE(l)+ 1.5_r_kind) - gammln(DBLE(n)+DBLE(l)+ 1.5_r_kind)) )
     !radial_wf_prefactor = sqrt(radial_wf_prefactor)

    

  END FUNCTION radial_wf_prefactor
  
  REAL(kind=r_kind) FUNCTION overlap_ho(n1,l1,n2,l2)
    

    IMPLICIT NONE
    INTEGER, intent(in) :: n1,l1,n2,l2
    INTEGER :: II

    REAL(kind=r_kind), ALLOCATABLE :: f1(:),f2(:),fw(:)
    REAL(kind=r_kind) :: lnfac1, lnfac2


    overlap_ho = 0.0

    IF(.not. is_init_grid_GH) THEN
       WRITE(*,*) 'GH grid is not initialized'
       STOP
    END IF

    ALLOCATE(f1(grid_size_GH),f2(grid_size_GH),fw(grid_size_GH))
    
    CALL LaguerreL2(n1, l1, grid_points_GH**2, f1, fw, grid_size_GH)
    CALL LaguerreL2(n2, l2, grid_points_GH**2, f2, fw, grid_size_GH)

    DO II = 1,grid_size_GH
       overlap_ho = overlap_ho + grid_weights_GH(II)*grid_points_GH(II)**(l1+l2+2)*f1(II)*f2(II)  
       !overlap_ho = overlap_ho + grid_points_GH(II)**2*grid_weights_GH(II)
    END DO

!!$    IF (n1 == 0) THEN
!!$      lnfac1 = 0.0_r_kind
!!$    ELSE
!!$      lnfac1 = gammln(DBLE(n1)+1.0_r_kind)
!!$    END IF
!!$    IF (n2 == 0) THEN
!!$      lnfac2 = 0.0_r_kind
!!$    ELSE
!!$      lnfac2 = gammln(DBLE(n2)+1.0_r_kind)
!!$    END IF

    
    !overlap_ho = 2.0_r_kind * EXP( 0.5_r_kind*(lnfac1 + lnfac2 - gammln(DBLE(n1)+DBLE(l1)+ 1.5_r_kind) - gammln(DBLE(n2)+DBLE(l2)+ 1.5_r_kind)) ) * overlap_ho

    overlap_ho = radial_wf_prefactor(n1,l1)*radial_wf_prefactor(n2,l2)* overlap_ho
    
    !WRITE(*,*) 'lnfac1 = ', lnfac1, 'lnfac2= ',lnfac2

    !WRITE(*,*) 2.0_r_kind * EXP( 0.5_r_kind*(lnfac1 + lnfac2 - gammln(DBLE(n1)+DBLE(l1)+ 1.5_r_kind) - gammln(DBLE(n2)+DBLE(l2)+ 1.5_r_kind)) )
    !WRITE(*,*) radial_wf_prefactor(n1,l1)*radial_wf_prefactor(n2,l2)


    DEALLOCATE(f1,f2,fw)

    RETURN 

  END FUNCTION overlap_ho


  REAL(kind=r_kind) FUNCTION one_body_radial_matel_GH(n1,l1,n2,l2,potential_function)
    
    IMPLICIT NONE
    
    INTERFACE       
       !REAL(kind=r_kind) FUNCTION potential_function(r) !cannot acces r_kind in this scope
       REAL(8) FUNCTION potential_function(r)
         !REAL(kind=r_kind), intent(in) :: r
         REAL(8), intent(in) :: r
       END FUNCTION potential_function
    END INTERFACE

    INTEGER, intent(in) :: n1, l1, n2, l2  
    INTEGER :: II
    REAL(kind=r_kind) :: matel

    REAL(kind=r_kind), ALLOCATABLE :: f1(:),f2(:),fw(:)
    REAL(kind=r_kind) :: lnfac1, lnfac2

    IF(.not. is_init_grid_GH) THEN
       WRITE(*,*) 'GH grid is not initialized'
       STOP
    END IF

    ALLOCATE(f1(grid_size_GH),f2(grid_size_GH),fw(grid_size_GH))

    CALL LaguerreL2(n1, l1, grid_points_GH**2, f1, fw, grid_size_GH)
    CALL LaguerreL2(n2, l2, grid_points_GH**2, f2, fw, grid_size_GH)

   
    matel = 0.0_r_kind

    DO II = 1,grid_size_GH
       matel = matel + grid_weights_GH(II)*potential_function(Ho_b*ABS(grid_points_GH(II)))*ABS(grid_points_GH(II))**(2+l1+l2)*f1(II)*f2(II)
       
       !matel = matel + ABS(grid_points_GH(II))**(2+l1+l2)*f1(II)*f2(II)
       !for debug
       !WRITE(*,*) matel
       !end for debug

    END DO

    matel = radial_wf_prefactor(n1,l1)*radial_wf_prefactor(n2,l2)*matel 

    DEALLOCATE(f1,f2,fw)

    one_body_radial_matel_GH = matel

    RETURN 

    
  END FUNCTION one_body_radial_matel_GH

!!$  SUBROUTINE test
!!$
!!$    IMPLICIT NONE
!!$    REAL(kind=r_kind) :: x
!!$
!!$    WRITE(*,*) is_init_grid_GH
!!$
!!$  END SUBROUTINE test


  REAL(kind=r_kind) FUNCTION kinetic_matel_analytic(n1,l1,n2,l2)
    IMPLICIT NONE
    INTEGER, intent(in) :: n1,l1,n2,l2
    REAL(kind=r_kind) :: matel

    IF(l1 /= l2) THEN
      kinetic_matel_analytic = 0.0_r_kind
       RETURN
    END IF
    
    SELECT CASE(n1-n2)
    CASE(0)
       matel = 2*n1 + l1 + 1.5_r_kind
    CASE(-1)
       matel = sqrt(n2*(n2+l1+0.5_r_kind))
    CASE(1)
       matel = sqrt(n1*(n1+l1+0.5_r_kind))
    CASE DEFAULT
       matel = 0.0_r_kind
    END SELECT

   kinetic_matel_analytic = 0.5_r_kind * Ho_hbaromega * matel 


  END FUNCTION kinetic_matel_analytic



  ! log(Gamma(xx)) From numerical recipies
  FUNCTION gammln(xx)
    IMPLICIT NONE
    DOUBLE PRECISION gammln,xx
    ! Returns the value ln[GAM(xx)] for xx > 0.
    INTEGER j
    DOUBLE PRECISION ser,stp,tmp,x,y,cof(6)
    SAVE cof,stp
    DATA cof,stp/76.18009172947146d0,-86.50532032941677d0,&
          24.01409824083091d0,-1.231739572450155d0,.1208650973866179d-2,&
          -.5395239384953d-5,2.5066282746310005d0/
    x=xx
    y=x
    tmp=x+5.5d0
    tmp=(x+0.5d0)*log(tmp)-tmp
    ser=1.000000000190015d0
    do j=1,6
       y=y+1.d0
       ser=ser+cof(j)/y
    enddo
    gammln=tmp+log(stp*ser/x)
    return
  END FUNCTION gammln

  
!  L = L_(n)^(l+1/2) ! Using recursion relations

! Originally returned sign(L) and log(abs(L)) /Daniel W
  Subroutine LaguerreL2(n, l, RVEC, FVEC, FVEC_S, dimr) 
    IMPLICIT NONE
    INTEGER :: n,l,Ik,II, dimr
    REAL(kind=r_kind) :: RVEC(dimr), FVEC(dimr),FVEC_S(dimr),bin,alpha
    REAL(kind=r_kind) :: L0(dimr), L1(dimr)

    IF(n.lt.0) THEN
       FVEC   = 0.0_r_kind
       FVEC_S = 0.0_r_kind
       RETURN
    END IF

    alpha = l + 0.5_r_kind
    
    L1 = 0.0_r_kind; FVEC = 1.0_r_kind;
    DO ii = 1 , n 
       L0 = L1
       L1 = FVEC
       FVEC = ((2.0_r_kind * ii- 1.0_r_kind + alpha- RVEC)* L1- (ii- 1.0_r_kind + alpha)* L0)/ REAL(ii,kind=r_kind)
    END DO
  
    FVEC_S = sign(1.0_r_kind,FVEC)
    !Commented away statement below I want the value not the log /Daniel W
    !FVEC   = log(abs(FVEC)) 
    !End Comment /Daniel W
    RETURN 
  END Subroutine LaguerreL2

  !Calculates the polynomial part of the radial HO-wf
  Subroutine RadHO_poly(n, l, b, RVEC, FVEC, dimr)
     IMPLICIT NONE
    INTEGER :: n,l,dimr
    DOUBLE PRECISION :: nR,lR,b, RVEC(dimr), FVEC(dimr), FVEC_S(dimr), FVECtmp(dimr), lnfac
    nR = DBLE(n) 
    lR = DBLE(l)
    CALL LaguerreL2(n, l, (RVEC/b)**2, FVEC, FVEC_S, dimr)
     
    ! gamma(n+1) = n!
    IF (n == 0) THEN
      lnfac = 0d0
    ELSE
      lnfac = gammln(nR+1d0)
    END IF

   FVEC = SQRT(2d0/b**3)* EXP(0.5d0* ( lnfac - gammln(nR+lR+1.5d0) ) )* (RVEC/b)**l* FVEC 
   
 END Subroutine RadHO_poly


! Calculates a vector of values of g_nl(r), where g_nl(r) is the radial part of a HO wave function with size parameter b as defined
! on page 49 of Jouni Sohonen, From Nucleons to Nucleus, Springer
  Subroutine RadHO(n, l, b, RVEC, FVEC, dimr)
    IMPLICIT NONE
    INTEGER :: n,l,dimr
    REAL(kind=r_kind) :: nR,lR,b, RVEC(dimr), FVEC(dimr), FVEC_S(dimr), FVECtmp(dimr), lnfac
    nR = REAL(n,kind=r_kind) 
    lR = REAL(l,kind=r_kind)
    CALL LaguerreL2(n, l, (RVEC/b)**2, FVEC, FVEC_S, dimr)
     
    ! gamma(n+1) = n!
    IF (n == 0) THEN
      lnfac = 0.0_r_kind
    ELSE
      lnfac = gammln(nR+1.0_r_kind)
    END IF

   FVEC = SQRT(2.0_r_kind/b**3)* EXP(0.5_r_kind* ( lnfac - gammln(nR+lR+1.5_r_kind) ) )* (RVEC/b)**l* EXP(-RVEC**2/2.0_r_kind/b**2)* FVEC 
   
  END Subroutine RadHO

! Computes overlap certain of radial HO functions < R_n0^(bN) | R_00^(ba) > with a closed expression
! n is nubmer of nodes of radial ho-wave function with l=0 and oscillator length bN, ba is oscillator length of n=0,l=0 wave function
  FUNCTION olrho(n,bN,ba)
    ! Returns the value of < R_n0^(bN) | R_00^(ba) >
    IMPLICIT NONE
    INTEGER :: n
    DOUBLE PRECISION :: nDbl, olrho, bN, ba  
    IF (n<0 .OR. bN<=0d0 .OR. ba<=0d0) THEN
      olrho = 0d0
      RETURN
    END IF

    IF (n==0) THEN
      olrho = ( 2d0*bN*ba/(bN**2+ba**2) )**(3d0/2d0)
      RETURN
    END IF
    
    nDbl = DBLE(n)
    olrho = EXP( 0.5d0*gammln(2*nDbl + 2) - gammln(nDbl + 1) )*2d0**(3d0/2d0 - nDbl)*(bN*ba)**(3d0/2d0)*(bN**2 - ba**2)**nDbl/(bN**2 + ba**2)**(3d0/2d0+nDbl)
    

  END FUNCTION olrho

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  FUNCTION ylm(l,m,theta, phi )
    IMPLICIT NONE
  INTEGER :: l, m
  DOUBLE PRECISION :: theta, phi, lD, mD 
  COMPLEX :: ylm
  DOUBLE PRECISION , PARAMETER ::  pi = 2d0*ACOS(0.0)
  
  IF(ABS(m)>l) THEN
    ylm = 0d0
    RETURN
  END IF
  
  lD = DBLE(l)
  IF(m >= 0) THEN
    mD = DBLE(m)
    ylm = sqrt( (2*l+1d0)/4d0/pi ) * exp( .5d0*( gammln(lD-mD+1d0) - gammln(lD+mD+1d0) ) )*plgndr(l,m,COS(theta))*exp( (0d0,1d0)*m*phi )
    RETURN
  ELSE !Y_l(-m) = (-1)^m Y^*_lm
    mD = DBLE(-1d0*m)
    m = -1*m
    ylm = (-1d0)**m*sqrt( (2*l+1d0)/4d0/pi ) * exp( .5d0*( gammln(lD-mD+1d0) - gammln(lD+mD+1d0) ) )*plgndr(l,m,COS(theta))*exp( (0d0,-1d0)*m*phi )
  END IF  

  END FUNCTION ylm



!FROM NUMERICAL RECIPES IN FORTRAN77 and FORTRAN 90 PressW.H. et al. Cambridge University Publishing 1997
!page 247
! CHANGED REAL TO DOUBLE PRECISION and removed do labels

  FUNCTION plgndr(l,m,x)
    IMPLICIT NONE
  INTEGER l,m
  DOUBLE PRECISION :: plgndr,x
  !Computes the associated Legendre polynomial Plm (x). Here m and l are integers satisfying
  !0 <= m <= l, while x lies in the range -1 <= x <= 1.
  INTEGER i,ll
  DOUBLE PRECISION :: fact,pll,pmm,pmmp1,somx2
  if(m.lt.0.or.m.gt.l.or.abs(x).gt.1.) THEN !pause ?bad arguments in plgndr?
    plgndr = 0d0
    RETURN
  end if
  
  pmm=1.0d0  !Compute P_m^m
  if(m.gt.0) then
      somx2=sqrt((1.0d0-x)*(1.0d0+x))
      fact=1.0d0
      do i=1,m
	pmm=-pmm*fact*somx2
	fact=fact+2.d0
      enddo 
  endif
  if(l.eq.m) then
      plgndr=pmm
  else
    pmmp1=x*(2d0*m+1d0)*pmm !Compute P_m+1^m 
    if(l.eq.m+1) then
      plgndr=pmmp1
    else !Compute P_l^m , l > m + 1.
      do ll=m+2,l
	pll=(x*(2d0*ll-1d0)*pmmp1-(ll+m-1d0)*pmm)/(ll-m)
	pmm=pmmp1
	pmmp1=pll
      enddo 
      plgndr=pll
    endif
  endif
  return
  END FUNCTION plgndr


  SUBROUTINE print_matrix(size,matrix)

    USE types

    IMPLICIT NONE

    INTEGER, intent(in) :: size
    REAL(kind=r_kind) :: matrix(size,size)

    INTEGER :: II, JJ

    DO II = 1,size
       DO JJ = 1,size
          WRITE(*,'(E18.8)',advance = "no") matrix(II,JJ)
       END DO
       WRITE(*,*)
    END DO



  END SUBROUTINE PRINT_MATRIX

    

END MODULE
