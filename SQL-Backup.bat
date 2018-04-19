sqlcmd -U sa -P xxxxxx -S .\SQL2014EXPRESS -Q "EXEC sp_BackupDatabases @backupLocation = 'C:\SQLBackups\', @backupType = 'F'" > C:\SQLBackups\Log\MSSQL-%date:~-4,4%%date:~-6,1%%date:~-10,2%.log
Powershell.exe -executionpolicy remotesigned -File  C:\Batch\Send-email.ps1
