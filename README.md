# Listing The Last Updated Date/Time Stamps of All Members of LMD and Text PDS/PDSE Data Sets from A Same DD Concatenation

1. This repository demonstrates how to read all PDS (Partitioned Data Set) or PDSE (Partitioned Data Set Extended) files in the same DD concatenation. The DD name is 'SYSUT1' in the program.

2. All data sets under the same DD name: SYSUT1 can be either Text or Binary (LMD, or Loaded Module) PDS or PDSE. Text and LMD data sets can be mixed together in the concatenating sequence.

3. A sample output: **PDSINFDD Sample Output.txt** is included to show that the latest updated members are listed first, so what files that were most recently updated are revealed.

4. Who or which ID did the changes to each member (normally are source code files) of a Text PDS is also displayed.  

5. The JCL: **PDSINFDD.JCL** showcases how to put several data sets under the same DD name: SYSUT1.

6. In **PDSINFDD.JCL** a second step of invoking SORT is employed to sort the Date/Time in descending order, so the most recently updated members are displayed first.

7. A variant of **PDSINFDD.asm**: **PDSINFDV.asm* is also included. So uncatalogued PDS data sets can also be put under the same DD card: **SYSUT1** with other catalogued PDS's, but ***UNIT=SYSDA,VOL=SER=xxxxxx*** keywords have to be added into the JCL DD statements, where xxxxxx should be replaced with a correct 6-letter Volume Serial Name. 

