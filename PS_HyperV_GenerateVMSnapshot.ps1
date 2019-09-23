	#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	# Script:   GenerateNewVMSnapshot.ps1
	# Author:   Demian Gomez
	# Date:     02/18/2013
	# Version:  1.0
  # Usage:    It can be used to take periodic Hyper-V snapshots of a VM using a schedule and sending an email report
  # Command line to execute script from Scheduled task: 
  # Powershell.exe -ExecutionPolicy Bypass -command "& C:\VirtualMachines\GenerateNewVMSnapshot.ps1 -VMname VirtualMachine -emailServer "smtp.server.com";exit $LASTEXITCODE"
	#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	#Script Parameters 
	param ([String] $VMname=$null, [string] $emailServer="smtp.domain.com")
	
	# Call to Import Hyper-V Powershell Module IF NOT LOADED - Downloaded from http://pshyperv.codeplex.com/
	if (!(Get-Module -Name HyperV)) {Import-Module HyperV}
	
	#Function to delete current snapshot and merge it (if needed) and then take a new one.
	Function New.VM.Snapshot ($VirtualMachine) {
	
	$Snaps = (Get-VMSummary $VirtualMachine).Snapshots
	
	If ($Snaps -eq $null) {
		New-VMSnapshot $VirtualMachine -force -wait
	}	 
	Else { 
	  Remove-VMSnapshot (Get-VMSnapshot $VirtualMachine) -force -Wait
		Invoke-VMShutdown $VirtualMachine -force
	 	Start-Sleep 60
	 	Start-VM $VirtualMachine -HeartBeatTimeOut 120
	 	New-VMSnapshot $VirtualMachine -force -wait
	 }
	} #End Function
		
	#-----------------
	# Script Variables
	#-----------------
	
	$VM = Get-VM ($VMname)
	$MailServer = $emailServer
	$SubjectSuccess = "["+ $VM.VMElementName + "] Hyper-V VM Snapshot was successful"  	
	$SubjectFailed  = "["+ $VM.VMElementName + "] Hyper-V VM Snapshot Failed. Check Hyper V Server [" + $VM.__SERVER +"]"
	$IT = "IT@domain.com>"
	$Body = Get-VMState $VM | Select Host,VMElementName,UptimeFormatted,EnabledState,IPAddress | ConvertTo-HTML | Out-String
	
	
	#----------------
	# Script START
	#----------------
	
	#To start script logging remove "#" if needed.
	
	$ErrorActionPreference = "Stop"
	Start-Transcript -Path "C:TEMP\GenerateVMSnapshot.log"
	
	# Check VM status and act based on that. 
	# State "2" means VM is started. State "3" means it's turned off.
	
	#If VM is started then take snapshot and send email with success.	
	
	If ($VM.OperationalStatus -eq 2) {
	    New.VM.Snapshot ($VM)
	    Send-MailMessage -From $Infra -To $Infra -Subject $SubjectSuccess -body $Body -bodyAsHTML -SMTPServer $MailServer
		exit 0x0
	 }
			
	#Else if VM is stopped then start it and then take snapshot and send email with success. Exit with success.
	
	ElseIf ($VM.OperationalStatus -eq 3) {
		Start-VM $VM -HeartBeatTimeOut 120
		New.VM.Snapshot ($VM)
		Send-MailMessage -From $Infra -To $Infra -Subject $SubjectSuccess -body $Body -bodyAsHTML -SMTPServer $MailServer
		exit 0x0
	 }
	
	#Else send email with failure due to not usable VM status. Exit with failure code0x500
	
	Else {
	    
	    Send-MailMessage -From $Infra -To $Infra -Subject $SubjectFailed -body $Body -bodyAsHTML -priority High -SMTPServer $MailServer
		exit 0x500
	}
	
	#Remove "#" to see script output for troubleshooting.
	
	Stop-Transcript
	
			
	#----------------
	# Script END
	#----------------
