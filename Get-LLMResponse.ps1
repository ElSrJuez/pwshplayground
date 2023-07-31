# This script is a demo of the function to submit a LLM response (using Azure OpenAI)

# This function takes a few parameters and submits an LLM (Azure OpenAI) request, it can take chat history if needed.
function Get-LLMResponse {
    [CmdletBinding()]
    param (
        [Parameter(Position=0,mandatory=$true)]
        [string]$userPrompt,
        [Parameter(mandatory=$true)]
        [string]$TokenValue,
        [Parameter(mandatory=$true)]
        [string]$ModelURI,
        [Parameter(mandatory=$false)]
        $PreviousObject,
        [string]$SystemPrompt = 'You are a chat-type assistant that will answer open questions.',
        [Parameter(mandatory=$false)]
        [Int32]$MaxToken = 8000,
        [string]$TokenType = 'Bearer',
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