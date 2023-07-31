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
        [string]$SystemPrompt = "You are an assistant that helps creating content based on a sequence of questions that you ask and answers the user provides. You will ask one question and wait for one answer, only then you will ask the next question. For maximum efficiency, your questions must be simple YES/NO or simple multiple-choice, do not ask open questions. You will design each next question to maximize the knowledge you accumulate about the subject. Afer the user answers your last question you will output a rich and meaningul seamless document based on the original request of the user and you will start that last response with the string ---COMPLETE---.",
        [Int32]$MaxToken = 8000,
        [string]$TokenType = 'Bearer',
        [string]$ModelURI = "https://oa-ucefdev-openai-2.openai.azure.com/openai/deployments/ucefdev-language-16k/chat/completions?api-version=2023-03-15-preview",
        [switch]$Verbose
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
Connect-AzAccount -UseDeviceAuthentication
$aiToken = Get-AzAccessToken -ResourceUrl 'https://cognitiveservices.azure.com'

# Demo user prompt
$CreateCVPropmpt = "I want to create a CV but I dont know how, so: come up with 6 questions that will build an excellent CV for me. Do not ask me contact details, as I will complete these later. Ready? Ask question one:"

# loop until complete response.
Remove-Variable r, x -ErrorAction SilentlyContinue
$a = $CreateCVPropmpt
while ($x -notlike "*---COMPLETE---*") {
    if ($r) {
        $r = Get-LLMResponse  -TokenValue $aiToken.Token -userPrompt $a -PreviousObject $r -ver
    } else {
        $r = Get-LLMResponse  -TokenValue $aiToken.Token -userPrompt $a
    }
    cls
    $x = Find-LastAssistantMessage $r
    $a = Read-Host "$($x)" 
}


$r2 = Get-LLMResponse -TokenValue $aiToken.Token -PreviousObject $r1 -userPrompt $a1 

$x = Find-LastAssistantMessage $r2
$a2 = Read-Host "$($x)" 

$r3 = Get-LLMResponse -TokenValue $aiToken.Token -PreviousObject $r2 -userPrompt $a2
$h2 = @{}
$r2.psobject.properties | 
    ForEach-Object { $h2[$_.Name] = $_.Value }
$h = @{
    $h1,
    $h2
}

#$response = Invoke-WebRequest -Uri $aiuri -Method POST -Headers $authHeader -Body $body  

| Out-Host


        $codeMessage = @{
    "role" = "user"
    "content"= $AssistantResponse | ConvertTo-Json
    }
$CommentPrompt = "You are an API function that takes an input block of text from the user that may contain programming or scripting code, or a combination of text an code. You will first detect the programming or scripting language of the code. Then you will convert any non-runnable text or comments into syntactically and contextually correct code in the format of the original language."
$bodyCode = @{  
    "messages" = @(  
        @{  
            "role" = "system"  
            "content" = $CommentPrompt
        },
        $codeMessage 
    )  
    "max_tokens" = $MaxToken  
    "temperature" = 0.3  
    "frequency_penalty" = 0  
    "presence_penalty" = 0  
    "top_p" = 0.95  
    "stop" = $null  
} | ConvertTo-Json -Compress

$apiCodeResponse = Invoke-RestMethod -Method Post -Uri $aiuri -Headers $aiHeaders -Body $bodyCode

$runnableCode = $apiCodeResponse.choices.message.content 

Write-Host "Now I will do what no human should allow ever - to run AI-generated code." -ForegroundColor Yellow -BackgroundColor Red
write-host 
$runnableCode | Out-Host
Write-Host "Remember SKYNET!!" -ForegroundColor Yellow -BackgroundColor Red
write-host 
$answer = Read-Host "Type YES to save and run the code block above:" 
if ($answer = 'YES') {
    $runnableCode | Out-File $outputCodeFileName 
    & .\$outputCodeFileName
}
