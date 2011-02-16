#!/usr/local/bin/tclsh8.5

set ::app_branch	"dev"
set ::app_timestamp	[clock seconds]

foreach tclf {version.tcl config.tcl} {
	if {[file exists $tclf]} {
		set fillfn $tclf
	} else {
		set fullfn "[regsub {[^/]+$} [info script] ""]$tclf"
	}
	if {[catch "source $fullfn" error] && $tclf != "version.tcl"} {
		puts stderr "Unable to locate $tclf"
		puts stderr $error
		exit -1
	}
}
package require Pgtcl
package require Syslog

proc logmsg {buf} {
	syslog -ident appglog -facility daemon notice $buf
}

proc logerr {buf} {
	syslog -ident appglog -facility daemon error $buf
}

proc db_connect {} {
	set ::db [pg_connect -connlist [array get ::dbconfig]]

	return
}

proc do_sql {sql} {
    set sqlstart [clock seconds]

    logmsg "Executed: $sql"

    set res [pg_exec $::db "$sql"]
    if {[pg_result $res -numTuples] > 0} {
        set result [pg_result $res -getTuple 0]
    } else {
        set result 0
    }

    set status [pg_result $res -status]
    set error [pg_result $res -error]
    if {$error != ""} {
        logerr "$error"
        logerr "ERROR SQL: $sql"
        after 5000
    }
    pg_result $res -clear

    set sqldiff [expr {[clock seconds] - $sqlstart}]
    if {$sqldiff > 1} {
        logmsg "SQL slowness: \"$sql\" took $sqldiff seconds"
    }

    return [list $result $status $error]
}

proc main {} {
	set entrance "Starting apache_pg_log ($::app_branch) built [clock format $::app_timestamp -format "%Y-%m-%d @ %H:%M"] on [info hostname]"
	logmsg $entrance
	db_connect

	pg_on_connection_loss $::db {
		logerr "Connection to database lost"
		after 3000
		db_connect
	}

	while {1} {
		logmsg "Loop"
		set buf [gets stdin]
		logmsg "buf $buf"

		set buflist [split $buf "\t"]
		logmsg "buflist $buflist"

		if {[catch {array set bufarray $buflist} err]} {
			logerr "$err"
		} else  {
			set fields [array names bufarray]
			set values [list]

			logmsg "ts1 $bufarray(ts)"
			set bufarray(ts) [clock format $bufarray(ts) -format "%Y-%m-%d %T" -gmt 1]
			logmsg "ts2 $bufarray(ts)"


			foreach f $fields {
				lappend values [pg_quote $bufarray($f)]
			}

			set sql "INSERT INTO access_log ([join $fields ","]) VALUES ([join $values ","]);"
			do_sql $sql
		}
	}
}

if !$tcl_interactive main
