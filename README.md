Apache Pgsql Log
================

This is a facility and related toolbox which is used as a piped log so that your Apache HTTP Server
can log its activity into a PostgreSQL database alongside traditional file logging, or as a total
replacement.

Logging to a database has several significant advantages over file-based logging, such as:

* No ambiguity when later processing the logs, no need to parse the data
* Truly typed data (e.g. "inet" field types for logged IP addresses)
* Simpler to collate logs from multiple servers into a single log repository


Requirements
------------

* [PosgreSQL](http://www.postgresql.org/)
* Tcl 8.5 or newer
* Tclx
* [tcllauncher](https://github.com/flightaware/tcllauncher)
* [Tcl Syslog](http://sourceforge.net/projects/tcl-syslog/)

Installation
------------

1. Create a PostgreSQL database somewhere.
2. Run the `./db/schema.sql` file in the database to create the tables and roles.
3. Copy the included config.tcl.sample to config.tcl and edit to suit your environment.
4. Install the app `sudo make install`

Configuration
-------------

If you want every vhost to be logged to the same database, you only need a single instance of
apache-pg-sql for the server.  If you want to log each vhost differently, you'll need to add a
CustomLog entry for those vhosts independently.

For a single log, comment out every CustomLog configuration entry in your Apache config.  This
includes the base httpd.conf and any vhost include files that may exist.

Place the contents of the `sample.conf` file into your main Apache configuration file.

Restart Apache

Now What?
---------

Apache Pgsql Log also provides a workalike to `tail -f` which allows you to watch the logs in real
time on stdout of a terminal window.  Simply run:

`apache_pg_log tail`
