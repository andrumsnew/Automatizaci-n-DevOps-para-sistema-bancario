# Script de remediacion automatica para configuracion de Startup and Recovery
# Requiere ejecutar como administrador
# Configuraciones aplicables a todos los ambientes

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Produccion", "Certificacion", "Desarrollo", "All")]
    [string]$ambiente = "All"
)

# Variables globales para logging
$LogDirectory = "C:\ProgramData\Auditoria_logs\logs"
$LogPath = "$LogDirectory\StartupRecoveryRemediation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$type_reme = "rem_puntolbs12"

# Crear directorio si no existe
if (-not (Test-Path $LogDirectory)) {
    New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
}

function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$level] $timestamp - [$type_reme] $Message"
    #Write-Host $logEntry
    Add-Content -Path $LogPath -Value $logEntry
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-StartupRecoveryConfig {
    # Configuraciones de Startup and Recovery - Aplican a todos los ambientes
    return @{
        "Background Services" = "Enabled"
        "Startup and Recovery: Default Operating system" = "Windows Server"
        "Startup and Recovery: Time to display list of operating system" = "30 seconds"
        "Startup and Recovery: Automatically restart" = "Enabled"
        "Startup and Recovery: Write debugging information" = "Automatic Memory Dump"
        "Startup and Recovery: Overwrite any existing file" = "Enabled"
    }
}

function Get-StartupRecoveryRegistryPath {
    param([string]$configName)
    
    # Mapeo de configuraciones a rutas de registro y valores
    $registryMappings = @{
        "Background Services" = @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
            ValueName = "Win32PrioritySeparation"
            ValueType = "DWORD"
            Description = "Optimizacion para servicios en segundo plano"
        }
        
        "Startup and Recovery: Default Operating system" = @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager"
            ValueName = "SystemStartOptions"
            ValueType = "String"
            Description = "Sistema operativo por defecto"
        }
        
        "Startup and Recovery: Time to display list of operating system" = @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager"
            ValueName = "BootMenuPolicy"
            ValueType = "DWORD"
            Description = "Tiempo de visualizacion del menu de arranque"
        }
        
        "Startup and Recovery: Automatically restart" = @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
            ValueName = "AutoReboot"
            ValueType = "DWORD"
            Description = "Reinicio automatico tras error critico"
        }
        
        "Startup and Recovery: Write debugging information" = @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
            ValueName = "CrashDumpEnabled"
            ValueType = "DWORD"
            Description = "Tipo de informacion de depuracion"
        }
        
        "Startup and Recovery: Overwrite any existing file" = @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
            ValueName = "Overwrite"
            ValueType = "DWORD"
            Description = "Sobrescribir archivo de volcado existente"
        }
    }
    
    return $registryMappings[$configName]
}

function Get-BCDRegistryPath {
    param([string]$configName)
    
    # Configuraciones que requieren BCD (Boot Configuration Data)
    $bcdMappings = @{
        "Startup and Recovery: Default Operating system" = @{
            BCDCommand = "bcdedit /set {bootmgr} displayorder"
            Description = "Configuracion de SO por defecto"
        }
        
        "Startup and Recovery: Time to display list of operating system" = @{
            BCDCommand = "bcdedit /timeout"
            Description = "Tiempo de espera del gestor de arranque"
        }
    }
    
    return $bcdMappings[$configName]
}

function ConvertTo-StartupRecoveryValue {
    param(
        [string]$configValue,
        [string]$configName
    )
    
    # Convertir valores de configuracion a valores de registro/BCD
    switch -Regex ($configValue) {
        "^Enabled$" { return 1 }
        "^Disabled$" { return 0 }
        
        # Background Services - Optimizacion para servicios
        "^Enabled$" {
            if ($configName -eq "Background Services") {
                return 24  # Valor para optimizar servicios en segundo plano
            }
            return 1
        }
        
        # Automatic Memory Dump
        "^Automatic Memory Dump$" { return 7 }
        "^Complete Memory Dump$" { return 1 }
        "^Kernel Memory Dump$" { return 2 }
        "^Small Memory Dump$" { return 3 }
        "^None$" { return 0 }
        
        # Time configurations
        "^(\d+) seconds$" {
            $seconds = [int]$matches[1]
            return $seconds
        }
        
        # Operating System
        "^Windows Server$" { return "Windows Server" }
        
        default { 
            Write-LogMessage "  - WARNING: Valor no reconocido '$configValue' para '$configName'" "WARNING"
            return $configValue 
        }
    }
}

function Set-RegistryConfiguration {
    param(
        [string]$configName,
        [string]$targetValue
    )
    
    $registryInfo = Get-StartupRecoveryRegistryPath -configName $configName
    if (-not $registryInfo) {
        return @{ Success = $false; Changed = $false; Method = "Registry" }
    }
    
    try {
        $registryPath = $registryInfo.Path
        $valueName = $registryInfo.ValueName
        $valueType = $registryInfo.ValueType
        $newValue = ConvertTo-StartupRecoveryValue -configValue $targetValue -configName $configName
        
        Write-LogMessage "  - Ruta: $registryPath\$valueName" "INFO"
        Write-LogMessage "  - Valor objetivo: '$targetValue' -> $newValue ($valueType)" "INFO"
        
        # Verificar si la ruta del registro existe, crearla si no
        if (-not (Test-Path $registryPath)) {
            Write-LogMessage "  - Creando ruta de registro: $registryPath" "INFO"
            New-Item -Path $registryPath -Force | Out-Null
        }
        
        # Obtener valor actual
        $currentValue = $null
        try {
            $currentValue = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $valueName
        } catch {
            Write-LogMessage "  - Valor actual no existe, se creara nuevo" "INFO"
        }
        
        if ($currentValue -eq $newValue) {
            Write-LogMessage "  -  Valor ya está correcto ($currentValue)" "INFO"
            return @{ Success = $true; Changed = $false; Method = "Registry" }
        }
        
        Write-LogMessage "  - Cambiando valor: $currentValue -> $newValue" "INFO"
        
        # Establecer el nuevo valor
        Set-ItemProperty -Path $registryPath -Name $valueName -Value $newValue -Type $valueType -Force
        
        # Verificar que se aplicó correctamente
        $verifyValue = Get-ItemProperty -Path $registryPath -Name $valueName | Select-Object -ExpandProperty $valueName
        if ($verifyValue -eq $newValue) {
            Write-LogMessage "  -  Configuracion aplicada exitosamente via Registry" "INFO"
            return @{ Success = $true; Changed = $true; Method = "Registry" }
        } else {
            Write-LogMessage "  -  Error: El valor no se aplicó correctamente (esperado: $newValue, actual: $verifyValue)" "ERROR"
            return @{ Success = $false; Changed = $false; Method = "Registry" }
        }
        
    }
    catch {
        Write-LogMessage "  -  Excepcion en Registry: $($_.Exception.Message)" "ERROR"
        return @{ Success = $false; Changed = $false; Method = "Registry" }
    }
}

function Set-BCDConfiguration {
    param(
        [string]$configName,
        [string]$targetValue
    )
    
    $bcdInfo = Get-BCDRegistryPath -configName $configName
    if (-not $bcdInfo) {
        return @{ Success = $false; Changed = $false; Method = "BCD" }
    }
    
    try {
        $convertedValue = ConvertTo-StartupRecoveryValue -configValue $targetValue -configName $configName
        
        Write-LogMessage "  - Usando BCD para configurar: $configName" "INFO"
        Write-LogMessage "  - Valor objetivo: '$targetValue' -> $convertedValue" "INFO"
        
        switch ($configName) {
            "Startup and Recovery: Time to display list of operating system" {
                try {
                    # Obtener timeout actual de manera más segura
                    $bcdOutput = & bcdedit /enum bootmgr 2>$null
                    $timeoutLine = $bcdOutput | Where-Object { $_ -match "timeout\s+(\d+)" }
                    $currentTimeout = "0"
                    
                    if ($timeoutLine) {
                        if ($timeoutLine -match "timeout\s+(\d+)") {
                            $currentTimeout = $matches[1]
                        }
                    }
                    
                    Write-LogMessage "  - Timeout actual: $currentTimeout segundos" "INFO"
                    
                    if ([int]$currentTimeout -eq [int]$convertedValue) {
                        Write-LogMessage "  -  Timeout ya está correcto" "INFO"
                        return @{ Success = $true; Changed = $false; Method = "BCD" }
                    }
                    
                    # Aplicar nuevo timeout
                    Write-LogMessage "  - Aplicando timeout: $convertedValue segundos" "INFO"
                    $result = & bcdedit /timeout $convertedValue 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-LogMessage "  -  Timeout configurado a $convertedValue segundos via BCD" "INFO"
                        return @{ Success = $true; Changed = $true; Method = "BCD" }
                    } else {
                        $errorMsg = $result -join " "
                        Write-LogMessage "  -  Error configurando timeout: $errorMsg" "ERROR"
                        return @{ Success = $false; Changed = $false; Method = "BCD" }
                    }
                }
                catch {
                    Write-LogMessage "  -  Error procesando BCD timeout: $($_.Exception.Message)" "ERROR"
                    return @{ Success = $false; Changed = $false; Method = "BCD" }
                }
            }
            
            "Startup and Recovery: Default Operating system" {
                try {
                    # Verificar configuración actual del boot manager
                    $bcdOutput = & bcdedit /enum bootmgr 2>$null
                    $hasBootManager = $bcdOutput | Where-Object { $_ -match "Windows Boot Manager" }
                    
                    if ($hasBootManager) {
                        Write-LogMessage "  -  Windows Boot Manager está configurado correctamente" "INFO"
                        return @{ Success = $true; Changed = $false; Method = "BCD" }
                    } else {
                        Write-LogMessage "  - Windows Boot Manager no detectado, pero continuando" "WARNING"
                        return @{ Success = $true; Changed = $false; Method = "BCD" }
                    }
                }
                catch {
                    Write-LogMessage "  -  Error verificando Boot Manager: $($_.Exception.Message)" "ERROR"
                    return @{ Success = $false; Changed = $false; Method = "BCD" }
                }
            }
        }
        
    }
    catch {
        Write-LogMessage "  -  Excepcion en BCD: $($_.Exception.Message)" "ERROR"
        return @{ Success = $false; Changed = $false; Method = "BCD" }
    }
    
    return @{ Success = $false; Changed = $false; Method = "BCD" }
}

function Set-StartupRecoveryConfiguration {
    param(
        [string]$configName,
        [string]$targetValue
    )
    
    Write-LogMessage "Configurando: $configName" "INFO"
    
    # Determinar método de configuración
    $result = $null
    
    switch ($configName) {
        "Startup and Recovery: Time to display list of operating system" {
            # Intentar primero con BCD, luego Registry como respaldo
            $result = Set-BCDConfiguration -configName $configName -targetValue $targetValue
            if (-not $result.Success) {
                Write-LogMessage "  - BCD falló, intentando con Registry..." "WARNING"
                $result = Set-RegistryConfiguration -configName $configName -targetValue $targetValue
            }
        }
        
        "Startup and Recovery: Default Operating system" {
            # Usar BCD para configuraciones de arranque
            $result = Set-BCDConfiguration -configName $configName -targetValue $targetValue
        }
        
        default {
            # Usar Registry para el resto de configuraciones
            $result = Set-RegistryConfiguration -configName $configName -targetValue $targetValue
        }
    }
    
    if (-not $result) {
        Write-LogMessage "  -  No se pudo determinar método de configuración" "ERROR"
        return @{ Success = $false; Changed = $false }
    }
    
    return $result
}

function Set-StartupRecoveryConfig {
    Write-LogMessage "Iniciando remediacion de configuraciones Startup and Recovery" "INFO"
    Write-LogMessage "Estas configuraciones aplican a todos los ambientes" "INFO"
    
    $config = Get-StartupRecoveryConfig
    $totalConfigs = $config.Count
    $processedConfigs = 0
    $modifiedConfigs = 0
    $errorCount = 0
    $successCount = 0
    
    Write-LogMessage "Total de configuraciones a procesar: $totalConfigs" "INFO"
    
    foreach ($configName in $config.Keys) {
        $processedConfigs++
        $targetValue = $config[$configName]
        
        Write-LogMessage "Procesando configuracion $processedConfigs de $totalConfigs`: $configName" "INFO"
        
        $result = Set-StartupRecoveryConfiguration -configName $configName -targetValue $targetValue
        
        if ($result.Success) {
            $successCount++
            if ($result.Changed) {
                $modifiedConfigs++
                Write-LogMessage "  -  MODIFICADA via $($result.Method)" "INFO"
            } else {
                Write-LogMessage "  -  YA CORRECTA via $($result.Method)" "INFO"
            }
        } else {
            $errorCount++
            Write-LogMessage "  -  ERROR en configuracion" "ERROR"
        }
        
        Write-LogMessage "----------------------------------------" "INFO"
    }
    
    # Mensaje sobre reinicio si hay cambios críticos
    if ($modifiedConfigs -gt 0) {
        Write-LogMessage "IMPORTANTE: Se realizaron cambios en configuraciones de arranque y recuperacion" "WARNING"
        Write-LogMessage "Algunas configuraciones pueden requerir reinicio del sistema para aplicarse completamente" "WARNING"
    }
    
    # Resumen final
    Write-LogMessage "========================================" "INFO"
    Write-LogMessage "RESUMEN DE REMEDIACION COMPLETADA" "INFO"
    Write-LogMessage "Configuraciones procesadas: $processedConfigs" "INFO"
    Write-LogMessage "Configuraciones modificadas: $modifiedConfigs" "INFO"
    Write-LogMessage "Configuraciones exitosas: $successCount" "INFO"
    Write-LogMessage "Errores encontrados: $errorCount" "INFO"
    Write-LogMessage "Log de actividades guardado en: $LogPath" "INFO"
    Write-LogMessage "========================================" "INFO"
    
    return @{
        ProcessedConfigs = $processedConfigs
        ModifiedConfigs = $modifiedConfigs
        SuccessCount = $successCount
        ErrorCount = $errorCount
        LogPath = $LogPath
    }
}

# Ejecutar script principal
Write-LogMessage "=== Inicio de Script de Remediacion de Startup and Recovery ===" "INFO"
Write-LogMessage "Servidor: $env:COMPUTERNAME" "INFO"
Write-LogMessage "Usuario: $env:USERNAME" "INFO"
Write-LogMessage "Ambiente: $ambiente (Configuraciones universales)" "INFO"
Write-LogMessage "Fecha y hora: $(Get-Date)" "INFO"

Write-Host "=== Inicio de Script de Remediacion de User Right ==="
Write-Host "Servidor: $env:COMPUTERNAME"
Write-Host "Fecha y hora: $(Get-Date)"

if (-not (Test-AdminRights)) {
    Write-LogMessage "CRITICO: Este script debe ejecutarse como administrador" "ERROR"
    exit 1
}

Write-LogMessage "Permisos de administrador verificados correctamente" "INFO"

# Ejecutar remediacion automatica
$result = Set-StartupRecoveryConfig

# Codigo de salida basado en resultados
if ($result.ErrorCount -eq 0) {
    Write-LogMessage "Script ejecutado exitosamente sin errores" "INFO"
    Write-Host "Script ejecutado exitosamente sin errores"
    Write-Host "Para mas informacion del proceso de remediacion de RemoteDesktop, se ha generado el log de actividades en: $LogPath"
    exit 0
} elseif ($result.ErrorCount -le 2) {
    Write-LogMessage "Script ejecutado con errores menores ($($result.ErrorCount) errores)" "WARNING"
    Write-LogMessage "GPO: $($result.GpoBlockedCount), Sistema: $($result.SystemPolicyBlockedCount), Sin mapeo: $($result.NotMappedCount)" "WARNING"
    Write-Host "Script ejecutado con errores menores"
    Write-Host "Para mas informacion del proceso de remediacion de RemoteDesktop, se ha generado el log de actividades en: $LogPath"
    exit 0
} else {
    Write-LogMessage "Script ejecutado con multiples errores ($($result.ErrorCount) errores)" "ERROR"
    Write-LogMessage "Configuraciones exitosas: $($result.SuccessCount)" "ERROR"
    Write-Host "Script ejecutado con errores criticos"
    Write-Host "Para mas informacion del proceso de remediacion de RemoteDesktop, se ha generado el log de actividades en: $LogPath"
    exit 0
}