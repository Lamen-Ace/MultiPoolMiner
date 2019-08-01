﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\EthDcrMiner64.exe"
$HashSHA256 = "640D067A458117274E4FF64F269082E9CE62AB9D5AC4D60ED177ED97801B4649"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/ethdcrminer64/ClaymoreDual_v14.7.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=1433925.0"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "";        Params = ""} #Ethash2gb
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; Params = ""} #Ethash2gb/Blake2s
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred";  Params = ""} #Ethash2GB/Decred
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak";  Params = ""} #Ethash2GB/Keccak
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry";    Params = ""} #Ethash2GB/Lbry
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal";  Params = ""} #Ethash2GB/Pascal
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "sia";     Params = ""} #Ethash2GB/Sia
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "";        Params = ""} #Ethash3GB
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; Params = ""} #Ethash3GB/Blake2s
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred";  Params = ""} #Ethash3GB/Decred
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak";  Params = ""} #Ethash3GB/Keccak
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry";    Params = ""} #Ethash3GB/Lbry
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal";  Params = ""} #Ethash3GB/Pascal
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "sia";     Params = ""} #Ethash3GB/Sia
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "";        Params = ""} #Ethash
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; Params = ""} #Ethash/Blake2s
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "decred";  Params = ""} #Ethash/Decred
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "keccak";  Params = ""} #Ethash/Keccak
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "lbry";    Params = ""} #Ethash/Lbry
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "pascal";  Params = ""} #Ethash/Pascal
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "sia";     Params = ""} #Ethash/Sia
    )
}

$SecondaryAlgoIntensities = [PSCustomObject]@{
    "blake2s" = @(40, 60, 80)
    "decred"  = @(20, 40, 70)
    "keccak"  = @(20, 30, 40)
    "lbry"    = @(60, 75, 90)
    "pascal"  = @(20, 40, 60)
    "sia"     = @(20, 40, 60, 80)
}

#Intensities from config file take precedence
$Miner_Config.SecondaryAlgoIntensities.PSObject.Properties.Name | Select-Object | ForEach-Object {
    $SecondaryAlgoIntensities | Add-Member $_ $Miner_Config.SecondaryAlgoIntensities.$_ -Force
}

$Commands | ForEach-Object {
    if ($_.SecondaryAlgorithm) {
        $Command = $_
        $SecondaryAlgoIntensities.$($_.SecondaryAlgorithm) | Select-Object | ForEach-Object {
            if ($null -ne $Command.SecondaryAlgoIntensity) {
                $Command = ($Command | ConvertTo-Json | ConvertFrom-Json)
                $Command | Add-Member SecondaryAlgoIntensity ([String] $_) -Force
                $Commands += $Command
            }
            else {$Command | Add-Member SecondaryAlgoIntensity $_}
        }
    }
}

#CommonCommandsAll from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParametersAll = $Miner_Config.CommonParametersAll}
else {$CommonParametersAll = " -dbg -1 -strap 1"}

#CommonCommandsNvidia from config file take precedence
if ($Miner_Config.CommonParametersNvidia) {$CommonParametersNvidia = $Miner_Config.CommonParametersNvidia}
else {$CommonParametersNvidia = " -platform 2"}

#CommonCommandsAmd from config file take precedence
if ($Miner_Config.CommonParametersAmd) {$CommonCommmandAmd = $Miner_Config.CommonParametersAmd}
else {$CommonParametersAmd = " -platform 1 -y 1 -rxboost 1"}

$Devices = @($Devices | Where-Object Type -EQ "GPU")
$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    switch ($_.Vendor) {
        "Advanced Micro Devices, Inc." {$CommonParameters = $CommonParametersAmd + $CommonParametersAll}
        "NVIDIA Corporation" {$CommonParameters = $CommonParametersNvidia + $CommonParametersAll}
        Default {$CommonParameters = $CommonParametersAll}
    }

    #Remove -strap parameter, not all card models support it
    if ($Device.Model_Norm -notmatch "^GTX10.*|^Baffin.*|^Ellesmere.*|^Polaris.*|^Vega.*|^gfx900.*") {
        $CommonParameters = $CommonParameters -replace " -strap [\d,]{1,}"
    }
    
    $Commands | ForEach-Object {$Main_Algorithm_Norm = Get-Algorithm $_.MainAlgorithm; $_} | Where-Object {$Pools.$Main_Algorithm_Norm.Host} | ForEach-Object {
        $Main_Algorithm = $_.MainAlgorithm
        $MinMemGB = $_.MinMemGB
        $Parameters = $_.Parameters

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            #Get parameters for active miner devices
            if ($Miner_Config.Parameters.$Main_Algorithm_Norm) {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$($Main_Algorithm_Norm) $Miner_Device.Type_Vendor_Index
                if ($Miner_Config.Parameters.$Secondary_Algorithm_Norm -and $Secondary_Algorithm_Norm -and $_.SecondaryAlgoIntensity -gt 0) {
                    $Parameters += Get-ParameterPerDevice $Miner_Config.Parameters.$($Secondary_Algorithm_Norm) $Miner_Device.Type_Vendor_Index
                }
            }
            elseif ($Miner_Config.Parameters."*") {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
            }
            else {
                $Parameters = Get-ParameterPerDevice $Parameters $Miner_Device.Type_Vendor_Index
            }

            if ($null -ne $_.SecondaryAlgoIntensity) {
                $Secondary_Algorithm = $_.SecondaryAlgorithm
                $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm

                $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) + @("$Main_Algorithm_Norm$($Secondary_Algorithm_Norm -replace 'Nicehash'<#temp fix#>)") + @($_.SecondaryAlgoIntensity) | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; $Secondary_Algorithm_Norm = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week}

                switch ($_.Secondary_Algorithm_Norm) {
                    "Decred"      {$Secondary_Algorithm = "dcr"}
                    "Lbry"        {$Secondary_Algorithm = "lbc"}
                    "Pascal"      {$Secondary_Algorithm = "pasc"}
                    "SiaClaymore" {$Secondary_Algorithm = "sc"}
                }
                $Arguments_Secondary = " -dcoin $Secondary_Algorithm -dpool $($Pools.$Secondary_Algorithm_Norm.Host):$($Pools.$Secondary_Algorithm_Norm.Port) -dwal $($Pools.$Secondary_Algorithm_Norm.User) -dpsw $($Pools.$Secondary_Algorithm_Norm.Pass)$(if($_.SecondaryAlgoIntensity -ge 0){" -dcri $($_.SecondaryAlgoIntensity)"})"
                if ($Miner_Device | Where-Object {$_.OpenCL.GlobalMemsize -gt 3GB}) {
                    $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = 1 / 100; $Secondary_Algorithm_Norm = 0 / 100}
                }
                else {
                    $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = 0 / 100; $Secondary_Algorithm_Norm = 0 / 100}
                }
            }
            else {
                $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week}
                $Arguments_Secondary = ""

                if ($Miner_Device | Where-Object {$_.OpenCL.GlobalMemsize -gt 3GB}) {
                    $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = 1 / 100}
                }
                else {
                    $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = 0 / 100}
                }
            }
            #Avoid DAG switching
            switch ($Main_Algorithm_Norm) {
                "Ethash" {$Allcoins = " -allcoins etc"}
                default  {$Allcoins = " -allcoins 1"}
            }

            #Optionally disable dev fee mining
            if ($null -eq $Miner_Config) {$Miner_Config = [PSCustomObject]@{DisableDevFeeMining = $Config.DisableDevFeeMining}}
            if ($Miner_Config.DisableDevFeeMining) {
                $NoFee = " -nofee 1"
                $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = 0 / 100}
            }
            else {$NoFee = ""}

            #Remove -strap parameter for Nvidia 1080(Ti) and Titan cards, OhGoAnETHlargementPill is not compatible
            if ($Device.Model -match "GeForce GTX 1080|GeForce GTX 1080 Ti|Nvidia TITAN.*" -and (Get-CIMInstance CIM_Process | Where-Object Processname -like "OhGodAnETHlargementPill*")) {
                $CommonParameters = $CommonParameters -replace " -strap [\d,]{1,}"
            }

            [PSCustomObject]@{
                Name               = $Miner_Name
                BaseName           = $Miner_BaseName
                Version            = $Miner_Version
                DeviceName         = $Miner_Device.Name
                Path               = $Path
                HashSHA256         = $HashSHA256
                Arguments          = ("-mport -$Miner_Port -epool $($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port) -ewal $($Pools.$Main_Algorithm_Norm.User) -epsw $($Pools.$Main_Algorithm_Norm.Pass) -allpools 1$Allcoins -esm 3$Arguments_Secondary$Parameters$CommonParameters$NoFee -di $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.PCIBus_Type_Vendor_Index}) -join '')" -replace "\s+", " ").trim()
                HashRates          = $Miner_HashRates
                API                = "Claymore"
                Port               = $Miner_Port
                URI                = $Uri
                Fees               = $Miner_Fees
                IntervalMultiplier = $IntervalMultiplier
                WarmupTime         = 45 #seconds
            }
        }
    }
}
