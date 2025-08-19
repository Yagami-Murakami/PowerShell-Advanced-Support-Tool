<#
.SYNOPSIS
    Ferramenta de Suporte Avancado em PowerShell para diagnostico e administracao de sistemas Windows.

.DESCRIPTION
    Este script fornece um dashboard com informacoes do sistema e um menu interativo para executar
    diversas tarefas de manutencao, diagnostico e otimizacao de rede, sistema, usuarios e mais.

.AUTHOR
    Tuninho kjr (Versao Original) / Gemini (Revisao e Melhorias) / Versao Completa

.VERSION
    2.4 (Versao completa com todas as funcoes implementadas)
#>

#region Funcoes de Exibicao (Menus e Dashboard)
function Show-Dashboard {
    Clear-Host
    try {
        # Coleta informacoes de forma mais eficiente
        $computerInfo = Get-ComputerInfo -Property 'OsName', 'TotalPhysicalMemory', 'CsName' -ErrorAction SilentlyContinue
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $driveC = Get-PSDrive -Name 'C' -ErrorAction SilentlyContinue
        
        # Busca o endereco IPv4 principal de forma confiavel
        $ipAddress = try {
            (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -ne "Loopback Pseudo-Interface 1" } | Select-Object -First 1).IPAddress
        } catch {
            "Nao disponivel"
        }
        
        # Calculos
        $ramFreeGB = if ($osInfo) { [math]::Round($osInfo.FreePhysicalMemory / 1MB / 1024, 2) } else { 0 }
        $ramTotalGB = if ($computerInfo) { [math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2) } else { 0 }
        $diskFreeGB = if ($driveC) { [math]::Round($driveC.Free / 1GB, 2) } else { 0 }
        $diskUsedGB = if ($driveC) { [math]::Round($driveC.Used / 1GB, 2) } else { 0 }
        
        # Exibicao do Dashboard
        Write-Host "========================== STATUS DO SISTEMA ==========================" -ForegroundColor Cyan
        Write-Host "Computador : $($env:COMPUTERNAME)"
        Write-Host "Usuario    : $($env:USERNAME)"
        Write-Host "IP         : $($ipAddress)"
        Write-Host "Sistema    : $($computerInfo.OsName -replace 'Microsoft Windows ', '')"
        Write-Host "RAM Livre  : $ramFreeGB GB de $ramTotalGB GB"
        Write-Host "Disco C:   : $diskFreeGB GB Livres / $diskUsedGB GB Total"
        Write-Host "Data/Hora  : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
        Write-Host "=======================================================================" -ForegroundColor Cyan
        Write-Host
    } catch {
        Write-Host "Erro ao carregar informacoes do sistema: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-MainMenu {
    Write-Host "========================== MENU PRINCIPAL ===========================" -ForegroundColor Yellow
    Write-Host "[R] Rede e Conectividade"
    Write-Host "[S] Sistema e Hardware"
    Write-Host "[U] Usuarios e Seguranca"
    Write-Host "[M] Monitoramento e Logs"
    Write-Host "[O] Otimizacao e Performance"
    Write-Host "[T] Ferramentas Avancadas"
    Write-Host "[H] Ajuda e Documentacao"
    Write-Host "[X] Sair"
    Write-Host "=======================================================================" -ForegroundColor Yellow
}

function Show-SubMenu {
    param(
        [string]$Title,
        [hashtable]$Options
    )
    Write-Host "=============== $($Title.ToUpper()) ===============" -ForegroundColor Yellow
    # Itera sobre o hashtable para criar o menu dinamicamente
    foreach ($key in $Options.Keys | Sort-Object { [int]$_ }) {
        Write-Host "[$key] - $($Options[$key])"
    }
    Write-Host "[0] - Voltar ao Menu Principal"
    Write-Host "========================================================" -ForegroundColor Yellow
}
#endregion

#region Funcoes de Execucao das Opcoes
function Invoke-NetworkActions {
    param([string]$option)
    try {
        switch ($option) {
            "1" { Get-NetIPConfiguration -Detailed | Format-List * }
            "2" { 
                Clear-DnsClientCache
                Write-Host "Cache DNS limpo com sucesso." -ForegroundColor Green
            }
            "3" {
                Write-Host "Liberando e renovando IP..." -ForegroundColor Yellow
                ipconfig /release | Out-Null
                ipconfig /renew | Out-Null
                Write-Host "IP renovado com sucesso." -ForegroundColor Green
            }
            "4" { 
                netsh winsock reset | Out-Null
                Write-Host "Winsock resetado. E necessario reiniciar o computador para completar a operacao." -ForegroundColor Yellow
            }
            "5" { Get-NetNeighbor | Sort-Object -Property InterfaceIndex | Format-Table -AutoSize }
            "6" { Get-NetRoute | Where-Object { $_.NextHop -ne "0.0.0.0" } | Sort-Object -Property InterfaceIndex | Format-Table -AutoSize }
            "14" {
                $hosts = "8.8.8.8", "1.1.1.1", "google.com"
                foreach ($host in $hosts) {
                    Write-Host "--- Testando conexao com $host ---" -ForegroundColor Yellow
                    Test-NetConnection $host -InformationLevel Detailed
                    Write-Host ""
                }
            }
            "15" {
                $host = Read-Host "Digite o host para testar (ex: google.com)"
                $port = Read-Host "Digite a porta para testar (ex: 443)"
                if ($host -and $port) {
                    Test-NetConnection -ComputerName $host -Port $port
                }
            }
            "16" { 
                netsh winhttp show proxy
                Write-Host "`nConfiguracoes do Internet Explorer:" -ForegroundColor Yellow
                Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" | Select-Object ProxyServer, ProxyEnable
            }
            "17" { 
                netsh int ip reset | Out-Null
                Write-Host "TCP/IP resetado. E necessario reiniciar o computador." -ForegroundColor Yellow
            }
            "18" { Get-NetTCPConnection | Sort-Object -Property State, RemotePort | Format-Table -AutoSize }
            "19" {
                $domain = Read-Host "Digite o dominio para consultar (ex: google.com)"
                if ($domain) {
                    Resolve-DnsName -Name $domain
                }
            }
            default { Write-Host "Opcao invalida!" -ForegroundColor Red }
        }
    } catch {
        Write-Host "Erro ao executar operacao: $($_.Exception.Message)" -ForegroundColor Red
    }
    if ($option -ne "0") { Pause-Execution }
}

function Invoke-SystemActions {
    param([string]$option)
    try {
        switch ($option) {
            "20" { Get-ComputerInfo | Format-List }
            "21" {
                try {
                    # Tenta obter temperatura via WMI
                    $temp = Get-CimInstance -Namespace "root/wmi" -ClassName "MSAcpi_ThermalZoneTemperature" -ErrorAction Stop
                    if ($temp) {
                        foreach ($zone in $temp) {
                            $currentTempCelsius = ($zone.CurrentTemperature / 10) - 273.15
                            Write-Host ("Zona Termica: {0:N2} C" -f $currentTempCelsius) -ForegroundColor Green
                        }
                    }
                } catch {
                    Write-Host "Temperatura nao disponivel neste sistema. Execute como Administrador ou verifique compatibilidade do hardware." -ForegroundColor Yellow
                }
            }
            "22" { Get-CimInstance Win32_PhysicalMemory | Select-Object Manufacturer, Capacity, Speed, DeviceLocator | Format-Table -AutoSize }
            "23" { Get-PSDrive | Where-Object Provider -eq "FileSystem" | Select-Object Name, @{N="Total (GB)"; E={[math]::Round(($_.Used + $_.Free) / 1GB, 2)}}, @{N="Usado (GB)"; E={[math]::Round($_.Used / 1GB, 2)}}, @{N="Livre (GB)"; E={[math]::Round($_.Free / 1GB, 2)}} | Format-Table -AutoSize }
            "24" { Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher | Where-Object DisplayName | Sort-Object DisplayName | Format-Table -AutoSize }
            "25" { Get-WindowsDriver -Online | Where-Object { $_.ProviderName -ne "Microsoft" } | Sort-Object ProviderName | Format-Table -AutoSize }
            "26" { Get-Service | Sort-Object Status, DisplayName | Format-Table Status, Name, DisplayName -AutoSize }
            default { Write-Host "Opcao invalida!" -ForegroundColor Red }
        }
    } catch {
        Write-Host "Erro ao executar operacao: $($_.Exception.Message)" -ForegroundColor Red
    }
    if ($option -ne "0") { Pause-Execution }
}

function Invoke-UserSecurityActions {
    param([string]$option)
    try {
        switch ($option) {
            "27" { query user }
            "28" {
                try {
                    Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624} -MaxEvents 10 | Select-Object TimeCreated, @{N='User'; E={$_.Properties[5].Value}}, @{N='LogonType'; E={$_.Properties[8].Value}} | Format-Table -AutoSize
                } catch {
                    Write-Host "Nao foi possivel acessar os logs de seguranca. Execute como Administrador." -ForegroundColor Yellow
                }
            }
            "29" { net accounts }
            "30" {
                Write-Host "Iniciando um scan rapido com o Windows Defender..." -ForegroundColor Yellow
                try {
                    Start-MpScan -ScanType QuickScan
                    Write-Host "Scan concluido." -ForegroundColor Green
                } catch {
                    Write-Host "Erro ao iniciar scan. Verifique se o Windows Defender esta habilitado." -ForegroundColor Red
                }
            }
            "31" {
                Write-Host "Verificando atualizacoes pendentes..." -ForegroundColor Yellow
                try {
                    $updateSession = New-Object -ComObject Microsoft.Update.Session
                    $updateSearcher = $updateSession.CreateUpdateSearcher()
                    $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
                    
                    if ($searchResult.Updates.Count -eq 0) {
                        Write-Host "Nenhuma atualizacao pendente encontrada." -ForegroundColor Green
                    } else {
                        Write-Host "Atualizacoes pendentes encontradas:" -ForegroundColor Yellow
                        $searchResult.Updates | ForEach-Object { Write-Host "- $($_.Title)" -ForegroundColor White }
                    }
                } catch {
                    Write-Host "Erro ao verificar atualizacoes: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            "32" { Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User | Format-Table -AutoSize }
            default { Write-Host "Opcao invalida!" -ForegroundColor Red }
        }
    } catch {
        Write-Host "Erro ao executar operacao: $($_.Exception.Message)" -ForegroundColor Red
    }
    if ($option -ne "0") { Pause-Execution }
}

function Invoke-MonitoringActions {
    param([string]$option)
    try {
        switch ($option) {
            "33" {
                Write-Host "Coletando eventos criticos do sistema..." -ForegroundColor Yellow
                $logs = @('System', 'Application')
                foreach ($log in $logs) {
                    Write-Host "`n--- Log: $log ---" -ForegroundColor Cyan
                    Get-WinEvent -FilterHashtable @{LogName=$log; Level=1,2,3} -MaxEvents 10 -ErrorAction SilentlyContinue | 
                        Select-Object TimeCreated, LevelDisplayName, Id, ProviderName, Message | 
                        Format-Table -Wrap
                }
            }
            "34" {
                Write-Host "Monitorando CPU e memoria por 30 segundos... (Pressione Ctrl+C para parar)" -ForegroundColor Yellow
                $samples = 6
                for ($i = 1; $i -le $samples; $i++) {
                    $cpu = Get-Counter "\Processor(_Total)\% Processor Time"
                    $memory = Get-CimInstance Win32_OperatingSystem
                    $memoryUsage = [math]::Round((($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / $memory.TotalVisibleMemorySize) * 100, 2)
                    
                    $output = "Amostra $i de $samples | CPU: {0:N2}% | Memoria: {1:N2}%" -f $cpu.CounterSamples.CookedValue, $memoryUsage
                    Write-Progress -Activity "Monitorando Performance" -Status $output -PercentComplete (($i / $samples) * 100)
                    Write-Host $output
                    
                    if ($i -lt $samples) { Start-Sleep -Seconds 5 }
                }
            }
            "35" {
                Write-Host "Top 10 processos por uso de CPU:" -ForegroundColor Yellow
                Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, CPU, @{N='Memory(MB)'; E={[math]::Round($_.WorkingSet / 1MB, 2)}} | Format-Table -AutoSize
            }
            "36" {
                Write-Host "Top 10 processos por uso de memoria:" -ForegroundColor Yellow
                Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 Name, @{N='Memory(MB)'; E={[math]::Round($_.WorkingSet / 1MB, 2)}}, CPU | Format-Table -AutoSize
            }
            default { Write-Host "Opcao invalida!" -ForegroundColor Red }
        }
    } catch {
        Write-Host "Erro ao executar operacao: $($_.Exception.Message)" -ForegroundColor Red
    }
    if ($option -ne "0") { Pause-Execution }
}

function Invoke-OptimizationActions {
    param([string]$option)
    try {
        switch ($option) {
            "37" {
                Write-Host "Limpando arquivos temporarios..." -ForegroundColor Yellow
                Get-ChildItem -Path $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host "Arquivos temporarios do usuario limpos." -ForegroundColor Green
                
                Get-ChildItem -Path "C:\Windows\Temp" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host "Arquivos temporarios do Windows limpos." -ForegroundColor Green
            }
            "38" {
                Write-Host "Executando limpeza de disco..." -ForegroundColor Yellow
                Start-Process cleanmgr -ArgumentList "/sagerun:1" -Wait
                Write-Host "Limpeza de disco concluida." -ForegroundColor Green
            }
            "39" {
                Write-Host "Iniciando otimizacao de disco..." -ForegroundColor Yellow
                $drives = Get-Volume | Where-Object { $_.DriveLetter -and $_.FileSystem -eq "NTFS" }
                foreach ($drive in $drives) {
                    Write-Host "Otimizando drive $($drive.DriveLetter)..." -ForegroundColor Yellow
                    Optimize-Volume -DriveLetter $drive.DriveLetter -Defrag -Verbose
                }
                Write-Host "Otimizacao concluida." -ForegroundColor Green
            }
            "40" {
                Write-Host "Limpando cache dos navegadores... (Feche os navegadores antes de continuar)" -ForegroundColor Yellow
                Pause-Execution
                # Chrome
                $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
                if (Test-Path $chromePath) { Remove-Item -Path "$chromePath\*" -Force -Recurse -ErrorAction SilentlyContinue; Write-Host "Cache do Chrome limpo." -ForegroundColor Green }
                # Edge
                $edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
                if (Test-Path $edgePath) { Remove-Item -Path "$edgePath\*" -Force -Recurse -ErrorAction SilentlyContinue; Write-Host "Cache do Edge limpo." -ForegroundColor Green }
                # Firefox
                $firefoxProfile = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue
                if ($firefoxProfile) {
                    foreach ($profile in $firefoxProfile) {
                        $cachePath = "$($profile.FullName)\cache2"
                        if (Test-Path $cachePath) { Remove-Item -Path "$cachePath\*" -Force -Recurse -ErrorAction SilentlyContinue }
                    }
                    Write-Host "Cache do Firefox limpo." -ForegroundColor Green
                }
            }
            "41" {
                Write-Host "Verificando integridade dos arquivos do sistema... Isso pode levar varios minutos." -ForegroundColor Yellow
                sfc.exe /scannow
                Write-Host "Verificacao SFC concluida. Verifique o resultado acima." -ForegroundColor Green
            }
            default { Write-Host "Opcao invalida!" -ForegroundColor Red }
        }
    } catch {
        Write-Host "Erro ao executar operacao: $($_.Exception.Message)" -ForegroundColor Red
    }
    if ($option -ne "0") { Pause-Execution }
}

function Invoke-AdvancedToolsActions {
    param([string]$option)
    try {
        switch ($option) {
            "50" {
                Write-Host "Gerando relatorio completo do sistema..." -ForegroundColor Yellow
                $reportPath = "$env:USERPROFILE\Desktop\RelatorioSistema_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
                
                $head = @"
<style>
body { font-family: Arial, sans-serif; margin: 20px; background-color: #f9f9f9; }
h1, h2 { color: #333; border-bottom: 2px solid #0078D4; padding-bottom: 5px; }
table { border-collapse: collapse; width: 100%; margin: 10px 0; box-shadow: 0 2px 3px rgba(0,0,0,0.1); }
th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
th { background-color: #0078D4; color: white; }
tr:nth-child(even) { background-color: #f2f2f2; }
.info { background-color: #e7f3ff; padding: 15px; margin: 10px 0; border-left: 5px solid #0078D4; }
</style>
"@
                $body = "<h1>Relatorio do Sistema</h1><div class='info'><strong>Computador:</strong> $env:COMPUTERNAME<br><strong>Usuario:</strong> $env:USERNAME<br><strong>Data/Hora:</strong> $(Get-Date)</div>"
                $body += Get-ComputerInfo | ConvertTo-Html -As Table -Fragment -PreContent "<h2>Informacoes do Sistema</h2>"
                $body += Get-NetIPConfiguration | ConvertTo-Html -As Table -Fragment -PreContent "<h2>Configuracao de Rede</h2>"
                $body += Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 Name, CPU, @{N='Memory(MB)'; E={[math]::Round($_.WorkingSet / 1MB, 2)}} | ConvertTo-Html -As Table -Fragment -PreContent "<h2>Top 20 Processos por CPU</h2>"
                
                ConvertTo-Html -Head $head -Body $body | Out-File -FilePath $reportPath -Encoding UTF8
                Write-Host "Relatorio salvo em: $reportPath" -ForegroundColor Green
                Start-Process $reportPath
            }
            "51" {
                Write-Host "Historico de comandos PowerShell:" -ForegroundColor Yellow
                Get-History | Format-Table -AutoSize
            }
            "52" {
                Write-Host "Executando diagnosticos de rede avancados..." -ForegroundColor Yellow
                netsh int ip reset
                netsh winsock reset
                netsh advfirewall reset
                ipconfig /flushdns
                Write-Host "Diagnosticos de rede concluidos. Reinicializacao recomendada." -ForegroundColor Green
            }
            "53" {
                Write-Host "Coletando informacoes detalhadas do hardware..." -ForegroundColor Yellow
                Write-Host "`n--- PROCESSADOR ---" -ForegroundColor Cyan
                Get-CimInstance Win32_Processor | Format-List Name, Manufacturer, MaxClockSpeed, NumberOfCores, NumberOfLogicalProcessors
                Write-Host "`n--- MEMORIA ---" -ForegroundColor Cyan
                Get-CimInstance Win32_PhysicalMemory | Format-Table Manufacturer, Capacity, Speed, DeviceLocator -AutoSize
                Write-Host "`n--- PLACAS DE VIDEO ---" -ForegroundColor Cyan
                Get-CimInstance Win32_VideoController | Format-List Name, AdapterRAM, DriverVersion
                Write-Host "`n--- DISCOS RIGIDOS ---" -ForegroundColor Cyan
                Get-CimInstance Win32_DiskDrive | Format-List Model, Size, MediaType, InterfaceType
            }
            default { Write-Host "Opcao invalida!" -ForegroundColor Red }
        }
    } catch {
        Write-Host "Erro ao executar operacao: $($_.Exception.Message)" -ForegroundColor Red
    }
    if ($option -ne "0") { Pause-Execution }
}

function Show-Help {
    Clear-Host
    Write-Host "========================== AJUDA E DOCUMENTACAO ==========================" -ForegroundColor Cyan
    Write-Host "DESCRICAO:" -ForegroundColor Yellow
    Write-Host "Esta ferramenta oferece funcionalidades para diagnostico e manutencao de sistemas Windows."
    Write-Host ""
    Write-Host "CATEGORIAS DISPONIVEIS:" -ForegroundColor Yellow
    Write-Host "[R] REDE E CONECTIVIDADE: Configuracao de rede, DNS, testes de conexao."
    Write-Host "[S] SISTEMA E HARDWARE: Informacoes de sistema, temperatura, memoria, drivers."
    Write-Host "[U] USUARIOS E SEGURANCA: Sessoes, antivirus, atualizacoes do Windows."
    Write-Host "[M] MONITORAMENTO E LOGS: Logs de eventos, monitoramento de CPU e memoria."
    Write-Host "[O] OTIMIZACAO E PERFORMANCE: Limpeza de arquivos, desfragmentacao."
    Write-Host "[T] FERRAMENTAS AVANCADAS: Relatorios em HTML, diagnosticos avancados."
    Write-Host ""
    Write-Host "REQUISITOS:" -ForegroundColor Yellow
    Write-Host "- Windows 10/11, PowerShell 5.1+, Privilegios de Administrador."
    Write-Host ""
    Write-Host "AUTOR: Tuninho kjr / Versao Completa" -ForegroundColor Green
    Write-Host "VERSAO: 2.4" -ForegroundColor Green
    Write-Host "========================================================================" -ForegroundColor Cyan
}
#endregion

#region Funcoes Auxiliares
function Pause-Execution {
    Write-Host ""
    Read-Host "Pressione ENTER para continuar..."
}

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
#endregion

#========================= INICIO DO SCRIPT =========================#
if (-not (Test-Admin)) {
    Write-Warning "Este script requer privilegios de Administrador para funcionar corretamente."
    Write-Warning "Por favor, execute-o em um terminal PowerShell como Administrador."
    Pause-Execution
    exit
}

# Definicao dos menus
$menus = @{
    "R" = @{
        Title = "Rede e Conectividade"
        Executor = ${function:Invoke-NetworkActions}
        Options = @{
            "1"  = "Exibir configuracoes de IP completas"
            "2"  = "Limpar cache de DNS"
            "3"  = "Renovar configuracao de IP"
            "4"  = "Resetar Winsock (requer reinicializacao)"
            "5"  = "Mostrar tabela de vizinhos (ARP)"
            "6"  = "Mostrar rotas de rede"
            "14" = "Teste de conectividade com hosts comuns"
            "15" = "Testar porta especifica em um host"
            "16" = "Verificar configuracoes de proxy"
            "17" = "Resetar pilha TCP/IP (requer reinicializacao)"
            "18" = "Exibir conexoes TCP ativas"
            "19" = "Consultar DNS (nslookup)"
        }
    }
    "S" = @{
        Title = "Sistema e Hardware"
        Executor = ${function:Invoke-SystemActions}
        Options = @{
            "20" = "Informacoes completas do sistema"
            "21" = "Verificar temperatura da CPU"
            "22" = "Detalhes dos modulos de memoria RAM"
            "23" = "Uso de espaco em todos os discos"
            "24" = "Listar programas instalados"
            "25" = "Listar drivers de terceiros instalados"
            "26" = "Status de todos os servicos Windows"
        }
    }
    "U" = @{
        Title = "Usuarios e Seguranca"
        Executor = ${function:Invoke-UserSecurityActions}
        Options = @{
            "27" = "Listar usuarios logados na maquina"
            "28" = "Verificar ultimos logins bem-sucedidos"
            "29" = "Exibir politicas de senha locais"
            "30" = "Iniciar Scan rapido com Windows Defender"
            "31" = "Verificar atualizacoes do Windows pendentes"
            "32" = "Listar programas na inicializacao"
        }
    }
    "M" = @{
        Title = "Monitoramento e Logs"
        Executor = ${function:Invoke-MonitoringActions}
        Options = @{
            "33" = "Exibir eventos criticos do sistema"
            "34" = "Monitor de CPU e memoria em tempo real"
            "35" = "Top processos por uso de CPU"
            "36" = "Top processos por uso de memoria"
        }
    }
    "O" = @{
        Title = "Otimizacao e Performance"
        Executor = ${function:Invoke-OptimizationActions}
        Options = @{
            "37" = "Limpar arquivos temporarios"
            "38" = "Executar limpeza de disco"
            "39" = "Otimizar/desfragmentar discos"
            "40" = "Limpar cache dos navegadores"
            "41" = "Verificar integridade dos arquivos do sistema (SFC)"
        }
    }
    "T" = @{
        Title = "Ferramentas Avancadas"
        Executor = ${function:Invoke-AdvancedToolsActions}
        Options = @{
            "50" = "Gerar relatorio completo em HTML"
            "51" = "Exibir historico de comandos"
            "52" = "Diagnosticos de rede avancados"
            "53" = "Informacoes detalhadas de hardware"
        }
    }
}

# Loop principal do programa
$mainLoop = $true
while ($mainLoop) {
    Show-Dashboard
    Show-MainMenu
    $category = Read-Host "Digite a letra da categoria desejada"
    
    if ($menus.ContainsKey($category.ToUpper())) {
        $selectedMenu = $menus[$category.ToUpper()]
        $subMenuLoop = $true
        
        while ($subMenuLoop) {
            Clear-Host
            Show-SubMenu -Title $selectedMenu.Title -Options $selectedMenu.Options
            $option = Read-Host "Escolha uma opcao"
            
            if ($option -eq "0") {
                $subMenuLoop = $false
            }
            elseif ($selectedMenu.Options.ContainsKey($option)) {
                Clear-Host
                Write-Host "=== EXECUTANDO: $($selectedMenu.Options[$option]) ===" -ForegroundColor Green
                # Invoca a funcao correspondente ao menu
                & $selectedMenu.Executor -option $option
            }
            else {
                Write-Host "Opcao invalida!" -ForegroundColor Red
                Pause-Execution
            }
        }
    }
    elseif ($category.ToUpper() -eq 'X') {
        $mainLoop = $false
        Write-Host "Encerrando o programa. Obrigado por usar as Ferramentas de Suporte!" -ForegroundColor Cyan
    }
    elseif ($category.ToUpper() -eq 'H') {
        Show-Help
        Pause-Execution
    }
    else {
        Write-Host "Categoria invalida!" -ForegroundColor Red
        Pause-Execution
    }
}
