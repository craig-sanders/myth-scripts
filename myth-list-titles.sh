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
  -w, --watched       watched 0 or 1 (default = either)
  -t, --totals-only   only display totals
  -b, --basename-only only display basename of recording

  -s, --sort         sort by title, size, date (default)
  -A, --ASC          sort ASCENDING (DEFAULT)
  -D, --DESC         sort DESCENDING

  -d, --debug         debug mode
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
TEMP=$(getopt -o 'ldtrbw:hs:AD' --long 'like,debug,totals-only,regexp,basename-only,watched:,help,sort:,asc,desc' -n "$0" -- "$@")

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- "$TEMP"

LIKE=""
REGEXP=""
BNAME=""
DEBUG=""
HIDE_TOTALS=""
TOTAL_ONLY=""
SORT_BY="starttime"
SORT_DIR="ASC"

while true ; do
    case "$1" in
        -l|--like)   LIKE="1" ; shift ;;

        -r|--reg*)   REGEXP="1" ; shift ;;

        -w|--wat*)   WATCHED="$2" ; shift 2 ;;

        -b|--bas*)   BNAME="1" ; HIDE_TOTALS="1" ; shift ;;

        -d|--deb*)   DEBUG="1" ; shift ;;

        -t|--tot*)   TOTAL_ONLY="1" ; shift ;;

        -h|--help)   usage ; exit 2 ;;

        -s|--sor*)  SORT_OPT="$2" ;
                    case "$SORT_OPT" in
                        t*) SORT_BY="title" ;;
                        d*) SORT_BY="starttime" ;;
                        s*) SORT_BY="filesize" ;;
                         *) echo "invalid sort option: $SORT_OPT" ; usage ; exit 2;;
                    esac ;
                    shift 2 ;;

        -A|--ASC*)  SORT_DIR="ASC" ; shift ;;
        -D|--DESC*) SORT_DIR="DESC" ; shift ;;

        --)          shift ; break ;;

        *)           echo 'Internal error!' ; exit 1 ;;
    esac
done

TITLE="$@"

if [ -n "$LIKE" ] ; then
  WHERE="title LIKE '%$TITLE%'"
elif [ -n "$REGEXP" ] ; then
  WHERE="title REGEXP '$TITLE'"
else
  WHERE="title = '$TITLE'"
fi

if [ -n "$WATCHED" ] ; then
  WHERE="$WHERE AND watched=$WATCHED"
fi


FIELDS="substr(title,1,20) as title, substr(subtitle,1,20) as subtitle, starttime,(filesize/(1024*1024*1024)) as GB, recordingprofiles.name as Transcoder,basename"
if [ -n "$BNAME" ] ; then
  FIELDS="basename"
fi

SQL1="SELECT $FIELDS
      FROM recorded
      JOIN recordingprofiles on (recordingprofiles.id = transcoder and recordingprofiles.profilegroup = 6)
      WHERE $WHERE
      ORDER by $SORT_BY $SORT_DIR"

#      ORDER by starttime"

SQL2="SELECT count(*) as Num_Recordings, sum(filesize/(1024*1024*1024)) as GB
      FROM recorded
      WHERE $WHERE"


if [ -z "$HIDE_TOTALS" ] ; then
  if [ -z "$TOTAL_ONLY" ] ; then 
    exec_sql "$SQL1"
  fi
  exec_sql "$SQL2"
else
    exec_sql3 "$SQL1"
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

### describe recordingprofiles;
### +--------------+------------------+------+-----+---------+----------------+
### | Field        | Type             | Null | Key | Default | Extra          |
### +--------------+------------------+------+-----+---------+----------------+
### | id           | int(10) unsigned | NO   | PRI | NULL    | auto_increment |
### | name         | varchar(128)     | YES  |     | NULL    |                |
### | videocodec   | varchar(128)     | YES  |     | NULL    |                |
### | audiocodec   | varchar(128)     | YES  |     | NULL    |                |
### | profilegroup | int(10) unsigned | NO   | MUL | 0       |                |
### +--------------+------------------+------+-----+---------+----------------+
