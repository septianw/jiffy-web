<?php

// Copyright 2008 Whitepages.com, Inc. See License.txt for more information.


    // Oracle Configuration
    define( 'DBTYPE', 'oci');
    define( 'DBHOST', 'dbqa1.qa.whitepages.com');
    define( 'DBNAME', 'repdwqa');
    define( 'DBUSER', 'jiffy_reader');
    define( 'DBPASS', 'jre_qa');
    define( 'DBSCHEMA','jiffy.');

    // MySQL configuration
	#define( 'DBTYPE',  'mysql');
    #define( 'DBHOST',  '<!--HOSTNAME-->');
    #define( 'DBNAME',  '<!--DBNAME-->');
    #define( 'DBUSER',  '<!--USERNAME-->');
    #define( 'DBPASS',  '<!--PASSWORD-->');
    #define( 'DBSCHEMA','');

    function get_dbconn() {
        // caller should wrap this in a try block to prevent printing out db conn info to screen
        return new PDO( sprintf("%s:host=%s;dbname=%s",DBTYPE,DBHOST,DBNAME),DBUSER,DBPASS);
    }

?>
