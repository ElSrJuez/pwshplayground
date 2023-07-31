# Parse LLM Powershell object and grab the string output for the assistant element
function Find-LastAssistantMessage {
    param ($LLMOutput)

    Remove-Variable i,j -ErrorAction SilentlyContinue
    [int]$i = 0
    foreach ($a in $LLMOutput.GetEnumerator()) {
        #Write-Host "$($i) $($a.role) = $($a.content)"
        IF ($a.role -eq 'assistant' ) {$j = $a.content}
        $i++
    }
    $j
}