MODULE sorting

  !===================================================================    
  !                                                                       
  !     SORTRX -- SORT, R-I-T input, indeX output                          
  !                                                                       
  !                                                                       
  !     Input:  N     INTEGER                                             
  !             DATA  REAL-INTEGER-TYPE(big)
  !                                                                       
  !     Output: INDEX INTEGER (DIMENSION N)                               
  !                                                                       
  ! This routine performs an in-memory sort of the first N elements of    
  ! array DATA, returning into array INDEX the indices of elements of     
  ! DATA arranged in ascending order.  Thus,                              
  !                                                                       
  !    DATA(INDEX(1)) will be the smallest number in array DATA;          
  !    DATA(INDEX(N)) will be the largest number in DATA.                 
  !                                                                       
  ! The original data is not physically rearranged.  The original order   
  ! of equal input values is not necessarily preserved.                   
  !                                                                       
  !===================================================================    
  !                                                                       
  ! SORTRX uses a hybrid QuickSort algorithm, based on several            
  ! suggestions in Knuth, Volume 3, Section 5.2.2.  In particular, the    
  ! "pivot key" [my term] for dividing each subsequence is chosen to be   
  ! the median of the first, last, and middle values of the subsequence;  
  ! and the QuickSort is cut off when a subsequence has 9 or fewer        
  ! elements, and a straight insertion sort of the entire array is done   
  ! at the end.  The result is comparable to a pure insertion sort for    
  ! very short arrays, and very fast for very large arrays (of order 12   
  ! micro-sec/element on the 3081K for arrays of 10K elements).  It is    
  ! also not subject to the poor performance of the pure QuickSort on     
  ! partially ordered data.                                               
  !                                                                       
  ! Created:  15 Jul 1986  Len Moss                                       
  !                                                                       
  !===================================================================    

  INTERFACE sortrx
     MODULE PROCEDURE sortrx_real8,sortrx_int8,sortrx_int4,sortrx_int2
  END INTERFACE

CONTAINS

  SUBROUTINE sortrx_real8(N, DATA, INDEX) 
    !===================================================================    
    !                                                                       
    !     SORTRX -- SORT, Real input, indeX output                          
    !                                                                       
    !===================================================================    

    !     QuickSort Cutoff                                                  
    !                                                                       
    !     Quit QuickSort-ing when a subsequence contains M or fewer         
    !     elements and finish off at end with straight insertion sort.      
    !     According to Knuth, V.3, the optimum value of M is around 9.      

    INTEGER, PARAMETER :: M = 9

    INTEGER   N,INDEX(:)
    REAL(8)   DATA(:)

    INTEGER   LSTK(31),RSTK(31),ISTK                                  
    INTEGER   L,R,I,J,P,INDEXP,INDEXT                                 
    REAL(8)   DATAP                                                   

    !===================================================================    
    !                                                                       
    !     Make initial guess for INDEX                                      

    DO 50 I = 1, N 
       INDEX (I) = I 
50  END DO

    !     If array is short, skip QuickSort and go directly to              
    !     the straight insertion sort.                                      

    IF (N <= M) GOTO 900 

    !===================================================================    
    !                                                                       
    !     QuickSort                                                         
    !                                                                       
    !     The "Qn:"s correspond roughly to steps in Algorithm Q,            
    !     Knuth, V.3, PP.116-117, modified to select the median             
    !     of the first, last, and middle elements as the "pivot             
    !     key" (in Knuth's notation, "K").  Also modified to leave          
    !     data in place and produce an INDEX array.  To simplify            
    !     comments, let DATA[I]=DATA(INDEX(I)).                             

    ! Q1: Initialize                                                        
    ISTK = 0 
    L = 1 
    R = N 

200 CONTINUE 

    ! Q2: Sort the subsequence DATA[L]..DATA[R].                            
    !                                                                       
    !     At this point, DATA[l] <= DATA[m] <= DATA[r] for all l < L,       
    !     r > R, and L <= m <= R.  (First time through, there is no         
    !     DATA for l < L or r > R.)                                         

    I = L 
    J = R 

    ! Q2.5: Select pivot key                                                
    !                                                                       
    !     Let the pivot, P, be the midpoint of this subsequence,            
    !     P=(L+R)/2; then rearrange INDEX(L), INDEX(P), and INDEX(R)        
    !     so the corresponding DATA values are in increasing order.         
    !     The pivot key, DATAP, is then DATA[P].                            

    P = (L + R) / 2 
    INDEXP = INDEX(P) 
    DATAP = DATA(INDEXP) 

    IF (DATA(INDEX(L)) > DATAP) THEN 
       INDEX(P) = INDEX(L) 
       INDEX(L) = INDEXP 
       INDEXP = INDEX(P) 
       DATAP = DATA(INDEXP) 
    ENDIF

    IF (DATAP > DATA(INDEX(R))) THEN 
       IF (DATA(INDEX(L)) > DATA(INDEX(R))) THEN 
          INDEX(P) = INDEX(L) 
          INDEX(L) = INDEX(R) 
       ELSE 
          INDEX(P) = INDEX(R) 
       ENDIF
       INDEX(R) = INDEXP 
       INDEXP = INDEX(P) 
       DATAP = DATA(INDEXP) 
    ENDIF

    !     Now we swap values between the right and left sides and/or        
    !     move DATAP until all smaller values are on the left and all       
    !     larger values are on the right.  Neither the left or right        
    !     side will be internally ordered yet; however, DATAP will be       
    !     in its final position.                                            

300 CONTINUE 

    ! Q3: Search for datum on left >= DATAP                                 
    !                                                                       
    !     At this point, DATA[L] <= DATAP.  We can therefore start scanning 
    !     up from L, looking for a value >= DATAP (this scan is guaranteed  
    !     to terminate since we initially placed DATAP near the middle of   
    !     the subsequence).                                                 

    I = I + 1 
    IF (DATA(INDEX(I)) < DATAP) GOTO 300 

400 CONTINUE 

    ! Q4: Search for datum on right <= DATAP                                
    !                                                                       
    !     At this point, DATA[R] >= DATAP.  We can therefore start scanning 
    !     down from R, looking for a value <= DATAP (this scan is guaranteed
    !     to terminate since we initially placed DATAP near the middle of   
    !     the subsequence).                                                 

    J = J - 1 
    IF (DATA (INDEX (J) ) > DATAP) GOTO 400 

    ! Q5: Have the two scans collided?                                      

    IF (I<J) THEN 

       ! Q6: No, interchange DATA[I] <--> DATA[J] and continue                 

       INDEXT = INDEX (I) 
       INDEX (I) = INDEX (J) 
       INDEX (J) = INDEXT 
       GOTO 300 
    ELSE 

       ! Q7: Yes, select next subsequence to sort                              
       !                                                                       
       !     At this point, I >= J and DATA[l] <= DATA[I] == DATAP <= DATA[r], 
       !     for all L <= l < I and J < r <= R.  If both subsequences are      
       !     more than M elements long, push the longer one on the stack and   
       !     go back to QuickSort the shorter; if only one is more than M      
       !     elements long, go back and QuickSort it; otherwise, pop a         
       !     subsequence off the stack and QuickSort it.                       

       IF (R - J.GE.I - L.AND.I - L>M) THEN 
          ISTK = ISTK + 1 
          LSTK (ISTK) = J + 1 
          RSTK (ISTK) = R 
          R = I - 1 
       ELSEIF (I - L>R - J.AND.R - J>M) THEN 
          ISTK = ISTK + 1 
          LSTK (ISTK) = L 
          RSTK (ISTK) = I - 1 
          L = J + 1 
       ELSEIF (R - J>M) THEN 
          L = J + 1 
       ELSEIF (I - L>M) THEN 
          R = I - 1 
       ELSE 
          ! Q8: Pop the stack, or terminate QuickSort if empty                    
          IF (ISTK<1) GOTO 900 
          L = LSTK (ISTK) 
          R = RSTK (ISTK) 
          ISTK = ISTK - 1 
       ENDIF
       GOTO 200 
    ENDIF

900 CONTINUE 

    !===================================================================    
    !                                                                       
    ! Q9: Straight Insertion sort                                           

    DO 950 I = 2, N 
       IF (DATA (INDEX (I - 1) ) >DATA (INDEX (I) ) ) THEN 
          INDEXP = INDEX (I) 
          DATAP = DATA (INDEXP) 
          P = I - 1 
920       CONTINUE 
          INDEX (P + 1) = INDEX (P) 
          P = P - 1 
          IF (P>0) THEN 
             IF (DATA (INDEX (P) ) >DATAP) GOTO 920 
          ENDIF
          INDEX (P + 1) = INDEXP 
       ENDIF
950 END DO

    !===================================================================    
    !                                                                       
    !     All done                                                          

  END SUBROUTINE sortrx_real8

  SUBROUTINE sortrx_int8(N, DATA, INDEX) 
    !===================================================================    
    !                                                                       
    !     SORTRX -- SORT, Real input, indeX output                          
    !                                                                       
    !===================================================================    

    !     QuickSort Cutoff                                                  
    !                                                                       
    !     Quit QuickSort-ing when a subsequence contains M or fewer         
    !     elements and finish off at end with straight insertion sort.      
    !     According to Knuth, V.3, the optimum value of M is around 9.      

    INTEGER, PARAMETER :: M = 9

    INTEGER   N,INDEX(:)
    INTEGER(8)   DATA(:)

    INTEGER   LSTK(31),RSTK(31),ISTK                                  
    INTEGER   L,R,I,J,P,INDEXP,INDEXT                                 
    INTEGER(8)   DATAP                                                   

    !===================================================================    
    !                                                                       
    !     Make initial guess for INDEX                                      

    DO 50 I = 1, N 
       INDEX (I) = I 
50  END DO

    !     If array is short, skip QuickSort and go directly to              
    !     the straight insertion sort.                                      

    IF (N <= M) GOTO 900 

    !===================================================================    
    !                                                                       
    !     QuickSort                                                         
    !                                                                       
    !     The "Qn:"s correspond roughly to steps in Algorithm Q,            
    !     Knuth, V.3, PP.116-117, modified to select the median             
    !     of the first, last, and middle elements as the "pivot             
    !     key" (in Knuth's notation, "K").  Also modified to leave          
    !     data in place and produce an INDEX array.  To simplify            
    !     comments, let DATA[I]=DATA(INDEX(I)).                             

    ! Q1: Initialize                                                        
    ISTK = 0 
    L = 1 
    R = N 

200 CONTINUE 

    ! Q2: Sort the subsequence DATA[L]..DATA[R].                            
    !                                                                       
    !     At this point, DATA[l] <= DATA[m] <= DATA[r] for all l < L,       
    !     r > R, and L <= m <= R.  (First time through, there is no         
    !     DATA for l < L or r > R.)                                         

    I = L 
    J = R 

    ! Q2.5: Select pivot key                                                
    !                                                                       
    !     Let the pivot, P, be the midpoint of this subsequence,            
    !     P=(L+R)/2; then rearrange INDEX(L), INDEX(P), and INDEX(R)        
    !     so the corresponding DATA values are in increasing order.         
    !     The pivot key, DATAP, is then DATA[P].                            

    P = (L + R) / 2 
    INDEXP = INDEX(P) 
    DATAP = DATA(INDEXP) 

    IF (DATA(INDEX(L)) > DATAP) THEN 
       INDEX(P) = INDEX(L) 
       INDEX(L) = INDEXP 
       INDEXP = INDEX(P) 
       DATAP = DATA(INDEXP) 
    ENDIF

    IF (DATAP > DATA(INDEX(R))) THEN 
       IF (DATA(INDEX(L)) > DATA(INDEX(R))) THEN 
          INDEX(P) = INDEX(L) 
          INDEX(L) = INDEX(R) 
       ELSE 
          INDEX(P) = INDEX(R) 
       ENDIF
       INDEX(R) = INDEXP 
       INDEXP = INDEX(P) 
       DATAP = DATA(INDEXP) 
    ENDIF

    !     Now we swap values between the right and left sides and/or        
    !     move DATAP until all smaller values are on the left and all       
    !     larger values are on the right.  Neither the left or right        
    !     side will be internally ordered yet; however, DATAP will be       
    !     in its final position.                                            

300 CONTINUE 

    ! Q3: Search for datum on left >= DATAP                                 
    !                                                                       
    !     At this point, DATA[L] <= DATAP.  We can therefore start scanning 
    !     up from L, looking for a value >= DATAP (this scan is guaranteed  
    !     to terminate since we initially placed DATAP near the middle of   
    !     the subsequence).                                                 

    I = I + 1 
    IF (DATA(INDEX(I)) < DATAP) GOTO 300 

400 CONTINUE 

    ! Q4: Search for datum on right <= DATAP                                
    !                                                                       
    !     At this point, DATA[R] >= DATAP.  We can therefore start scanning 
    !     down from R, looking for a value <= DATAP (this scan is guaranteed
    !     to terminate since we initially placed DATAP near the middle of   
    !     the subsequence).                                                 

    J = J - 1 
    IF (DATA (INDEX (J) ) > DATAP) GOTO 400 

    ! Q5: Have the two scans collided?                                      

    IF (I<J) THEN 

       ! Q6: No, interchange DATA[I] <--> DATA[J] and continue                 

       INDEXT = INDEX (I) 
       INDEX (I) = INDEX (J) 
       INDEX (J) = INDEXT 
       GOTO 300 
    ELSE 

       ! Q7: Yes, select next subsequence to sort                              
       !                                                                       
       !     At this point, I >= J and DATA[l] <= DATA[I] == DATAP <= DATA[r], 
       !     for all L <= l < I and J < r <= R.  If both subsequences are      
       !     more than M elements long, push the longer one on the stack and   
       !     go back to QuickSort the shorter; if only one is more than M      
       !     elements long, go back and QuickSort it; otherwise, pop a         
       !     subsequence off the stack and QuickSort it.                       

       IF (R - J.GE.I - L.AND.I - L>M) THEN 
          ISTK = ISTK + 1 
          LSTK (ISTK) = J + 1 
          RSTK (ISTK) = R 
          R = I - 1 
       ELSEIF (I - L>R - J.AND.R - J>M) THEN 
          ISTK = ISTK + 1 
          LSTK (ISTK) = L 
          RSTK (ISTK) = I - 1 
          L = J + 1 
       ELSEIF (R - J>M) THEN 
          L = J + 1 
       ELSEIF (I - L>M) THEN 
          R = I - 1 
       ELSE 
          ! Q8: Pop the stack, or terminate QuickSort if empty                    
          IF (ISTK<1) GOTO 900 
          L = LSTK (ISTK) 
          R = RSTK (ISTK) 
          ISTK = ISTK - 1 
       ENDIF
       GOTO 200 
    ENDIF

900 CONTINUE 

    !===================================================================    
    !                                                                       
    ! Q9: Straight Insertion sort                                           

    DO 950 I = 2, N 
       IF (DATA (INDEX (I - 1) ) >DATA (INDEX (I) ) ) THEN 
          INDEXP = INDEX (I) 
          DATAP = DATA (INDEXP) 
          P = I - 1 
920       CONTINUE 
          INDEX (P + 1) = INDEX (P) 
          P = P - 1 
          IF (P>0) THEN 
             IF (DATA (INDEX (P) ) >DATAP) GOTO 920 
          ENDIF
          INDEX (P + 1) = INDEXP 
       ENDIF
950 END DO

    !===================================================================    
    !                                                                       
    !     All done                                                          

  END SUBROUTINE sortrx_int8

  SUBROUTINE sortrx_int4(N, DATA, INDEX) 
    !===================================================================    
    !                                                                       
    !     SORTRX -- SORT, Integer input, indeX output                          
    !                                                                       
    !===================================================================    

    !     QuickSort Cutoff                                                  
    !                                                                       
    !     Quit QuickSort-ing when a subsequence contains M or fewer         
    !     elements and finish off at end with straight insertion sort.      
    !     According to Knuth, V.3, the optimum value of M is around 9.      

    INTEGER, PARAMETER :: M = 9

    INTEGER    N,INDEX(:)
    INTEGER(4) DATA(:)

    INTEGER    LSTK(31),RSTK(31),ISTK                                  
    INTEGER    L,R,I,J,P,INDEXP,INDEXT                                 
    INTEGER(4) DATAP                                                   

    !===================================================================    
    !                                                                       
    !     Make initial guess for INDEX                                      

    DO 50 I = 1, N 
       INDEX (I) = I 
50  END DO

    !     If array is short, skip QuickSort and go directly to              
    !     the straight insertion sort.                                      

    IF (N<=M) GOTO 900 

    !===================================================================    
    !                                                                       
    !     QuickSort                                                         
    !                                                                       
    !     The "Qn:"s correspond roughly to steps in Algorithm Q,            
    !     Knuth, V.3, PP.116-117, modified to select the median             
    !     of the first, last, and middle elements as the "pivot             
    !     key" (in Knuth's notation, "K").  Also modified to leave          
    !     data in place and produce an INDEX array.  To simplify            
    !     comments, let DATA[I]=DATA(INDEX(I)).                             

    ! Q1: Initialize                                                        
    ISTK = 0 
    L = 1 
    R = N 

200 CONTINUE 

    ! Q2: Sort the subsequence DATA[L]..DATA[R].                            
    !                                                                       
    !     At this point, DATA[l] <= DATA[m] <= DATA[r] for all l < L,       
    !     r > R, and L <= m <= R.  (First time through, there is no         
    !     DATA for l < L or r > R.)                                         

    I = L 
    J = R 

    ! Q2.5: Select pivot key                                                
    !                                                                       
    !     Let the pivot, P, be the midpoint of this subsequence,            
    !     P=(L+R)/2; then rearrange INDEX(L), INDEX(P), and INDEX(R)        
    !     so the corresponding DATA values are in increasing order.         
    !     The pivot key, DATAP, is then DATA[P].                            

    P = (L + R) / 2 
    INDEXP = INDEX (P) 
    DATAP = DATA (INDEXP) 

    IF (DATA (INDEX (L) ) >DATAP) THEN 
       INDEX (P) = INDEX (L) 
       INDEX (L) = INDEXP 
       INDEXP = INDEX (P) 
       DATAP = DATA (INDEXP) 
    ENDIF

    IF (DATAP>DATA (INDEX (R) ) ) THEN 
       IF (DATA (INDEX (L) ) >DATA (INDEX (R) ) ) THEN 
          INDEX (P) = INDEX (L) 
          INDEX (L) = INDEX (R) 
       ELSE 
          INDEX (P) = INDEX (R) 
       ENDIF
       INDEX (R) = INDEXP 
       INDEXP = INDEX (P) 
       DATAP = DATA (INDEXP) 
    ENDIF

    !     Now we swap values between the right and left sides and/or        
    !     move DATAP until all smaller values are on the left and all       
    !     larger values are on the right.  Neither the left or right        
    !     side will be internally ordered yet; however, DATAP will be       
    !     in its final position.                                            

300 CONTINUE 

    ! Q3: Search for datum on left >= DATAP                                 
    !                                                                       
    !     At this point, DATA[L] <= DATAP.  We can therefore start scanning 
    !     up from L, looking for a value >= DATAP (this scan is guaranteed  
    !     to terminate since we initially placed DATAP near the middle of   
    !     the subsequence).                                                 

    I = I + 1 
    IF (DATA (INDEX (I) ) <DATAP) GOTO 300 

400 CONTINUE 

    ! Q4: Search for datum on right <= DATAP                                
    !                                                                       
    !     At this point, DATA[R] >= DATAP.  We can therefore start scanning 
    !     down from R, looking for a value <= DATAP (this scan is guaranteed
    !     to terminate since we initially placed DATAP near the middle of   
    !     the subsequence).                                                 

    J = J - 1 
    IF (DATA (INDEX (J) ) >DATAP) GOTO 400 

    ! Q5: Have the two scans collided?                                      

    IF (I<J) THEN 

       ! Q6: No, interchange DATA[I] <--> DATA[J] and continue                 

       INDEXT = INDEX (I) 
       INDEX (I) = INDEX (J) 
       INDEX (J) = INDEXT 
       GOTO 300 
    ELSE 

       ! Q7: Yes, select next subsequence to sort                              
       !                                                                       
       !     At this point, I >= J and DATA[l] <= DATA[I] == DATAP <= DATA[r], 
       !     for all L <= l < I and J < r <= R.  If both subsequences are      
       !     more than M elements long, push the longer one on the stack and   
       !     go back to QuickSort the shorter; if only one is more than M      
       !     elements long, go back and QuickSort it; otherwise, pop a         
       !     subsequence off the stack and QuickSort it.                       

       IF (R - J.GE.I - L.AND.I - L>M) THEN 
          ISTK = ISTK + 1 
          LSTK (ISTK) = J + 1 
          RSTK (ISTK) = R 
          R = I - 1 
       ELSEIF (I - L>R - J.AND.R - J>M) THEN 
          ISTK = ISTK + 1 
          LSTK (ISTK) = L 
          RSTK (ISTK) = I - 1 
          L = J + 1 
       ELSEIF (R - J>M) THEN 
          L = J + 1 
       ELSEIF (I - L>M) THEN 
          R = I - 1 
       ELSE 
          ! Q8: Pop the stack, or terminate QuickSort if empty                    
          IF (ISTK<1) GOTO 900 
          L = LSTK (ISTK) 
          R = RSTK (ISTK) 
          ISTK = ISTK - 1 
       ENDIF
       GOTO 200 
    ENDIF

900 CONTINUE 

    !===================================================================    
    !                                                                       
    ! Q9: Straight Insertion sort                                           

    DO 950 I = 2, N 
       IF (DATA (INDEX (I - 1) ) >DATA (INDEX (I) ) ) THEN 
          INDEXP = INDEX (I) 
          DATAP = DATA (INDEXP) 
          P = I - 1 
920       CONTINUE 
          INDEX (P + 1) = INDEX (P) 
          P = P - 1 
          IF (P>0) THEN 
             IF (DATA (INDEX (P) ) >DATAP) GOTO 920 
          ENDIF
          INDEX (P + 1) = INDEXP 
       ENDIF
950 END DO

    !===================================================================    
    !                                                                       
    !     All done                                                          

  END SUBROUTINE sortrx_int4

  SUBROUTINE sortrx_int2(N, DATA, INDEX) 
    !===================================================================    
    !                                                                       
    !     SORTRX -- SORT, Integer (16 bit) input, indeX output
    !                                                                       
    !===================================================================    

    !     QuickSort Cutoff                                                  
    !                                                                       
    !     Quit QuickSort-ing when a subsequence contains M or fewer         
    !     elements and finish off at end with straight insertion sort.      
    !     According to Knuth, V.3, the optimum value of M is around 9.      

    INTEGER, PARAMETER :: M = 9

    INTEGER    N,INDEX(:)
    INTEGER(2) DATA(:)

    INTEGER    LSTK(31),RSTK(31),ISTK                                  
    INTEGER    L,R,I,J,P,INDEXP,INDEXT                                 
    INTEGER(2) DATAP                                                   

    !===================================================================    
    !                                                                       
    !     Make initial guess for INDEX                                      

    DO 50 I = 1, N 
       INDEX (I) = I 
50  END DO

    !     If array is short, skip QuickSort and go directly to              
    !     the straight insertion sort.                                      

    IF (N<=M) GOTO 900 

    !===================================================================    
    !                                                                       
    !     QuickSort                                                         
    !                                                                       
    !     The "Qn:"s correspond roughly to steps in Algorithm Q,            
    !     Knuth, V.3, PP.116-117, modified to select the median             
    !     of the first, last, and middle elements as the "pivot             
    !     key" (in Knuth's notation, "K").  Also modified to leave          
    !     data in place and produce an INDEX array.  To simplify            
    !     comments, let DATA[I]=DATA(INDEX(I)).                             

    ! Q1: Initialize                                                        
    ISTK = 0 
    L = 1 
    R = N 

200 CONTINUE 

    ! Q2: Sort the subsequence DATA[L]..DATA[R].                            
    !                                                                       
    !     At this point, DATA[l] <= DATA[m] <= DATA[r] for all l < L,       
    !     r > R, and L <= m <= R.  (First time through, there is no         
    !     DATA for l < L or r > R.)                                         

    I = L 
    J = R 

    ! Q2.5: Select pivot key                                                
    !                                                                       
    !     Let the pivot, P, be the midpoint of this subsequence,            
    !     P=(L+R)/2; then rearrange INDEX(L), INDEX(P), and INDEX(R)        
    !     so the corresponding DATA values are in increasing order.         
    !     The pivot key, DATAP, is then DATA[P].                            

    P = (L + R) / 2 
    INDEXP = INDEX (P) 
    DATAP = DATA (INDEXP) 

    IF (DATA (INDEX (L) ) >DATAP) THEN 
       INDEX (P) = INDEX (L) 
       INDEX (L) = INDEXP 
       INDEXP = INDEX (P) 
       DATAP = DATA (INDEXP) 
    ENDIF

    IF (DATAP>DATA (INDEX (R) ) ) THEN 
       IF (DATA (INDEX (L) ) >DATA (INDEX (R) ) ) THEN 
          INDEX (P) = INDEX (L) 
          INDEX (L) = INDEX (R) 
       ELSE 
          INDEX (P) = INDEX (R) 
       ENDIF
       INDEX (R) = INDEXP 
       INDEXP = INDEX (P) 
       DATAP = DATA (INDEXP) 
    ENDIF

    !     Now we swap values between the right and left sides and/or        
    !     move DATAP until all smaller values are on the left and all       
    !     larger values are on the right.  Neither the left or right        
    !     side will be internally ordered yet; however, DATAP will be       
    !     in its final position.                                            

300 CONTINUE 

    ! Q3: Search for datum on left >= DATAP                                 
    !                                                                       
    !     At this point, DATA[L] <= DATAP.  We can therefore start scanning 
    !     up from L, looking for a value >= DATAP (this scan is guaranteed  
    !     to terminate since we initially placed DATAP near the middle of   
    !     the subsequence).                                                 

    I = I + 1 
    IF (DATA (INDEX (I) ) <DATAP) GOTO 300 

400 CONTINUE 

    ! Q4: Search for datum on right <= DATAP                                
    !                                                                       
    !     At this point, DATA[R] >= DATAP.  We can therefore start scanning 
    !     down from R, looking for a value <= DATAP (this scan is guaranteed
    !     to terminate since we initially placed DATAP near the middle of   
    !     the subsequence).                                                 

    J = J - 1 
    IF (DATA (INDEX (J) ) >DATAP) GOTO 400 

    ! Q5: Have the two scans collided?                                      

    IF (I<J) THEN 

       ! Q6: No, interchange DATA[I] <--> DATA[J] and continue                 

       INDEXT = INDEX (I) 
       INDEX (I) = INDEX (J) 
       INDEX (J) = INDEXT 
       GOTO 300 
    ELSE 

       ! Q7: Yes, select next subsequence to sort                              
       !                                                                       
       !     At this point, I >= J and DATA[l] <= DATA[I] == DATAP <= DATA[r], 
       !     for all L <= l < I and J < r <= R.  If both subsequences are      
       !     more than M elements long, push the longer one on the stack and   
       !     go back to QuickSort the shorter; if only one is more than M      
       !     elements long, go back and QuickSort it; otherwise, pop a         
       !     subsequence off the stack and QuickSort it.                       

       IF (R - J.GE.I - L.AND.I - L>M) THEN 
          ISTK = ISTK + 1 
          LSTK (ISTK) = J + 1 
          RSTK (ISTK) = R 
          R = I - 1 
       ELSEIF (I - L>R - J.AND.R - J>M) THEN 
          ISTK = ISTK + 1 
          LSTK (ISTK) = L 
          RSTK (ISTK) = I - 1 
          L = J + 1 
       ELSEIF (R - J>M) THEN 
          L = J + 1 
       ELSEIF (I - L>M) THEN 
          R = I - 1 
       ELSE 
          ! Q8: Pop the stack, or terminate QuickSort if empty                    
          IF (ISTK<1) GOTO 900 
          L = LSTK (ISTK) 
          R = RSTK (ISTK) 
          ISTK = ISTK - 1 
       ENDIF
       GOTO 200 
    ENDIF

900 CONTINUE 

    !===================================================================    
    !                                                                       
    ! Q9: Straight Insertion sort                                           

    DO 950 I = 2, N 
       IF (DATA (INDEX (I - 1) ) >DATA (INDEX (I) ) ) THEN 
          INDEXP = INDEX (I) 
          DATAP = DATA (INDEXP) 
          P = I - 1 
920       CONTINUE 
          INDEX (P + 1) = INDEX (P) 
          P = P - 1 
          IF (P>0) THEN 
             IF (DATA (INDEX (P) ) >DATAP) GOTO 920 
          ENDIF
          INDEX (P + 1) = INDEXP 
       ENDIF
950 END DO

    !===================================================================    
    !                                                                       
    !     All done                                                          

  END SUBROUTINE sortrx_int2

END MODULE sorting


