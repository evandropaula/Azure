# Helper Functions ------------------------------------------------------>
function WriteHeader($message)
{
    Write-Host 
    Write-Host "******************** $($message) at $(Get-Date -format 'u') ********************" -ForegroundColor Magenta
    Write-Host 
}

function WriteTitle($message)
{
    Write-Host "***** $($message) *****" -ForegroundColor Cyan
}

function WriteText($message)
{
    Write-Host $message -ForegroundColor Yellow
}

function WriteSuccess()
{
    Write-Host "[Done]" -ForegroundColor Green
    Write-Host
    Write-Host
}

function WriteError($message)
{
    Write-Host $message -ForegroundColor Red
}