<?php

    // Oracle Configuration
    define( 'DBTYPE',  'oci');
    define( 'DBHOST',  '<!--HOSTNAME-->');
    define( 'DBNAME',  '<!--SID-->');
    define( 'DBUSER',  '<!--USERNAME-->');
    define( 'DBPASS',  '<!--PASSWORD-->');
    define( 'DBSCHEMA','<!--SCHEMANAME-->');

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
