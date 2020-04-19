DUALPORT MODULE FOR SDRAM CONTROLLER
====================================

    These are the design files for the dualport module that attaches to the
    SDRAM controller core and the surrounding application that uses the core
    to test the SDRAM on the XESS FPGA boards.

    You can find application notes about the dualport module at
    http://www.xess.com/ho03000.html.

APPLICATION DIRECTORY TREE
--------------------------

      top ---+
             |
             +--- XS_LIB
             |
             +--- XSA ---+
             |           |
             |           +---XSA_LIB
             |           |
             |           +---50  -----+
             |           |            |
             |           |            +--- test_dualport
             |           |
             |           +---100 -----+
             |           |            |
             |           |            +--- test_dualport
             |           |
             |           +---200 -----+
             |           |            |
             |           |            +--- test_dualport
             |           |
             |           +---3S1000---+
             |                        |
             |                        +--- test_dualport
             |            
             +--- XSB ---+
                         |
                         +---XSB_LIB
                         |
                         +---300E-----+
                                      |
                                      +--- test_dualport
                     
    The content of each subdirectory is listed below.

    * XS_LIB
        This directory stores the VHDL files for all cores that are
        applicable to all models of XESS FPGA boards. This includes the
        dualport module and the SDRAM controller core.

    * XSA
        This directory stores all the project directories for all the models
        of XSA Boards.

    * XSA_LIB
        This directory stores the VHDL files for all cores that have been
        customized for the XSA Boards. This includes the core for testing
        the SDRAM.

    * 50, 100, 200, 3S1000
        Each of these directories stores the project directories for a
        particular model of XSA Board: XSA-50, XSA-100, XSA-200 or
        XSA-3S1000.

    * XSB
        This directory stores all the project directories for all the models
        of XSB Boards.

    * XSB_LIB
        This directory stores the VHDL files for all cores that have been
        customized for the XSB Boards. This includes the core for testing
        the SDRAM.

    * 300E
        Each of these directories stores the project directories for a
        particular model of XSB Board: XSB-300E.

    * test_dualport:
        This directory contains a test_dualport.vhd file that instantiates
        the dualport module and SDRAM test module for a particular model of
        XESS FPGA board. The test_dualport.ucf file stores the appropriate
        pin assignments for the board. The test_dualport.npl file allows you
        to rebuild the application using WebPACK. The resulting
        test_dualport.bit file can be downloaded to the FPGA board to test
        the dualport access to the SDRAM.

AUTHOR
------

    Dave Vanden Bout, X Engineering Software Systems Corp.

    Send bug reports to bugs@xess.com.

COPYRIGHT AND LICENSE
---------------------

    Copyright 2005 by X Engineering Software Systems Corporation.

    These applications can be freely distributed and modified as long as you
    do not remove the attributions to the author or his employer.

HISTORY
-------

    Version 1.0 - 07/12/05

    *   Initial revision.

