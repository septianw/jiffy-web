// Copyright 2008 Whitepages.com, Inc. See License.txt for more information.

<?php

// Requires PHP5 >= 5.2.0 or PECL json: >= 1.2.0

require_once 'dbconn.inc.php';

// Default parameters
$q_params = array(
	// Defaults to yesterday between 00:00:00 and 23:59:59
	startdate => date('Y-m-d H:i:s',mktime(0,0,0,date('m'),date('d')-1,date('Y'))),
	enddate   => date('Y-m-d H:i:s',mktime(23,59,59,date('m'),date('d')-1,date('Y'))),
	rtype     => 'all',
	rinterval => '1h'
);

if ( isset($_REQUEST['v']) ) {
	if ( $_REQUEST['v'] == 'types' ) {
		// Connction is wrapped in a try block to intercept any database errors which would print out the
		// password to the web user
		try {
			$dbh = get_dbconn();
			// Schema is used because the current usage of this example uses Oracle, and the particular
			// test case has a read-only user logging in to the database and no synonyms defined
			$sth = $dbh->prepare('SELECT * FROM '.DBSCHEMA.'MEASUREMENT_TYPES');
			$sth->execute();
			$rows = array();
			while ($row = $sth->fetch(PDO::FETCH_ASSOC)) {
				$rows[$row['CODE']] = $row;
			}
			return_data($rows);
		}
		catch ( PDOException $e) {
			bad_call( "Error!: " . $e->getMessage() );
		}
	} else
	if ( $_REQUEST['v'] == 'measures' ) {
		// If no variables are applied to the POST, then use defaults
		if ( isset($_REQUEST['start']) )    { $q_params['startdate'] = $_REQUEST['start']." 00:00:00"; }
		if ( isset($_REQUEST['end']) )      { $q_params['enddate']   = $_REQUEST['end']." 23:59:59";   }
		if ( isset($_REQUEST['type']) )     { $q_params['rtype']     = $_REQUEST['type'];              }
		if ( isset($_REQUEST['interval']) ) { $q_params['rinterval'] = $_REQUEST['interval'];          }

		$rows = array();

		// Connction is wrapped in a try block to intercept any database errors which would print out the
		// password to the web user
		try {
			$dbh = get_dbconn();
			// Schema is used because the current usage of this example uses Oracle, and the particular
			// test case has a read-only user logging in to the database and no synonyms defined.
			//
			// This has not yet been tested with any database other than Oracle. In the near future this will
			// be exampled using other databases as well.
			$sql = "
				SELECT
					TRUNC(server_time,'HH24') stime
					, measurement_code
					, SUM(elapsed_time) / COUNT(elapsed_time) et_mean
				FROM ".DBSCHEMA."MEASUREMENT_VIEW
				WHERE server_time BETWEEN
					TO_DATE(?,'YYYY-MM-DD HH24:MI:SS') AND
					TO_DATE(?,'YYYY-MM-DD HH24:MI:SS')
				GROUP BY
					  TRUNC(server_time,'HH24')
					, measurement_code
			";
			$sth = $dbh->prepare($sql);

			$sth->bindParam(1,$q_params['startdate']);
			$sth->bindParam(2,$q_params['enddate']);
			$sth->execute();
			// This is a complicated way of building an array of rows each with the stime, formatted time and
			// mean event timing for current events loaded in the database.
			while ($row = $sth->fetch(PDO::FETCH_ASSOC)) {
				$row['FTIME'] = strftime('%Y-%m-%d %H:%M',strtotime($row['STIME']));
				$row['STIME'] = strftime('%m-%d %H',strtotime($row['STIME'])).'h';
				if (!isset($rows[$row['STIME']])) { $rows[$row['STIME']] = array(); }
				$rows[$row['STIME']][$row['MEASUREMENT_CODE']] = $row['ET_MEAN'];
				if ( !isset($rows[$row['STIME']]['stime']) ) {
					$rows[$row['STIME']]['stime'] = $row['STIME'];
				}
				if ( !isset($rows[$row['STIME']]['ftime']) ) {
					$rows[$row['STIME']]['ftime'] = $row['FTIME'];
				}
			}
		}
		catch ( PDOException $e) {
			bad_call( "Error!: " . $e->getMessage() );
		}

		$retval = array(
			params => $q_params,
			rows   => array_values($rows)
		);
		return_data($retval);
	} else {
		bad_call("Invalid resource type specified");
	}
} else {
	bad_call("No resource type specified");
}

exit();

function bad_call($msg) {
	print $msg . "<br \>";
}

function return_data($data) {
	print json_encode($data);
}

?>
