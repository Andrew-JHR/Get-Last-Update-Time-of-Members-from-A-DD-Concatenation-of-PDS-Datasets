//ANDREWJA JOB  CLASS=A,MSGCLASS=X,NOTIFY=&SYSUID
//STEP1    EXEC ASMACL,REGION=0M
//SYSIN    DD   *
         PRINT NOGEN
*---------------------------------------------------------------------*
* This program is used to check PDS (lmd or text files) members' last *
* updated date as well as other information                           *
* All PDS's from the same DD concatenation will be processed          *
* Only the directory blocks are read for text PDS members, but LMD    *
* members' are also read to get the last updated date/time            *
* Both text PDSs and LMD PDSs can be mixed up in the DD concatenation *
* The DD name for the concatenation is SYSUT1                         *
* Andrew Jan 06/Sep/2018                                              *
*---------------------------------------------------------------------*
* Add volser information so uncatalogued data sets can be included    *
* Andrew Jan 10/Sep/2018                                              *
*---------------------------------------------------------------------*
*
         PRINT OFF
         LCLA  &REG
.LOOP    ANOP                              GENERATE REGS.
R&REG    EQU   &REG
&REG     SETA  &REG+1
         AIF   (&REG LE 15).LOOP
         PRINT ON
*
WORKLEN  EQU   176*256            work area for JFCBs in concatenation
CONCLEN  EQU   (L'JFCBDSNM+6)*256 work area for up to 256 ds names
*
         DSECT
         IEFJFCBN                gen. JFCB DSECT
*
*--The following are for the directory information-------*
*--------------------------------------------------------*
*
DIR_ENTRY DSECT
DIRNAME  DS    CL8
DIRTTR   DS    CL3
DIRC     DS    CL1
DIRUSR   DS    CL62
         ORG   DIRUSR
DIRVV     DS    CL1        version
DIRMM     DS    CL1        modified
DIRMOD    DS    CL1        mod
DIRCSS    DS    CL1        seconds of the current update
DIRIY2K   DS    CL1        y2k indicator of init.
DIRIYYDDD DS    CL3        packed yyddd for init.
DIRCY2K   DS    CL1        y2k indicator of the update update.
DIRCYYDDD DS    CL3        packed yyddd of the current update
DIRCHHMM  DS    CL2        hours:minutes of the current update
DIRCLINE  DS    CL2        total lines of the current update
DIRILINE  DS    CL2        total lines of the init. version.
DIRUNKWN  DS    CL2        don't know just put x'00'
DIRUSRID  DS    CL10       the user id who did the last update
          ORG
*
*------------------------------------------------*
*
PDSINFDV CSECT
PDSINFDV AMODE 31
         USING *,R15              setup addressibility
         STM   R14,R12,12(R13)    save parent's register
         LR    R2,R13             parent's save area pointer
         B     CMNTTAIL           skip over the remarks
*
CMNTHEAD EQU   *
         PRINT GEN                print out remarks
         DC    CL8'&SYSDATE'      compiling date
         DC    C' '
         DC    CL5'&SYSTIME'      compiling time
         DC    C'ANDREW JAN'      author
         CNOP  2,4                ensure half word boundary
         PRINT NOGEN              disable macro expansion
CMNTTAIL EQU   *

         BALR  R12,0              for easier byte calculation
         BAL   R13,76(,R12)       use R13 as base as well as savearea

         DROP  R15                avoid compiling warning

SAVREG   DS    18F                save area
         USING SAVREG,R13         setup addressibility
         ST    R2,4(,R13)         save our save area adr to parent's
         ST    R13,8(,R2)         save parent's save area to ours
*
C        USING S99RBP,RBPTR2      req blk ptr dsect
D        USING S99RB,REQBLK2      req blk dsect
*
*---MAINSTREAM------------------------------------*
*
        BAL    R6,RDJFCB            read in the JFCB
*
        BAL    R6,OPEN_DIR          open the directory
*
        B      GET_MEMBER_NAME      get member name to temp stor.
*
FINISH  EQU    *
        BAL    R6,CLOSE_DIR         close dir
*
        B      RETURN               RETURN TO SYSTEM
*
*-------------------------------------------------------*
*
RDJFCB    EQU  *
*---------------------------------------------------------------*
         GETMAIN RU,LV=WORKLEN,LOC=(RES,ANY)  get storage for work
         ST    R1,INAREA         base of workarea
         GETMAIN RU,LV=CONCLEN,LOC=(RES,ANY)  get storage for work
         ST    R1,DSAREA         base of workarea

*---------------------------------------------------------------*
         RDJFCB DIR                read in the JFCB
         LTR    R15,R15            invoked OK ?
         BZ     GO_ON              yes, go on
         ABEND  901                no, go ABEND
*---------------------------------------------------------------*

GO_ON    EQU   *
         ICM    R1,X'F',INAREA       test area of ARL
         BZ     FINISH               impossible
         CLI    INRCODE,0            test rdjfcb reason code
         BNE    FINISH
*
         LH     R9,INRTRVD           get # of jfcb's retrieved
         STH    R9,DSCNT             save the number
         L      R2,INAREA            point to ARA
         L      R4,DSAREA            point to dsn save area
         USING  ARA,R2               addressibility
A        USING  INFMJFCB,ARAJFCB     addressibility fot ara JFCB
ARALOOP  EQU    *
         MVC    0(L'JFCBDSNM,R4),A.JFCBDSNM  save the dsname
         MVC    L'JFCBDSNM(6,R4),A.JFCBVOLS  save the 1st volser
         LA     R4,L'JFCBDSNM+6(,R4)  next avail. address
ARANEXT  EQU    *
         AH     R2,ARALEN           point to next ARA entry
         BCT    R9,ARALOOP          loop to decrement JFCB counter
ARAEXIT  EQU    *

         BR     R6
*-------------------------------------------------------*
*
*
*-------------------------------------------------------*
*
OPEN_DIR   EQU  *
         OPEN  (DIR,INPUT,PRINT,OUTPUT)
         BR    R6
*
*-------------------------------------------------------*
*
GET_MEMBER_NAME  EQU  *
*
         L     R12,DSAREA            dsname table
*
ONE_MORE_BLOCK  EQU  *
*
         READ  DECB,SF,DIR,DIRAREA,256   READ A DIR. BLK.
         CHECK DECB                         CHECK
*
         LA    R3,DIRAREA            R3 LOCATE AT DIRAREA
         LH    R5,0(0,R3)            PUT LEN. COUNT TO R5
         AR    R5,R3                 GET THE LAST USED -
         BCTR  R5,0                  - ADDR. FOR BXLE
         LA    R3,2(0,R3)            SKIP THE COUNT
*
NEXT_ITEM  EQU  *
*
        CLC   0(8,R3),BINONES       END OF DIR. ?
        BNE   NEXT_ITEM_01          no, branch
        FEOV  DIR,LEAVE             yes, read the next in the concat.
        LA    R12,L'JFCBDSNM+6(,R12) next dsname in the concat.
        B     ONE_MORE_BLOCK        next dd in the same concatenation
*
NEXT_ITEM_01  EQU  *
        XR    R4,R4                 CLEAR R4 FOR IC
        IC    R4,11(0,R3)           GET USERDATA-
        N     R4,=X'0000001F'       - LENG. IN HALFWORD (5 BITS)
        AR    R4,R4                 TRANS. TO BYTE

        BZ    PDSTXT                zero in length,branch

        CH    R4,=H'30'             text ?
        BE    PDSTXT                yes

        CH    R4,=H'4'              text ?
        BNH   PDSTXT                yes

PDSLMD  EQU   *
        BAL   R7,RDDIRLMD           read user data for lmd
*
        NI    ALOCNOK,X'FF'-L'ALOCNOK
        BAL   R7,ALLOC_MEM          allocate member
        TM    ALOCNOK,L'ALOCNOK     test if alloc ok
        BO    ENDFILE_1             omit this member
        BAL   R7,OPEN_MEM           OPEN FILES
        B     READ_IN_MEM           GO GET MEMBER THEN PRCOESS
ENDFILE EQU   *
        BAL   R7,CLOSE_MEM          CLOSE MEMBER
        B     PRTLINE
ENDFILE_1 EQU   *
        MVC   BFMBR(27),=C'#unknown,        ,        ,'
        B     PRTLINE

PDSTXT  EQU   *
        BAL   R7,RDDIRTXT           read user data for text

PRTLINE EQU   *                     read user data
        PUT   PRINT,BUFFER          print out

        LA    R4,12(0,R4)           PLUS LEN. OF NAME(8)+TTR(3)+C(1)
*                                   R4 : STEP LEN. R5 : END-ADDR.
        BXLE  R3,R4,NEXT_ITEM       LOOP UNTIL REACH END-ADDR.
        B     ONE_MORE_BLOCK        GET ANOTHER DIR BLOCK
*
*--------------------------------------------------------*
*
RDDIRTXT   EQU   *
         USING DIR_ENTRY,R3       addressibility
*  clear
         MVC   BUFFER,BLANK       clear buffer
*  volser
         MVC   BFVOL,L'JFCBDSNM(R12)    the volser
*  pds name
         LA    R2,L'JFCBDSNM      max. length of the dsname
         LA    R11,BFDSN          target
         LR    R14,R12            source
RDDIRTXT_01    EQU   *
         CLI   0(R14),C' '        blank?
         BE    RDDIRTXT_02        yes
         MVC   0(1,R11),0(R14)    print the dsn name
         LA    R11,1(,R11)        next char
         LA    R14,1(,R14)        next char
         BCT   R2,RDDIRTXT_01     loop
RDDIRTXT_02    EQU   *
         MVI   0(R11),C','        delimitor
*  member name
         MVC   BFMBR,DIRNAME      put the member name
         MVI   BFMBR+8,C','       delimitor
         LTR   R4,R4              chk any user data
         BZ    PUT_SKEL           no, branch
         CH    R4,=H'4'           chk any user data
         BNH   PUT_SKEL           no, branch

*  update date
         MVC   W_JULIAN,DIRCYYDDD move the packed yyddd
         MVC   W_CENTURY,DIRCY2K  19xx or 20xx
         CONVTOD CONVVAL=WORK16,TODVAL=W_TOD,DATETYPE=YYDDD
         STCKCONV STCKVAL=W_TOD,CONVVAL=WORK16,DATETYPE=YYYYMMDD
         UNPK  W_9,W_5             unpack to be in char
         MVC   BFUPDATE,W_9        move the update date
*  update time
         MVC   W_4(2),DIRCHHMM  move the packed hhmm
         MVC   W_4+2(1),DIRCSS  move the packed ss
         UNPK  W_7,W_4          unpack the hhmmss
         MVC   BFUPTIME(2),W_7  move the hh
         MVI   BFUPTIME+2,C':'  delimitor
         MVC   BFUPTIME+3(2),W_7+2  move the mm
         MVI   BFUPTIME+5,C':'  delimitor
         MVC   BFUPTIME+6(2),W_7+4  move the mm
*  current lines
         LH    R2,DIRCLINE      current # of lines
         CVD   R2,W_TOD         convert to packed decimal
         UNPK  W_7,W_TOD+4(4)   unpack
         MVC   BFSIZE(2),=C'00' pad the 1st byte
         MVC   BFSIZE+2,W_7+1   copy it
         OI    BFSIZE+7,X'F0'   readable
*  no ttr for text
         MVC   BFTTR,BLANK      clear the field
         MVC   BFTTR,BLANK      clear the field
*  init.  date
         MVC   W_JULIAN,DIRIYYDDD move the packed yyddd
         MVC   W_CENTURY,DIRIY2K  19xx or 20xx
         CONVTOD CONVVAL=WORK16,TODVAL=W_TOD,DATETYPE=YYDDD
         STCKCONV STCKVAL=W_TOD,CONVVAL=WORK16,DATETYPE=YYYYMMDD
         UNPK  W_9,W_5             unpack to be in char
         MVC   BFINDATE,W_9        move the update date
* by whom
         MVC   BFWHO,DIRUSRID     user id
*  init. # of lines
         LH    R2,DIRILINE      init. # of lines
         CVD   R2,W_TOD         convert to packed decimal
         UNPK  W_7,W_TOD+4(4)   unpack
         MVC   BFISZE,W_7+1     readable
         OI    BFISZE+5,X'F0'   readable
*  update vv.mm.mod
         XR    R2,R2            clear for insert
         IC    R2,DIRVV         insert
         CVD   R2,W_TOD         convert to packed decimal
         UNPK  W_7(3),W_TOD+6(2) unpack
         MVC   BFVER(2),W_7+1   move the vv
         OI    BFVER+1,X'F0'    readable
         MVI   BFVER+2,C'.'     delimitor
         IC    R2,DIRMM         insert
         CVD   R2,W_TOD         convert to packed decimal
         UNPK  W_7(3),W_TOD+6(2) unpack
         MVC   BFVER+3(2),W_7+1 move the mm
         OI    BFVER+4,X'F0'    readable
         MVI   BFVER+5,C'.'     delimitor
         IC    R2,DIRMOD        insert
         CVD   R2,W_TOD         convert to packed decimal
         UNPK  W_7(3),W_TOD+6(2) unpack
         MVC   BFVER+6(2),W_7+1 move the mm
         OI    BFVER+7,X'F0'    readable

PUT_SKEL EQU   *
         MVI   BFUPDATE+L'BFUPDATE,C',' delimitor
         MVI   BFUPTIME+8,C','          delimitor
         MVI   BFSIZE+L'BFSIZE,C','     delimitor
         MVI   BFTTR+L'BFTTR,C','       delimitor
         MVI   BFINDATE+L'BFINDATE,C',' delimitor
         MVI   BFWHO+L'BFWHO,C','       delimitor
         MVI   BFISZE+L'BFISZE,C','     delimitor
         MVI   BFVER+L'BFVER,C','       delimitor
         MVI   BFVOL+L'BFVOL,C','       delimitor

*
         BR    R7
*
*-------------------------------------------------------*
*
ALLOC_MEM EQU  *
        MVC    DYNNAM2,0(R12)       dataset name
        MVC    DYNVOL2,L'JFCBDSNM(R12) volser name
        MVC    DYNMBR2,0(R3)        member name
** set up SVC99 request-blk
        XC      REQBLK2,REQBLK2    clear RB
        MVI     D.S99RBLN,REQBLKLN2  set RB len
        MVI     D.S99VERB,S99VRBAL   set as allocation
        LA      R2,TUPTR002        ld adr of bg of text-unit-ptr
        ST      R2,D.S99TXTPP        store that adr into RB
** set up SVC99 request-blk-ptr
        LA      R2,REQBLK2          load addr of RB
        ST      R2,C.S99RBPTR        store RB adr into RB ptr
        OI      C.S99RBPTR,S99RBPND  turn on high order bit
** issue SVC99
        LA     R1,RBPTR2            ld adr of RB ptr for svc99
        DYNALLOC                    svc 99
        LTR    R15,R15              test if alloc ok
        BZR    R7                   allocated ok
        OI     ALOCNOK,L'ALOCNOK    allocated not ok
        BR     R7                   go back
*
*-------------------------------------------------------*
*
OPEN_MEM  EQU  *
         OPEN  (INFILE,INPUT)         OPEN member to read
         BR    R7
*
*-------------------------------------------------------*
*
READ_IN_MEM EQU   *
         MVC   BFMBR,0(R3)        put the member name
         MVI   BFMBR+8,C','       delimitor
         GET   INFILE             get a record
         LR    R8,R1              save the address
         CLC   0(8,R8),=C'IEWPLMH ' different format of lmd ?
         BE    NEW_LMD             yes, new form of lmd (from binder)

         CLC   0(3,R8),=X'80FA01' keyword found?
         BNE   READ_IN_MEM        no,check next

         GET   INFILE             get this rec
         LR    R8,R1              save the address
         MVC   W_JULIAN,15(R8)    move the packed yyddd
         CLI   W_JULIAN,X'70'     determine  19xx or 20xx
         BL    YEAR2K             less than 70, treat as 20xx
         MVI   W_CENTURY,X'00'    19xx
         B     YYYYMMDD
YEAR2K   EQU   *
         MVI   W_CENTURY,X'01'    20xx not 19xx
YYYYMMDD EQU   *
         CONVTOD CONVVAL=WORK16,TODVAL=W_TOD,DATETYPE=YYDDD
         STCKCONV STCKVAL=W_TOD,CONVVAL=WORK16,DATETYPE=YYYYMMDD
         UNPK  W_9,W_5             unpack to be in char

         CLI   1(R8),X'15'        any time stamp ?
         BL    OLDSTYLE           no, branch

NEWSTYLE EQU   *
         UNPK  W_7,18(4,R8)       unpack the time
         MVC   BFDATA(8),C_Y4MMDD save date
         MVI   BFDATA+8,C','      delimiter
         MVC   BFDATA+9(2),W_7+1  hh
         MVI   BFDATA+11,C':'      delimiter
         MVC   BFDATA+12(2),W_7+3  mm
         MVI   BFDATA+14,C':'     delimiter
         MVC   BFDATA+15(2),W_7+5 ss
         MVI   BFDATA+17,C','     delimiter
         B     ENDFILE

OLDSTYLE EQU   *
         MVC   BFDATA(8),C_Y4MMDD save date
OUT_DELIM EQU  *
         MVI   BFDATA+8,C','      delimiter
         MVI   BFDATA+17,C','     delimiter
         B     ENDFILE

NEW_LMD  EQU   *
         LA    R11,4086           max. length
         LA    R10,0(,R8)         look for the keyword
READ_IN_REC    EQU  *
         CLC   0(10,R10),=C'5695PMB01 ' the binder name?
         BE    BIND_DATE          yes
         LA    R10,1(,R10)        increase
         BCT   R11,READ_IN_REC    increase
         GET   INFILE             get next rec
         LR    R8,R1              save the address
         B     NEW_LMD            loop

BIND_DATE  EQU  *
         MVC   W_JULIAN,13(R10)   move the packed yyddd
         MVI   W_CENTURY,X'01'    20xx not 19xx
         CONVTOD CONVVAL=WORK16,TODVAL=W_TOD,DATETYPE=YYDDD
         STCKCONV STCKVAL=W_TOD,CONVVAL=WORK16,DATETYPE=YYYYMMDD
         UNPK  W_9,W_5            unpack to be in char
         UNPK  W_7,16(4,R10)      unpack the time
         MVC   BFDATA(8),C_Y4MMDD save date
         MVI   BFDATA+8,C','      delimiter
         MVC   BFDATA+9(2),W_7+1  hh
         MVI   BFDATA+11,C':'      delimiter
         MVC   BFDATA+12(2),W_7+3  mm
         MVI   BFDATA+14,C':'     delimiter
         MVC   BFDATA+15(2),W_7+5 ss
         MVI   BFDATA+17,C','     delimiter
         B     ENDFILE

*
*--------------------------------------------------------*
CLOSE_MEM  EQU   *
         CLOSE INFILE             close files
         BR    R7
*
*--------------------------------------------------------*
RDDIRLMD EQU   *
         MVC   BUFFER,BLANK       clear buffer
*
         UNPK  W_7,22(4,R3)       get size of lmd 8+3+1+10
         MVC   BFSIZE(2),=C'00'   pad the 1st byte
         MVC   BFSIZE+2,W_7       copy it
         TR    BFSIZE,H2C-C'0'    for a-f display
         MVI   BFSIZE+L'BFSIZE,C','    delimitor
*
         UNPK  W_7,DIRTTR(4)      get TTR
         MVC   BFTTR,W_7          copy it
         TR    BFTTR,H2C-C'0'     for a-f display
         MVI   BFTTR+L'BFTTR,C','    delimitor
*
CHKAC    EQU   *
         CH    R4,=H'24'          basic form ?
         BH    CHKAC1
         CH    R4,=H'22'          even simpler ?
         BH    CHKAC0             no
         MVI   BFAC,C'0'          ac(0)
         B     CHKAMODE
CHKAC0   EQU   *
         TM    34(R3),X'01'       ac code 8+3+1+22
         BO    ACCODE1            yes
         MVI   BFAC,C'0'          ac(0)
         B     CHKAMODE
ACCODE1  EQU   *
         MVI   BFAC,C'1'          ac(1)
         B     CHKAMODE
CHKAC1   EQU   *
         CH    R4,=H'32'          another form?
         BNE   CHKAC2
         MVI   BFAC,C'0'          ac(0)
         B     CHKAMODE
CHKAC2   EQU   *
         LR    R9,R3              copy start addr
         AR    R9,R4              plus user data len
         TM    11(R9),X'01'       ac code 8+3+1+22
         BO    ACCODE1            yes
         MVI   BFAC,C'0'          ac(0)
CHKAMODE EQU   *
         MVI   BFAC+L'BFAC,C':'   delimitor
         TM    31(R3),X'03'       8+3+1+19
         BO    AMODEANY           yes
         TM    31(R3),X'02'       8+3+1+19
         BO    AMODE31            yes
         MVC   BFAMRM(3),=C'A24'  amode=24
         B     CHKRMODE
AMODEANY EQU   *
         MVC   BFAMRM(3),=C'ANY'  amode=any
         B     CHKRMODE
AMODE31  EQU   *
         MVC   BFAMRM(3),=C'A31'  amode=31
CHKRMODE EQU   *
         TM    31(R3),X'10'       8+3+1+19
         BO    RMODEANY           yes,branch
         MVC   BFAMRM+3(3),=C'R24' rmode=24
         B     CHKSSID
RMODEANY EQU   *
         MVC   BFAMRM+3(3),=C'ANY' rmode=any
CHKSSID  EQU   *
         MVI   BFAMRM+L'BFAMRM,C','  delimitor
         CH    R4,=H'38'          alias & ssid ?
         BL    CHKSSID1           no branch
         MVC   W_5(4),44(R3)      ssid
         UNPK  W_9,W_5            unpack
         MVC   BFSSID,W_9         copy the upacked ssid
         TR    BFSSID,H2C-C'0'    for a-f display
         MVC   BFALIAS,36(R3)     alias name
         B     CHKRENT
CHKSSID1 EQU   *
         CH    R4,=H'36'          alias & ssid ?
         BL    CHKALIAS           no branch
         MVC   W_5(4),42(R3)      ssid
         UNPK  W_9,W_5            unpack
         MVC   BFSSID,W_9         copy the upacked ssid
         TR    BFSSID,H2C-C'0'    for a-f display
         B     CHKRENT
CHKALIAS EQU   *
         CH    R4,=H'33'          only alias ?
         BL    CHKALIAS1          no branch
         MVC   BFALIAS,36(R3)     alias name
         B     CHKRENT
CHKALIAS1 EQU   *
         CH    R4,=H'32'          only alias ?
         BL    CHKSSID2           no branch
         MVC   BFALIAS,36(R3)     alias name
         B     CHKRENT
CHKSSID2 EQU   *
         CH    R4,=H'26'          only alias ?
         BL    CHKRENT            no branch
         MVC   W_5(4),34(R3)      ssid
         UNPK  W_9,W_5            unpack
         MVC   BFSSID,W_9         copy the upacked ssid
         TR    BFSSID,H2C-C'0'    for a-f display
         B     CHKRENT
CHKRENT  EQU   *
         MVI   BFALIAS+L'BFALIAS,C','   delimitor
         MVI   BFSSID+L'BFSSID,C','   delimitor
         TM    20(R3),X'80'           8+3+1+8  chk rn
         BNO   CHKRU                  no, may be ru
         MVC   BFRENT+2(2),=C'RN'     set as rn
CHKRU    EQU   *
         TM    20(R3),X'40'           8+3+1+8  chk rn
         BNO   CHKRF                  no, may be ru
         MVC   BFRENT+4(2),=C'RU'     set as ru
CHKRF    EQU   *
         TM    21(R3),X'01'           8+3+1+9  chk rf
         BNO   CHKOK                  no, may be rf
         MVC   BFRENT(2),=C'RF'       set as rf
CHKOK    EQU   *
         MVI   BFRENT+L'BFRENT,C','   delimitor
*
*  volser
         MVC   BFVOL,L'JFCBDSNM(R12)  volser
         MVI   BFVOL+L'BFVOL,C','     delimitor
*
*  pds name
         LA    R9,L'JFCBDSNM      max. length of the dsname
         LA    R11,BFDSN          target
         LR    R14,R12            source
RDDIRLMD_01    EQU   *
         CLI   0(R14),C' '        blank?
         BE    RDDIRLMD_02        yes
         MVC   0(1,R11),0(R14)    print the dsn name
         LA    R11,1(,R11)        next char
         LA    R14,1(,R14)        next char
         BCT   R9,RDDIRLMD_01     loop
RDDIRLMD_02    EQU   *
         MVI   0(R11),C','        delimitor
*
         BR    R7
*
*--------------------------------------------------------*
*
CLOSE_DIR  EQU  *
         CLOSE DIR                close the dir
         CLOSE PRINT              close the output
         BR    R6
*
*--------------------------------------------------------*
*
RETURN   EQU   *
         L     R15,RTNCD                    Load termination code
         L     R13,4(R13)
         RETURN (14,12),RC=(15)   back to caller
*
*--------------------------------------------------------*
*
         LTORG
*
*--------------------------------------------------------*
*
*
*--------------------------------------------------------*
*
DIRAREA  DS    CL256           WORK AREA FOR A 256-BYTE BLOCK OF DIR
*
BINONES  DC    8XL1'FF'        INDICATE THE END OF DIR.
*
BUFFER   DS    CL120
         ORG   BUFFER
BFMBR    DS    CL8
         DS    C
BFDATA   DS    0CL17
BFUPDATE DS    CL8
         DS    C
BFUPTIME DS    CL8
         DS    C
BFALIAS  DS    0CL8
BFWHO    DS    CL8
         DS    C
BFSIZE   DS    CL8
         DS    C
BFTTR    DS    CL6
         DS    C
BFINDATE DS    0CL8
BFAC     DS    CL1
         DS    C
BFAMRM   DS    CL6
         DS    C
BFRENT   DS    0CL6
BFISZE   DS    CL6
         DS    C
BFSSID   DS    0CL8
BFVER    DS    CL8
         DS    C
BFVOL    DS    CL6
         DS    C
BFDSN    DS    CL44
         DS    C
         ORG
BLANK    DS    0CL120
         DC    120C' '
*
W_TOD    DS    D                tod
*
RTNCD     DS   F                 return code
*
DSAREA    DS   A                 a table for all concatenated dsnames
DSCNT     DS   H                 how many ds in the dd concatenation
*
*
WORK16    DS   0F                work to convert time format
          DS    XL8              HHMMSSTHMIJU0000
W_5       DS   0CL5              5-byte field for unpk source
W_Y4MMDD  DS   0CL4              4-byte yyyymmdd after stckconv
W_CENTURY DS    CL1              x'01' means 20xx
W_JULIAN  DS    CL3              packed yyddd
          DS    F                reserved
*
W_9      DS    0CL9             9-byte field for unpk outcome
C_Y4MMDD DS    CL8              8-byte yyyymmdd in character
         DS    CL1              working byte
*
W_4      DS    CL4
W_7      DS    CL7
*
H2C      DC    C'0123456789'      for 0-9 conversion
         DC    C'ABCDEF'          for a-f conversion
*
*--------------------------------------------------------*
*
DIR    DCB DSORG=PS,DDNAME=SYSUT1,MACRF=R,RECFM=U,EODAD=FINISH,        X
               EXLST=JFCBPTR
INFILE DCB DSORG=PS,DDNAME=SYSUT3,MACRF=GL,EODAD=ENDFILE
PRINT  DCB DSORG=PS,DDNAME=PRINT,MACRF=PM,LRECL=120
*
JFCBPTR  DC    0F'0',AL1(EXLLASTE+EXLARL) type 13, allocation inform.
         DC    AL3(INSTRT)
INSTRT   IHAARL DSECT=NO,PREFIX=IN    allocation retrieval list

RBPTR2    DS        F
REQBLK2   DS        CL(S99RBEND-S99RB)
REQBLKLN2 EQU       L'REQBLK2

TUPTR002  DS        0F
          DC        A(TUDDNA2)   adr of tu for ddname
          DC        A(TUDSNA2)   adr of tu for dsname
          DC        A(TUDSSA2)   adr of tu for ds status
          DC        A(TUVOLA2)   adr of tu for ds status
          DC        A(TUMBRA2)   adr of tu for member name
          DC        X'80'        ind. the last tu adr
          DC        AL3(TUCLSA2)   adr of tu to request unalloC        X
                                   when close file
TUDDNA2   DC        AL2(DALDDNAM)  tu key for ddname
          DC        AL2(1)         number of entries
          DC        AL2(8)         length of ddname
          DC        CL8'SYSUT3'    ddname
TUDSNA2 DC AL2(DALDSNAM),AL2(1)     tu key for dsname
NAMELN2 DC AL2(44)                  len of the dsn
DYNNAM2 DS CL44                     dsname
TUDSSA2 DC AL2(DALSTATS),AL2(1),AL2(1),X'08'   shr
**                                     x'01'   old
**                                     x'02'   mod
**                                     x'04'   new
TUVOLA2 DC AL2(DALVLSER),AL2(1)     tu key for volume
VOLLEN2 DC AL2(6)                   volser length
DYNVOL2 DS CL6                      volume serial
TUMBRA2 DC AL2(DALMEMBR),AL2(1)     tu key for pds member
MBRNLN2 DC AL2(8)                      member name length
DYNMBR2 DS CL8                         member name
TUCLSA2 DC AL2(DALCLOSE),AL2(0)

FLAG    DC   X'00'             initiate as low value
        ORG  FLAG              redefine
ALOCNOK DS   0XL(B'10000000')  ind. dyn. alloc failure

        IEFZB4D0 ,       gen. dect for req. blk, text unit et.
        IEFZB4D2 ,       gen. table of quates for tu keys.
*--------------------------------------------------------------*
        IHAARA ,
        IHAEXLST ,
*
        END
/*
//L.SYSLMOD DD  DISP=SHR,DSN=ANDREWJ.SOURCE.LMD(PDSINFDV)
//
//G.PRINT   DD  SYSOUT=*
//G.SYSUT1  DD  DISP=SHR,DSN=CPAC.LINKLIB,
//          UNIT=SYSDA,VOL=SER=ZT2CAT
//          DD  DISP=SHR,DSN=ANDREWJ.SOURCE.ASM
//          DD  DISP=SHR,DSN=ANDREWJ.SOURCE.JCL
//          DD  DISP=SHR,DSN=ANDREWJ.SOURCE.LMD
//          DD  DISP=SHR,DSN=CPAC.SOURCE.JCL,
//          UNIT=SYSDA,VOL=SER=ZT2CAT
//
