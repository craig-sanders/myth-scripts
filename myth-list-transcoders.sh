#! /bin/bash

MYSQL_HOST="localhost"

# (C) Copyright Craig Sanders <cas@taz.net.au> 2009-2016
#
# This script is licensed under the terms of the GNU General Public
# License version 3 (or later, at your option).

usage () {
SCRIPT_NAME=$(basename $0)
cat <<__EOF__
Usage: $SCRIPT_NAME

OPTIONS:
  -h, --help          this usage message
__EOF__
}

function exec_sql () {
  [ "$DEBUG" = "1" ] && echo $1 >&2
  mysql -h $MYSQL_HOST mythconverg --table --execute "$1"
}

function exec_sql2 () {
  [ "$DEBUG" = "1" ] && echo $1 >&2
  mysql -h $MYSQL_HOST mythconverg --batch --silent --execute "$1"
}

function exec_sql3 () {
  [ "$DEBUG" = "1" ] && echo $1 >&2
  mysql -h $MYSQL_HOST mythconverg --batch --skip-column-names --execute "$1"
}

# uses the "getopt" program from util-linux, which supports long
# options...unlike the "getopts" built-in to bash.
TEMP=$(getopt -o 'h' --long 'help' -n "$0" -- "$@")

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- "$TEMP"

while true ; do
    case "$1" in
        -h|--help)   usage ; exit 2 ;;

        --)          shift ; break ;;

        *)           echo 'Internal error!' ; exit 1 ;;
    esac
done


SQL1="SELECT *
      FROM recordingprofiles
      WHERE profilegroup = 6
      order by id"

exec_sql "$SQL1"

