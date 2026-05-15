@{
    Severity = @('Error', 'Warning')

    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
    )

    Rules = @{
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
        }

        PSUseDeclaredVarsMoreThanAssignments = @{
            Enable = $true
        }

        PSUseConsistentIndentation = @{
            Enable = $true
            Kind = 'space'
            IndentationSize = 4
        }
    }
}
