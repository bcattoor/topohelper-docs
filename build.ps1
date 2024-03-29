# functions

function Remove-Folders {
    [CmdletBinding()]
    param([parameter(Mandatory = $true)][System.IO.DirectoryInfo[]] $Folders) 
    if ( $Folders -eq "" -or $Folders.Count -eq 0 ) {
        Write-Verbose "No folders to delete."
    }
    else {
        foreach ($Folder in $Folders) {
            Remove-Folder $Folder
        } 
    }
}

function Remove-Folder {
    [CmdletBinding()]
    param ([parameter(Mandatory = $true)][System.IO.DirectoryInfo] $FolderPath ) 
    if ( $FolderPath.Exists ) {
        #http://stackoverflow.com/questions/7909167/how-to-quietly-remove-a-directory-with-content-in-powershell/9012108#9012108
        Get-ChildItem -Path  $FolderPath.FullName -Force -Recurse | Remove-Item -Force -Recurse
        Remove-Item $FolderPath.FullName -Force
        Write-Verbose "Deleted folder: $FolderPath.FullName"
    }
    else { Write-Warning "Failed to delete folder-path: $FolderPath.FullName, folder was not found." }
}

function Remove-Files {
    [CmdletBinding()]
    param ([parameter(Mandatory = $true)][System.IO.FileInfo[]] $FilesToDelete ) 
    if ( $FilesToDelete -eq "" -or $FilesToDelete.Count -eq 0 ) {
        Write-Verbose "No files to delete."
    }
    else {
        foreach ($File in $FilesToDelete) {
            if ( $File.Exists ) {
                Remove-Item $File.FullName -Force -ErrorAction Stop
                Write-Verbose "Deleted file:  $File.FullName"
            }
            else { Write-Warning "Failed to delete file-path: $File.FullName, file was not found." }
        } 
    }
}

function Push-GitRepository {
    param ([parameter(Mandatory = $true)][string] $FolderContext) 
    # Publish changes to github
    $WorkingFolder = Get-Location
    Set-Location $FolderContext
    try {  
        Invoke-Utility git add -A
        Invoke-Utility git commit -m "Update from PS."
        Invoke-Utility git push
    }
    catch { Throw }
    finally {
        Set-Location $WorkingFolder
    }
}

function Stop-Processes {
    param([parameter(Mandatory = $true)][string] $processName, [int]$timeout = 1)
    $processList = Get-Process $processName -ErrorAction SilentlyContinue
    if ($processList) {
        # Try gracefully first
        $processList.CloseMainWindow() | Out-Null
        timeout 1
        # Else: kill
        $processList = Get-Process $processName -ErrorAction SilentlyContinue
        if ( $processList -ne "" -or $processList.Count -ne 0 ) {
            foreach ($process in $processList) {
                Stop-Process -Force $process
                Write-Warning "Forcefully KILLED process $process"
            }
        }
        Write-Verbose "process stopped gracefully: $processName"
    }
    else {
        Write-Verbose "Did not find Process to stop: $processName"
    }
}

function Open-WithExplorer {
    [CmdletBinding()]
    param ([parameter(Mandatory = $true)][string] $Url ) 
    Write-Verbose "|___/--> Opening $Url" 
    explorer $Url 
}

function Invoke-Utility {
    <#
.SYNOPSIS
Invokes an external utility, ensuring successful execution.
https://stackoverflow.com/a/48877892

.DESCRIPTION
Invokes an external utility (program) and, if the utility indicates failure by 
way of a nonzero exit code, throws a script-terminating error.

* Pass the command the way you would execute the command directly.
* Do NOT use & as the first argument if the executable name is not a literal.

.EXAMPLE
Invoke-Utility git push

Executes `git push` and throws a script-terminating error if the exit code
is nonzero.
#>
    $exe, $argsForExe = $Args
    $ErrorActionPreference = 'Continue' # to prevent 2> redirections from triggering a terminating error.
    # The ampersand (&) here tells PowerShell to execute that command, instead of treating it as a cmdlet or a string. 
    try { & $exe $argsForExe } catch { Throw } # catch is triggered ONLY if $exe can't be found, never for errors reported by $exe itself
    if ($LASTEXITCODE) { Throw "$exe indicated failure (exit code $LASTEXITCODE; full command: $Args)." }
}

################################################################################
###############CODE####STARTS####HERE###########################################
################################################################################
# When the script is not able to be executed:
# INFO: Set-ExecutionPolicy Unrestricted -Scope Process -Force 

# INPUT
$arguments = "local", "local-fast" , "push" , "push-fast" , "pdf" 
$DestinationPath = "C:\Users\cwn8400\Documents\GitHub\topohelper-github_pages"
$SourcePath = ".\_build\html"
$PrefferedBrowser = "msedge"
$urls = @(
    "C:\Users\cwn8400\Documents\GitHub\topohelper-docs\_build\html\index.html", 
    "https://bcattoor.github.io/topohelper/",
    "C:\Users\cwn8400\Documents\GitHub\topohelper-docs\_build\latex\topohelper.pdf")
$Push = 0 # Push to github?
$PDF = 0 # make a PDF?
$FastRun = 0 # run fast?
if ($args.Count -eq 0 -or $args[0] -eq "" -or $arguments.Contains($args[0]) -ne 1) { Write-Error "Please provide one of the following arguments: $arguments"; return; }
if ($args[0] -eq "local") { $FastRun = 0 }
if ($args[0] -eq "local-fast") { $FastRun = 1 }
if ($args[0] -eq "push") { $Push = 1 }
if ($args[0] -eq "push-fast") { $FastRun = 1; $Push = 1 }
if ($args[0] -eq "pdf") { $PDF = 1 }
# END INPUT
################################################################################

if (!$FastRun) { Stop-Processes $PrefferedBrowser }
if (!$FastRun) { ./make clean }
./make html
if ($PDF) { ./make latexpdf }

if (!$FastRun -or $Push) {
    # Copy generated files to the topohelper repository responsible for publishing
    # GO GET all child folders who are not named ".git", delete these childfolders
    $FoldersToDelete = Get-ChildItem $DestinationPath -Directory | Where-Object { $_.Name -cnotlike ".git*" }
    if ($FoldersToDelete.Count -ne 0) { Remove-Folders $FoldersToDelete }

    # We also delete files in root folder
    $FilesToDelete = Get-ChildItem -Path $DestinationPath -File | Where-Object { $_.Name -cnotlike ".git*" }
    if ($FilesToDelete.Count -ne 0) { Remove-Files $FilesToDelete }
}

# Copy new files to the destination, we don't use force here, becouse the folder.
if ($Push) {
    Copy-Item $SourcePath\* $DestinationPath -recurse -ErrorAction Stop
    Write-Information "New files were written to the github pages publish-folder here: $DestinationPath" -InformationAction Continue
    Push-GitRepository $DestinationPath 
    Write-Information "The git-command was run in this location: $SourcePath" -InformationAction Continue
}
else { Write-Information "No push to github executed." -InformationAction Continue }
#########################################################
#########################################################
# Show RESULT
if ($Push) { Open-WithExplorer $urls[1] }elseif ($PDF) { Open-WithExplorer $urls[2] }else { Open-WithExplorer $urls[0] }