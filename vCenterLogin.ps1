######################################################################################################
#
# vCenterLogin.ps1 - Automatically login to vCenter
#
# Prior to executing this script for the first time, you need
# to securely store your credentials by executing the following:
# $creds = Get-Credential
# $pwLocation = "H:\PowerShell\Credentials\vCenterLogin.txt"
# $creds.Password | ConvertFrom-SecureString | Set-Content $pwLocation
#
# The above only needs to be done once. 
# Make sure you add/modify the 3 variables below, as needed.
######################################################################################################

$SiteURL    = "https://vcenter.acme.local/vsphere-client/?csp"
$UserName   = "user@vSphere.local"
$pwLocation = "H:\PowerShell\Credentials\vCenterLogin.txt"

######################################################################################################

# retrieve your securely stored password
$securePW = Get-Content $pwLocation | ConvertTo-SecureString
$creds    = New-object System.Management.Automation.PSCredential($userName,$securePW)
$password = $creds.GetNetworkCredential().Password


function LogMsg ($msg, $newLine) {
    $strDate = [DateTime]::Now.ToString("[MM/dd/yyy HH:mm:ss]:")
    if ($newLine) {
            Write-Host  "$($strDate) $($msg)"
    } else {
            Write-Host  "$($strDate) $($msg)" -NoNewLine
    }
}

function Log ($msg) {
            LogMsg $msg $True
}

function LogNoNewLine ($msg) {
            LogMsg $msg $False
}

function Cleanup() {
    # clean up 
    if (Test-Path variable:\ie) {
                        if ($ie -is [System.__ComObject]) {
                                    #Log "Closing the IE COM object."
                                    #$ie.Quit()
                                    Start-Sleep -m 500
                                    Log "Removing existing IE COM object."
                               [System.Runtime.Interopservices.Marshal]::ReleaseComObject($ie) | Out-Null
                                    Start-Sleep -m 500
                        }
    }
}

Function Find-IE () {
   $app = New-Object -com Shell.Application
   $docs = @($app.windows() | Where {$_.Type  -eq "HTML Document"})
   if ($docs.Length -gt 0) {
            Log "Found IE object ..."
            $doc = $docs[0].Document
   } else {
            $doc = $Null
            Log "IE window not found ... creating new IE object."
   }
   $doc
}  

function Wait-ForPageReady {
    LogNoNewLine "Waiting for page to be displayed ..." 
    $secs = 0
    while ($ie.ReadyState -ne 4) {
        Write-Host "." -NoNewLine
                        ++$secs
                        if ($secs -gt $timeoutSecs) {
                                    Log "Timeout waiting for IE page to be ready ... exiting."
                                    Return
                        }
                        Write-Host "." -NoNewLine
                        Start-Sleep 1
    }
    Write-Host "."

}

Log "*************************************************************"
Log "****************     vCenter Login Script    ****************"
Log "*************************************************************"

if ($script:MyInvocation.MyCommand.Path -eq $Null) {
            $ScriptDir = $pwd.Path 
} else {
            $ScriptDir = Split-Path $Script:MyInvocation.MyCommand.Path
}

Set-StrictMode -Version 2
$LoginButtonId = "submit" 
$UsernameTextBoxId = "username" 
$PasswordTextBoxId = "password" 
$timeoutSecs = 30

$ie = Find-IE
if ($ie -eq $Null) {        
            [System.__ComObject]$ie = New-Object -ComObject "InternetExplorer.Application" 
}
$ie.visible = $true
Start-Sleep 1

Log "Navigating to '$SiteURL' ... "
$ie.Navigate2($SiteURL)
Wait-ForPageReady
# need a slight delay here
Start-Sleep 1

Log "Accessing DOM"
$frame = ($ie.document.getElementsByTagName("iframe"))[0]  
  
$document = $frame.contentWindow.document                           
Log "Getting UserName textbox"
$userNameTextBox  = $document.getElementById($UsernameTextBoxId)
Log "Getting Password textbox"
$passwordTextBox = $document.getElementById($PasswordTextBoxId)
Log "Getting Logon button"
$loginButton = $document.getElementById($LoginButtonId)

if ($userNameTextBox -ne $null -and $userNameTextBox.GetType() -ne [DBNull]) {
            Log "Setting UserName '$UserName'"
            $userNameTextBox.Value = $UserName
} else {
            throw "UserName textbox not found"
}

if ($passwordTextBox -ne $null -and $passwordTextBox.GetType() -ne [DBNull]) {
            Log "Setting Password"
            $passwordTextBox.Value = $password
} else {
            throw "Password textbox not found"
}

if ($loginButton -ne $null -and $loginButton.GetType() -ne [DBNull]) {
            Log "Clicking login button ..."
            $loginButton.disabled = $False
            $loginButton.Click()
} else {
            throw "Login button not found"
}

# wait for new page to load
Wait-ForPageReady

Cleanup

Log "Done."

Log "****************    vCenter Script End    ****************"
