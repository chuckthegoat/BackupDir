<#
	.SYNOPSIS
		Script to backup a directory tree to another location.
	.DESCRIPTION
		Backups up a directory tree after creating hard links of previously
		backed up files.
	
		Backups are saved to $backups_root\$date where date is the date of
		that backup. By default 30 backups are kept before the oldest is
		deleted.
	.NOTES
		Created by: Joseph Shea-Bianco
	.PARAMETER target
		The directory tree to be backed up.
	.PARAMETER backups_root
		The root directory for backups to be saved to.
#>

$count=30
$date=$(Get-Date -Format "yyyy-MM-dd")

function CreateLinks {
	# Takes a target directory and a destination directory and recursively creates hard links of every file
	# inside of the target directory in the destination.
	#
	# $target and $dest should both be absolute paths.

	Param(
		[string]$target,
		[string]$dest
	)

	$starting_dir=Get-Location
	cd $target

	foreach ($directory in Get-ChildItem -Recurse | ?{ $_.PSIsContainer } | Resolve-Path -Relative) {
		New-Item -ItemType Directory -Path $dest -Name $directory -Value $directory -ea stop
	}

	foreach ($item in Get-ChildItem -Recurse . | where { ! $_.PSIsContainer } | Resolve-Path -Relative) {
        cmd.exe /c mklink /H $dest"\"$item $item
	}

	Set-Location $starting_dir
}

function GetLast {
	# Returns the last created backup

	Param(
		[string]$backups_root
	)
	
	return Get-ChildItem $backups_root | ?{ $_.PSIsContainer } | Where-Object { $_.Name -Match "\d\d\d\d-\d\d-\d\d" } | Sort-Object Name | Select-Object -Last 1 | Convert-Path
}

function MakeBackup {
	# Creates a new backup directory in $backups_root, builds hard links for every file in the last backup,
	# then mirrors any new files from the target directory over to the new backup.

	Param(
		[string]$target,
		[string]$backups_root
	)
	
	if (!(Test-Path $backups_root"\logs")) {
		New-Item -ItemType Directory -Path $backups_root -Name "logs"
	}

	$last_backup=$(GetLast -backups_root $backups_root)
	$new_backup=$backups_root+"\"+$date
    
	try {
		if (Compare-Object $last_backup $new_backup) {
            New-Item -ItemType Directory -Path $backups_root -Name $date -ea stop
			CreateLinks -target $last_backup -dest $new_backup
		}
	} catch {
		$_
	}

	robocopy $target $backups_root"\"$date /mir /XJD /XA:H > $backups_root"\logs\"$date".log"

	while ($(Get-ChildItem | ?{ $_.PSIsContainer } | Where-Object { $_.Name -Match "\d\d\d\d-\d\d-\d\d" } | Measure).Count -gt $count) {
		foreach ($backup in Get-ChildItem $backups_root | ?{ $_.PSIsContainer } | Where-Object { $_.Name -Match "\d\d\d\d-\d\d-\d\d" } | Sort-Object Name | Select-Object -First 1) {
			Remove-Item -Recurse -Force $backup
		}
	}
}


# MakeBackup -target C:\Users\myHomeDir -backups_root D:\Backup\myHomeDir
