# This script is a demo of the function to submit a LLM response (using Azure OpenAI)

# This function takes a few parameters and submits an LLM (Azure OpenAI) request, it can take chat history if needed.
function Get-LLMResponse {
    [CmdletBinding()]
    param (
        [Parameter(Position=0,mandatory=$true)]
        [string]$userPrompt,
        [Parameter(mandatory=$true)]
        [string]$TokenValue,
        [Parameter(mandatory=$false)]
        $PreviousObject,
        [string]$SystemPrompt = 'You are a chat-type assistant that will answer open questions.',
        [Parameter(mandatory=$false)]
        [Int32]$MaxToken = 8000,
        [string]$TokenType = 'Bearer',
        [string]$ModelURI = "https://oa-ucefdev-openai-2.openai.azure.com/openai/deployments/ucefdev-language-16k/chat/completions?api-version=2023-03-15-preview"
    )

    # init request elements
    $messages = @()

    # System Prompt
    $SystemHash = @{
            "role" = "system"  
            "content" = $SystemPrompt 
    }
    $messages += $SystemHash

    # Chat History
    if ($PSBoundParameters.ContainsKey('PreviousObject')) {
        $messages += $PreviousObject
    }
    
    # Current iterations' users' prompt
    $usermessage = @{
        "role" = "user"
        "content"= $userPrompt
    }
    $messages += $usermessage

    # Build JSON request body
    $body = @{  
        "messages" = $messages
        "max_tokens" = $MaxToken  
        "temperature" = 0.5  
        "frequency_penalty" = 0  
        "presence_penalty" = 0  
        "top_p" = 0.95  
        "stop" = $null  
    } | ConvertTo-Json -Compress
    
    $body | Write-Verbose
    $aiHeaders = @{
        'Authorization' = "$($TokenType) $($TokenValue)"
        'Content-type' = 'application/json'
      }
    
    # Finally, submit REST 
    $apiResponse = Invoke-RestMethod -Method Post -Uri $ModelURI -Headers $aiHeaders -Body $body

    # Build function output including history
    Remove-Variable h,myOutput -ErrorAction SilentlyContinue
    $myOutput = @()
    
    if ($PSBoundParameters.ContainsKey('PreviousObject')) {
        $myOutput += $PreviousObject
    }
    $myOutput += $usermessage
    
    # it needs to be a hash...
    $h = @{}
    $apiResponse.choices.message.psobject.properties | 
        ForEach-Object { $h[$_.Name] = $_.Value }
    $myOutput += $h
    
    # just return the object.
    $myOutput
}

# separate function to parse the last assistant response, just to make code more readable
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

# Login 
if ($aitoken) {
    Write-Host "Already logged in as `"$($aitoken.UserId)`"."
} else {
    Connect-AzAccount -UseDeviceAuthentication
}
if ($aiToken.ExpiresOn -le (get-date))  {
    $aiToken = Get-AzAccessToken -ResourceUrl 'https://cognitiveservices.azure.com'
}

# Demo user prompt
$CreateCVSystem = "You are an assistant that helps creating content based on a sequence of questions that you ask and answers the user provides. You will ask one question and wait for one answer, only then you will ask the next question. You will design each next question to maximize the knowledge you accumulate about the subject. After the user answers your last question you will output a rich and meaningul seamless document based on the original request of the user and you will start that last response with the string ---COMPLETE---. Before each question you will inform the user a rough estimate how much information you think is needed the user has already provided in the format of `"You have answered x number of questions, I think with y more questions The information you have provided will be enough`". For maximum efficiency, ALWAYS ask in the form of simple multiple-choice prompting using letters for each choice. NEVER ask open-ended questions."
$CreateCVPrompt = "I want to create a CV but I dont know how, so: come up with a number of questions and when you have enough information, build a complete rich CV. The name and contact information should be in the last question. Ready? Ask question one:"

# loop until complete response.
Remove-Variable r -ErrorAction SilentlyContinue
$exit = $false
$a = $CreateCVPrompt
[string[]]$x = ''
do {
    if ($r) {
        $r = Get-LLMResponse -TokenValue $aiToken.Token -userPrompt $a -PreviousObject $r -SystemPrompt $CreateCVSystem
    } else {
        $r = Get-LLMResponse -TokenValue $aiToken.Token -userPrompt $a -SystemPrompt $CreateCVSystem
    }
    cls
    Write-Host "Type EXIT to quit."
    IF ($r) {
        $x = Find-LastAssistantMessage $r
    }
    else {
        write-host "LLM Response was null or unexpected result, exiting." -ForegroundColor Yellow
        $exit = $true
    }
    if ($x) {
        $a = Read-Host "$($x)"
        if ($a -eq 'EXIT') {
            $exit = $true
        }   
    }
} until ([Boolean]($x | Select-String "---COMPLETE---" -SimpleMatch) -or $exit) 