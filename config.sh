#!/bin/bash
# shellcheck disable=SC2034  # used by the scripts that source this file
# All settings. Change the passwords BEFORE the first ./start.sh:
# the database keeps the ones it was created with.

DOMJUDGE_VERSION=9.0.1     # https://hub.docker.com/r/domjudge/domserver/tags
MARIADB_VERSION=11.8
TIMEZONE=Asia/Tehran       # contest times are shown in this timezone
PORT=12345                 # web interface: http://<server>:PORT
JUDGEHOSTS=2               # judgehosts use CPU cores 1..N; core 0 is left for the server

MYSQL_PASSWORD=change_me
MYSQL_ROOT_PASSWORD=change_me_too
