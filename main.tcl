#!/usr/local/bin/tclsh8.5

set ::app_branch	"dev"
set ::app_timestamp	[clock seconds]

set ::debug 0

foreach tclf {version.tcl config.tcl} {
	unset -nocomplain fullfn
	if {[file exists $tclf]} {
		set fullfn $tclf
	} else {
		set fullfn "[regsub {[^/]+$} [info script] ""]$tclf"
	}
	if {[info exists fullfn] && [catch "source $fullfn" error] && $tclf != "version.tcl"} {
		puts stderr "Unable to locate $tclf"
		puts stderr $error
		exit -1
	}
}

package require Pgtcl
package require Syslog
package require Tclx

proc debug {buf} {
	syslog -ident appglog -facility daemon debug $buf
}

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

	debug "Executed: $sql"

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

proc receiver {} {
	set entrance "Starting apache_pg_log ($::app_branch) reciever built [clock format $::app_timestamp -format "%Y-%m-%d @ %H:%M"] on [info hostname]"
	logmsg $entrance
	db_connect

	pg_on_connection_loss $::db {
		logerr "Connection to database lost"
		after 3000
		db_connect
	}

	while {1} {
		set buf [gets stdin]
		set buflist [split $buf "\t"]

		if {[catch {array set bufarray $buflist} err]} {
			logerr "$err"
		} else  {
			set fields [array names bufarray]
			set values [list]

			set bufarray(ts) [clock format $bufarray(ts) -format "%Y-%m-%d %T" -gmt 1]

			foreach f $fields {
				lappend values [pg_quote $bufarray($f)]
			}

			set sql    "INSERT INTO access_log ([join $fields ","]) VALUES ([join $values ","]); "
			append sql "NOTIFY logactivity; "

			logerr [do_sql $sql]
		}
	}
}

proc bail {} {
	puts "User exit detected"
	pg_disconnect $::db
	puts "Disconnected from database"
	exit
}

proc tail_log {regexp} {
	set entrance "Starting apache_pg_log ($::app_branch) tail_log built [clock format $::app_timestamp -format "%Y-%m-%d @ %H:%M"] on [info hostname]"
	puts $entrance
	db_connect

	pg_select $::db "SELECT max(id) as id, max(length(server_name)) as m_server_name FROM access_log" buf {
		set ::last_id $buf(id)
		foreach lf {server_name} {
			set ::max($lf) $buf(m_$lf)
		}
		pg_listen $::db logactivity new_logs
	}

	signal trap SIGINT bail
	vwait die
}

proc new_logs {} {
	pg_select $::db "SELECT * FROM access_log WHERE id > $::last_id ORDER BY id" buf {
		# Combined
		#puts "$buf(remote_host) $buf(remote_logname) $buf(remote_user) \[$buf(ts)\] \"$buf(request_uri)\" $buf(status_last) $buf(content_bytes) \"$buf(referer)\" \"$buf(user_agent)\""
		#
		set outbuf ""
		append outbuf "$buf(ts) "

		append outbuf "[format "%$::max(server_name)s" $buf(server_name)] "

		switch $buf(local_port) {
			     80 { append outbuf "http  " }
			    443 { append outbuf "https " }
			default { append outbuf "  ?   " }
		}
		append outbuf " [format "%3d" $buf(status_last)] "

		append outbuf "[format "%5d" [expr $buf(content_bytes) / 1024]]kB "

		append outbuf "$buf(remote_host) $buf(remote_logname) $buf(remote_user) \"$buf(request_uri)\" \"$buf(referer)\" \"$buf(user_agent)\""

		puts $outbuf
		set ::last_id $buf(id)
	}
}


proc main {argv} {
	if {![info exists argv] || $argv =="" || $argv == "receiver"} {
		receiver
	} else {
		if {[regexp {^tail} $argv]} {
			tail_log ".*"
		}
	}
}


if !$tcl_interactive {
	main $argv
}
