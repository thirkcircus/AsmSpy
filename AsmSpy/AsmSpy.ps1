param(
  [parameter(Mandatory=$true)]
  [ValidateScript({Test-Path $_ -PathType Container})]
  [string]$binDirectory,
  [string]$specificAssembly,
  [switch]$includeSystemAssemblies
)

Set-PSDebug -Strict

$assemblyFiles = gci $binDirectory -Recurse -include *.dll

if (!$assemblyFiles){
  Write-Warning "No dll files found in dir $binDirectory"
  return
}

Write-Host "Checking assemblies in `"$binDirectory`""

$assemblyDetails=@{}

foreach ($file in $assemblyFiles) {
  # load the assembly
  Write-Debug "Processing $($file.Name)"
  try {
    $assembly = [System.Reflection.Assembly]::LoadFrom($file)
  }
  catch [System.Exception]{
    Write-Error $_.Exception.ToString()
    Write-Warning "Failed to load assembly: $($assembly.FullName)"
    continue
  }	
  # check all referenced assemblies for this assembly
  foreach($referencedAssembly in $assembly.GetReferencedAssemblies()){
    Write-Verbose "Referenced assembly: $($referencedAssembly.Name)"
    if(!$assemblyDetails.ContainsKey($referencedAssembly.Name)){
      $assemblyDetails[$referencedAssembly.Name] = New-Object System.Collections.ArrayList
    }
    $assemblyDetails[$referencedAssembly.Name].Add(@($referencedAssembly.Version,$assembly.GetName().Name)) | Out-Null
  }
}

#report results
$assemblyDetails.GetEnumerator() | Sort-Object Name | ForEach-Object {
  $referencedAssembly = $_.key
  Write-Debug "Showing assemblies dependant on $($referencedAssembly)"
  # exclude system assemblies unless specified
  if(!$includeSystemAssemblies -and ($referencedAssembly.StartsWith("System") -or $referencedAssembly -eq "mscorlib")){
    Write-Debug "Skipping system assembly $referencedAssembly"
    return
  } 

  $matchesSpecificAssembly = ($specificAssembly -and ($referencedAssembly.IndexOf($specificAssembly, [System.StringComparison]::OrdinalIgnoreCase) -gt 0))
  Write-Host "Reference: $referencedAssembly" -ForegroundColor $(if($matchesSpecificAssembly){"Red"} else {"DarkGreen"})
  foreach($referencedAssembly in $_.value){
    Write-Host "`t$($referencedAssembly[0]) by $($referencedAssembly[1])" -ForegroundColor DarkGray
  }
}
