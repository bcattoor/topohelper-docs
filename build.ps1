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
    git add -A
    git commit -m "Update from PS."
    git push
    Set-Location $WorkingFolder
}

function Stop-Processes {
    param([parameter(Mandatory = $true)][string] $processName, $timeout = 100)
    $processList = Get-Process $processName -ErrorAction SilentlyContinue
    if ($processList) {
        # Try gracefully first
        $processList.CloseMainWindow() | Out-Null

        # Wait until all processes have terminated or until timeout
        for ($i = 0 ; $i -le $timeout; $i ++) {
            Get-Process $processName -ErrorAction SilentlyContinue | ForEach-Object {
                If (!$_.HasExited) { Start-Sleep 1 }                    
            }
        }
        # Else: kill
        $processList = Get-Process $processName -ErrorAction SilentlyContinue
        if ( $processList -ne "" -or $processList.Count -ne 0 ) {
            foreach ($process in $processList) {
                # $processList | Stop-Process -Force | Write-Verbose "Forcefully KILLED process $_.Name"
                Stop-Process -Force $process
                Write-Verbose "Forcefully KILLED process $process.Name"
            }
        }
        Write-Verbose "process stopped gracefully: $processName"
    }
    else {
        Write-Verbose "Did not find Process to stop: $processName"
    }
}

################################################################################
###############CODE####STARTS####HERE###########################################
################################################################################
# INPUT
$DestinationPath = "F:\Source\Repos\documentation\topohelper-github-pages"
$SourcePath = ".\_build\html"
$PrefferedBrowser = "msedge"
$urls = @(
    "F:\Source\Repos\documentation\topohelper-docs\_build\html\index.html", 
    "https://bcattoor.github.io/topohelper/",
    "F:\Source\Repos\documentation\topohelper-docs\_build\latex\topohelper.pdf")
$Push = 0
$PDF = 0
if ($args[0] -eq "gh") { $Push = 1 }
if ($args[0] -eq "pdf") { $PDF = 1 }
if ($args[0] -eq "full") { 
    $PDF = 1 
    $Push = 1 
}
# END INPUT
################################################################################

Stop-Processes $PrefferedBrowser -Verbose
./make clean
./make html
if ($PDF) { ./make latexpdf }

# Copy generated files to the topohelper repository responsible for publishing
# GO GET all child folders who are not named ".git", delete these childfolders
$FoldersToDelete = Get-ChildItem $DestinationPath -Directory | Where-Object { $_.Name -cnotlike ".git*" }
Remove-Folders $FoldersToDelete

# We also delete files in root folder
$FilesToDelete = Get-ChildItem -Path $DestinationPath -File | Where-Object { $_.Name -cnotlike ".git*" }
Remove-Files $FilesToDelete

# Copy new files to the destination, we don't use force here, becouse the folder
# should be empty
Copy-Item $SourcePath\* $DestinationPath -recurse
Write-Host "Info: New files were written to the github pages publish-folder here: $DestinationPath"

if ($Push) { Push-GitRepository $DestinationPath }
else { Write-Warning "No push to github executed." }
#########################################################
#########################################################

# Show RESULT = Open local and online pages.
if ($Push) { explorer $urls[1] }
else { explorer $urls[0] }
if ($PDF) { explorer $urls[2] }