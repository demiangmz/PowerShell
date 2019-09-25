#----------------------------------------------------------------------------------------------------------------------------------------
# Script:  RemoveOldApplicationVersions.ps1
# Authors:  German Taboadela, Demian Gomez
# Date:    9/5/2016  
# Version: 1.1
# Description: This script is useful to groom your application directories and remove older versions from them.
# -The code here it's meant to serve as an example of what can you do with regex (regular expressions) to purge old versions.
# -You should adapt the script's regex to your own application folder format and build server if you use one.
# -The script should be set up as a scheduled task and then you can monitor the event log and act upon the events.
#----------------------------------------------------------------------------------------------------------------------------------------
# Parameter Definition
#----------------------------------------------------------------------------------------------------------------------------------------
Param(
   #Specifies the environment root path, other paths were not tested
  [Parameter(Mandatory=$True)]
  [string]$envPath, 
  [Parameter(Mandatory=$True)]
  [string]$environment,
  [Parameter(Mandatory=$True)]
  [int]$numberOfVersions,
  [switch]$remove
 )
#----------------------------------------------------------------------------------------------------------------------------------------
# Functions
#----------------------------------------------------------------------------------------------------------------------------------------
Function getCurrentVersion ($appName) {

$client = "Tenant1"

#Replace this with the path that is being evaluated
#$inspectedPath = "\\server\share\client\env\app"

# Retrieve the lowest folder of the path evaluated
#$application = $inspectedPath.Split("\")[-1]

# Build service uri to query for current App version
$uri = "http://build.domain.com/Business/Application/GetLatestVersion?ClientName=$client&ApplicationName=$appName&EnvironmentName=$environment"

# Call service and convert JSON result into a parseable object
$result = Invoke-WebRequest -Uri $uri | ConvertFrom-Json

# Retrieve version name from result
$currentVersion = $result.Resultset[0].Name

Return $currentVersion
}

# Function inspectFolders parses a directory looking for version folders.
  Function inspectFolder ($folder) {
    
  $VersionCount = (Get-ChildItem $folder | Where { $_.PSIsContainer -and ($_.Name -match "\d{4}\.\d{4}\.\d{1,2}") }).Count 
  
  #If we have more than X Versions, create a list of versions to delete, leaving only X
  If ($VersionCount -GT $numberOfVersions) {
  
  $currentVersion = getCurrentVersion($folder)

  if ($currentVersion) {
  
  $versionsToDelete = Get-ChildItem $folder| Where {($_.PSIsContainer -and ($_.Name -match "\d{4}\.\d{4}\.\d{1,2}")) -and ($_.PSIsContainer -and ($_.Name -notmatch $currentVersion)) } | Sort-Object LastWriteTime | Select-Object -First ($versioncount - $numberOfVersions)
  }
  else {
  $versionsToDelete = Get-ChildItem $folder| Where {($_.PSIsContainer -and ($_.Name -match "\d{4}\.\d{4}\.\d{1,2}"))} | Sort-Object LastWriteTime | Select-Object -First ($versioncount -$numberOfVersions)
  }  

  #Call the actual delete function, passing the list of versions to delete
  deleteVersions -versions $versionsToDelete 
   
  } #End If
  
  } #End Function

  # Function deleteVersions actually deletes the old versions
  Function deleteVersions ($versions){
  $global:log += $versions | Select @{ expression={$_.Fullname}; label="Directory " + $versions[0].parent} | ft | Out-String
  
  #Removes only if -remove switch is present.
  If ($remove) {  $versions | Remove-Item -Recurse -Force }  
  }  
  #End Function
  
#----------------------------------------------------------------------------------------------------------------------------------------  
#Main Script
#----------------------------------------------------------------------------------------------------------------------------------------
#Global Variable  that will populate the list of folders being removed or not, wether switch -remove was specified or not
If ($remove) {$global:log = "The following folders were removed:`n"} else {$global:log = "The following folders would be removed if -remove switch were present (NO FILES WERE DELETED):`n"}

#List folder candidates for inspection, excluding version folders and version folders subdirectories.
$folderCandidates = Get-ChildItem $envPath -recurse | where {($_.psiscontainer) -and ($_.FullName -notmatch "\d{4}\.\d{4}\.\d{1,2}")}

foreach ($item in $folderCandidates){ inspectfolder -folder $item.FullName }

# Write To Windows Eventlog
If ([System.Diagnostics.EventLog]::SourceExists("Maintenance")) {

  Try{
      Write-Eventlog -LogName Application -Source "Maintenance" -EventID 1234 -Message "Successfully executed RemoveOldApplicationVersion script in order to purge old versions from Application `n`nEnvironment: $environment - Path: $envPath  `n`n$Log" -EntryType Information -ErrorAction Stop
     }
  Catch [System.Management.Automation.ParameterBindingException] {
     $today = Get-Date
     Set-content -Path "C:\Temp\RemoveOldApplicationVersions_$($environment)_$($today.Year.toString())$($today.Month.toString())$($today.Day.toString()).txt" -Value $log
     Write-Eventlog -LogName Application -Source "Maintenance" -EventID 1234 -Message "Successfully executed RemoveOldApplicationVersions script in order to purge old versions from Application `n`nEnvironment: $environment - Path: $envPath  `n`n The folder removal detail is too big for the Event Log. You can find it at `"C:\Temp\RemoveOldApplicationVersions_$($environment)_$($today.Year.toString())$($today.Month.toString())$($today.Day.toString()).txt`"" -EntryType Information -ErrorAction Stop
  }
}

Else { [System.Diagnostics.EventLog]::CreateEventSource("Maintenance","Application")

Try{ 
     Write-Eventlog -LogName Application -Source "Maintenance" -EventID 1234 -Message "Successfully executed RemoveOldApplicationVersions script in order to purge old versions from Application `n`nEnvironment: $environment - Path: $envPath  `n`n$Log" -EntryType Information  }

Catch [System.Management.Automation.ParameterBindingException] {
     $today = Get-Date
     Set-content -Path "C:\Temp\RemoveOldApplicationVersions_$($environment)_$($today.Year.toString())$($today.Month.toString())$($today.Day.toString()).txt" -Value $log
     Write-Eventlog -LogName Application -Source "Maintenance" -EventID 1234 -Message "Successfully executed RemoveOldApplicationVersions script in order to purge old versions from Application `n`nEnvironment: $environment - Path: $envPath  `n`n The folder removal detail is too big for the Event Log. You can find it at `"C:\Temp\RemoveOldApplicationVersions_$($environment)$($today.Year.toString())$($today.Month.toString())$($today.Day.toString()).txt`"" -EntryType Information -ErrorAction Stop
  }
}
