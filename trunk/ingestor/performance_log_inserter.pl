#!/usr/local/bin/perl 
##############################################################################
# jiffy-inserter
#
# Grab jiffy log data from jiffy.log and insert into database, tossing
# malformed lines to stdout.
#								
# Copyright 2008 Whitepages.com, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
##############################################################################

##########
# tables #
##########
# measurement_YYYYMMDD
# Name                  TYPE            Null?   
# --------------------- --------------- --------
# UUID                  VARCHAR2(32)    NOT NULL,
# MEASUREMENT_CODE      VARCHAR2(20)    NOT NULL,
# PAGE_NAME             VARCHAR2(255),
# ELAPSED_TIME          NUMBER(7),
# CLIENT_IP             CHAR(15),
# USER_AGENT            VARCHAR2(255),
# BROWSER               VARCHAR2(255),
# OS                    VARCHAR2(255),
# SERVER                VARCHAR2(255),
# SERVER_TIME           TIMESTAMP,
# USER_CAT1             VARCHAR2(255),
# USER_CAT2             VARCHAR2(255),
# ----------------------------------------------------------------------------
#
# MEASUREMENT_TYPES
# Name                  TYPE            Null?   
# --------------------- --------------- --------
# CODE       	        VARCHAR2(20)    Not
# NAME                  VARCHAR2(100)   Not
# DESCRIPTION           VARCHAR2(255)
# ---------------------------------------

###########
# require #
###########
use strict qw(vars);
use vars qw($DBH);
use File::stat;
use Getopt::Std;
use DBI;
use Math::BigInt;
use Math::BigInt lib => 'GMP';
use Data::Dumper;

#############
# constants #
#############
$| = 1;
my $VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
my $SERVER = `/bin/hostname -s`; chomp $SERVER;
my $LOCKFILE = "/var/tmp/jiffy.LCK";
my $TMPFILE  = "/var/tmp/jiffy.tmp"; # high water mark from previous inserter runs
my $BADLOG   = "/var/tmp/jiffy.bad"; # bad entries log
my $LONG_JOB_SECS = (5*60);	# time to silently wait for long running previous instance of cron

my %MONTH_HASH = (
	Jan => '01', Feb => '02', Mar => '03',
	Apr => '04', May => '05', Jun => '06',
	Jul => '07', Aug => '08', Sep => '09',
	Oct => '10', Nov => '11', Dec => '12' 
);
my %OPTS;
my $START_DATE = "";
my $END_DATE = "";

###########
# globals #
###########
my $VERBOSE = 0; # set to 0 for silent running, 1 will output to STDOUT
my $DEBUG = 0;
my $LOG = ""; # source log
my $MAX_LINES = 100_000; # max logfile lines to process

# database 
my $DSN = "DBI:";
my $CLIENT_DIR;
my $HOST;
my $USER;
my $PASS;

########
# main #
########
sub main {
    # get runtime options
    getopts('hVDOMA:m:l:c:H:U:P:W:', \%OPTS);
    
    # command line assignments
    $VERBOSE=1  if ($OPTS{V});
    $DEBUG=1    if ($OPTS{D});
    $LOG        = $OPTS{l};
    $MAX_LINES  = $OPTS{m} if ($OPTS{m});
    $HOST       = $OPTS{H};
    $CLIENT_DIR = $OPTS{c};
    $USER       = $OPTS{U};
    $PASS       = $OPTS{P};
    $LONG_JOB_SECS = $OPTS{W} if $OPTS{W};
    
    # find a reason to bail
    Usage() if ($OPTS{h}); # -h
    Usage() if ($OPTS{O} && $OPTS{M}); # can't have both 
    Usage() if ((!$OPTS{O} && !$OPTS{M}) && !$DEBUG); # can't have neither except in debug mode
    Usage() if ((!$OPTS{H} || !$OPTS{U}) && !$DEBUG); # need host + user except in debug mode
    
    # check access log
    die "Can't read $LOG" if (! -r $LOG);
    die "Can't write $LOG" if (! -w $LOG);
    
    # set up the database
    if ($OPTS{O}) {
        $DSN .= "Oracle:$HOST";
        $ENV{ORACLE_HOME} = $CLIENT_DIR;
        $ENV{LD_LIBRARY_PATH} = "$CLIENT_DIR/lib";
    }
    elsif ($OPTS{M}) {
        die "MySQL not supported yet";
    }
    else {
        die "Unknown database" if (!$DEBUG);
    }
    
    # open DB handle 
    if (!$DEBUG) {
        #$DBH = DBI->connect($DSN, $USER, $PASS, { AutoCommit => 1, RaiseError => 1, }) 
        $DBH = DBI->connect($DSN, $USER, $PASS, { AutoCommit => 0, PrintError => 0, RaiseError => 0, })
               || die "Can't connect: $DBH::err";
    
        # set lockfile
	my $lockfile_age_secs = -M $LOCKFILE * (24*60*60);
        unless (system("/usr/bin/lockfile -r 0 ${LOCKFILE}")) {
	    if ($lockfile_age_secs > $LONG_JOB_SECS) {
		die "Unable to obtain lock after $LONG_JOB_SECS seconds";
	    }
	    else {
		exit(0);
	    }
	}
    }
    
    # execution block
    my $line_count = 0;
    my $insert_count = 0;
    eval {
        my $file_info;
        my $file_stat;
    
        # get stat from current logfile
        $file_stat = stat($LOG);
        die("Cannot stat logfile: $LOG") if (!$file_stat);
    
        # get inode and offset info from previous run
        $file_info = getFileInfo();
    
        # no file info
        if ($file_info->{inode} eq "") {
            print "No logfile info.  Will set logfile offset to beginning.\n" if ($VERBOSE);
            updateFileInfo($file_stat->ino, 0) || die("Failed to update file info");
        }
    
        # new logfile
        if ($file_info->{inode} != $file_stat->ino) {
            print "Recreating logfile info.\n" if ($VERBOSE);
            $file_info->{inode} = $file_stat->ino;
            $file_info->{offset} = 0;
        }
    
        # Check for a truncated log
        $file_info->{offset} = 0 if ( $file_stat->size < $file_info->{offset} );
    
        # open logfile and seek to line last read
        open(LOGFILE, $LOG) or die("Cannot open $LOG");
        seek(LOGFILE, $file_info->{offset}, 0);
    
        # open bad file for entries that dont go into the DB for one reason or another
        open(BADFILE, ">>$BADLOG") or die("Cannot open $BADLOG");
    
        # read lines, gather stats
        my ($entry,$entries);
        while (<LOGFILE>) {
            # process line
            $entries = eval { parseLogEntry($_); };
    
            # warn on error and skip
            if ($@) {
                warn($@) if ($VERBOSE);
                chomp $_;
                printf BADFILE ("%s INVALID\n", $_); 
                next;
            }
    
            for $entry (@$entries) {
                # look at successes, ignore rest
                next unless $entry->{status} eq '200';
        
                # set start date of first valid row, end date is always last row 
                $START_DATE = $entry->{server_time} unless ( $START_DATE );
        
                # DB transactions
                my $insertResult;
                eval { $insertResult = insertRow($entry) };
        
                # warn or die on DB error
                # some errors aren't showstoppers, and we should log these but continue
                if ($insertResult) {
                    chomp $_;
                    printf BADFILE ("%s ORA-%05d\n", $_, $insertResult); 
                    next;
                }
                else {
                    $insert_count++;
                }
                $END_DATE = $entry->{server_time};
            }
        
            # throttle if we've been doing this a while
            $line_count++;
            if ($line_count > $MAX_LINES) {
                warn("$MAX_LINES lines processed, stopping") if ($VERBOSE);
                last;
            }
    
        } # end while
    
        # get current offset and close logfile
        my $new_offset = Math::BigInt->new(tell LOGFILE);
        close(LOGFILE);
        close(BADFILE);
    
        # update offset and time
        updateFileInfo($file_info->{inode}, $new_offset->bstr()) || die("Failed to update file info");
    
        # verboseness
        die ($@) if ($@);
    };
    
    my $exception = $@;
    
    # close DB, remove locks
    if (!$DEBUG) {
	# be sure the DB commit/disconect doesn't prevent us from releasing the lock
        eval { $DBH->commit(); };      $exception .= " >> $@" if $@;
        eval { $DBH->disconnect(); };  $exception .= " >> $@" if $@;
        unlink $LOCKFILE;
    }
    
    # report any error condition
    die($exception) if ($exception); 
    
    # summarize results
    if ($VERBOSE) {
        if ($START_DATE eq "" || $END_DATE eq "") {
            print "No data processed.\n";
        }
        else {
            print "Data processed for $START_DATE ==> $END_DATE\n";
        } 
        print "$line_count lines read, $insert_count inserts executed.\n"
    }
} # end main

# take a log entry string and return array of hash-refs, each hash describing a logged measure
# accomodates old single-entry log format and new bulk log format
# validates all fields, throwing exception on validation failures
sub parseLogEntry {
    my($entry) = @_;
    my %rec = ();

    if ($entry !~ /^(\S+) \[(\S+).*\] "(.*)" (\S+) "(.*)" "(.*)" "(.*)"/) {
        warn("Invalid fields in row: '$entry'") if ($DEBUG);
        return;
    }

    # grab primary log field data
    $rec{client_ip} = $1;
    $rec{server_time} = $2;
    $rec{request} = substr($3,0,1023);
    $rec{status} = $4;
    $rec{url} = substr($5,0,255); # some urls actually longer than 255 char 
    $rec{user_agent} = substr($6,0,255);

    die("Invalid ClientIP: $entry\n") unless validIP( $rec{client_ip} );

    # extract time/date values
    my ($day,$month,$year,$hours,$minutes,$seconds) = $rec{server_time} =~ /^(\d+)\/(\w+)\/(\d+):(\d+):(\d+):(\d+).*/;
    # get time in string YYYYMMDD for event table 
    $rec{table_partition} = sprintf("%d%s%02d", $year, $MONTH_HASH{$month}, $day); 
    # change ret->{time} to portable format
    $rec{server_time} = sprintf("%d-%02d-%02d %02d:%02d:%02d", $year, $MONTH_HASH{$month}, $day, $hours, $minutes, $seconds); 

    # extract query string values
    my $qsh = queryString2Hash($rec{request});
    $rec{uuid} = $qsh->{uid};
    die("Invalid UID: $entry\n") if ($rec{uuid} eq "");
    $rec{page_name} = $qsh->{pn};
    $rec{user_cat1} = $qsh->{sid};

    # collect elapsed times
    my $elapsed_time_str =
        defined($qsh->{jlv}) || defined($qsh->{ets}) ?  # jiffy-log-version or ets field defined
            $qsh->{ets} :
            join(':', @$qsh{ qw(id et) }); # compose pre-versioned logs into new list format
    my %elapsed_times =
        map { m/(\w+):(-?\d+)/ }          # break pairs into name and value
        split( ',', $elapsed_time_str );  # split Name:et pairs

    die("No elapsed times: $entry\n") unless scalar %elapsed_times;

    # force et values into valid ranges
    for my $val (values %elapsed_times) {
        $val = -$val     if $val < 0;
        $val = 9_999_999 if $val > 9_999_999;
    }
    
    # make array of entries for each elapsed time measure
    my @ret = ();
    for my $measurement_code (keys %elapsed_times) {
        my $entry = { %rec }; # copy master record hash into entry
        $entry->{measurement_code} = $measurement_code;
        $entry->{elapsed_time} = $elapsed_times{$measurement_code};
        push @ret, $entry;
    }

    return \@ret;
} # parseLogEntry

# build associative array representing parsed query string name=value pairs
# returns empty hashref if no query-string
sub queryString2Hash {
    my ($str) = @_;
    my ($qs) =
        $str =~ m{
          ^[^?]*    # throw away path info before first ?
          \?        # must have a ? or there's no query string
          (.*)$     # capture everything to end
        }x;
    return {} unless defined $qs;
    
    my %query =			# construct hash
        map  { /([^=]+)=(.*)/ }	# capture (key) = (value)
        grep { /[^=]+=/ }	# discard if not key=value
        split( /\&/, $qs );	# split on amp seperator
  
    return \%query;
}

# return true if string is valid IP address
sub validIP {
    my($ip) = @_;
    return 4 ==   # must have four octets in 0..255
            scalar ( grep { 0 <= $_ && $_ <= 255}
                     $ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/ );
}

# update location & time stats on this logfile
sub updateFileInfo {               
    my($inode, $offset) = @_;
    
    my $file_info = sprintf("%d,%s", $inode, $offset);
    if ($DEBUG) {
        printf "Would write (inode,offset) to $TMPFILE: $file_info\n";
    }
    else {
        # update file
        open(OUT, ">$TMPFILE") || return 0;
        print OUT $file_info;
        close(OUT);
    }

    return 1;
}

# get location stats from the previous run of this log file
sub getFileInfo {
    my $result = {};
    my @contents;
    
    # open temp file
    open(IN, "<$TMPFILE");
            
    # get data
    @contents = split(/,/, <IN>); close(IN);
    $result->{inode} = $contents[0];
    $result->{offset} = Math::BigInt->new($contents[1]);
    
    # close
    close(IN);

    # return
    return $result;
} 

my @JIFFY_FIELDS = qw(
    uuid
    measurement_code
    page_name
    elapsed_time
    client_ip
    user_agent
    browser
    os
    server
    server_time
    user_cat1
    user_cat2
);
my $SQL_FIELDS = join(',', @JIFFY_FIELDS);
my $SQL_VALUES = join(',',
    map {$_ ne 'server_time' ? "?" : "to_date(?,'yyyy-mm-dd hh24:mi:ss')"} @JIFFY_FIELDS );
my $last_table_partition;
my $last_sth;

sub insertRow {
    my ($entry) = @_;
    my $sth;
    my $sqlString;

    $entry->{server} = $SERVER;
    
    if ($entry->{table_partition} eq $last_table_partition) {
        $sth = $last_sth;
    }
    else {
        $sqlString = "INSERT INTO jiffy.measurement_$entry->{table_partition} ($SQL_FIELDS) VALUES ($SQL_VALUES)";
        if ($DEBUG) {
            $last_sth = $sth = $sqlString;
        }
        else {
            $last_sth = $sth = $DBH->prepare( $sqlString );
        }
        $last_table_partition = $entry->{table_partition};
    }

    if ($DEBUG) {
        print "Would execute SQL<<$sth>> on \n", Dumper($entry);
    }
    else {
        my $param_i = 1;
        for my $param (@JIFFY_FIELDS) {
            $sth->bind_param( $param_i++, $entry->{$param} );
        }
        $sth->execute();
    
        # errors?
        if ($sth->err() > 0) {
            print "BAD INSERT: " . $sth->errstr() . "\n" if ($VERBOSE);
            return $sth->err();
        }
    }
    return 0;
}

sub Usage {
    print STDERR <<"EOF";

usage: $0 [-hVD] -l <file> -m <value> -W <value> -O|-M -c <client path> -H <host> -U <user> [-P <passwd>]

 -h		: this message
 -V		: verbose output
 -D		: debug mode (no database interaction)
 -l <file>	: file containing jiffy logs
 -m <value>     : maximum number of lines to process this time (default $MAX_LINES)
 -O|-M		: use Oracle | MySQL
 -c <path>	: path to client (ie ORACLE_HOME)
 -A <file>	: file containing database auth (COMING SOON)
 -H		: database host (or tnsname if -O)
 -U		: database user
 -P		: database password
 -W             : time in seconds to silently allow previous job to run

EOF
    exit;
}

main();
