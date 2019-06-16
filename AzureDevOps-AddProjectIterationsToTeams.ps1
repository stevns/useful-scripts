# Variables required for the script
$orgUrl = "https://dev.azure.com/organisationname"
$personalToken = "personalaccesstoken"
$projectId = "projectname"

# Pass the required authorization ifo using PAT token
Write-Host "Initialize authentication context" -ForegroundColor Yellow
$token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($personalToken)"))
$header = @{authorization = "Basic $token"}

#Set the overall URL to be used
$tfsBaseUrl = $orgUrl
$projectiterations = ''

# Let's start by getting all of the classification nodes at the project level.
$projectclassificationnodesUrl = "$($tfsBaseUrl)/$($projectId)/_apis/wit/classificationnodes?`$`depth=2&api-version=5.1-preview"
$projectclassificationnodes = Invoke-RestMethod -Uri $projectclassificationnodesUrl -Method Get -ContentType "application/json" -Headers $header

# We don't care about area path, so let's just get the set of iterations that are children of root
$projectclassificationnodes.value | ForEach-Object {
    if ($_.structureType -eq "iteration"){
        $projectiterations = $_.children
    }
}

# Query the API for all teams in our project
$projectteamsurl = "$($tfsBaseUrl)/_apis/projects/$($projectId)/teams?api-version=5.0"
$projectteams = Invoke-RestMethod -Uri $projectteamsurl -Method Get -ContentType "application/json" -Headers $header

# Iterate over those teams
$projectteams.value | ForEach-Object {
    # Display the team name
    Write-Host "+ $($_.name)"
    
    # Query for the iterations inside of this team
    $iterationsinteamurl = "$($tfsBaseUrl)/$($projectId)/$($_.id)/_apis/work/teamsettings/iterations?api-version=5.0"
    $iterationsinteam = Invoke-RestMethod -Uri $iterationsinteamurl -Method Get -ContentType "application/json" -Headers $header

    # Iterate over the project level iterations
    # Check if the project level iteration exists in the context of this team
    # If it does not exist, send a post to the API
    # If it exists, output that the iteration exists
    $projectiterations | ForEach-Object {
        $value = $iterationsinteam.value | Where-Object -Property name -Contains -Value $_.name
        if ($value -eq $null){
            Write-Host "-- $($_.name) needs to be added" -ForegroundColor Yellow
            $idToPost = $_.identifier
            $hash = @{id="$idToPost";}
            $json = $hash | convertTo-Json
            Invoke-WebRequest -Uri $iterationsinteamurl -Method POST -Body $json -ContentType "application/json"  -Headers $header
        } else {
            Write-Host "== $($_.name) exists" -ForegroundColor Green
        }
   }
} 