# Server_Backup
Weekly and daily backup scripts, shipped with a crontab and a logrotate configuration file for the logs.

## Daily backup
The daily script uses Rsync to backup files incrementally.
It also dumps every database in a separate, gzipped file.
It then send an email to the system administrator and write a log file.

## Weekly backup
The weekly backup script compresses the last incremental backup using
Plzip, a multi-threaded data compressor using the Lzip algorithm, thus
achieving excellent compression rates.
It then sends the file to a remote FTP server, sends and email to the
system administrator and writes a log file.

## Cron file
Schedules the daily backup to run every night, and the weekly backup
to run once a weeky (on mondays). It uses `nice` and `ionice` to ensure
the server is not overloaded by the various IO and CPU heavy operations.

## Logrotate file
Takes care of the log files generated by both the backup scripts.
