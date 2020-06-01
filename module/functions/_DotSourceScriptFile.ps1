# <copyright file="_DotSourceScriptFile.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Dot sources the specified file and returns the output.

.DESCRIPTION
Dot sources the specified file and returns the output - this function exists to aid testability.

.PARAMETER ConfigPath
The path to the file being dot sourced.

#>
function _DotSourceScriptFile
{
    param
    (
        $Path
    )

    $(. "$Path")
}