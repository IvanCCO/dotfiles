# Theme
oh-my-posh --init --shell pwsh --config "C:\Program Files (x86)\oh-my-posh\themes\jandedobbeleer.omp.json" | Invoke-Expression


# Aliases
Set-Alias winfetch pwshfetch-test-1


# ==== AUTOCOMPLETE ===== #
Import-Module PSReadLine

# Shows navigable menu of all options when hitting Tab
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# Autocompleteion for Arrow keys
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

Set-PSReadLineOption -ShowToolTips
Set-PSReadLineOption -PredictionSource History
