#PostgreSQL
./psql -h <hostname or ip> -p <port> -U <username> -d <database name> -l

#MS SQL
./isql -v Dns_Name_As_Specified_In_ODBCinst User_Name Pass_Word

#ORACLE
./sqlplus <user>/<password>@<Name from tnsnames.ora>
#check tnsnames.ora
./tnsping <Name from tnsnames.ora>

#Netezza
./nzsql -u [username] -pw [password] -d [database] -host [Netezza_host]