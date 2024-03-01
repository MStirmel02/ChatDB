color 04
@ECHO OFF
ECHO Creating Database

sqlcmd -S localhost -E -i net3.sql

rem server is localhost

ECHO Database created if no errors occured
PAUSE