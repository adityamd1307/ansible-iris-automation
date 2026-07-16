# if they installed on Windows only, just exit
$ubuntu = Read-Host -Prompt "You should only run this script if you installed IRIS on the Ubuntu VM. Did you? (Y/N)"
if (-Not ("Yy".Contains($ubuntu))) {exit}

# get Windows IP address
$IP = (Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -ne $null}).IPv4Address.IPAddress 
# in config.json, replace smtp address of "localhost" with IP address
$configfile = Get-Content -Path "C:\Program Files\MailSlurper\config.json" -Raw | ConvertFrom-Json
$configfile.smtpAddress = $IP
$configfile | ConvertTo-Json -Depth 10 | Set-Content "C:\Program Files\MailSlurper\config.json"
"Updated config.json"

# stop and start mailslurper task
Stop-ScheduledTask -TaskName "mailslurper"
Start-Sleep -Seconds 2
Start-ScheduledTask -TaskName "mailslurper"
"Restarted MailSlurper task"
Start-Sleep -Seconds 3