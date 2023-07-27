function Get-LLMResponse {
    param (
        [string]$userPrompt = "I want to create a CV but I dont know how, so: come up with 6 questions that will but excellent CV for me. Ready? Ask question one:",
        [string]$SystemPrompt = "You are an assistant that helps creating content based on a sequence of questions that you ask and answers the user provides. Your questions must be simple YES/NO or simple multiple-choice. You will ask one question and wait for one answer, only then you will ask the next question. For maximum efficiency, you will desigin each next question to maximize the knowledge you accumulate about the subject. Afer I answer your last question you will output a rich and meaningul seamless document based on the original request of the user.",
        [string]$TokenValue,
        $PreviousObject,
        [Int32]$MaxToken = 8000,
        [string]$TokenType = 'Bearer',
        [string]$ModelURI = "https://oa-ucefdev-openai-2.openai.azure.com/openai/deployments/ucefdev-language-16k/chat/completions?api-version=2023-03-15-preview"
    )

    $usermessage = @{
        "role" = "user"
        "content"= $userPrompt
    }



    $usermessage | Out-Host


    if ($PSBoundParameters.ContainsKey('PreviousObject')) {
        Remove-Variable ht -ErrorAction SilentlyContinue
        $body = @{  
            "messages" = @(  
                @{  
                    "role" = "system"  
                    "content" = $SystemPrompt 
                },
                $usermessage,
                $ht
            )  
            "max_tokens" = $MaxToken  
            "temperature" = 0.5  
            "frequency_penalty" = 0  
            "presence_penalty" = 0  
            "top_p" = 0.95  
            "stop" = $null  
        } | ConvertTo-Json 
        
    } else {
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
        } | ConvertTo-Json 
    }

    $aiHeaders = @{
        'Authorization' = "$($TokenType) $($TokenValue)"
        'Content-type' = 'application/json'
      }
    
    $body | Out-Host
    $apiResponse = Invoke-RestMethod -Method Post -Uri $ModelURI -Headers $aiHeaders -Body $body

    Remove-Variable ho -ErrorAction SilentlyContinue
    $ho = @{}
    $apiResponse.choices.message.psobject.properties | 
        ForEach-Object { $ho[$_.Name] = $_.Value }
    if ($PSBoundParameters.ContainsKey('PreviousObject')) {
        $out = @{
            "messages" = @(
                $usermessage,
                $ht,
                $ho
            )
        }
    } else {
        $out = @{
            "messages" = @(
                $usermessage,
                $ho
            )
        }
    
    }
    $out
}



Connect-AzAccount -UseDeviceAuthentication

$aiToken = Get-AzAccessToken -ResourceUrl 'https://cognitiveservices.azure.com'


$r1 = Get-LLMResponse  -TokenValue $aiToken.Token

$h1 = @{}
$r1.psobject.properties | 
    ForEach-Object { $h1[$_.Name] = $_.Value }


$a1 = Read-Host "$($r1.content)" 

$r2 = Get-LLMResponse -TokenValue $aiToken.Token -PreviousObject $r1 -userPrompt $a1 
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
