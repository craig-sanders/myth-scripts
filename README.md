# myth-scripts

My mythtv-related scripts.

very useful:

 - myth-list-new.sh          -- list new recordings
 - myth-list-queue.sh        -- list the myth job queue
 - myth-list-titles.sh       -- list recordings

not so useful:

 - myth-list-transcoders.sh  -- list transcodersh


---

All of these scripts interact with the `mythconverg` mysql database
directly.

They assume that there is a properly configured `~/.my.cnf` file with
authentication details.

    $ cat <<__EOF__ > ~/.my.cnf
    [mysql]
    user      = mythtv
    password  = PASSWORD
    database  = mythconverg
    __EOF__
    chmod 600 ~/.my.cnf

