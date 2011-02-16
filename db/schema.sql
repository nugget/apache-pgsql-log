CREATE ROLE apache LOGIN ENCRYPTED PASSWORD 'password';

CREATE ROLE webservers;
GRANT webservers TO apache;

CREATE TABLE access_log (
	id serial NOT NULL,
	ts timestamp without time zone NOT NULL DEFAULT (current_timestamp at time zone 'utc'),	-- %{%s}t
	local_ip inet NOT NULL,			-- %A
	remote_ip inet NOT NULL,		-- %a
	remote_host varchar,			-- %h
	request_uri varchar,			-- %U
	query_string varchar,			-- %q
	content_bytes bigint NOT NULL,	-- %B
	received_bytes bigint NOT NULL,	-- %I
	sent_bytes bigint NOT NULL,		-- %O
	usec integer NOT NULL,			-- %D
	filename varchar NOT NULL,		-- %f
	protocol varchar,				-- %H
	method varchar,					-- %m
	keepalives smallint,			-- %k
	remote_logname varchar,			-- %l
	local_port integer,				-- %{local}p
	remote_port integer,			-- %{remote}p
	pid integer,					-- %{pid}P
	tid integer,					-- %{tid}P
	first_ine varchar,				-- %r
	handler varchar,				-- %R
	status_first smallint,			-- %s
	status_last	smallint,			-- %>s
	remote_user	varchar,			-- %u
	server_name varchar,			-- %v
	status_completed varchar,		-- %X
	referer varchar,				-- %{Referer}i
	user_agent varchar,				-- %{User-Agent}i
	PRIMARY KEY(local_ip,id)
);
GRANT INSERT ON access_log TO webservers;

