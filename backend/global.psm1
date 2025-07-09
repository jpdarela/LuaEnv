$VerbosePreference = "SilentlyContinue"

[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='This variable is exported for use by other modules.')]

$VERBOSE_MESSAGES = "SilentlyContinue" # "Continue" #
$DEBUG_MESSAGES = "SilentlyContinue" # "Continue" #
$WARNING_MESSAGES = "SilentlyContinue" # "Continue" #

# EXPORT VARIABLES
Export-ModuleMember -Variable "DEBUG_MESSAGES"
Export-ModuleMember -Variable "VERBOSE_MESSAGES"
Export-ModuleMember -Variable "WARNING_MESSAGES"