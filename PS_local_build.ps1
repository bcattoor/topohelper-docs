# functions

function DeleteFolders ($Folders) {
    if ( $Folders -eq "" -or $Folders.Count -eq 0 ) {
        Write-Output "No folders to delete."
    }
    else {
        foreach ($Folder in $Folders) {
            
            DeleteFolder $Folder
            Write-Output "Deleted $Folder"
        } 
    }
}

function DeleteFolder ($dir ) {
    if ( Test-Path $dir ) {
        #http://stackoverflow.com/questions/7909167/how-to-quietly-remove-a-directory-with-content-in-powershell/9012108#9012108
        Get-ChildItem -Path  $dir -Force -Recurse | Remove-Item -Force -Recurse
        Remove-Item $dir -Force
    }
}

function DeleteFiles ($FilesToDelete ) {
    if ( $FilesToDelete -eq "" -or $FilesToDelete.Count -eq 0 ) {
        write-host "No files to delete."
    }
    else {
        foreach ($File in $FilesToDelete) {
            Remove-Item $File -Force -ErrorAction SilentlyContinue
            write-host "Deleted $File"
        } 
    }
}

function Stop-Processes {
    param(
        [parameter(Mandatory = $true)] $processName,
        $timeout = 5
    )
    $processList = Get-Process $processName -ErrorAction SilentlyContinue
    if ($processList) {
        # Try gracefully first
        $processList.CloseMainWindow() | Out-Null

        # Wait until all processes have terminated or until timeout
        for ($i = 0 ; $i -le $timeout; $i ++) {
            $AllHaveExited = $True
            $processList | % {
                $process = $_
                If (!$process.HasExited) {
                    $AllHaveExited = $False
                }                    
            }
            If ($AllHaveExited) {
                Return
            }
            sleep 1
        }
        # Else: kill
        $processList | Stop-Process -Force        
    }
}

#########################################################
#########################################################
#########################################################

Stop-Processes "msedge"
./make clean
./make html

#########################################################
#########################################################
# Copy generated files to the topohelper repository responsible for publish to github
$DestinationPath = "F:\Source\Repos\documentation\topohelper-github-pages"
$SourcePath = ".\_build\html"

#  get all child folders who are not named ".git", delete these childfolders
$FoldersToDelete = Get-ChildItem $DestinationPath -Directory -ErrorAction SilentlyContinue -Exclude ".git"
DeleteFolders $FoldersToDelete

# We also delete files in root folder
$FilesToDelete = Get-ChildItem -Path $DestinationPath -File
DeleteFiles $FilesToDelete

# Copy new files to the destination, we don't use force here, becouse the folder
# should be empty
Copy-Item $SourcePath\* $DestinationPath -recurse
Write-Host "New files were written to the github pages publish-folder here: $DestinationPath"

#########################################################
#########################################################


explorer "F:\Source\Repos\documentation\topohelper-docs\_build\html\welcome.html"