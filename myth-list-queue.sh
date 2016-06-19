#! /bin/bash

MYSQL_HOST="localhost"

# (C) Copyright Craig Sanders <cas@taz.net.au> 2009-2016
#
# This script is licensed under the terms of the GNU General Public
# License version 3 (or later, at your option).

usage () {
SCRIPT_NAME=$(basename $0)
cat <<__EOF__
Usage: $SCRIPT_NAME [OPTIONS]

OPTIONS:
  -r, --running      show running jobs
  -q, --queued       show queued jobs
  -c, --completed    show completed jobs
  -e, --errors       show errored jobs
  -f, --flag         show commflag jobs
  -t, --transcoded   show transcode jobs
  -h, --help         this usage message

  -s, --sort         sort by title, chanid, starttime, inserttime (default), host
  -A, --ASC          sort ASCENDING (default)
  -D, --DESC         sort DESCENDING
__EOF__
}

# uses the "getopt" program from util-linux, which supports long
# options...unlike the "getopts" built-in to bash.
TEMP=$(getopt -o 'drqcehfts:AD' --long 'debug,running,queued,completed,errors,flag,transcode,sort:,ASC,DESC' -n "$0" -- "$@")

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- "$TEMP"

DEBUG=0
AND=""
WHERE="WHERE"
STATUS=""
TYPE=""
#SORT_BY="inserttime,starttime"
SORT_BY="jobqueue.inserttime"
SORT_DIR="ASC"

while true ; do
    case "$1" in
        -r|--run*) STATUS="$STATUS,4" ; shift ;;

        -q|--que*) STATUS="$STATUS,1" ; shift ;;

        -c|--com*) STATUS="$STATUS,272" ; shift ;;

        -e|--err*) WHERE="$WHERE status > 272" ; shift ;;

        -f|--fla*) TYPE="$TYPE,2" ; shift ;;

        -t|--tra*) TYPE="$TYPE,1" ; shift ;;

        -d|--debug) DEBUG=1 ; shift ;;

        -h|--help)   usage ; exit 2 ;;

        -s|--sor*)  SORT_OPT="$2" ;
                    case "$SORT_OPT" in
                        t*) SORT_BY="title" ;;
                        c*) SORT_BY="chanid" ;;
                        s*) SORT_BY="jobqueue.starttime" ;;
                        i*) SORT_BY="jobqueue.inserttime" ;;
                        h*) SORT_BY="jobqueue.hostname" ;;
                         *) echo "invalid sort option: $SORT_OPT" ; usage ; exit 2;;
                    esac ;
                    shift 2 ;;

        -A|--ASC*)  SORT_DIR="ASC" ; shift ;;
        -D|--DESC*) SORT_DIR="DESC" ; shift ;;

        --)          shift ; break ;;

        *)           echo 'Internal error!' ; exit 1 ;;
    esac
done

STATUS=$(echo "$STATUS" | sed -e 's/^,//')
TYPE=$(echo "$TYPE" | sed -e 's/^,//')

if [ "$WHERE" = "WHERE" ] ; then
   [ -n "$STATUS" ] && WHERE="$WHERE status in ($STATUS)" && AND="AND"
else
   AND="AND"
fi

[ -n "$TYPE" ] && WHERE="$WHERE $AND type in ($TYPE)"

[ "$WHERE" = "WHERE" ] && WHERE=""

ORDER_BY="ORDER BY $SORT_BY $SORT_DIR"

function exec_sql () {
  [ "$DEBUG" = "1" ] && echo $1
  mysql -h $MYSQL_HOST mythconverg -t -e "$1"
}

#
#SQL1="SELECT substr(recorded.title,1,20) as title, chanid, jobqueue.starttime, inserttime, type as T, cmds as C, flags as F, status as S, jobqueue.hostname as
SQL1="SELECT substr(recorded.title,1,20) as title, chanid, jobqueue.starttime, type as T, cmds as C, flags as F, status as S, jobqueue.hostname as
host, substr(comment,1,30) as comment
      FROM jobqueue
      JOIN recorded using (chanid,starttime)
      $WHERE
      $ORDER_BY"

#SELECT substr(recorded.title,1,20) as title, chanid, jobqueue.starttime, inserttime, type as T, cmds as C, flags as F, status as S, jobqueue.hostname as host,
#substr(comment,1,20)   FROM jobqueue       JOIN recorded using (chanid,starttime) ORDER by inserttime,starttime;

echo " Key: T=type C=cmds F=flags S=status"
exec_sql "$SQL1"


### +--------------+--------------+------+-----+---------------------+-----------------------------+
### | Field        | Type         | Null | Key | Default             | Extra                       |
### +--------------+--------------+------+-----+---------------------+-----------------------------+
### | id           | int(11)      | NO   | PRI | NULL                | auto_increment              |
### | chanid       | int(10)      | NO   | MUL | 0                   |                             |
### | starttime    | datetime     | NO   |     | 0000-00-00 00:00:00 |                             |
### | inserttime   | datetime     | NO   |     | 0000-00-00 00:00:00 |                             |
### | type         | int(11)      | NO   |     | 0                   |                             |
### | cmds         | int(11)      | NO   |     | 0                   |                             |
### | flags        | int(11)      | NO   |     | 0                   |                             |
### | status       | int(11)      | NO   |     | 0                   |                             |
### | statustime   | timestamp    | NO   |     | CURRENT_TIMESTAMP   | on update CURRENT_TIMESTAMP |
### | hostname     | varchar(64)  | NO   |     |                     |                             |
### | args         | blob         | NO   |     | NULL                |                             |
### | comment      | varchar(128) | NO   |     |                     |                             |
### | schedruntime | datetime     | NO   |     | 2007-01-01 00:00:00 |                             |
### +--------------+--------------+------+-----+---------------------+-----------------------------+
