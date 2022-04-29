#! /bin/bash

MYSQL_HOST="localhost"

# (C) Copyright Craig Sanders <cas@taz.net.au> 2009-2016
#
# This script is licensed under the terms of the GNU General Public
# License version 3 (or later, at your option).

usage () {
SCRIPT_NAME=$(basename $0)
cat <<__EOF__
Usage: $SCRIPT_NAME [OPTIONS] [title search string]

OPTIONS:
  -l, --like          mysql 'LIKE' search rather than equals
  -r, --regexp        mysql 'REGEXP' search rather than equals

  -c, --cutlist      cutlist 0 or 1 (Default: either)
  -t, --totals-only  only display totals

  -T, --transcoded   transcoded 0=no, 1=yes, 2=either (Default: 1)
  -b, --bookmark     bookmark 0 or 1 (Default: either)
  -w, --watched      watched 0 or 1 (Default: either)
  -f, --flagged      commflagged 0 or 1 (Default: either)
  -o, --hostname     show recording host
  -n, --filename     show recording filename

  -q, --queue        output SQL to insert transcode commands into jobqueue table
  -e, --execute      execute SQL rather than display it
  --force            force queuing of finished jobs that are still listed in the queue

  -d, --debug        show SQL commands as they are run
  -h, --help         this usage message

  -7, --seven        exclude ABC News and 7.30 Report

  -s, --sort         sort by title, size, date (Default: date)
  -L, --limit        SQL query limit (Default: no limit)
  -A, --ASC          sort ASCENDING (Default for title)
  -D, --DESC         sort DESCENDING (Default for size, date)
__EOF__
}

# uses the "getopt" program from util-linux, which supports long
# options...unlike the "getopts" built-in to bash.
TEMP=$(getopt -o 'lrT:b:c:w:f:htdqeon7s:ADL:' --long 'like,regexp,transcoded:,bookmark:,cutlist:watched:,flagged:,help,totals-only,debug,queue,execute,hostname,filename,seven,sort:,asc,desc,force,limit' -n "$0" -- "$@")

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- "$TEMP"

TRANSCODED=0
CUTLIST=''
BOOKMARK=''
WATCHED=''
FLAGGED=''
HNAME=''
FNAME=''
TOTAL_ONLY=0
DEBUG=0
QUEUE=0
MYCMD='cat'
SORT_BY='starttime'
#SORT_DIR='ASC'
SORT_DIR=''
FORCE=0
LIMIT=''

ABCNEWS=""

while true ; do
    case "$1" in
        -l|--like)  LIKE="1" ; shift ;;

        -r|--reg*)  REGEXP="1" ; shift ;;

        -T|--tran*) TRANSCODED="$2" ; shift 2 ;;

        -b|--book*) BOOKMARK="$2" ; shift 2 ;;

        -c|--cut*)  CUTLIST="$2" ; shift 2 ;;

        -w|--wat*)  WATCHED="$2" ; shift 2 ;;

        -f|--fla*)  FLAGGED="$2" ; shift 2 ;;

        -t|--tot*)  TOTAL_ONLY=1 ; shift ;;

        -d|--deb*)  DEBUG=1 ; shift ;;

        #-q|--que*)  QUEUE=1 ; CUTLIST=1 ; shift ;;
        -q|--que*)  QUEUE=1 ; shift ;;
        -e|--exec*) MYCMD="mysql -h $MYSQL_HOST -Bs" ; shift ;
                    if [ "$QUEUE" = "0" ] ; then
                      echo "Aborting.  --exec requires --queue, to minimise risk of accidentally queuing transcode jobs"
                      exit 1;
                    fi
                    ;;
        --force) FORCE=1 ; shift ;;


        -o|--hos*)  HNAME=1 ; shift ;;

        -n|--fil*)  FNAME=1 ; shift ;;

        -h|--help)  usage ; exit 2 ;;

        -7|--sev*)  ABCNEWS=" AND title not in ('ABC News','The 7.30 Report','7.30')"; shift ;;

        -s|--sor*)  SORT_OPT="$2" ;
                    case "$SORT_OPT" in
                        t*) SORT_BY="title" ; SORT_DIR="${SORT_DIR:-ASC}" ;;
                        d*) SORT_BY="starttime" ; SORT_DIR="${SORT_DIR:-DESC}" ;;
                        s*) SORT_BY="filesize" ; SORT_DIR="${SORT_DIR:-DESC}" ;;
                         *) echo "Invalid sort option: $SORT_OPT" ; usage ; exit 2;;
                    esac ;
                    shift 2 ;;

        -A|--ASC*)  SORT_DIR="ASC" ; shift ;;
        -D|--DESC*) SORT_DIR="DESC" ; shift ;;

        -L|--lim*)  LIMIT="LIMIT $2" ; shift 2 ;;

        --)         shift ; break ;;

        *)          echo 'Internal error!' ; exit 1 ;;
    esac
done

SORT_DIR="${SORT_DIR:-DESC}"

TITLE="$@"

if [ -n "$TITLE" ] ; then
  if [ -n "$LIKE" ] ; then
    TWHERE=" AND title LIKE '%$TITLE%'"
  elif [ -n "$REGEXP" ] ; then
    TWHERE=" AND title REGEXP '$TITLE'"
  else
    TWHERE=" AND title = '$TITLE'"
  fi
fi

TRSYMBOL="="
[ "$TRANSCODED" = "2" ] && TRSYMBOL="<"

WHERE="transcoded $TRSYMBOL $TRANSCODED"

if [ -n "$CUTLIST" ] ; then
  WHERE="$WHERE AND cutlist=$CUTLIST"
fi

if [ -n "$BOOKMARK" ] ; then
  WHERE="$WHERE AND bookmark=$BOOKMARK"
fi

if [ -n "$WATCHED" ] ; then
  WHERE="$WHERE AND watched=$WATCHED"
fi

if [ -n "$FLAGGED" ] ; then
  WHERE="$WHERE AND commflagged=$FLAGGED"
fi

WHERE="$WHERE $ABCNEWS $TWHERE"


function exec_sql () {
  [ "$DEBUG" = "1" ] && echo $1 >&2
  mysql -h $MYSQL_HOST mythconverg -t -e "$1"
}

function exec_sql2 () {
  [ "$DEBUG" = "1" ] && echo $1 >&2
  mysql -h $MYSQL_HOST mythconverg -Bse "$1"
}

FIELDS="substr(title,1,20) as title, substr(subtitle,1,20) as subtitle, CONVERT_TZ(starttime,'GMT','Australia/Melbourne') AS starttime, (filesize/(1024*1024*1024)) as GB"
[ "$HNAME" = "1" ] && FIELDS="$FIELDS, hostname"
[ "$FNAME" = "1" ] && FIELDS="$FIELDS, basename"

SQL1="SELECT $FIELDS
      FROM recorded
      WHERE $WHERE
      ORDER BY $SORT_BY $SORT_DIR $LIMIT"

SQL2="SELECT count(*) as Num_Recordings, sum(filesize/(1024*1024*1024)) as GB
      FROM (SELECT filesize FROM recorded
      WHERE $WHERE ORDER BY $SORT_BY $SORT_DIR $LIMIT) as a"

#SELECT COUNT(*), SUM(score) FROM (SELECT * FROM answers WHERE user=1 LIMIT 5) AS a

SQL3="SELECT chanid, starttime FROM recorded WHERE $WHERE"
if [ "$FORCE" = "1" ] ; then
  # not sure if these status codes are right
  SQL3="$SQL3 AND concat(chanid,starttime) NOT IN (SELECT concat(chanid,starttime) from jobqueue WHERE type=1 AND status not in (272,304))"
else
  SQL3="$SQL3 AND concat(chanid,starttime) NOT IN (SELECT concat(chanid,starttime) from jobqueue WHERE type=1)"
fi
SQL3="$SQL3 ORDER BY $SORT_BY $SORT_DIR $LIMIT"

if [ "$QUEUE" = "1" ] ; then
  # transcoder 61 = Lossless, 62 = 576p mpeg4
  #echo -e -n 'UPDATE `mythconverg`.`recorded` SET transcoder = 61 WHERE transcoded = 1  AND (cutlist = 1 OR commflagged=1);\n' | $MYCMD
  #echo -e -n 'UPDATE `mythconverg`.`recorded` SET transcoder = 62 WHERE transcoded = 1  AND (cutlist = 1 OR commflagged=1);\n' | $MYCMD
  exec_sql2 "$SQL3" | while read chanid starttime; do
    echo -e -n 'INSERT INTO `mythconverg`.`jobqueue` (`id`, `chanid`, `starttime`, `inserttime`, `type`, `cmds`, `flags`, `status`, `statustime`, `hostname`, `comment`)' \
               " VALUES (NULL, '$chanid', '$starttime', NOW( ), 1, 0, 1, 1, NOW( ), '', '');\n" | $MYCMD
  done 
elif [ "$TOTAL_ONLY" != "1" ] ; then
  exec_sql "$SQL1"
  exec_sql "$SQL2"
else
  exec_sql "$SQL2"
fi


### mysql> describe recorded;
### +-----------------+------------------+------+-----+---------------------+-----------------------------+
### | Field           | Type             | Null | Key | Default             | Extra                       |
### +-----------------+------------------+------+-----+---------------------+-----------------------------+
### | chanid          | int(10) unsigned | NO   | PRI | 0                   |                             |
### | starttime       | datetime         | NO   | PRI | 0000-00-00 00:00:00 |                             |
### | endtime         | datetime         | NO   | MUL | 0000-00-00 00:00:00 |                             |
### | title           | varchar(128)     | NO   | MUL |                     |                             |
### | subtitle        | varchar(128)     | NO   |     |                     |                             |
### | description     | text             | NO   |     | NULL                |                             |
### | category        | varchar(64)      | NO   |     |                     |                             |
### | hostname        | varchar(64)      | NO   |     |                     |                             |
### | bookmark        | tinyint(1)       | NO   |     | 0                   |                             |
### | editing         | int(10) unsigned | NO   |     | 0                   |                             |
### | cutlist         | tinyint(1)       | NO   |     | 0                   |                             |
### | autoexpire      | int(11)          | NO   |     | 0                   |                             |
### | commflagged     | int(10) unsigned | NO   |     | 0                   |                             |
### | recgroup        | varchar(32)      | NO   | MUL | Default             |                             |
### | recordid        | int(11)          | YES  | MUL | NULL                |                             |
### | seriesid        | varchar(40)      | NO   | MUL |                     |                             |
### | programid       | varchar(40)      | NO   | MUL |                     |                             |
### | lastmodified    | timestamp        | NO   |     | CURRENT_TIMESTAMP   | on update CURRENT_TIMESTAMP |
### | filesize        | bigint(20)       | NO   |     | 0                   |                             |
### | stars           | float            | NO   |     | 0                   |                             |
### | previouslyshown | tinyint(1)       | YES  |     | 0                   |                             |
### | originalairdate | date             | YES  |     | NULL                |                             |
### | preserve        | tinyint(1)       | NO   |     | 0                   |                             |
### | findid          | int(11)          | NO   |     | 0                   |                             |
### | deletepending   | tinyint(1)       | NO   | MUL | 0                   |                             |
### | transcoder      | int(11)          | NO   |     | 0                   |                             |
### | timestretch     | float            | NO   |     | 1                   |                             |
### | recpriority     | int(11)          | NO   |     | 0                   |                             |
### | basename        | varchar(255)     | NO   |     | NULL                |                             |
### | progstart       | datetime         | NO   |     | 0000-00-00 00:00:00 |                             |
### | progend         | datetime         | NO   |     | 0000-00-00 00:00:00 |                             |
### | playgroup       | varchar(32)      | NO   |     | Default             |                             |
### | profile         | varchar(32)      | NO   |     |                     |                             |
### | duplicate       | tinyint(1)       | NO   |     | 0                   |                             |
### | transcoded      | tinyint(1)       | NO   |     | 0                   |                             |
### | watched         | tinyint(4)       | NO   |     | 0                   |                             |
### | storagegroup    | varchar(32)      | NO   |     | Default             |                             |
### | bookmarkupdate  | timestamp        | NO   |     | 0000-00-00 00:00:00 |                             |
### +-----------------+------------------+------+-----+---------------------+-----------------------------+
