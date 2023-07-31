param (
    [string[]]$userTextData,
    [string]$userInstruction = "Please convert the sample BASIC Code below into Powershell Code:" ,
    $outputCodeFileName = "outputScript.ps1"
)

Connect-AzAccount -UseDeviceAuthentication

$sampleBASICCode = 
@"  
10 PRINT "HELLO WORLD!"
20 GOTO 10
"@  

if ($PSBoundParameters.ContainsKey('userTextData')) {  
    
} else {  
    Write-Host "userPrompt was not specified, using sample BASIC Code."
    $userTextData = $sampleBASICCode
}  

$systemPrompt = 'You are an AI API that actions on a pair of parameters, a text instruction and a block of text that may contain code or text and code. You should process the instruction and if it involves generating text, it must syntactically correct, runnable code on the correct programming or scripting language. Your output is a single file containing exclusively programming or scripting language code.'
$MaxToken = 16000


$aiToken = Get-AzAccessToken -ResourceUrl 'https://cognitiveservices.azure.com'

# play with model to change programming language

$aiuri = "https://{oairesource}.openai.azure.com/openai/deployments/{oaimodelname}/chat/completions?api-version=2023-03-15-preview"


$aiHeaders = @{
    'Authorization' = "$($aiToken.Type) $($aiToken.Token)"
    'Content-type' = 'application/json'
  }
Remove-Variable userPrompt -ErrorAction SilentlyContinue
[string[]]$userPrompt = $userInstruction +[environment]::Newline + $userTextData
$usermessage = @{
    "role" = "user"
    "content"= $userPrompt | ConvertTo-Json
  }
$body = @{  
    "messages" = @(  
        @{  
            "role" = "system"  
            "content" = $SystemPrompt 
        },
        $usermessage
    )  
    "max_tokens" = $MaxToken  
    "temperature" = 0.5  
    "frequency_penalty" = 0  
    "presence_penalty" = 0  
    "top_p" = 0.95  
    "stop" = $null  
} | ConvertTo-Json -Compress

#$response = Invoke-WebRequest -Uri $aiuri -Method POST -Headers $authHeader -Body $body  

$apiResponse = Invoke-RestMethod -Method Post -Uri $aiuri -Headers $aiHeaders -Body $body

$apiresponse.choices.message.content | Out-Host

$AssistantResponse = $apiresponse.choices.message | 
    Where-Object {$_.role -eq 'assistant'} | 
        Select-Object -ExpandProperty content

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
