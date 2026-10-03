@{
    Severity = @('Error')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSUseShouldProcessForStateChangingFunctions'
    )
    Rules = @{
        PSAvoidUsingCmdletAliases = @{ Whitelist = @('%','?','cd','echo','foreach','group','history','ls','measure','mkdir','popd','pushd','pwd','sleep','sort','where','write') }
    }
}
