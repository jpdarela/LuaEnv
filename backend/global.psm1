$VerbosePreference = "SilentlyContinue"

[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='This variable is exported for use by other modules.')]
$DEBUG_MESSAGES = "SilentlyContinue" # "Continue" #

# EXPORT VARIABLES
Export-ModuleMember -Variable "DEBUG_MESSAGES"