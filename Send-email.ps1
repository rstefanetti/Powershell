#############################################################################
$SMTPServer = "smtp.gmail.com"
$SMTPPort = "123"
$Username = "User@gmail.com"
$Password = "Password"

$to = "sysadmin@company.it"
$data = Get-Date -format yyyyMdd
$attachment = "C:\SQLBackups\Log\MSSQL-$data.log"
$subject = "[NAV2015-PROD]Backup MSSQL2014-Express"
$body = "Backup Completed"

$message = New-Object System.Net.Mail.MailMessage
$message.subject = $subject
$message.body = $body
$message.to.add($to)
$message.from = $Username
$message.attachments.add($attachment)

$smtp = New-Object System.Net.Mail.SmtpClient($SMTPServer, $SMTPPort);
$smtp.EnableSSL = $true
$smtp.Credentials = New-Object System.Net.NetworkCredential($Username, $Password);
$smtp.send($message)
write-host "Mail Sent"


#
#Send-MailMessage -From $From -to $To -Subject $Subject `
#-Body $Body -SmtpServer $SMTPServer -port $SMTPPort `
#-Credential (Get-Credential) -Attachments $Attachment
#
##############################################################################