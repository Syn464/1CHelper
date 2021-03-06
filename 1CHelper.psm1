﻿<#
.Synopsis
   Очистка временных каталогов 1С
.DESCRIPTION
   Удаляет временные каталоги 1С для пользователя(-ей) с возможностью отбора
.NOTES      
   Name: 1CHelper    
   Author: yauhen.makei@gmail.com.LINK      
   https://github.com/emakei/1CHelper.psm1
.EXAMPLE
   # Удаление всех временных каталогов информационных баз для текущего пользователя
   Remove-1CTempDirs
#>
function Remove-1CTempDirs
{
   [CmdletBinding(SupportsShouldProcess = $true)]
   Param    
   (
       # Имя пользователя для удаления каталогов(-а)
       [Parameter(Mandatory=$false,
                  ValueFromPipelineByPropertyName=$true,
                  Position=0)]
       [string[]]$User,
       # Фильтр каталогов
       [Parameter(Mandatory=$false,
                  ValueFromPipelineByPropertyName=$true,
                  Position=1)]
       [string[]]$Filter        
   )        
   
   if( -not $User )
   {
      $AppData = @($env:APPDATA, $env:LOCALAPPDATA)
   }
   else
   {
      Write-Host "Пока не поддерживается"
      return
   }
   
   $Dirs = $AppData | % { gci $_\1C\1cv8*\* -Directory } | Where-Object Name -Match "^\w{8}\-(\w{4}\-){3}\w{12}$"
   if($Filter)
   {
      $Dirs = $Dirs | ? { $_.Name -in $Filter }
   }
   
   if($WhatIfPreference)
   {
      $Dirs | % { "УДАЛЕНИЕ: $($_.FullName)" }
   }
   else
   {
      $Dirs | % { rm $_.FullName -Confirm:$ConfirmPreference -Verbose:$VerbosePreference -Recurse -Force }
   }
}

<#
.Synopsis
   Преобразует данные файла технологического журнала в таблицу
.DESCRIPTION
   Производит извлечение данных из файла(-ов) технологического журнала и преобразует в таблицу
.NOTES  
    Name: 1CHelper
    Author: yauhen.makei@gmail.com
.LINK  
    https://github.com/emakei/1CHelper.psm1
.INPUTS
   Пусть к файлу(-ам) технологического журнала
.OUTPUTS
   Массив строк технологического журнала
.EXAMPLE
   $table = Get-TechJournalLOGtable 'C:\LOG\rmngr_1908\17062010.log'
.EXAMPLE
   $table = Get-TechJournalLOGtable 'C:\LOG\' -Verbose
#>
function Get-TechJournalLOGtable
{
    [CmdletBinding()]
    [OutputType([Object[]])]
    Param
    (
        # Имя файла лога
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $fileName
    )

    Begin
    {
    $table = @()
    }

    Process
    {

    Get-ChildItem $fileName -Recurse -File | % {
        Write-Verbose $_.FullName
        $creationTime = $_.CreationTime
        $processName = $_.Directory.Name.Split('_')[0]
        $processID = $_.Directory.Name.Split('_')[1]
        Get-TechJournalData $_.FullName | % {
            $timeValue = $_.Groups['time'].Value
            $errorTime = $creationTime.AddMinutes($timeValue.Substring(0,2)).AddSeconds($timeValue.Substring(3,2))
            $duration = $timeValue.Split('-')[1]
            $beginTime = $timeValue.Split('.')[1].Split('-')[0]
            $newLine = 1 | Select-Object @{Label='time';           Expression={$errorTime}  }`
                                        ,@{Label='begin';          Expression={$beginTime}  }`
                                        ,@{Label='duration';       Expression={$duration}   }`
                                        ,@{Label='fn:processName'; Expression={$processName}}`
                                        ,@{Label='fn:processID';   Expression={$processID}  }
            $names  = $_.Groups['name'] 
            $values = $_.Groups['value']
            1..$names.Captures.Count | % {
                $propertyName = $names.Captures[$_-1].Value
                $propertyValue = $values.Captures[$_-1].Value
                if ( ($newLine | gm $propertyName) -eq $null ) 
                {
                    Add-Member -MemberType NoteProperty -Name $propertyName -Value $propertyValue -InputObject $newLine 
                }
                else
                {
                    $newValue = @()
                    $newLine.$propertyName | % {$newValue += $_}
                    $newValue += $propertyValue
                    $newLine.$propertyName = $newValue
                }
            }
            $table += $newLine
        }
    }

    }

    End
    {
    $table
    }
}

<#
.Synopsis
   Извлекает данные из xml-файла выгрузки APDEX
.DESCRIPTION
   Производит извлечение данных из xml-файла выгрузки APDEX
.NOTES  
    Name: 1CHelper
    Author: yauhen.makei@gmail.com
.LINK  
    https://github.com/emakei/1CHelper.psm1
.EXAMPLE
   Get-APDEX-Data C:\APDEX\2017-05-16 07-02-54.xml
.EXAMPLE
   Get-APDEX-Data C:\APDEX\ -Verbose
#>
function Get-APDEXinfo
{
    [CmdletBinding()]
    [OutputType([Object[]])]
    Param
    (
        # Имя файла лога
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $fileName
    )

    Begin {
        $xdoc = New-Object System.Xml.XmlDocument
        $tree = @()
    }

    Process {
        Get-ChildItem $fileName -Recurse -File | % {
            Write-Verbose $_.FullName
            try {
                $xdoc.Load($_.FullName)
                if ($xdoc.HasChildNodes) {
                    $tree += $xdoc.Performance.KeyOperation
                }
            } catch {
                $Error | % { Write-Error $_ }
            }
        }
    }

    End {
        $tree
    }
   
}

<#
.Synopsis
   Извлекает данные из файла лога технологического журнала
.DESCRIPTION
   Производит извлечение данных из файла лога технологического журнала
.NOTES  
    Name: 1CHelper
    Author: yauhen.makei@gmail.com
.LINK  
    https://github.com/emakei/1CHelper.psm1
.INPUTS
   Пусть к файлу(-ам) технологического журнала
.OUTPUTS
   Массив данных разбора текстовой информации журнала
.EXAMPLE
   Get-TechJournalData C:\LOG\rphost_280\17061412.log
   $properties = $tree | % { $_.Groups['name'].Captures } | select -Unique
.EXAMPLE
   Get-TechJournalData C:\LOG\ -Verbose
   $tree | ? { $_.Groups['name'] -like '*Context*' } | % { $_.Groups['value'] } | Select Value -Unique | fl
#>
function Get-TechJournalData
{
    [CmdletBinding()]
    [OutputType([Object[]])]
    Param
    (
        # Имя файла лога
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $fileName
    )

    Begin {
        # Данный шаблон соответствует одной записи журнала
        $template = @"
^(?<line>(?<time>\d\d\:\d\d\.\d{6}\-\d)\,(?<type>\w+)\,(?<level>\d)(\,(?<name>(\w+\:)?\w+)\=(?<value>([^"'\,\n]+|(\"[^"]+\")|(\'[^']+\'))?))+.*)
"@
        $regex = New-Object System.Text.RegularExpressions.Regex ($template, [System.Text.RegularExpressions.RegexOptions]::Multiline)
        $tree = @()
    }

    Process {
        Get-ChildItem $fileName -Recurse -File | % {
            Write-Verbose $_.FullName
            $rawText = Get-Content $_.FullName -Encoding UTF8 -Raw
            if ($rawText) {
                $matches = $regex.Matches($rawText)
                $tree += $matches
            }
        }
    }

    End {
        $tree
    }
   
}

function Remove-NotUsedObjects
<#
.Synopsis
   Удаление неиспользуемых объектов конфигурации

.DESCRIPTION
   Удаление элементов конфигурации с синонимом "(не используется)"

.EXAMPLE
   PS C:\> $modules = Remove-NotUsedObjects E:\TEMP\ExportingConfiguration
   PS C:\> $gr = $modules | group File, Object | select -First 1
   PS C:\> ise ($gr.Group.File | select -First 1) # открываем модуль в новой вкладке ISE
   # альтернатива 'start notepad $gr.Group.File[0]'
   PS C:\> $gr.Group | select Object, Type, Line, Position -Unique | sort Line, Position | fl # Смотрим что корректировать
   PS C:\>  $modules = $modules | ? File -NE ($gr.Group.File | select -First 1) # удаление обработанного файла из списка объектов
   # альтернатива '$modules = $modules | ? File -NE $psise.CurrentFile.FullPath'
   # и все сначала с команды '$gr = $modules | group File, Object | select -First 1'

.NOTES  
    Name: 1CHelper
    Author: yauhen.makei@gmail.com

.LINK  
    https://github.com/emakei/1CHelper.psm1

.INPUTS
   Пусть к файлам выгрузки конфигурации

.OUTPUTS
   Массив объектов с описанием файлов модулей и позиций, содержащих упоминания удаляемых объектов

#>
{
    [CmdletBinding(DefaultParameterSetName='pathToConfigurationFiles', 
                  SupportsShouldProcess=$true, 
                  PositionalBinding=$true,
                  ConfirmImpact='Medium')]
    [OutputType([Object[]])]
    Param
    (
        # Путь к файлам выгрузки конфигурации
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=0,
                   HelpMessage='Путь к файлам выгрузки конфигурации')]
        [ValidateNotNullOrEmpty()]
        [Alias("pathToFiles")] 
        [ValidateScript({Test-Path -LiteralPath $_})]
        [string]
        $pathToConfigurationFiles
    )

    Begin
    {
        Write-Verbose "Начало обработки файлов в $(Get-Date)"
        # Переменная для поиска подстроки определения типа платформы в строке с типом метаданных
        $chars = [char[]]("A")
        66..90 | % { $chars += [char]$_ }
        # Содержит псевдонимы пространств имен для XPath
        $hashTable = @{ root = "http://v8.1c.ru/8.3/MDClasses"; core = "http://v8.1c.ru/8.1/data/core"; readable = "http://v8.1c.ru/8.3/xcf/readable" }
        # Используется для приведения строки в нижний регистр при поиске подстроки "(не используется)"
        $dict = @{ replace = "НЕИСПОЛЬЗУТЯ"; with = "неиспользутя" }
        # эти данные не требуется обрабатывать
        $excludeTypes = @('Template','Help','WSDefinition')
    }
    Process
    {
        if ($pscmdlet.ShouldProcess("Обработать файлы в каталоге '$pathToFiles'"))
        {
            # Содержит имена на удаляемых файлов
            $fileRefs = [string[]]("")
            # Содержит имена файлов модулей, в которых упоминаются не используемые объекты
            $modules = @()
            # Содержит имена типов объектов конфигурации для удаления
            $typeRefs = [string[]]("")
            # Содержит имена типов дочерних объектов конфигурации (формы, команды, реквизиты, ресурсы, макеты)
            $childRefs = [string[]]("")
            # Выборка файлов вида <ИмяТипаПлатформы>.<ИмяТипаМетаданных>.xml
            Write-Progress -Activity "Поиск файлов *.xml" -Completed 
            $files = ls -LiteralPath $pathToFiles -Filter *.xml -File #| ? { $_.Name.ToString().Split('.').Count -eq 3 }
            $i = 1
            foreach ($item in $files) {
                Write-Progress -Activity "Поиск не используемых элементов в файлах *.xml" -PercentComplete ( $i / $files.Count * 100 )
                $thisIsShort = ($item.Name.ToString().Split('.').Count -eq 3)
                if ( $item.Name.Split('.').Count % 2 -eq 1 ) {
                    $pref = $item.Name.Split('.')[$item.Name.Split('.').Count-3]
                    $name = $item.Name.Split('.')[$item.Name.Split('.').Count-2]
                } else {
                    $pref = $item.Name.Split('.')[$item.Name.Split('.').Count-2]
                    $name = $item.Name.Split('.')[$item.Name.Split('.').Count-3]
                }
                $addAll = $false
                [xml]$xml = Get-Content $item.FullName -Encoding UTF8
                $nsmgr = New-Object -TypeName System.Xml.XmlNamespaceManager($xml.NameTable)
                # Добавляем псевдоним для 'v8'
                $nsmgr.AddNamespace("core", "http://v8.1c.ru/8.1/data/core")
                $nsmgr.AddNamespace("root", "http://v8.1c.ru/8.3/MDClasses")
                $nsmgr.AddNamespace("item", "http://v8.1c.ru/8.3/xcf/readable")
                $nsmgr.AddNamespace("exch", "http://v8.1c.ru/8.3/xcf/extrnprops")
                # Если синоним объекта содержит подстроку '(не используется)', то
                if ($thisIsShort -and ($xml | `
                    Select-Xml -XPath ("//root:$pref/root:Properties/root:Synonym/core:item/core:content[contains(translate(text(),$($dict.replace),$($dict.with)),'(не используется)')]") `
                        -Namespace $hashTable `
                        | measure).Count -gt 0) {
                    # Добавляем имя файла в массив удаляемых
                    $fileRefs += $item.FullName
                    # Находим производные типы
                    $tmp = $xml | Select-Xml -XPath ("//root:$pref/root:InternalInfo/readable:GeneratedType/@name") -Namespace $hashTable
                    $tmp | % { $typeRefs += $_.ToString() }
                    # Находим подчиненные объекты (<ИмяТипаПлатформы>.<ИмяТипаМетаданных>.*) и добавляем к удаляемым файлам
                    ls -LiteralPath $pathToFiles -Filter "$($m[0]).$($m[1]).*" -File | ? { $_.Name.ToString().Split('.').Count -gt 3 } | % { $fileRefs += $_.FullName }
                    $addAll = $true
                } elseif(-not $thisIsShort) {
                    
                }
                # Поиск аттрибутов
                if ($addAll) {
                    # Поиск аттрибутов
                    $xml.SelectNodes("//root:MetaDataObject/root:$pref/root:ChildObjects/root:Attribute/root:Properties/root:Name", $nsmgr) | % { $childRefs += "$pref.$name.Attribute.$($_.'#text')" } 
                    # Поиск форм
                    $xml.SelectNodes("//root:MetaDataObject/root:$pref/root:ChildObjects/root:Form", $nsmgr) | % { $childRefs += "$pref.$name.Form.$($_.'#text')" }
                    # Поиск команд
                    $xml.SelectNodes("//root:MetaDataObject/root:$pref/root:ChildObjects/root:Command/root:Properties/root:Name", $nsmgr) | % { $childRefs += "$pref.$name.Command.$($_.'#text')" }
                    # Поиск макетов
                    $xml.SelectNodes("//root:MetaDataObject/root:$pref/root:ChildObjects/root:Template", $nsmgr) | % { "$pref.$name.Template.$($_.'#text')" }
                    # Поиск ресурсов информациооного регистра
                    if ($pref -eq 'InformationRegister') {
                        $xml.SelectNodes("//root:MetaDataObject/root:$pref/root:ChildObjects/root:Resource/root:Properties/root:Name", $nsmgr) | % { "$pref.$name.Resource.$($_.'#text')" }
                    }
                } else {
                    <# 
                    # Если синоним объекта содержит текст "(не используется)", тогда удаляем файл
                    if (($xml | `
                        Select-Xml -XPath ("//root:$pref/root:Properties/root:Synonym/core:item/core:content[contains(translate(text(),$($dict.replace),$($dict.with)),'(не используется)')]") `
                            -Namespace $hashTable `
                            | measure).Count -gt 0) {
                        # Удаление файлов
                        rm ($item.Name.Substring(0, $item.Name.Length - $item.Extension.Length) + '*') -Verbose
                    } 
                    #>
                }
                $i++
            }
            # Удаляем файлы
            $fileRefs | ? { $_ -notlike '' } | % {rm $_ -Verbose}
            # Выбираем оставшиеся для поиска неиспользуемых ссылок на типы и атрибутов
            Write-Progress -Activity "Поиск файлов *.xml" -Completed -Status "Подготовка"
            $filesToUpdate = ls -LiteralPath $pathToFiles -Filter *.xml -File
            # Удаляем пустой элемент (Создан при вызове конструктора типа)
            Write-Progress -Activity "Обработка ссылок для поиска" -Completed -Status "Подготовка"
            $typeRefs = $typeRefs | ? { $_ -notlike '' } | select -Unique
            $childRefs = $childRefs | ? { $_ -notlike '' } | select -Unique
            $i = 1
            foreach ( $item in $filesToUpdate ) {
                Write-Progress -Activity "Обработка файлов *.xml" -PercentComplete ( $i / $filesToUpdate.Count * 100 )
                Write-Verbose "Файл '$($item.FullName)'"
                if ( $item.Name.Split('.').Count % 2 -eq 1 ) {
                    $pref = $item.Name.Split('.')[$item.Name.Split('.').Count-3]
                    $name = $item.Name.Split('.')[$item.Name.Split('.').Count-2]
                } else {
                    $pref = $item.Name.Split('.')[$item.Name.Split('.').Count-2]
                    $name = $item.Name.Split('.')[$item.Name.Split('.').Count-3]
                }
                if ($pref -in $excludeTypes) { 
                    Write-Verbose "Пропуск файла по шаблону '$pref'"
                    Continue
                }
                [xml]$xml = Get-Content $item.FullName -Encoding UTF8
                # Создаем менеджер пространств имен для XPath
                $nsmgr = New-Object -TypeName System.Xml.XmlNamespaceManager($xml.NameTable)
                # Добавляем псевдоним для 'v8'
                $nsmgr.AddNamespace("core", "http://v8.1c.ru/8.1/data/core")
                $nsmgr.AddNamespace("root", "http://v8.1c.ru/8.3/MDClasses")
                $nsmgr.AddNamespace("item", "http://v8.1c.ru/8.3/xcf/readable")
                $nsmgr.AddNamespace("exch", "http://v8.1c.ru/8.3/xcf/extrnprops")
                # Если это файл описания конфигурации
                #else
                if ($item.Name -eq 'Configuration.xml') {
                    Write-Verbose "in 'Configuration'"
                    foreach ($tref in $typeRefs) {
                        # Получаем из <ИмяТипаПлатформы>.<ИмяТипаМетаданных> значение <ИмяТипаПлатформы>
                        if ($tref.ToString().Split('.').Count -lt 2) {
                            Write-Error "Неверный тип для поиска" -ErrorId C1 -Targetobject $tref -Category ParserError
                            continue
                        }
                        $tpref = $tref.ToString().Split('.')[0] 
                        $max = -1
                        $chars | % { $max = [Math]::Max($max, $tpref.LastIndexOf($_)) }
                        if ($max -eq -1) {
                            Write-Error "Неверный тип для поиска" -ErrorId C2 -Targetobject $tref -Category ParserError
                            continue
                        } else {
                            $type = if($max -eq 0) { $tref.Split('.')[0] } else { $tpref.Substring(0, $max) }
                            try {
                                $xml.SelectNodes("//root:MetaDataObject/root:Configuration/root:ChildObjects/root:$type[text()='$($tref.Split('.')[1])']/.", $nsmgr) `
                                    | % { $_.ParentNode.RemoveChild($_) | Out-Null }
                            } catch {
                                Write-Error "Ошибка обработки файла" -ErrorId C3 `
                                    -Targetobject "//root:MetaDataObject/root:Configuration/root:ChildObjects/root:$type[text()='$($tref.Split('.')[1])']/."
                                    -Category ParserError
                            }
                        }
                    }
                }
                # Если это файл описания командного интерфейса конфигурации
                elseif ($item.Name -eq 'Configuration.CommandInterface.xml') {
                    Write-Verbose "in 'Configuration.CommandInterface'"
                    foreach ($tref in $typeRefs) {
                        # Обрабатываем только роли и подсистемы
                        if (-not ($tref.StartsWith('Role.') -or $tref.StartsWith('Subsystem.'))) { Continue }
                        # Получаем из <ИмяТипаПлатформы>.<ИмяТипаМетаданных> значение <ИмяТипаПлатформы>
                        if ($tref.ToString().Split('.').Count -lt 2) {
                            Write-Error "Неверный тип для поиска" -ErrorId C1 -Targetobject $tref -Category ParserError
                            continue
                        }
                        $tpref = $tref.ToString().Split('.')[0] 
                        $max = -1
                        $chars | % { $max = [Math]::Max($max, $tpref.LastIndexOf($_)) }
                        if ($max -eq -1) {
                            Write-Error "Неверный тип для поиска" -ErrorId C2 -Targetobject $tref -Category ParserError
                            continue
                        } else {
                            $type = if($max -eq 0) { $tref.Split('.')[0] } else { $tpref.Substring(0, $max) }
                            if ($tref.StartsWith('Role.')) {
                                try {
                                    $xml.SelectNodes("//exch:$name/exch:SubsystemsVisibility/exch:Subsystem/exch:Visibility/item:Value[@name='$tref']/.", $nsmgr) `
                                        | % { $_.ParentNode.RemoveChild($_) | Out-Null }
                                } catch {
                                    Write-Error "Ошибка обработки файла" -ErrorId C3 `
                                        -Targetobject "//exch:$name/exch:SubsystemsVisibility/exch:Subsystem/exch:Visibility/item:Value[@name='$tref']/."
                                        -Category ParserError
                                }
                            } else {
                                try {
                                    $xml.SelectNodes("//exch:$name/exch:SubsystemsVisibility/exch:Subsystem[@name='$tref']/.", $nsmgr) `
                                        | % { $_.ParentNode.RemoveChild($_) | Out-Null }
                                } catch {
                                    Write-Error "Ошибка обработки файла" -ErrorId C3 `
                                        -Targetobject "//exch:$name/exch:SubsystemsVisibility/exch:Subsystem[@name='$tref']/."
                                        -Category ParserError
                                }
                                try {
                                    $xml.SelectNodes("//exch:$name/exch:SubsystemsOrder/exch:Subsystem[text()='$tref']/.", $nsmgr) `
                                        | % { $_.ParentNode.RemoveChild($_) | Out-Null }
                                } catch {
                                    Write-Error "Ошибка обработки файла" -ErrorId C3 `
                                        -Targetobject "//exch:$name/exch:SubsystemsOrder/exch:Subsystem[text()='$tref']/."
                                        -Category ParserError
                                }
                            }
                        }
                    }
                }
                # Если это файл описания командного интерфейса подсистемы
                elseif ($pref -eq 'CommandInterface') {
                    <#Write-Verbose "in 'Subsystem.*.CommandInterface'"
                    foreach ($tref in $typeRefs) {
                        # Обрабатываем только роли и подсистемы
                        if (-not ($tref.StartsWith('Role.') -or $tref.StartsWith('Subsystem.'))) { Continue }
                        # Получаем из <ИмяТипаПлатформы>.<ИмяТипаМетаданных> значение <ИмяТипаПлатформы>
                        if ($tref.ToString().Split('.').Count -lt 2) {
                            Write-Error "Неверный тип для поиска" -ErrorId C1 -Targetobject $tref -Category ParserError
                            continue
                        }
                        $tpref = $tref.ToString().Split('.')[0] 
                        $max = -1
                        $chars | % { $max = [Math]::Max($max, $tpref.LastIndexOf($_)) }
                        if ($max -eq -1) {
                            Write-Error "Неверный тип для поиска" -ErrorId C2 -Targetobject $tref -Category ParserError
                            continue
                        } else {
                            $type = if($max -eq 0) { $tref.Split('.')[0] } else { $tpref.Substring(0, $max) }
                            if ($tref.StartsWith('Role.')) {
                                try {
                                    $xml.SelectNodes("//exch:$name/exch:SubsystemsVisibility/exch:Subsystem/exch:Visibility/item:Value[@name='$tref']/.", $nsmgr) `
                                        | % { $_.ParentNode.RemoveChild($_) | Out-Null }
                                } catch {
                                    Write-Error "Ошибка обработки файла" -ErrorId C3 `
                                        -Targetobject "//exch:$name/exch:SubsystemsVisibility/exch:Subsystem/exch:Visibility/item:Value[@name='$tref']/."
                                        -Category ParserError
                                }
                            } else {
                                try {
                                    $xml.SelectNodes("//exch:$name/exch:SubsystemsVisibility/exch:Subsystem[@name='$tref']/.", $nsmgr) `
                                        | % { $_.ParentNode.RemoveChild($_) | Out-Null }
                                } catch {
                                    Write-Error "Ошибка обработки файла" -ErrorId C3 `
                                        -Targetobject "//exch:$name/exch:SubsystemsVisibility/exch:Subsystem[@name='$tref']/."
                                        -Category ParserError
                                }
                                try {
                                    $xml.SelectNodes("//exch:$name/exch:SubsystemsOrder/exch:Subsystem[text()='$tref']/.", $nsmgr) `
                                        | % { $_.ParentNode.RemoveChild($_) | Out-Null }
                                } catch {
                                    Write-Error "Ошибка обработки файла" -ErrorId C3 `
                                        -Targetobject "//exch:$name/exch:SubsystemsOrder/exch:Subsystem[text()='$tref']/."
                                        -Category ParserError
                                }
                            }
                        }
                    }#>
                }
                # Если это файл описания подсистемы
                elseif (($pref -eq 'Subsystem') -and ($item.Name.Split('.').Count % 2 -eq 1)) {
                    Write-Verbose "in 'Subsystem'"
                    foreach ($tref in $typeRefs) {
                        # Получаем из <ИмяТипаПлатформы>.<ИмяТипаМетаданных> значение <ИмяТипаПлатформы>
                        if ($tref.ToString().Split('.').Count -lt 2) {
                            Write-Error "Неверный тип для поиска" -ErrorId S1 -Targetobject $tref -Category ParserError
                            continue
                        }
                        $tpref = $tref.ToString().Split('.')[0]
                        $max = -1
                        $chars | % { $max = [Math]::Max($max, $tpref.LastIndexOf($_)) }
                        if ($max -eq -1) {
                            Write-Error "Неверный тип для поиска" -ErrorId S2 -Targetobject $tref -Category ParserError
                            continue
                        } else {
                            $type = if($max -eq 0) { $tref.Split('.')[0] } else { $tpref.Substring(0, $max) }
                            try {
                                $xml.SelectNodes("//root:MetaDataObject/root:Subsystem/root:Properties/root:Content/item:Item[text()='$($type+'.'+$tref.Split('.')[1])']/.", $nsmgr) `
                                    | % { $_.ParentNode.RemoveChild($_) | Out-Null }
                            } catch {
                                Write-Error "Ошибка обработки файла" -ErrorId S3 `
                                    -Targetobject "//root:MetaDataObject/root:Subsystem/root:Properties/root:Content/item:Item[text()='$($type+'.'+$tref.Split('.')[1])']/."
                                    -Category ParserError
                            }
                        }
                    }
                }
                # Если это файл описания состава плана обмена
                elseif ($pref -eq 'Content') {
                    Write-Verbose "in 'Content'"
                    foreach ($tref in $typeRefs) {
                        # Получаем из <ИмяТипаПлатформы>.<ИмяТипаМетаданных> значение <ИмяТипаПлатформы>
                        if ($tref.ToString().Split('.').Count -lt 2) {
                            Write-Error "Неверный тип для поиска" -ErrorId S1 -Targetobject $tref -Category ParserError
                            continue
                        }
                        $tpref = $tref.ToString().Split('.')[0]
                        $max = -1
                        $chars | % { $max = [Math]::Max($max, $tpref.LastIndexOf($_)) }
                        if ($max -eq -1) {
                            Write-Error "Неверный тип для поиска" -ErrorId S2 -Targetobject $tref -Category ParserError
                            continue
                        } else {
                            $type = if($max -eq 0) { $tref.Split('.')[0] } else { $tpref.Substring(0, $max) }
                            try {
                                $xml.SelectNodes("//exch:$name/exch:Item/exch:Metadata/[text()='$($type+'.'+$tref.Split('.')[1])']/.", $nsmgr) `
                                    | % { $_.ParentNode.RemoveChild($_) | Out-Null }
                            } catch {
                                Write-Error "Ошибка обработки файла" -ErrorId S3 `
                                    -Targetobject "//exch:$name/exch:Item/exch:Metadata/[text()='$($type+'.'+$tref.Split('.')[1])']/."
                                    -Category ParserError
                            }
                        }
                    }
                }
                # Если это файл описания прав доступа
                elseif ($pref -eq 'Rights') {
                }
                # Иначе удаляем ссылки на неиспользуемые типы и узлы с синонимом содержащим текст "(не используется)" 
                else {
                    Write-Verbose "Поиск ссылок" 
                    $typeRefs | % { $xml.SelectNodes("//*/core:Type[contains(text(), '$_')]/.", $nsmgr) } | % { $_.ParentNode.RemoveChild($_) | Out-Null }
                    Write-Verbose "Поиск неиспользуемых атрибутов"
                    $xml.SelectNodes("//*/core:content[contains(translate(text(),$($dict.replace),$($dict.with)),'(не используется)')]/../../../..", $nsmgr) `
                        | % { $_.ParentNode.RemoveChild($_) | Out-Null }
                }
                if (Test-Path -LiteralPath $item.FullName) {
                    $xml.Save($item.FullName)
                }
                $i++
            }
            # Обработка модулей объектов
            Write-Progress -Activity "Поиск файлов модулей (*.txt)" -Completed
            $txtFiles = ls -LiteralPath $pathToFiles -Filter *.txt -File
            $i = 1
            foreach ( $item in $txtFiles ) {
                Write-Progress -Activity "Обработка файлов *.txt" -PercentComplete ( $i / $txtFiles.Count * 100 )
                Write-Verbose "Файл '$($item.FullName)'"
                $data = Get-Content $item.FullName -Encoding UTF8
                $lineNumber = 0
                foreach ( $str in $data ) {
                    $lineNumber += 1
                    # Если строка закомментирована - продолжаем
                    if ($str -match "\A[\t, ]*//") { continue }
                    foreach ( $tref in $typeRefs ) {
                        try {
                            $subString = $tref.ToString().Split('.')[1]
                            $subStringType = $tref.ToString().Split('.')[0]
                        } catch {
                            Write-Error "Неверный тип для поиска" -ErrorId T1 -Targetobject $tref -Category ParserError
                            continue
                        }
                        $ind = $str.IndexOf($subString)
                        if ($ind -ne -1) {
                            # Костыль
                            $modules += 1 | Select-Object @{ Name = 'File';     Expression = { $item.FullName } },
                                                          @{ Name = 'Line';     Expression = { $lineNumber } },
                                                          @{ Name = 'Position'; Expression = { $ind + 1 } },
                                                          @{ Name = 'Object';   Expression = { $subString } },
                                                          @{ Name = 'Type';     Expression = { $subStringType } }
                            Write-Verbose "`$tref = $tref; `$lineNumber = $lineNumber; `$ind = $ind`n`$subString = '$subString'"
                        }
                    }
                }
                $i++
            }
            Write-Output $modules
        }
    }
    End
    {
        Write-Verbose "Окончание обработки файлов в $(Get-Date)"
    }
}

function Find-1CEstart
<#
.Synopsis
   Поиск стартера 1С

.DESCRIPTION
   Поиск исполняемого файла 1cestart.exe

.NOTES  
    Name: 1CHelper
    Author: yauhen.makei@gmail.com

.LINK  
    https://github.com/emakei/1CHelper.psm1

.EXAMPLE
   Find-1CEstart

.OUTPUTS
   NULL или строку с полным путём к исполняемому файлу
#>
{
    Param(
        # Имя компьютера для поиска версии
        [string]$ComputerName = $env:COMPUTERNAME
    )
    
    $pathToStarter = $null

    $keys = @( @{ leaf='ClassesRoot'; path='Applications\\1cestart.exe\\shell\\open\\command' } )
    $keys += @{ leaf='ClassesRoot'; path='V83.InfoBaseList\\shell\\open\\command' }
    $keys += @{ leaf='ClassesRoot'; path='V83.InfoBaseListLink\\shell\\open\\command' }
    $keys += @{ leaf='ClassesRoot'; path='V82.InfoBaseList\\shell\\open\\command' }
    $keys += @{ leaf='LocalMachine'; path='SOFTWARE\\Classes\\Applications\\1cestart.exe\\shell\\open\\command' }
    $keys += @{ leaf='LocalMachine'; path='SOFTWARE\\Classes\\V83.InfoBaseList\\shell\\open\\command' }
    $keys += @{ leaf='LocalMachine'; path='SOFTWARE\\Classes\\V83.InfoBaseListLink\\shell\\open\\command' }
    $keys += @{ leaf='LocalMachine'; path='SOFTWARE\\Classes\\V82.InfoBaseList\\shell\\open\\command' }

    foreach( $key in $keys ) {
                
         Try {
             $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey( $key.leaf, $computerName )
         } Catch {
             Write-Error $_
             Continue
         }
 
         $regkey = $reg.OpenSubKey( $key.path )

         If( -not $regkey ) {
             Write-Warning "Не найдены ключи в: $($string.leaf)\\$($string.path)"
         }

         $defaultValue = $regkey.GetValue("").ToString()

         $index = $defaultValue.IndexOf("1cestart.exe")

         if ( $index -gt 0 ) {

            if ( $defaultValue[0] -eq '"' ) {
                $pathToStarter = $defaultValue.Substring( 1, $index + 11 )
            } else {
                $pathToStarter = $defaultValue.Substring( 0, $index + 11 )
            }

            $reg.Close()
            Break

         }

         $reg.Close()

    }

    # если не удалось найти, то пробуем через WinRM

    if ( -not $pathToStarter -and $ComputerName -ne $env:COMPUTERNAME ) {

        $pathToStarter = Invoke-Command -ComputerName $ComputerName -ScriptBlock { 
                            if ( Test-Path "${env:ProgramFiles(x86)}\1cv8\common\1cestart.exe" ) {
                                "${env:ProgramFiles(x86)}\1cv8\common\1cestart.exe" 
                            } elseif ( Test-Path "${env:ProgramFiles(x86)}\1cv82\common\1cestart.exe" ) {
                                "${env:ProgramFiles(x86)}\1cv82\common\1cestart.exe"
                            } else { $null } 
                         } -ErrorAction Continue

    } elseif ( -not $pathToStarter ) {

        $pathToStarter = if ( Test-Path "${env:ProgramFiles(x86)}\1cv8\common\1cestart.exe" ) {
                                "${env:ProgramFiles(x86)}\1cv8\common\1cestart.exe" 
                            } elseif ( Test-Path "${env:ProgramFiles(x86)}\1cv82\common\1cestart.exe" ) {
                                "${env:ProgramFiles(x86)}\1cv82\common\1cestart.exe"
                            } else { $null }
                              
    }

    $pathToStarter
}

function Find-1C8conn
<#
.Synopsis
   Поиск строк подключения 1С

.DESCRIPTION
   Поиск строк подключения

.NOTES  
    Name: 1CHelper
    Author: yauhen.makei@gmail.com

.LINK  
    https://github.com/emakei/1CHelper.psm1

.EXAMPLE
   Find-1C8conn

.OUTPUTS
   массив найденных строк поключения 1С
#>
{
    [OutputType([Object[]])]
    Param(
        # Использовать общие файлы
        [switch]$UseCommonFiles = $true,
        [string[]]$UseFilesFromDirectories
    )

    # TODO http://yellow-erp.com/page/guides/adm/service-files-description-and-location/
    # TODO http://yellow-erp.com/page/guides/adm/service-files-description-and-location/

    $list = @()

    # TODO 

    $list
    
}

function Get-ClusterData
<#
.Synopsis
    Собирает информацию с кластеров 1С

.DESCRIPTION

.NOTES  
    Name: 1CHelper
    Author: yauhen.makei@gmail.com

.LINK  
    https://github.com/emakei/1CHelper.psm1

.EXAMPLE
    Get-1CclusterData

.EXAMPLE
    Get-1CclusterData 'srv-01','srv-02'

.EXAMPLE
    $netHaspParams = Get-NetHaspIniStrings
    $hostsToQuery += $netHaspParams.NH_SERVER_ADDR
    $hostsToQuery += $netHaspParams.NH_SERVER_NAME
    
    $stat = $hostsToQuery | % { Get-1CclusterData $_ -Verbose }

.OUTPUTS
    Данные кластера
#>
{
[OutputType([Object[]])]
[CmdletBinding()]
Param(
    # Адрес хоста для сбора статистики
    [Parameter(Mandatory=$true)]
    [string]$HostName,
    # имя админитратора кластера
    [string]$User="",
    # пароль администратора кластера
    [Security.SecureString]$Password="",
    # не получать инфорацию об администраторах кластера
    [switch]$NoClusterAdmins=$false,
    # не получать инфорацию о менеджерах кластера
    [switch]$NoClusterManagers=$false,
    # не получать инфорацию о рабочих серверах
    [switch]$NoWorkingServers=$false,
    # не получать инфорацию о рабочих процессах
    [switch]$NoWorkingProcesses=$false,
    # не получать инфорацию о сервисах кластера
    [switch]$NoClusterServices=$false,
    # Получать информацию о соединениях только для кластера, везде или вообще не получать
    [ValidateSet('None', 'Cluster', 'Everywhere')]
    [string]$ShowConnections='Everywhere',
    # Получать информацию о сессиях только для кластера, везде или вообще не получать
    [ValidateSet('None', 'Cluster', 'Everywhere')]
    [string]$ShowSessions='Everywhere',
    # Получать информацию о блокировках только для кластера, везде или вообще не получать
    [ValidateSet('None', 'Cluster', 'Everywhere')]
    [string]$ShowLocks='Everywhere',
    # не получать инфорацию об информационных базах
    [switch]$NoInfobases=$false,
    # не получать инфорацию о требованиях назначения
    [switch]$NoAssignmentRules=$false,
    # верия компоненты
    [ValidateSet(2, 3, 4)]
    [int]$Version=3
    )

Begin {
    $connector = New-Object -ComObject "v8$version.COMConnector"
    }

Process {
              
    $obj = 1 | Select-Object  @{ name = 'Host';     Expression = { $HostName } }`
                            , @{ name = 'Error';    Expression = { '' } }`
                            , @{ name = 'Clusters'; Expression = {  @() } }

    try {
        Write-Verbose "Подключение к '$HostName'"
        $connection = $connector.ConnectAgent( $HostName )
        $abort = $false
    } catch {
        Write-Warning $_
        $obj.Error = $_.Exception.Message
        $result = $obj
        $abort = $true
    }
        
    if ( -not $abort ) {
            
        Write-Verbose "Подключен к `"$($connection.ConnectionString)`""

        $clusters = $connection.GetClusters()

        foreach( $cluster in $clusters ) {
                
            $cls = 1 | Select-Object  @{ name = 'ClusterName';                Expression = { $cluster.ClusterName } }`
                                    , @{ name = 'ExpirationTimeout';          Expression = { $cluster.ExpirationTimeout } }`
                                    , @{ name = 'HostName';                   Expression = { $cluster.HostName } }`
                                    , @{ name = 'LoadBalancingMode';          Expression = { $cluster.LoadBalancingMode } }`
                                    , @{ name = 'MainPort';                   Expression = { $cluster.MainPort } }`
                                    , @{ name = 'MaxMemorySize';              Expression = { $cluster.MaxMemorySize } }`
                                    , @{ name = 'MaxMemoryTimeLimit';         Expression = { $cluster.MaxMemoryTimeLimit } }`
                                    , @{ name = 'SecurityLevel';              Expression = { $cluster.SecurityLevel } }`
                                    , @{ name = 'SessionFaultToleranceLevel'; Expression = { $cluster.SessionFaultToleranceLevel } }`
                                    , @{ name = 'Error';                      Expression = {} }

            Write-Verbose "Получение информации кластера `"$($cluster.ClusterName)`" на `"$($cluster.HostName)`""
                
            try {
                Write-Verbose "Аутентификация в кластере $($cluster.HostName,':',$cluster.MainPort,' - ',$cluster.ClusterName)"
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
                $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                $connection.Authenticate( $cluster, $User, $PlainPassword )
                $abort = $false
            } catch {
                Write-Warning $_
                $cls.Error = $_.Exception.Message
                $obj.Clusters += $cls
                $result = $obj
                $abort = $true
            }

            if ( -not $abort ) {
                    
                # TODO возможно нужно получить информацию из 'GetAgentAdmins'

                if ( -not $NoClusterAdmins ) {
                   
                    $admins = $connection.GetClusterAdmins( $cluster )
                    $objAdmin = @()

                    foreach ( $admin in $admins ) {
                        $objAdmin += 1 | Select-Object  @{ Name = 'Name';                Expression = { $admin.Name } },
                                                        @{ Name = 'Descr';               Expression = { $admin.Descr } },
                                                        @{ Name = 'PasswordAuthAllowed'; Expression = { $admin.PasswordAuthAllowed } },
                                                        @{ Name = 'SysAuthAllowed';      Expression = { $admin.SysAuthAllowed } },
                                                        @{ Name = 'SysUserName';         Expression = { $admin.SysUserName } }
                    }

                    Add-Member -InputObject $cls -Name ClusterAdmins -Value $objAdmin -MemberType NoteProperty
                    
                }

                if ( -not $NoClusterManagers ) {

                    $mngrs = $connection.GetClusterManagers( $cluster )
                    $objMngr = @()

                    foreach ( $mngr in $mngrs ) {
                        $objMngr += 1 | Select-Object  @{ Name = 'HostName';    Expression = { $mngr.HostName } },
                                                        @{ Name = 'Descr';       Expression = { $mngr.Descr } },
                                                        @{ Name = 'MainManager'; Expression = { $mngr.MainManager } },
                                                        @{ Name = 'MainPort';    Expression = { $mngr.MainPort } },
                                                        @{ Name = 'PID';         Expression = { $mngr.PID } }
                    }

                    Add-Member -InputObject $cls -Name ClusterManagers -Value $objMngr -MemberType NoteProperty

                }

                if ( -not $NoWorkingServers ) {

                    $ws = $connection.GetWorkingServers( $cluster )
                    $objWS = @()
                    foreach( $workingServer in $ws ) {

                        $objWS += 1 | Select-Object @{ Name = 'ClusterMainPort';                   Expression = { $workingServer.ClusterMainPort } },
                                                    @{ Name = 'ConnectionsPerWorkingProcessLimit'; Expression = { $workingServer.ConnectionsPerWorkingProcessLimit } },
                                                    @{ Name = 'DedicatedManagers';                 Expression = { $workingServer.DedicatedManagers } },
                                                    @{ Name = 'HostName';                          Expression = { $workingServer.HostName } },
                                                    @{ Name = 'InfoBasesPerWorkingProcessLimit';   Expression = { $workingServer.InfoBasesPerWorkingProcessLimit } },
                                                    @{ Name = 'MainPort';                          Expression = { $workingServer.MainPort } },
                                                    @{ Name = 'MainServer';                        Expression = { $workingServer.MainServer } },
                                                    @{ Name = 'Name';                              Expression = { $workingServer.Name } },
                                                    @{ Name = 'SafeCallMemoryLimit';               Expression = { $workingServer.SafeCallMemoryLimit } },
                                                    @{ Name = 'SafeWorkingProcessesMemoryLimit';   Expression = { $workingServer.SafeWorkingProcessesMemoryLimit } },
                                                    @{ Name = 'WorkingProcessMemoryLimit';         Expression = { $workingServer.WorkingProcessMemoryLimit } }

                        if ( -not $NoAssignmentRules ) {
                            
                            $assignmentRules = $connection.GetAssignmentRules( $cluster, $workingServer )
                            $objAR = @()
                            foreach( $assignmentRule in $assignmentRules ) {
                                $objAR += 1 | Select-Object @{ Name = 'ApplicationExt'; Expression = { $assignmentRule.ApplicationExt } },
                                                            @{ Name = 'InfoBaseName';   Expression = { $assignmentRule.InfoBaseName } },
                                                            @{ Name = 'ObjectType';     Expression = { $assignmentRule.ObjectType } },
                                                            @{ Name = 'Priority';       Expression = { $assignmentRule.Priority } },
                                                            @{ Name = 'RuleType';       Expression = { $assignmentRule.RuleType } }
                            }
                
                            Add-Member -InputObject $objWS[$objWS.Count-1] -Name AssignmentRules -Value $objAR -MemberType NoteProperty

                        }

                    }

                    Add-Member -InputObject $cls -Name WorkingServers -Value $objWS -MemberType NoteProperty

                }

                if ( -not $NoWorkingProcesses ) {
                
                    $wp = $connection.GetWorkingProcesses( $cluster )
                    $objWP = @()

                    foreach( $workingProcess in $wp ) {
                    
                        $objWP += 1 | Select-Object @{ Name = 'AvailablePerfomance'; Expression = { $workingProcess.AvailablePerfomance } },
                                                    @{ Name = 'AvgBackCallTime';     Expression = { $workingProcess.AvgBackCallTime } },
                                                    @{ Name = 'AvgCallTime';         Expression = { $workingProcess.AvgCallTime } },
                                                    @{ Name = 'AvgDBCallTime';       Expression = { $workingProcess.AvgDBCallTime } },
                                                    @{ Name = 'AvgLockCallTime';     Expression = { $workingProcess.AvgLockCallTime } },
                                                    @{ Name = 'AvgServerCallTime';   Expression = { $workingProcess.AvgServerCallTime } },
                                                    @{ Name = 'AvgThreads';          Expression = { $workingProcess.AvgThreads } },
                                                    @{ Name = 'Capacity';            Expression = { $workingProcess.Capacity } },
                                                    @{ Name = 'Connections';         Expression = { $workingProcess.Connections } },
                                                    @{ Name = 'HostName';            Expression = { $workingProcess.HostName } },
                                                    @{ Name = 'IsEnable';            Expression = { $workingProcess.IsEnable } },
                                                    @{ Name = 'License';             Expression = { try { $workingProcess.License.FullPresentation } catch { $null } } },
                                                    @{ Name = 'MainPort';            Expression = { $workingProcess.MainPort   } },
                                                    @{ Name = 'MemoryExcessTime';    Expression = { $workingProcess.MemoryExcessTime } },
                                                    @{ Name = 'MemorySize';          Expression = { $workingProcess.MemorySize } },
                                                    @{ Name = 'PID';                 Expression = { $workingProcess.PID } },
                                                    @{ Name = 'Running';             Expression = { $workingProcess.Running } },
                                                    @{ Name = 'SelectionSize';       Expression = { $workingProcess.SelectionSize } },
                                                    @{ Name = 'StartedAt';           Expression = { $workingProcess.StartedAt } },
                                                    @{ Name = 'Use';                 Expression = { $workingProcess.Use } }

                    }

                    Add-Member -InputObject $cls -Name WorkingProcesses -Value $objWP -MemberType NoteProperty

                }

                if ( -not $NoClusterServices ) {

                    $сs = $connection.GetClusterServices( $cluster )
                    $objCS = @()
                    foreach( $service in $сs ) {
                        $objCS += 1 | Select-Object @{ Name = 'Descr';    Expression = { $service.Descr } },
                                                    @{ Name = 'MainOnly'; Expression = { $service.MainOnly } },
                                                    @{ Name = 'Name';     Expression = { $service.Name } }
                        $objCM = @()
                        foreach( $cmngr in $service.ClusterManagers ) {
                            $objCM += 1 | Select-Object @{ Name = 'HostName';    Expression = { $cmngr.HostName } },
                                                        @{ Name = 'Descr';       Expression = { $cmngr.Descr } },
                                                        @{ Name = 'MainManager'; Expression = { $cmngr.MainManager } },
                                                        @{ Name = 'MainPort';    Expression = { $cmngr.MainPort } },
                                                        @{ Name = 'PID';         Expression = { $cmngr.PID } }
                        }
                        Add-Member -InputObject $objCS -Name ClusterManagers -Value $objCM -MemberType NoteProperty
                    }             

                }

                if ( $ShowConnections -ne 'None' ) {

                    $cConnections = $connection.GetConnections( $cluster )
                    $objCC = @()
                    foreach( $conn in $cConnections ) {
                        
                        $objCC += 1 | Select-Object @{ Name = 'Application'; Expression = { $conn.Application } },
                                                    @{ Name = 'blockedByLS'; Expression = { $conn.blockedByLS } },
                                                    @{ Name = 'ConnectedAt'; Expression = { $conn.ConnectedAt } },
                                                    @{ Name = 'ConnID';      Expression = { $conn.ConnID } },
                                                    @{ Name = 'Host';        Expression = { $conn.Host } },
                                                    @{ Name = 'InfoBase';    Expression = { @{ Descr = $conn.InfoBase.Descr; Name = $conn.InfoBase.Name } } },
                                                    @{ Name = 'SessionID';   Expression = { $conn.SessionID } },
                                                    @{ Name = 'Process';     Expression = { if ( -not $NoWorkingProcesses ) { 1 | Select-Object   @{ Name = 'AvailablePerfomance'; Expression = { $conn.Process.AvailablePerfomance } },
                                                                                                                @{ Name = 'AvgBackCallTime';     Expression = { $conn.Process.AvgBackCallTime } },
                                                                                                                @{ Name = 'AvgCallTime';         Expression = { $conn.Process.AvgCallTime } },
                                                                                                                @{ Name = 'AvgDBCallTime';       Expression = { $conn.Process.AvgDBCallTime } },
                                                                                                                @{ Name = 'AvgLockCallTime';     Expression = { $conn.Process.AvgLockCallTime } },
                                                                                                                @{ Name = 'AvgServerCallTime';   Expression = { $conn.Process.AvgServerCallTime } },
                                                                                                                @{ Name = 'AvgThreads';          Expression = { $conn.Process.AvgThreads } },
                                                                                                                @{ Name = 'Capacity';            Expression = { $conn.Process.Capacity } },
                                                                                                                @{ Name = 'Connections';         Expression = { $conn.Process.Connections } },
                                                                                                                @{ Name = 'HostName';            Expression = { $conn.Process.HostName } },
                                                                                                                @{ Name = 'IsEnable';            Expression = { $conn.Process.IsEnable } },
                                                                                                                @{ Name = 'License';             Expression = { try { $conn.Process.License.FullPresentation } catch { $null } } },
                                                                                                                @{ Name = 'MainPort';            Expression = { $conn.Process.MainPort   } },
                                                                                                                @{ Name = 'MemoryExcessTime';    Expression = { $conn.Process.MemoryExcessTime } },
                                                                                                                @{ Name = 'MemorySize';          Expression = { $conn.Process.MemorySize } },
                                                                                                                @{ Name = 'PID';                 Expression = { $conn.Process.PID } },
                                                                                                                @{ Name = 'Running';             Expression = { $conn.Process.Running } },
                                                                                                                @{ Name = 'SelectionSize';       Expression = { $conn.Process.SelectionSize } },
                                                                                                                @{ Name = 'StartedAt';           Expression = { $conn.Process.Process.StartedAt } },
                                                                                                                @{ Name = 'Use';                 Expression = { $conn.Process.Use } } } } }

                        if ( $ShowLocks -eq 'Everywhere' ) {

                            $locks = $connection.GetConnectionLocks( $cluster, $conn )
                            $objLock = @()
                            foreach( $lock in $locks ) {
                                $objLock += 1 | Select-Object @{ Name = 'Connection';  Expression = { if ( $lock.Connection ) { 1 | Select-Object @{ Name = 'Application'; Expression = { $lock.Connection.Application } },
                                                                                                                    @{ Name = 'blockedByLS'; Expression = { $lock.Connection.blockedByLS } },
                                                                                                                    @{ Name = 'ConnectedAt'; Expression = { $lock.Connection.ConnectedAt } },
                                                                                                                    @{ Name = 'ConnID';      Expression = { $lock.Connection.ConnID } },
                                                                                                                    @{ Name = 'Host';        Expression = { $lock.Connection.Host } },
                                                                                                                    @{ Name = 'InfoBase';    Expression = { @{ Descr = $lock.Connection.InfoBase.Descr; Name = $lock.Connection.InfoBase.Name } } },
                                                                                                                    @{ Name = 'SessionID';   Expression = { $lock.Connection.SessionID } },
                                                                                                                    @{ Name = 'Process';     Expression = { if ( -not $NoWorkingProcesses ) { 1 | Select-Object @{ Name = 'AvailablePerfomance'; Expression = { $lock.Connection.Process.AvailablePerfomance } },
                                                                                                                                                                    @{ Name = 'AvgBackCallTime';     Expression = { $lock.Connection.Process.AvgBackCallTime } },
                                                                                                                                                                    @{ Name = 'AvgCallTime';         Expression = { $lock.Connection.Process.AvgCallTime } },
                                                                                                                                                                    @{ Name = 'AvgDBCallTime';       Expression = { $lock.Connection.Process.AvgDBCallTime } },
                                                                                                                                                                    @{ Name = 'AvgLockCallTime';     Expression = { $lock.Connection.Process.AvgLockCallTime } },
                                                                                                                                                                    @{ Name = 'AvgServerCallTime';   Expression = { $lock.Connection.Process.AvgServerCallTime } },
                                                                                                                                                                    @{ Name = 'AvgThreads';          Expression = { $lock.Connection.Process.AvgThreads } },
                                                                                                                                                                    @{ Name = 'Capacity';            Expression = { $lock.Connection.Process.Capacity } },
                                                                                                                                                                    @{ Name = 'Connections';         Expression = { $lock.Connection.Process.Connections } },
                                                                                                                                                                    @{ Name = 'HostName';            Expression = { $lock.Connection.Process.HostName } },
                                                                                                                                                                    @{ Name = 'IsEnable';            Expression = { $lock.Connection.Process.IsEnable } },
                                                                                                                                                                    @{ Name = 'License';             Expression = { try { $lock.Connection.Process.License.FullPresentation } catch { $null } } },
                                                                                                                                                                    @{ Name = 'MainPort';            Expression = { $lock.Connection.Process.MainPort } },
                                                                                                                                                                    @{ Name = 'MemoryExcessTime';    Expression = { $lock.Connection.Process.MemoryExcessTime } },
                                                                                                                                                                    @{ Name = 'MemorySize';          Expression = { $lock.Connection.Process.MemorySize } },
                                                                                                                                                                    @{ Name = 'PID';                 Expression = { $lock.Connection.Process.PID } },
                                                                                                                                                                    @{ Name = 'Running';             Expression = { $lock.Connection.Process.Running } },
                                                                                                                                                                    @{ Name = 'SelectionSize';       Expression = { $lock.Connection.Process.SelectionSize } },
                                                                                                                                                                    @{ Name = 'StartedAt';           Expression = { $lock.Connection.Process.Process.StartedAt } },
                                                                                                                                                                    @{ Name = 'Use';                 Expression = { $lock.Connection.Process.Use } } } } } } } },
                                                                @{ Name = 'LockDescr'; Expression = { $lock.LockDescr } },
                                                                @{ Name = 'LockedAt';  Expression = { $lock.LockedAt } },
                                                                @{ Name = 'Object';    Expression = { $lock.Object } },
                                                                @{ Name = 'Session';   Expression = { if ( $ShowSessions -eq 'Everywhere' ) { 1| Select-Object @{ Name = 'AppID'; Expression = { $lock.Session.AppID } },
                                                                                                            @{ Name = 'blockedByDBMS';                 Expression = { $lock.Session.blockedByDBMS } },
                                                                                                            @{ Name = 'blockedByLS';                   Expression = { $lock.Session.blockedByLS } },
                                                                                                            @{ Name = 'bytesAll';                      Expression = { $lock.Session.bytesAll } },
                                                                                                            @{ Name = 'bytesLast5Min';                 Expression = { $lock.Session.bytesLast5Min } },
                                                                                                            @{ Name = 'callsAll';                      Expression = { $lock.Session.callsAll } },
                                                                                                            @{ Name = 'callsLast5Min';                 Expression = { $lock.Session.callsLast5Min } },
                                                                                                            @{ Name = 'dbmsBytesAll';                  Expression = { $lock.Session.dbmsBytesAll } },
                                                                                                            @{ Name = 'dbmsBytesLast5Min';             Expression = { $lock.Session.dbmsBytesLast5Min } },
                                                                                                            @{ Name = 'dbProcInfo';                    Expression = { $lock.Session.dbProcInfo } },
                                                                                                            @{ Name = 'dbProcTook';                    Expression = { $lock.Session.dbProcTook } },
                                                                                                            @{ Name = 'dbProcTookAt';                  Expression = { $lock.Session.dbProcTookAt } },
                                                                                                            @{ Name = 'durationAll';                   Expression = { $lock.Session.durationAll } },
                                                                                                            @{ Name = 'durationAllDBMS';               Expression = { $lock.Session.durationAllDBMS } },
                                                                                                            @{ Name = 'durationCurrent';               Expression = { $lock.Session.durationCurrent } },
                                                                                                            @{ Name = 'durationCurrentDBMS';           Expression = { $lock.Session.durationCurrentDBMS } },
                                                                                                            @{ Name = 'durationLast5Min';              Expression = { $lock.Session.durationLast5Min } },
                                                                                                            @{ Name = 'durationLast5MinDBMS';          Expression = { $lock.Session.durationLast5MinDBMS } },
                                                                                                            @{ Name = 'Hibernate';                     Expression = { $lock.Session.Hibernate } },
                                                                                                            @{ Name = 'HibernateSessionTerminateTime'; Expression = { $lock.Session.HibernateSessionTerminateTime } },
                                                                                                            @{ Name = 'Host';                          Expression = { $lock.Session.Host } },
                                                                                                            @{ Name = 'InBytesAll';                    Expression = { $lock.Session.InBytesAll } },
                                                                                                            @{ Name = 'InBytesCurrent';                Expression = { $lock.Session.InBytesCurrent } },
                                                                                                            @{ Name = 'InBytesLast5Min';               Expression = { $lock.Session.InBytesLast5Min } },
                                                                                                            @{ Name = 'InfoBase';                      Expression = { @{ Descr = $lock.Session.InfoBase.Descr; Name = $lock.Session.InfoBase.Name } } },
                                                                                                            @{ Name = 'LastActiveAt';                  Expression = { $lock.Session.LastActiveAt } },
                                                                                                            @{ Name = 'License';                       Expression = { try { $lock.Session.Process.License.FullPresentation } catch { $null } } },
                                                                                                            @{ Name = 'Locale';                        Expression = { $lock.Session.Locale } },
                                                                                                            @{ Name = 'MemoryAll';                     Expression = { $lock.Session.MemoryAll } },
                                                                                                            @{ Name = 'MemoryCurrent';                 Expression = { $lock.Session.MemoryCurrent } },
                                                                                                            @{ Name = 'MemoryLast5Min';                Expression = { $lock.Session.MemoryLast5Min } },
                                                                                                            @{ Name = 'OutBytesAll';                   Expression = { $lock.Session.OutBytesAll } },
                                                                                                            @{ Name = 'OutBytesCurrent';               Expression = { $lock.Session.OutBytesCurrent } },
                                                                                                            @{ Name = 'OutBytesLast5Min';              Expression = { $lock.Session.OutBytesLast5Min } },
                                                                                                            @{ Name = 'PassiveSessionHibernateTime';   Expression = { $lock.Session.PassiveSessionHibernateTime } },
                                                                                                            @{ Name = 'SessionID';                     Expression = { $lock.Session.SessionID } },
                                                                                                            @{ Name = 'StartedAt';                     Expression = { $lock.Session.StartedAt } },
                                                                                                            @{ Name = 'UserName';                      Expression = { $lock.Session.UserName } },
                                                                                                            @{ Name = 'Process'; Expression = { if ( -not $NoWorkingProcesses ) { 1 | Select-Object @{ Name = 'AvailablePerfomance'; Expression = { $lock.Session.Process.AvailablePerfomance } },
                                                                                                                                                                    @{ Name = 'AvgBackCallTime';     Expression = { $lock.Session.Process.AvgBackCallTime } },
                                                                                                                                                                    @{ Name = 'AvgCallTime';         Expression = { $lock.Session.Process.AvgCallTime } },
                                                                                                                                                                    @{ Name = 'AvgDBCallTime';       Expression = { $lock.Session.Process.AvgDBCallTime } },
                                                                                                                                                                    @{ Name = 'AvgLockCallTime';     Expression = { $lock.Session.Process.AvgLockCallTime } },
                                                                                                                                                                    @{ Name = 'AvgServerCallTime';   Expression = { $lock.Session.Process.AvgServerCallTime } },
                                                                                                                                                                    @{ Name = 'AvgThreads';          Expression = { $lock.Session.Process.AvgThreads } },
                                                                                                                                                                    @{ Name = 'Capacity';            Expression = { $lock.Session.Process.Capacity } },
                                                                                                                                                                    @{ Name = 'Connections';         Expression = { $lock.Session.Process.Connections } },
                                                                                                                                                                    @{ Name = 'HostName';            Expression = { $lock.Session.Process.HostName } },
                                                                                                                                                                    @{ Name = 'IsEnable';            Expression = { $lock.Session.Process.IsEnable } },
                                                                                                                                                                    @{ Name = 'License';             Expression = { try { $lock.Session.Process.License.FullPresentation } catch { $null } } },
                                                                                                                                                                    @{ Name = 'MainPort';            Expression = { $lock.Session.Process.MainPort   } },
                                                                                                                                                                    @{ Name = 'MemoryExcessTime';    Expression = { $lock.Session.Process.MemoryExcessTime } },
                                                                                                                                                                    @{ Name = 'MemorySize';          Expression = { $lock.Session.Process.MemorySize } },
                                                                                                                                                                    @{ Name = 'PID';                 Expression = { $lock.Session.Process.PID } },
                                                                                                                                                                    @{ Name = 'Running';             Expression = { $lock.Session.Process.Running } },
                                                                                                                                                                    @{ Name = 'SelectionSize';       Expression = { $lock.Session.Process.SelectionSize } },
                                                                                                                                                                    @{ Name = 'StartedAt';           Expression = { $lock.Session.Process.Process.StartedAt } },
                                                                                                                                                                    @{ Name = 'Use';                 Expression = { $lock.Session.Process.Use } } } } },
                                                                                                            @{ Name = 'Connection'; Expression = { if ( $ShowConnections -eq 'Everywhere' ) { 1 | Select-Object @{ Name = 'Application'; Expression = { $lock.Session.Application } },
                                                                                                                                                                        @{ Name = 'blockedByLS'; Expression = { $lock.Session.blockedByLS } },
                                                                                                                                                                        @{ Name = 'ConnectedAt'; Expression = { $lock.Session.ConnectedAt } },
                                                                                                                                                                        @{ Name = 'ConnID';      Expression = { $lock.Session.ConnID } },
                                                                                                                                                                        @{ Name = 'Host';        Expression = { $lock.Session.Host } },
                                                                                                                                                                        @{ Name = 'InfoBase';    Expression = { @{ Descr = $lock.Session.InfoBase.Descr; Name = $lock.Session.InfoBase.Name } } },
                                                                                                                                                                        @{ Name = 'SessionID';   Expression = { $lock.Session.SessionID } },
                                                                                                                                                                        @{ Name = 'Process';     Expression = { if ( -not $NoWorkingProcesses ) { 1 | Select-Object   @{ Name = 'AvailablePerfomance'; Expression = { $lock.Session.Process.AvailablePerfomance } },
                                                                                                                                                                                                                                    @{ Name = 'AvgBackCallTime';     Expression = { $lock.Session.Process.AvgBackCallTime } },
                                                                                                                                                                                                                                    @{ Name = 'AvgCallTime';         Expression = { $lock.Session.Process.AvgCallTime } },
                                                                                                                                                                                                                                    @{ Name = 'AvgDBCallTime';       Expression = { $lock.Session.Process.AvgDBCallTime } },
                                                                                                                                                                                                                                    @{ Name = 'AvgLockCallTime';     Expression = { $lock.Session.Process.AvgLockCallTime } },
                                                                                                                                                                                                                                    @{ Name = 'AvgServerCallTime';   Expression = { $lock.Session.Process.AvgServerCallTime } },
                                                                                                                                                                                                                                    @{ Name = 'AvgThreads';          Expression = { $lock.Session.Process.AvgThreads } },
                                                                                                                                                                                                                                    @{ Name = 'Capacity';            Expression = { $lock.Session.Process.Capacity } },
                                                                                                                                                                                                                                    @{ Name = 'Connections';         Expression = { $lock.Session.Process.Connections } },
                                                                                                                                                                                                                                    @{ Name = 'HostName';            Expression = { $lock.Session.Process.HostName } },
                                                                                                                                                                                                                                    @{ Name = 'IsEnable';            Expression = { $lock.Session.Process.IsEnable } },
                                                                                                                                                                                                                                    @{ Name = 'License';             Expression = { try { $lock.Session.Process.License.FullPresentation } catch { $null } } },
                                                                                                                                                                                                                                    @{ Name = 'MainPort';            Expression = { $lock.Session.Process.MainPort   } },
                                                                                                                                                                                                                                    @{ Name = 'MemoryExcessTime';    Expression = { $lock.Session.Process.MemoryExcessTime } },
                                                                                                                                                                                                                                    @{ Name = 'MemorySize';          Expression = { $lock.Session.Process.MemorySize } },
                                                                                                                                                                                                                                    @{ Name = 'PID';                 Expression = { $lock.Session.Process.PID } },
                                                                                                                                                                                                                                    @{ Name = 'Running';             Expression = { $lock.Session.Process.Running } },
                                                                                                                                                                                                                                    @{ Name = 'SelectionSize';       Expression = { $lock.Session.Process.SelectionSize } },
                                                                                                                                                                                                                                    @{ Name = 'StartedAt';           Expression = { $lock.Session.Process.Process.StartedAt } },
                                                                                                                                                                                                                                    @{ Name = 'Use';                 Expression = { $lock.Session.Process.Use } } } } } } } } } } }
                            }

                            Add-Member -InputObject $objCC[$objCC.Count-1] -Name ConnectionLocks -Value $objLock -MemberType NoteProperty

                        }

                    }             

                    Add-Member -InputObject $cls -Name Connections -Value $objCC -MemberType NoteProperty

                }

                if ( -not $NoInfobases ) {

                    $infoBases = $connection.GetInfoBases( $cluster )
                    $objInfoBases = @()
                    foreach( $infoBase in $infoBases ) {
    
                        $objInfoBases += 1| Select-Object @{ Name = 'Descr'; Expression =  { $infoBase.Descr } },
                                                            @{ Name = 'Name';  Expression = { $infoBase.Name } }
                            
                        if ( $ShowSessions -eq 'Everywhere' ) {

                            $infoBaseSessions = $connection.GetInfoBaseSessions( $cluster, $infoBase )
                            $objInfoBaseSession = @()
                            foreach( $ibSession in $infoBaseSessions ) {
                                $objInfoBaseSession += 1| Select-Object @{ Name = 'AppID';                         Expression = { $ibSession.AppID } },
                                                                        @{ Name = 'blockedByDBMS';                 Expression = { $ibSession.blockedByDBMS } },
                                                                        @{ Name = 'blockedByLS';                   Expression = { $ibSession.blockedByLS } },
                                                                        @{ Name = 'bytesAll';                      Expression = { $ibSession.bytesAll } },
                                                                        @{ Name = 'bytesLast5Min';                 Expression = { $ibSession.bytesLast5Min } },
                                                                        @{ Name = 'callsAll';                      Expression = { $ibSession.callsAll } },
                                                                        @{ Name = 'callsLast5Min';                 Expression = { $ibSession.callsLast5Min } },
                                                                        @{ Name = 'dbmsBytesAll';                  Expression = { $ibSession.dbmsBytesAll } },
                                                                        @{ Name = 'dbmsBytesLast5Min';             Expression = { $ibSession.dbmsBytesLast5Min } },
                                                                        @{ Name = 'dbProcInfo';                    Expression = { $ibSession.dbProcInfo } },
                                                                        @{ Name = 'dbProcTook';                    Expression = { $ibSession.dbProcTook } },
                                                                        @{ Name = 'dbProcTookAt';                  Expression = { $ibSession.dbProcTookAt } },
                                                                        @{ Name = 'durationAll';                   Expression = { $ibSession.durationAll } },
                                                                        @{ Name = 'durationAllDBMS';               Expression = { $ibSession.durationAllDBMS } },
                                                                        @{ Name = 'durationCurrent';               Expression = { $ibSession.durationCurrent } },
                                                                        @{ Name = 'durationCurrentDBMS';           Expression = { $ibSession.durationCurrentDBMS } },
                                                                        @{ Name = 'durationLast5Min';              Expression = { $ibSession.durationLast5Min } },
                                                                        @{ Name = 'durationLast5MinDBMS';          Expression = { $ibSession.durationLast5MinDBMS } },
                                                                        @{ Name = 'Hibernate';                     Expression = { $ibSession.Hibernate } },
                                                                        @{ Name = 'HibernateSessionTerminateTime'; Expression = { $ibSession.HibernateSessionTerminateTime } },
                                                                        @{ Name = 'Host';                          Expression = { $ibSession.Host } },
                                                                        @{ Name = 'InBytesAll';                    Expression = { $ibSession.InBytesAll } },
                                                                        @{ Name = 'InBytesCurrent';                Expression = { $ibSession.InBytesCurrent } },
                                                                        @{ Name = 'InBytesLast5Min';               Expression = { $ibSession.InBytesLast5Min } },
                                                                        @{ Name = 'InfoBase';                      Expression = { @{ Descr = $ibSession.InfoBase.Descr; Name = $ibSession.InfoBase.Name } } },
                                                                        @{ Name = 'LastActiveAt';                  Expression = { $ibSession.LastActiveAt } },
                                                                        @{ Name = 'License';                       Expression = { try { $ibSession.Process.License.FullPresentation } catch { $null } } },
                                                                        @{ Name = 'Locale';                        Expression = { $ibSession.Locale } },
                                                                        @{ Name = 'MemoryAll';                     Expression = { $ibSession.MemoryAll } },
                                                                        @{ Name = 'MemoryCurrent';                 Expression = { $ibSession.MemoryCurrent } },
                                                                        @{ Name = 'MemoryLast5Min';                Expression = { $ibSession.MemoryLast5Min } },
                                                                        @{ Name = 'OutBytesAll';                   Expression = { $ibSession.OutBytesAll } },
                                                                        @{ Name = 'OutBytesCurrent';               Expression = { $ibSession.OutBytesCurrent } },
                                                                        @{ Name = 'OutBytesLast5Min';              Expression = { $ibSession.OutBytesLast5Min } },
                                                                        @{ Name = 'PassiveSessionHibernateTime';   Expression = { $ibSession.PassiveSessionHibernateTime } },
                                                                        @{ Name = 'SessionID';                     Expression = { $ibSession.SessionID } },
                                                                        @{ Name = 'StartedAt';                     Expression = { $ibSession.StartedAt } },
                                                                        @{ Name = 'UserName';                      Expression = { $ibSession.UserName } },
                                                                        @{ Name = 'Process'; Expression = { if ( -not $NoWorkingProcesses ) { 1 | Select-Object @{ Name = 'AvailablePerfomance'; Expression = { $ibSession.Process.AvailablePerfomance } },
                                                                                                                                @{ Name = 'AvgBackCallTime';     Expression = { $ibSession.Process.AvgBackCallTime } },
                                                                                                                                @{ Name = 'AvgCallTime';         Expression = { $ibSession.Process.AvgCallTime } },
                                                                                                                                @{ Name = 'AvgDBCallTime';       Expression = { $ibSession.Process.AvgDBCallTime } },
                                                                                                                                @{ Name = 'AvgLockCallTime';     Expression = { $ibSession.Process.AvgLockCallTime } },
                                                                                                                                @{ Name = 'AvgServerCallTime';   Expression = { $ibSession.Process.AvgServerCallTime } },
                                                                                                                                @{ Name = 'AvgThreads';          Expression = { $ibSession.Process.AvgThreads } },
                                                                                                                                @{ Name = 'Capacity';            Expression = { $ibSession.Process.Capacity } },
                                                                                                                                @{ Name = 'Connections';         Expression = { $ibSession.Process.Connections } },
                                                                                                                                @{ Name = 'HostName';            Expression = { $ibSession.Process.HostName } },
                                                                                                                                @{ Name = 'IsEnable';            Expression = { $ibSession.Process.IsEnable } },
                                                                                                                                @{ Name = 'License';             Expression = { try { $ibSession.Process.License.FullPresentation } catch { $null } } },
                                                                                                                                @{ Name = 'MainPort';            Expression = { $ibSession.Process.MainPort   } },
                                                                                                                                @{ Name = 'MemoryExcessTime';    Expression = { $ibSession.Process.MemoryExcessTime } },
                                                                                                                                @{ Name = 'MemorySize';          Expression = { $ibSession.Process.MemorySize } },
                                                                                                                                @{ Name = 'PID';                 Expression = { $ibSession.Process.PID } },
                                                                                                                                @{ Name = 'Running';             Expression = { $ibSession.Process.Running } },
                                                                                                                                @{ Name = 'SelectionSize';       Expression = { $ibSession.Process.SelectionSize } },
                                                                                                                                @{ Name = 'StartedAt';           Expression = { $ibSession.Process.Process.StartedAt } },
                                                                                                                                @{ Name = 'Use';                 Expression = { $ibSession.Process.Use } } } } },
                                                                        @{ Name = 'Connection'; Expression = { if ( $ShowConnections -eq 'Everywhere' ) { 1 | Select-Object @{ Name = 'Application'; Expression = { $ibSession.Application } },
                                                                                                                                    @{ Name = 'blockedByLS'; Expression = { $ibSession.blockedByLS } },
                                                                                                                                    @{ Name = 'ConnectedAt'; Expression = { $ibSession.ConnectedAt } },
                                                                                                                                    @{ Name = 'ConnID';      Expression = { $ibSession.ConnID } },
                                                                                                                                    @{ Name = 'Host';        Expression = { $ibSession.Host } },
                                                                                                                                    @{ Name = 'InfoBase';    Expression = { @{ Descr = $ibSession.InfoBase.Descr; Name = $ibSession.InfoBase.Name } } },
                                                                                                                                    @{ Name = 'SessionID';   Expression = { $ibSession.SessionID } },
                                                                                                                                    @{ Name = 'Process';     Expression = { if ( -not $NoWorkingProcesses ) { 1 | Select-Object   @{ Name = 'AvailablePerfomance'; Expression = { $ibSession.Process.AvailablePerfomance } },
                                                                                                                                                                                                @{ Name = 'AvgBackCallTime';     Expression = { $ibSession.Process.AvgBackCallTime } },
                                                                                                                                                                                                @{ Name = 'AvgCallTime';         Expression = { $ibSession.Process.AvgCallTime } },
                                                                                                                                                                                                @{ Name = 'AvgDBCallTime';       Expression = { $ibSession.Process.AvgDBCallTime } },
                                                                                                                                                                                                @{ Name = 'AvgLockCallTime';     Expression = { $ibSession.Process.AvgLockCallTime } },
                                                                                                                                                                                                @{ Name = 'AvgServerCallTime';   Expression = { $ibSession.Process.AvgServerCallTime } },
                                                                                                                                                                                                @{ Name = 'AvgThreads';          Expression = { $ibSession.Process.AvgThreads } },
                                                                                                                                                                                                @{ Name = 'Capacity';            Expression = { $ibSession.Process.Capacity } },
                                                                                                                                                                                                @{ Name = 'Connections';         Expression = { $ibSession.Process.Connections } },
                                                                                                                                                                                                @{ Name = 'HostName';            Expression = { $ibSession.Process.HostName } },
                                                                                                                                                                                                @{ Name = 'IsEnable';            Expression = { $ibSession.Process.IsEnable } },
                                                                                                                                                                                                @{ Name = 'License';             Expression = { try { $ibSession.Process.License.FullPresentation } catch { $null } } },
                                                                                                                                                                                                @{ Name = 'MainPort';            Expression = { $ibSession.Process.MainPort   } },
                                                                                                                                                                                                @{ Name = 'MemoryExcessTime';    Expression = { $ibSession.Process.MemoryExcessTime } },
                                                                                                                                                                                                @{ Name = 'MemorySize';          Expression = { $ibSession.Process.MemorySize } },
                                                                                                                                                                                                @{ Name = 'PID';                 Expression = { $ibSession.Process.PID } },
                                                                                                                                                                                                @{ Name = 'Running';             Expression = { $ibSession.Process.Running } },
                                                                                                                                                                                                @{ Name = 'SelectionSize';       Expression = { $ibSession.Process.SelectionSize } },
                                                                                                                                                                                                @{ Name = 'StartedAt';           Expression = { $ibSession.Process.Process.StartedAt } },
                                                                                                                                                                                                @{ Name = 'Use';                 Expression = { $ibSession.Process.Use } } } } } } } }
                            }

                            Add-Member -InputObject $objInfoBases[$objInfoBases.Count-1] -Name InfoBaseSessions -Value $objInfoBaseSession -MemberType NoteProperty
                            
                        }

                        if ( $ShowLocks -eq 'Everywhere' ) {
                            $nfoBaseLocks = $connection.GetInfoBaseLocks( $cluster, $infoBase )
                            $objIBL = @()
                            foreach( $ibLock in $nfoBaseLocks ) {
                                $objIBL += 1 | Select-Object @{ Name = 'Connection'; Expression = { if ( $ShowConnections -eq 'Everywhere' ) { 1 | Select-Object @{ Name = 'Application'; Expression = { $ibLock.Application } },
                                                                                                                                                    @{ Name = 'blockedByLS'; Expression = { $ibLock.blockedByLS } },
                                                                                                                                                    @{ Name = 'ConnectedAt'; Expression = { $ibLock.ConnectedAt } },
                                                                                                                                                    @{ Name = 'ConnID';      Expression = { $ibLock.ConnID } },
                                                                                                                                                    @{ Name = 'Host';        Expression = { $ibLock.Host } },
                                                                                                                                                    @{ Name = 'InfoBase';    Expression = { @{ Descr = $ibLock.InfoBase.Descr; Name = $ibLock.InfoBase.Name } } },
                                                                                                                                                    @{ Name = 'SessionID';   Expression = { $ibLock.SessionID } },
                                                                                                                                                    @{ Name = 'Process';     Expression = { if ( -not $NoWorkingProcesses ) { 1 | Select-Object   @{ Name = 'AvailablePerfomance'; Expression = { $ibLock.Process.AvailablePerfomance } },
                                                                                                                                                                                                                @{ Name = 'AvgBackCallTime';     Expression = { $ibLock.Process.AvgBackCallTime } },
                                                                                                                                                                                                                @{ Name = 'AvgCallTime';         Expression = { $ibLock.Process.AvgCallTime } },
                                                                                                                                                                                                                @{ Name = 'AvgDBCallTime';       Expression = { $ibLock.Process.AvgDBCallTime } },
                                                                                                                                                                                                                @{ Name = 'AvgLockCallTime';     Expression = { $ibLock.Process.AvgLockCallTime } },
                                                                                                                                                                                                                @{ Name = 'AvgServerCallTime';   Expression = { $ibLock.Process.AvgServerCallTime } },
                                                                                                                                                                                                                @{ Name = 'AvgThreads';          Expression = { $ibLock.Process.AvgThreads } },
                                                                                                                                                                                                                @{ Name = 'Capacity';            Expression = { $ibLock.Process.Capacity } },
                                                                                                                                                                                                                @{ Name = 'Connections';         Expression = { $ibLock.Process.Connections } },
                                                                                                                                                                                                                @{ Name = 'HostName';            Expression = { $ibLock.Process.HostName } },
                                                                                                                                                                                                                @{ Name = 'IsEnable';            Expression = { $ibLock.Process.IsEnable } },
                                                                                                                                                                                                                @{ Name = 'License';             Expression = { try { $ibLock.Process.License.FullPresentation } catch { $null } } },
                                                                                                                                                                                                                @{ Name = 'MainPort';            Expression = { $ibLock.Process.MainPort   } },
                                                                                                                                                                                                                @{ Name = 'MemoryExcessTime';    Expression = { $ibLock.Process.MemoryExcessTime } },
                                                                                                                                                                                                                @{ Name = 'MemorySize';          Expression = { $ibLock.Process.MemorySize } },
                                                                                                                                                                                                                @{ Name = 'PID';                 Expression = { $ibLock.Process.PID } },
                                                                                                                                                                                                                @{ Name = 'Running';             Expression = { $ibLock.Process.Running } },
                                                                                                                                                                                                                @{ Name = 'SelectionSize';       Expression = { $ibLock.Process.SelectionSize } },
                                                                                                                                                                                                                @{ Name = 'StartedAt';           Expression = { $ibLock.Process.Process.StartedAt } },
                                                                                                                                                                                                                @{ Name = 'Use';                 Expression = { $ibLock.Process.Use } } } } } } } },
                                                            @{ Name = 'LockDescr'; Expression = { $ibLock.LockDescr } },
                                                            @{ Name = 'LockedAt';  Expression = { $ibLock.MainManager } },
                                                            @{ Name = 'Object';    Expression = { $ibLock.MainPort } },
                                                            @{ Name = 'Session';   Expression = { if ( $ShowSessions -eq 'Everywhere' ) { 1| Select-Object @{ Name = 'AppID'; Expression = { $ibLock.Session.AppID } },
                                                                                                            @{ Name = 'blockedByDBMS';                 Expression = { $ibLock.Session.blockedByDBMS } },
                                                                                                            @{ Name = 'blockedByLS';                   Expression = { $ibLock.Session.blockedByLS } },
                                                                                                            @{ Name = 'bytesAll';                      Expression = { $ibLock.Session.bytesAll } },
                                                                                                            @{ Name = 'bytesLast5Min';                 Expression = { $ibLock.Session.bytesLast5Min } },
                                                                                                            @{ Name = 'callsAll';                      Expression = { $ibLock.Session.callsAll } },
                                                                                                            @{ Name = 'callsLast5Min';                 Expression = { $ibLock.Session.callsLast5Min } },
                                                                                                            @{ Name = 'dbmsBytesAll';                  Expression = { $ibLock.Session.dbmsBytesAll } },
                                                                                                            @{ Name = 'dbmsBytesLast5Min';             Expression = { $ibLock.Session.dbmsBytesLast5Min } },
                                                                                                            @{ Name = 'dbProcInfo';                    Expression = { $ibLock.Session.dbProcInfo } },
                                                                                                            @{ Name = 'dbProcTook';                    Expression = { $ibLock.Session.dbProcTook } },
                                                                                                            @{ Name = 'dbProcTookAt';                  Expression = { $ibLock.Session.dbProcTookAt } },
                                                                                                            @{ Name = 'durationAll';                   Expression = { $ibLock.Session.durationAll } },
                                                                                                            @{ Name = 'durationAllDBMS';               Expression = { $ibLock.Session.durationAllDBMS } },
                                                                                                            @{ Name = 'durationCurrent';               Expression = { $ibLock.Session.durationCurrent } },
                                                                                                            @{ Name = 'durationCurrentDBMS';           Expression = { $ibLock.Session.durationCurrentDBMS } },
                                                                                                            @{ Name = 'durationLast5Min';              Expression = { $ibLock.Session.durationLast5Min } },
                                                                                                            @{ Name = 'durationLast5MinDBMS';          Expression = { $ibLock.Session.durationLast5MinDBMS } },
                                                                                                            @{ Name = 'Hibernate';                     Expression = { $ibLock.Session.Hibernate } },
                                                                                                            @{ Name = 'HibernateSessionTerminateTime'; Expression = { $ibLock.Session.HibernateSessionTerminateTime } },
                                                                                                            @{ Name = 'Host';                          Expression = { $ibLock.Session.Host } },
                                                                                                            @{ Name = 'InBytesAll';                    Expression = { $ibLock.Session.InBytesAll } },
                                                                                                            @{ Name = 'InBytesCurrent';                Expression = { $ibLock.Session.InBytesCurrent } },
                                                                                                            @{ Name = 'InBytesLast5Min';               Expression = { $ibLock.Session.InBytesLast5Min } },
                                                                                                            @{ Name = 'InfoBase';                      Expression = { @{ Descr = $ibLock.Session.InfoBase.Descr; Name = $ibLock.Session.InfoBase.Name } } },
                                                                                                            @{ Name = 'LastActiveAt';                  Expression = { $ibLock.Session.LastActiveAt } },
                                                                                                            @{ Name = 'License';                       Expression = { try { $ibLock.Session.Process.License.FullPresentation } catch { $null } } },
                                                                                                            @{ Name = 'Locale';                        Expression = { $ibLock.Session.Locale } },
                                                                                                            @{ Name = 'MemoryAll';                     Expression = { $ibLock.Session.MemoryAll } },
                                                                                                            @{ Name = 'MemoryCurrent';                 Expression = { $ibLock.Session.MemoryCurrent } },
                                                                                                            @{ Name = 'MemoryLast5Min';                Expression = { $ibLock.Session.MemoryLast5Min } },
                                                                                                            @{ Name = 'OutBytesAll';                   Expression = { $ibLock.Session.OutBytesAll } },
                                                                                                            @{ Name = 'OutBytesCurrent';               Expression = { $ibLock.Session.OutBytesCurrent } },
                                                                                                            @{ Name = 'OutBytesLast5Min';              Expression = { $ibLock.Session.OutBytesLast5Min } },
                                                                                                            @{ Name = 'PassiveSessionHibernateTime';   Expression = { $ibLock.Session.PassiveSessionHibernateTime } },
                                                                                                            @{ Name = 'SessionID';                     Expression = { $ibLock.Session.SessionID } },
                                                                                                            @{ Name = 'StartedAt';                     Expression = { $ibLock.Session.StartedAt } },
                                                                                                            @{ Name = 'UserName';                      Expression = { $ibLock.Session.UserName } },
                                                                                                            @{ Name = 'Process'; Expression = { if ( -not $NoWorkingProcesses ) { 1 | Select-Object @{ Name = 'AvailablePerfomance'; Expression = { $ibLock.Session.Process.AvailablePerfomance } },
                                                                                                                                                                    @{ Name = 'AvgBackCallTime';     Expression = { $ibLock.Session.Process.AvgBackCallTime } },
                                                                                                                                                                    @{ Name = 'AvgCallTime';         Expression = { $ibLock.Session.Process.AvgCallTime } },
                                                                                                                                                                    @{ Name = 'AvgDBCallTime';       Expression = { $ibLock.Session.Process.AvgDBCallTime } },
                                                                                                                                                                    @{ Name = 'AvgLockCallTime';     Expression = { $ibLock.Session.Process.AvgLockCallTime } },
                                                                                                                                                                    @{ Name = 'AvgServerCallTime';   Expression = { $ibLock.Session.Process.AvgServerCallTime } },
                                                                                                                                                                    @{ Name = 'AvgThreads';          Expression = { $ibLock.Session.Process.AvgThreads } },
                                                                                                                                                                    @{ Name = 'Capacity';            Expression = { $ibLock.Session.Process.Capacity } },
                                                                                                                                                                    @{ Name = 'Connections';         Expression = { $ibLock.Session.Process.Connections } },
                                                                                                                                                                    @{ Name = 'HostName';            Expression = { $ibLock.Session.Process.HostName } },
                                                                                                                                                                    @{ Name = 'IsEnable';            Expression = { $ibLock.Session.Process.IsEnable } },
                                                                                                                                                                    @{ Name = 'License';             Expression = { try { $ibLock.Session.Process.License.FullPresentation } catch { $null } } },
                                                                                                                                                                    @{ Name = 'MainPort';            Expression = { $ibLock.Session.Process.MainPort   } },
                                                                                                                                                                    @{ Name = 'MemoryExcessTime';    Expression = { $ibLock.Session.Process.MemoryExcessTime } },
                                                                                                                                                                    @{ Name = 'MemorySize';          Expression = { $ibLock.Session.Process.MemorySize } },
                                                                                                                                                                    @{ Name = 'PID';                 Expression = { $ibLock.Session.Process.PID } },
                                                                                                                                                                    @{ Name = 'Running';             Expression = { $ibLock.Session.Process.Running } },
                                                                                                                                                                    @{ Name = 'SelectionSize';       Expression = { $ibLock.Session.Process.SelectionSize } },
                                                                                                                                                                    @{ Name = 'StartedAt';           Expression = { $ibLock.Session.Process.Process.StartedAt } },
                                                                                                                                                                    @{ Name = 'Use';                 Expression = { $ibLock.Session.Process.Use } } } } },
                                                                                                            @{ Name = 'Connection'; Expression = { if ( $ShowConnections -eq 'Everywhere') { 1 | Select-Object @{ Name = 'Application'; Expression = { $ibLock.Session.Application } },
                                                                                                                                                                        @{ Name = 'blockedByLS'; Expression = { $ibLock.Session.blockedByLS } },
                                                                                                                                                                        @{ Name = 'ConnectedAt'; Expression = { $ibLock.Session.ConnectedAt } },
                                                                                                                                                                        @{ Name = 'ConnID';      Expression = { $ibLock.Session.ConnID } },
                                                                                                                                                                        @{ Name = 'Host';        Expression = { $ibLock.Session.Host } },
                                                                                                                                                                        @{ Name = 'InfoBase';    Expression = { @{ Descr = $ibLock.Session.InfoBase.Descr; Name = $ibLock.Session.InfoBase.Name } } },
                                                                                                                                                                        @{ Name = 'SessionID';   Expression = { $ibLock.Session.SessionID } },
                                                                                                                                                                        @{ Name = 'Process';     Expression = { if ( -not $NoWorkingProcesses ) { 1 | Select-Object   @{ Name = 'AvailablePerfomance'; Expression = { $ibLock.Session.Process.AvailablePerfomance } },
                                                                                                                                                                                                                                    @{ Name = 'AvgBackCallTime';     Expression = { $ibLock.Session.Process.AvgBackCallTime } },
                                                                                                                                                                                                                                    @{ Name = 'AvgCallTime';         Expression = { $ibLock.Session.Process.AvgCallTime } },
                                                                                                                                                                                                                                    @{ Name = 'AvgDBCallTime';       Expression = { $ibLock.Session.Process.AvgDBCallTime } },
                                                                                                                                                                                                                                    @{ Name = 'AvgLockCallTime';     Expression = { $ibLock.Session.Process.AvgLockCallTime } },
                                                                                                                                                                                                                                    @{ Name = 'AvgServerCallTime';   Expression = { $ibLock.Session.Process.AvgServerCallTime } },
                                                                                                                                                                                                                                    @{ Name = 'AvgThreads';          Expression = { $ibLock.Session.Process.AvgThreads } },
                                                                                                                                                                                                                                    @{ Name = 'Capacity';            Expression = { $ibLock.Session.Process.Capacity } },
                                                                                                                                                                                                                                    @{ Name = 'Connections';         Expression = { $ibLock.Session.Process.Connections } },
                                                                                                                                                                                                                                    @{ Name = 'HostName';            Expression = { $ibLock.Session.Process.HostName } },
                                                                                                                                                                                                                                    @{ Name = 'IsEnable';            Expression = { $ibLock.Session.Process.IsEnable } },
                                                                                                                                                                                                                                    @{ Name = 'License';             Expression = { try { $ibLock.Session.Process.License.FullPresentation } catch { $null } } },
                                                                                                                                                                                                                                    @{ Name = 'MainPort';            Expression = { $ibLock.Session.Process.MainPort   } },
                                                                                                                                                                                                                                    @{ Name = 'MemoryExcessTime';    Expression = { $ibLock.Session.Process.MemoryExcessTime } },
                                                                                                                                                                                                                                    @{ Name = 'MemorySize';          Expression = { $ibLock.Session.Process.MemorySize } },
                                                                                                                                                                                                                                    @{ Name = 'PID';                 Expression = { $ibLock.Session.Process.PID } },
                                                                                                                                                                                                                                    @{ Name = 'Running';             Expression = { $ibLock.Session.Process.Running } },
                                                                                                                                                                                                                                    @{ Name = 'SelectionSize';       Expression = { $ibLock.Session.Process.SelectionSize } },
                                                                                                                                                                                                                                    @{ Name = 'StartedAt';           Expression = { $ibLock.Session.Process.Process.StartedAt } },
                                                                                                                                                                                                                                    @{ Name = 'Use';                 Expression = { $ibLock.Session.Process.Use } } } } } } } } } } }
                            }
                            Add-Member -InputObject $objInfoBases[$objInfoBases.Count-1] -Name InfoBaseLocks -Value $objIBL -MemberType NoteProperty
                        }

                        if ( $ShowConnections -eq 'Everywhere' ) {
                            $nfoBaseConnections = $connection.GetInfoBaseConnections( $cluster, $infoBase )
                            $objIBC = @()
                            foreach( $ibConnection in $nfoBaseConnections ) {
                                $objIBC += 1 | Select-Object @{ Name = 'Application'; Expression = { $ibConnection.Application } },
                                                            @{ Name = 'blockedByLS'; Expression = { $ibConnection.blockedByLS } },
                                                            @{ Name = 'ConnectedAt'; Expression = { $ibConnection.ConnectedAt } },
                                                            @{ Name = 'ConnID';      Expression = { $ibConnection.ConnID } },
                                                            @{ Name = 'Host';        Expression = { $ibConnection.Host } },
                                                            @{ Name = 'InfoBase';    Expression = { @{ Descr = $ibConnection.InfoBase.Descr; Name = $ibConnection.InfoBase.Name } } },
                                                            @{ Name = 'SessionID';   Expression = { $ibConnection.SessionID } },
                                                            @{ Name = 'Process';     Expression = { if ( -not $NoWorkingProcesses ) { 1 | Select-Object   @{ Name = 'AvailablePerfomance'; Expression = { $ibConnection.Process.AvailablePerfomance } },
                                                                                                                        @{ Name = 'AvgBackCallTime';     Expression = { $ibConnection.Process.AvgBackCallTime } },
                                                                                                                        @{ Name = 'AvgCallTime';         Expression = { $ibConnection.Process.AvgCallTime } },
                                                                                                                        @{ Name = 'AvgDBCallTime';       Expression = { $ibConnection.Process.AvgDBCallTime } },
                                                                                                                        @{ Name = 'AvgLockCallTime';     Expression = { $ibConnection.Process.AvgLockCallTime } },
                                                                                                                        @{ Name = 'AvgServerCallTime';   Expression = { $ibConnection.Process.AvgServerCallTime } },
                                                                                                                        @{ Name = 'AvgThreads';          Expression = { $ibConnection.Process.AvgThreads } },
                                                                                                                        @{ Name = 'Capacity';            Expression = { $ibConnection.Process.Capacity } },
                                                                                                                        @{ Name = 'Connections';         Expression = { $ibConnection.Process.Connections } },
                                                                                                                        @{ Name = 'HostName';            Expression = { $ibConnection.Process.HostName } },
                                                                                                                        @{ Name = 'IsEnable';            Expression = { $ibConnection.Process.IsEnable } },
                                                                                                                        @{ Name = 'License';             Expression = { try { $ibConnection.Process.License.FullPresentation } catch { $null } } },
                                                                                                                        @{ Name = 'MainPort';            Expression = { $ibConnection.Process.MainPort   } },
                                                                                                                        @{ Name = 'MemoryExcessTime';    Expression = { $ibConnection.Process.MemoryExcessTime } },
                                                                                                                        @{ Name = 'MemorySize';          Expression = { $ibConnection.Process.MemorySize } },
                                                                                                                        @{ Name = 'PID';                 Expression = { $ibConnection.Process.PID } },
                                                                                                                        @{ Name = 'Running';             Expression = { $ibConnection.Process.Running } },
                                                                                                                        @{ Name = 'SelectionSize';       Expression = { $ibConnection.Process.SelectionSize } },
                                                                                                                        @{ Name = 'StartedAt';           Expression = { $ibConnection.Process.Process.StartedAt } },
                                                                                                                        @{ Name = 'Use';                 Expression = { $ibConnection.Process.Use } } } } }
                            }
                            Add-Member -InputObject $objInfoBases[$objInfoBases.Count-1] -Name InfoBaseConnections -Value $objIBC -MemberType NoteProperty
                        }

                    }

                    Add-Member -InputObject $cls -Name InfoBases -Value $objInfoBases -MemberType NoteProperty

                }

                if ( $ShowLocks -ne 'None' ) {

                    $clusterLocks = $connection.GetLocks( $cluster )
                    $objClLock = @()
                    foreach( $clLock in $clusterLocks ) {
                        $objClLock += 1 | Select-Object @{ Name = 'Connection';  Expression = { if ( $clLock.Connection ) { 1 | Select-Object @{ Name = 'Application'; Expression = { $clLock.Connection.Application } },
                                                                                                            @{ Name = 'blockedByLS'; Expression = { $clLock.Connection.blockedByLS } },
                                                                                                            @{ Name = 'ConnectedAt'; Expression = { $clLock.Connection.ConnectedAt } },
                                                                                                            @{ Name = 'ConnID';      Expression = { $clLock.Connection.ConnID } },
                                                                                                            @{ Name = 'Host';        Expression = { $clLock.Connection.Host } },
                                                                                                            @{ Name = 'InfoBase';    Expression = { @{ Descr = $clLock.Connection.InfoBase.Descr; Name = $clLock.Connection.InfoBase.Name } } },
                                                                                                            @{ Name = 'SessionID';   Expression = { $clLock.Connection.SessionID } },
                                                                                                            @{ Name = 'Process';     Expression = { if ( -not $NoWorkingProcesses ) { 1 | Select-Object @{ Name = 'AvailablePerfomance'; Expression = { $clLock.Connection.Process.AvailablePerfomance } },
                                                                                                                                                            @{ Name = 'AvgBackCallTime';     Expression = { $clLock.Connection.Process.AvgBackCallTime } },
                                                                                                                                                            @{ Name = 'AvgCallTime';         Expression = { $clLock.Connection.Process.AvgCallTime } },
                                                                                                                                                            @{ Name = 'AvgDBCallTime';       Expression = { $clLock.Connection.Process.AvgDBCallTime } },
                                                                                                                                                            @{ Name = 'AvgLockCallTime';     Expression = { $clLock.Connection.Process.AvgLockCallTime } },
                                                                                                                                                            @{ Name = 'AvgServerCallTime';   Expression = { $clLock.Connection.Process.AvgServerCallTime } },
                                                                                                                                                            @{ Name = 'AvgThreads';          Expression = { $clLock.Connection.Process.AvgThreads } },
                                                                                                                                                            @{ Name = 'Capacity';            Expression = { $clLock.Connection.Process.Capacity } },
                                                                                                                                                            @{ Name = 'Connections';         Expression = { $clLock.Connection.Process.Connections } },
                                                                                                                                                            @{ Name = 'HostName';            Expression = { $clLock.Connection.Process.HostName } },
                                                                                                                                                            @{ Name = 'IsEnable';            Expression = { $clLock.Connection.Process.IsEnable } },
                                                                                                                                                            @{ Name = 'License';             Expression = { try { $clLock.Connection.Process.License.FullPresentation } catch { $null } } },
                                                                                                                                                            @{ Name = 'MainPort';            Expression = { $clLock.Connection.Process.MainPort } },
                                                                                                                                                            @{ Name = 'MemoryExcessTime';    Expression = { $clLock.Connection.Process.MemoryExcessTime } },
                                                                                                                                                            @{ Name = 'MemorySize';          Expression = { $clLock.Connection.Process.MemorySize } },
                                                                                                                                                            @{ Name = 'PID';                 Expression = { $clLock.Connection.Process.PID } },
                                                                                                                                                            @{ Name = 'Running';             Expression = { $clLock.Connection.Process.Running } },
                                                                                                                                                            @{ Name = 'SelectionSize';       Expression = { $clLock.Connection.Process.SelectionSize } },
                                                                                                                                                            @{ Name = 'StartedAt';           Expression = { $clLock.Connection.Process.Process.StartedAt } },
                                                                                                                                                            @{ Name = 'Use';                 Expression = { $clLock.Connection.Process.Use } } } } } } } },
                                                        @{ Name = 'LockDescr'; Expression = { $clLock.LockDescr } },
                                                        @{ Name = 'LockedAt';  Expression = { $clLock.LockedAt } },
                                                        @{ Name = 'Object';    Expression = { $clLock.Object } },
                                                        @{ Name = 'Session';   Expression = { if ( $ShowSessions -eq 'Everywhere' ) { 1| Select-Object @{ Name = 'AppID'; Expression = { $clLock.Session.AppID } },
                                                                                                    @{ Name = 'blockedByDBMS';                 Expression = { $clLock.Session.blockedByDBMS } },
                                                                                                    @{ Name = 'blockedByLS';                   Expression = { $clLock.Session.blockedByLS } },
                                                                                                    @{ Name = 'bytesAll';                      Expression = { $clLock.Session.bytesAll } },
                                                                                                    @{ Name = 'bytesLast5Min';                 Expression = { $clLock.Session.bytesLast5Min } },
                                                                                                    @{ Name = 'callsAll';                      Expression = { $clLock.Session.callsAll } },
                                                                                                    @{ Name = 'callsLast5Min';                 Expression = { $clLock.Session.callsLast5Min } },
                                                                                                    @{ Name = 'dbmsBytesAll';                  Expression = { $clLock.Session.dbmsBytesAll } },
                                                                                                    @{ Name = 'dbmsBytesLast5Min';             Expression = { $clLock.Session.dbmsBytesLast5Min } },
                                                                                                    @{ Name = 'dbProcInfo';                    Expression = { $clLock.Session.dbProcInfo } },
                                                                                                    @{ Name = 'dbProcTook';                    Expression = { $clLock.Session.dbProcTook } },
                                                                                                    @{ Name = 'dbProcTookAt';                  Expression = { $clLock.Session.dbProcTookAt } },
                                                                                                    @{ Name = 'durationAll';                   Expression = { $clLock.Session.durationAll } },
                                                                                                    @{ Name = 'durationAllDBMS';               Expression = { $clLock.Session.durationAllDBMS } },
                                                                                                    @{ Name = 'durationCurrent';               Expression = { $clLock.Session.durationCurrent } },
                                                                                                    @{ Name = 'durationCurrentDBMS';           Expression = { $clLock.Session.durationCurrentDBMS } },
                                                                                                    @{ Name = 'durationLast5Min';              Expression = { $clLock.Session.durationLast5Min } },
                                                                                                    @{ Name = 'durationLast5MinDBMS';          Expression = { $clLock.Session.durationLast5MinDBMS } },
                                                                                                    @{ Name = 'Hibernate';                     Expression = { $clLock.Session.Hibernate } },
                                                                                                    @{ Name = 'HibernateSessionTerminateTime'; Expression = { $clLock.Session.HibernateSessionTerminateTime } },
                                                                                                    @{ Name = 'Host';                          Expression = { $clLock.Session.Host } },
                                                                                                    @{ Name = 'InBytesAll';                    Expression = { $clLock.Session.InBytesAll } },
                                                                                                    @{ Name = 'InBytesCurrent';                Expression = { $clLock.Session.InBytesCurrent } },
                                                                                                    @{ Name = 'InBytesLast5Min';               Expression = { $clLock.Session.InBytesLast5Min } },
                                                                                                    @{ Name = 'InfoBase';                      Expression = { @{ Descr = $clLock.Session.InfoBase.Descr; Name = $clLock.Session.InfoBase.Name } } },
                                                                                                    @{ Name = 'LastActiveAt';                  Expression = { $clLock.Session.LastActiveAt } },
                                                                                                    @{ Name = 'License';                       Expression = { try { $clLock.Session.Process.License.FullPresentation } catch { $null } } },
                                                                                                    @{ Name = 'Locale';                        Expression = { $clLock.Session.Locale } },
                                                                                                    @{ Name = 'MemoryAll';                     Expression = { $clLock.Session.MemoryAll } },
                                                                                                    @{ Name = 'MemoryCurrent';                 Expression = { $clLock.Session.MemoryCurrent } },
                                                                                                    @{ Name = 'MemoryLast5Min';                Expression = { $clLock.Session.MemoryLast5Min } },
                                                                                                    @{ Name = 'OutBytesAll';                   Expression = { $clLock.Session.OutBytesAll } },
                                                                                                    @{ Name = 'OutBytesCurrent';               Expression = { $clLock.Session.OutBytesCurrent } },
                                                                                                    @{ Name = 'OutBytesLast5Min';              Expression = { $clLock.Session.OutBytesLast5Min } },
                                                                                                    @{ Name = 'PassiveSessionHibernateTime';   Expression = { $clLock.Session.PassiveSessionHibernateTime } },
                                                                                                    @{ Name = 'SessionID';                     Expression = { $clLock.Session.SessionID } },
                                                                                                    @{ Name = 'StartedAt';                     Expression = { $clLock.Session.StartedAt } },
                                                                                                    @{ Name = 'UserName';                      Expression = { $clLock.Session.UserName } },
                                                                                                    @{ Name = 'Process'; Expression = { if ( -not $NoWorkingProcesses ) { 1 | Select-Object @{ Name = 'AvailablePerfomance'; Expression = { $clLock.Session.Process.AvailablePerfomance } },
                                                                                                                                                            @{ Name = 'AvgBackCallTime';     Expression = { $clLock.Session.Process.AvgBackCallTime } },
                                                                                                                                                            @{ Name = 'AvgCallTime';         Expression = { $clLock.Session.Process.AvgCallTime } },
                                                                                                                                                            @{ Name = 'AvgDBCallTime';       Expression = { $clLock.Session.Process.AvgDBCallTime } },
                                                                                                                                                            @{ Name = 'AvgLockCallTime';     Expression = { $clLock.Session.Process.AvgLockCallTime } },
                                                                                                                                                            @{ Name = 'AvgServerCallTime';   Expression = { $clLock.Session.Process.AvgServerCallTime } },
                                                                                                                                                            @{ Name = 'AvgThreads';          Expression = { $clLock.Session.Process.AvgThreads } },
                                                                                                                                                            @{ Name = 'Capacity';            Expression = { $clLock.Session.Process.Capacity } },
                                                                                                                                                            @{ Name = 'Connections';         Expression = { $clLock.Session.Process.Connections } },
                                                                                                                                                            @{ Name = 'HostName';            Expression = { $clLock.Session.Process.HostName } },
                                                                                                                                                            @{ Name = 'IsEnable';            Expression = { $clLock.Session.Process.IsEnable } },
                                                                                                                                                            @{ Name = 'License';             Expression = { try { $clLock.Session.Process.License.FullPresentation } catch { $null } } },
                                                                                                                                                            @{ Name = 'MainPort';            Expression = { $clLock.Session.Process.MainPort   } },
                                                                                                                                                            @{ Name = 'MemoryExcessTime';    Expression = { $clLock.Session.Process.MemoryExcessTime } },
                                                                                                                                                            @{ Name = 'MemorySize';          Expression = { $clLock.Session.Process.MemorySize } },
                                                                                                                                                            @{ Name = 'PID';                 Expression = { $clLock.Session.Process.PID } },
                                                                                                                                                            @{ Name = 'Running';             Expression = { $clLock.Session.Process.Running } },
                                                                                                                                                            @{ Name = 'SelectionSize';       Expression = { $clLock.Session.Process.SelectionSize } },
                                                                                                                                                            @{ Name = 'StartedAt';           Expression = { $clLock.Session.Process.Process.StartedAt } },
                                                                                                                                                            @{ Name = 'Use';                 Expression = { $clLock.Session.Process.Use } } } } },
                                                                                                    @{ Name = 'Connection'; Expression = { if ( $ShowConnections -eq 'Everywhere') { 1 | Select-Object @{ Name = 'Application'; Expression = { $clLock.Session.Application } },
                                                                                                                                                                @{ Name = 'blockedByLS'; Expression = { $clLock.Session.blockedByLS } },
                                                                                                                                                                @{ Name = 'ConnectedAt'; Expression = { $clLock.Session.ConnectedAt } },
                                                                                                                                                                @{ Name = 'ConnID';      Expression = { $clLock.Session.ConnID } },
                                                                                                                                                                @{ Name = 'Host';        Expression = { $clLock.Session.Host } },
                                                                                                                                                                @{ Name = 'InfoBase';    Expression = { @{ Descr = $clLock.Session.InfoBase.Descr; Name = $clLock.Session.InfoBase.Name } } },
                                                                                                                                                                @{ Name = 'SessionID';   Expression = { $clLock.Session.SessionID } },
                                                                                                                                                                @{ Name = 'Process';     Expression = { if ( -not $NoWorkingProcesses ) { 1 | Select-Object   @{ Name = 'AvailablePerfomance'; Expression = { $clLock.Session.Process.AvailablePerfomance } },
                                                                                                                                                                                                                            @{ Name = 'AvgBackCallTime';     Expression = { $clLock.Session.Process.AvgBackCallTime } },
                                                                                                                                                                                                                            @{ Name = 'AvgCallTime';         Expression = { $clLock.Session.Process.AvgCallTime } },
                                                                                                                                                                                                                            @{ Name = 'AvgDBCallTime';       Expression = { $clLock.Session.Process.AvgDBCallTime } },
                                                                                                                                                                                                                            @{ Name = 'AvgLockCallTime';     Expression = { $clLock.Session.Process.AvgLockCallTime } },
                                                                                                                                                                                                                            @{ Name = 'AvgServerCallTime';   Expression = { $clLock.Session.Process.AvgServerCallTime } },
                                                                                                                                                                                                                            @{ Name = 'AvgThreads';          Expression = { $clLock.Session.Process.AvgThreads } },
                                                                                                                                                                                                                            @{ Name = 'Capacity';            Expression = { $clLock.Session.Process.Capacity } },
                                                                                                                                                                                                                            @{ Name = 'Connections';         Expression = { $clLock.Session.Process.Connections } },
                                                                                                                                                                                                                            @{ Name = 'HostName';            Expression = { $clLock.Session.Process.HostName } },
                                                                                                                                                                                                                            @{ Name = 'IsEnable';            Expression = { $clLock.Session.Process.IsEnable } },
                                                                                                                                                                                                                            @{ Name = 'License';             Expression = { try { $clLock.Session.Process.License.FullPresentation } catch { $null } } },
                                                                                                                                                                                                                            @{ Name = 'MainPort';            Expression = { $clLock.Session.Process.MainPort   } },
                                                                                                                                                                                                                            @{ Name = 'MemoryExcessTime';    Expression = { $clLock.Session.Process.MemoryExcessTime } },
                                                                                                                                                                                                                            @{ Name = 'MemorySize';          Expression = { $clLock.Session.Process.MemorySize } },
                                                                                                                                                                                                                            @{ Name = 'PID';                 Expression = { $clLock.Session.Process.PID } },
                                                                                                                                                                                                                            @{ Name = 'Running';             Expression = { $clLock.Session.Process.Running } },
                                                                                                                                                                                                                            @{ Name = 'SelectionSize';       Expression = { $clLock.Session.Process.SelectionSize } },
                                                                                                                                                                                                                            @{ Name = 'StartedAt';           Expression = { $clLock.Session.Process.Process.StartedAt } },
                                                                                                                                                                                                                            @{ Name = 'Use';                 Expression = { $clLock.Session.Process.Use } } } } } } } } } } }
                    }

                    Add-Member -InputObject $cls -Name Locks -Value $objClLock -MemberType NoteProperty

                }

                if ( $ShowSessions -ne 'None' ) {
                        
                    $clusterSessions = $connection.GetSessions( $cluster )
                    $objClSession = @()
                    foreach ( $clusterSession in $clusterSessions ) {
                        $objClSession += 1| Select-Object @{ Name = 'AppID'; Expression = { $clusterSession.AppID } },
                                                        @{ Name = 'blockedByDBMS';                 Expression = { $clusterSession.blockedByDBMS } },
                                                        @{ Name = 'blockedByLS';                   Expression = { $clusterSession.blockedByLS } },
                                                        @{ Name = 'bytesAll';                      Expression = { $clusterSession.bytesAll } },
                                                        @{ Name = 'bytesLast5Min';                 Expression = { $clusterSession.bytesLast5Min } },
                                                        @{ Name = 'callsAll';                      Expression = { $clusterSession.callsAll } },
                                                        @{ Name = 'callsLast5Min';                 Expression = { $clusterSession.callsLast5Min } },
                                                        @{ Name = 'dbmsBytesAll';                  Expression = { $clusterSession.dbmsBytesAll } },
                                                        @{ Name = 'dbmsBytesLast5Min';             Expression = { $clusterSession.dbmsBytesLast5Min } },
                                                        @{ Name = 'dbProcInfo';                    Expression = { $clusterSession.dbProcInfo } },
                                                        @{ Name = 'dbProcTook';                    Expression = { $clusterSession.dbProcTook } },
                                                        @{ Name = 'dbProcTookAt';                  Expression = { $clusterSession.dbProcTookAt } },
                                                        @{ Name = 'durationAll';                   Expression = { $clusterSession.durationAll } },
                                                        @{ Name = 'durationAllDBMS';               Expression = { $clusterSession.durationAllDBMS } },
                                                        @{ Name = 'durationCurrent';               Expression = { $clusterSession.durationCurrent } },
                                                        @{ Name = 'durationCurrentDBMS';           Expression = { $clusterSession.durationCurrentDBMS } },
                                                        @{ Name = 'durationLast5Min';              Expression = { $clusterSession.durationLast5Min } },
                                                        @{ Name = 'durationLast5MinDBMS';          Expression = { $clusterSession.durationLast5MinDBMS } },
                                                        @{ Name = 'Hibernate';                     Expression = { $clusterSession.Hibernate } },
                                                        @{ Name = 'HibernateSessionTerminateTime'; Expression = { $clusterSession.HibernateSessionTerminateTime } },
                                                        @{ Name = 'Host';                          Expression = { $clusterSession.Host } },
                                                        @{ Name = 'InBytesAll';                    Expression = { $clusterSession.InBytesAll } },
                                                        @{ Name = 'InBytesCurrent';                Expression = { $clusterSession.InBytesCurrent } },
                                                        @{ Name = 'InBytesLast5Min';               Expression = { $clusterSession.InBytesLast5Min } },
                                                        @{ Name = 'InfoBase';                      Expression = { @{ Descr = $clusterSession.InfoBase.Descr; Name = $clusterSession.InfoBase.Name } } },
                                                        @{ Name = 'LastActiveAt';                  Expression = { $clusterSession.LastActiveAt } },
                                                        @{ Name = 'License';                       Expression = { try { $clusterSession.Process.License.FullPresentation } catch { $null } } },
                                                        @{ Name = 'Locale';                        Expression = { $clusterSession.Locale } },
                                                        @{ Name = 'MemoryAll';                     Expression = { $clusterSession.MemoryAll } },
                                                        @{ Name = 'MemoryCurrent';                 Expression = { $clusterSession.MemoryCurrent } },
                                                        @{ Name = 'MemoryLast5Min';                Expression = { $clusterSession.MemoryLast5Min } },
                                                        @{ Name = 'OutBytesAll';                   Expression = { $clusterSession.OutBytesAll } },
                                                        @{ Name = 'OutBytesCurrent';               Expression = { $clusterSession.OutBytesCurrent } },
                                                        @{ Name = 'OutBytesLast5Min';              Expression = { $clusterSession.OutBytesLast5Min } },
                                                        @{ Name = 'PassiveSessionHibernateTime';   Expression = { $clusterSession.PassiveSessionHibernateTime } },
                                                        @{ Name = 'SessionID';                     Expression = { $clusterSession.SessionID } },
                                                        @{ Name = 'StartedAt';                     Expression = { $clusterSession.StartedAt } },
                                                        @{ Name = 'UserName';                      Expression = { $clusterSession.UserName } },
                                                        @{ Name = 'Process'; Expression = { if ( -not $NoWorkingProcesses ) { 1 | Select-Object @{ Name = 'AvailablePerfomance'; Expression = { $clusterSession.Process.AvailablePerfomance } },
                                                                                                                @{ Name = 'AvgBackCallTime';     Expression = { $clusterSession.Process.AvgBackCallTime } },
                                                                                                                @{ Name = 'AvgCallTime';         Expression = { $clusterSession.Process.AvgCallTime } },
                                                                                                                @{ Name = 'AvgDBCallTime';       Expression = { $clusterSession.Process.AvgDBCallTime } },
                                                                                                                @{ Name = 'AvgLockCallTime';     Expression = { $clusterSession.Process.AvgLockCallTime } },
                                                                                                                @{ Name = 'AvgServerCallTime';   Expression = { $clusterSession.Process.AvgServerCallTime } },
                                                                                                                @{ Name = 'AvgThreads';          Expression = { $clusterSession.Process.AvgThreads } },
                                                                                                                @{ Name = 'Capacity';            Expression = { $clusterSession.Process.Capacity } },
                                                                                                                @{ Name = 'Connections';         Expression = { $clusterSession.Process.Connections } },
                                                                                                                @{ Name = 'HostName';            Expression = { $clusterSession.Process.HostName } },
                                                                                                                @{ Name = 'IsEnable';            Expression = { $clusterSession.Process.IsEnable } },
                                                                                                                @{ Name = 'License';             Expression = { try { $clusterSession.Process.License.FullPresentation } catch { $null } } },
                                                                                                                @{ Name = 'MainPort';            Expression = { $clusterSession.Process.MainPort   } },
                                                                                                                @{ Name = 'MemoryExcessTime';    Expression = { $clusterSession.Process.MemoryExcessTime } },
                                                                                                                @{ Name = 'MemorySize';          Expression = { $clusterSession.Process.MemorySize } },
                                                                                                                @{ Name = 'PID';                 Expression = { $clusterSession.Process.PID } },
                                                                                                                @{ Name = 'Running';             Expression = { $clusterSession.Process.Running } },
                                                                                                                @{ Name = 'SelectionSize';       Expression = { $clusterSession.Process.SelectionSize } },
                                                                                                                @{ Name = 'StartedAt';           Expression = { $clusterSession.Process.Process.StartedAt } },
                                                                                                                @{ Name = 'Use';                 Expression = { $clusterSession.Process.Use } } } } },
                                                        @{ Name = 'Connection'; Expression = { if ( $ShowConnections -eq 'Everywhere') { 1 | Select-Object @{ Name = 'Application'; Expression = { $clusterSession.Application } },
                                                                                                                    @{ Name = 'blockedByLS'; Expression = { $clusterSession.blockedByLS } },
                                                                                                                    @{ Name = 'ConnectedAt'; Expression = { $clusterSession.ConnectedAt } },
                                                                                                                    @{ Name = 'ConnID';      Expression = { $clusterSession.ConnID } },
                                                                                                                    @{ Name = 'Host';        Expression = { $clusterSession.Host } },
                                                                                                                    @{ Name = 'InfoBase';    Expression = { @{ Descr = $clusterSession.InfoBase.Descr; Name = $clusterSession.InfoBase.Name } } },
                                                                                                                    @{ Name = 'SessionID';   Expression = { $clusterSession.SessionID } },
                                                                                                                    @{ Name = 'Process';     Expression = { if ( -not $NoWorkingProcesses ) { 1 | Select-Object   @{ Name = 'AvailablePerfomance'; Expression = { $clusterSession.Process.AvailablePerfomance } },
                                                                                                                                                                                @{ Name = 'AvgBackCallTime';     Expression = { $clusterSession.Process.AvgBackCallTime } },
                                                                                                                                                                                @{ Name = 'AvgCallTime';         Expression = { $clusterSession.Process.AvgCallTime } },
                                                                                                                                                                                @{ Name = 'AvgDBCallTime';       Expression = { $clusterSession.Process.AvgDBCallTime } },
                                                                                                                                                                                @{ Name = 'AvgLockCallTime';     Expression = { $clusterSession.Process.AvgLockCallTime } },
                                                                                                                                                                                @{ Name = 'AvgServerCallTime';   Expression = { $clusterSession.Process.AvgServerCallTime } },
                                                                                                                                                                                @{ Name = 'AvgThreads';          Expression = { $clusterSession.Process.AvgThreads } },
                                                                                                                                                                                @{ Name = 'Capacity';            Expression = { $clusterSession.Process.Capacity } },
                                                                                                                                                                                @{ Name = 'Connections';         Expression = { $clusterSession.Process.Connections } },
                                                                                                                                                                                @{ Name = 'HostName';            Expression = { $clusterSession.Process.HostName } },
                                                                                                                                                                                @{ Name = 'IsEnable';            Expression = { $clusterSession.Process.IsEnable } },
                                                                                                                                                                                @{ Name = 'License';             Expression = { try { $clusterSession.Process.License.FullPresentation } catch { $null } } },
                                                                                                                                                                                @{ Name = 'MainPort';            Expression = { $clusterSession.Process.MainPort   } },
                                                                                                                                                                                @{ Name = 'MemoryExcessTime';    Expression = { $clusterSession.Process.MemoryExcessTime } },
                                                                                                                                                                                @{ Name = 'MemorySize';          Expression = { $clusterSession.Process.MemorySize } },
                                                                                                                                                                                @{ Name = 'PID';                 Expression = { $clusterSession.Process.PID } },
                                                                                                                                                                                @{ Name = 'Running';             Expression = { $clusterSession.Process.Running } },
                                                                                                                                                                                @{ Name = 'SelectionSize';       Expression = { $clusterSession.Process.SelectionSize } },
                                                                                                                                                                                @{ Name = 'StartedAt';           Expression = { $clusterSession.Process.Process.StartedAt } },
                                                                                                                                                                                @{ Name = 'Use';                 Expression = { $clusterSession.Process.Use } } } } } } } }
                    }

                    Add-Member -InputObject $cls -Name Sessions -Value $objClSession -MemberType NoteProperty

                }

            }

            $obj.Clusters += $cls
            $result += $obj
                
        }

    }

    $result

    }

End {
    $connector = $null
    }

}

function Remove-Session
<#
.Synopsis
    Удаляет сеанс с кластера 1с

.DESCRIPTION

.NOTES  
    Name: 1CHelper
    Author: yauhen.makei@gmail.com

.LINK  
    https://github.com/emakei/1CHelper.psm1

.EXAMPLE
    $data = Get-1CclusterData 1c-cluster.contoso.com -NoClusterAdmins -NoClusterManagers -NoWorkingServers -NoWorkingProcesses -NoClusterServices -ShowConnections None -ShowSessions Cluster -ShowLocks None -NoInfobases -NoAssignmentRules -User Example -Password Example
    Remove-1Csession -HostName $data.Clusters.HostName -MainPort $data.Clusters.MainPort -User Admin -Password Admin -SessionID 3076 -InfoBaseName TestDB -Verbose -NotCloseConnection

#>
{
[CmdletBinding()]
Param(
        # Адрес хоста для удаления сеанса
        [Parameter(Mandatory=$true)]
        [string]$HostName,
        # Порт хоста для удаления сеанса
        [Parameter(Mandatory=$true)]
        [int]$MainPort,
        # Имя админитратора кластера
        [string]$User="",
        # Пароль администратора кластера
        [Security.SecureString]$Password="",
        # Порт хоста для удаления сеанса
        [Parameter(Mandatory=$true)]
        [int]$SessionID,
        # Порт хоста для удаления сеанса
        [Parameter(Mandatory=$true)]
        [string]$InfoBaseName,
        # Принудительно закрыть соединение с информационной базой после удаления сеанса
        [switch]$CloseIbConnection=$false,
        # Имя админитратора информационной базы
        [string]$IbUser="",
        # Пароль администратора информационной базы
        [string]$IbPassword="",
        # Версия компоненты
        [ValidateSet(2, 3, 4)]
        [int]$Version=3
    )

Begin {
    $connector = New-Object -ComObject "v8$version.COMConnector"
    }

Process {

    try {
        Write-Verbose "Подключение к '$HostName'"
        $connection = $connector.ConnectAgent( $HostName )
        $abort = $false
    } catch {
        Write-Warning $_
        $abort = $true
    }
        
    if ( -not $abort ) {
            
        Write-Verbose "Подключен к `"$($connection.ConnectionString)`""

        $clusters = $connection.GetClusters()

        foreach ( $cluster in $clusters ) {
            
            if ( $cluster.HostName -ne $HostName -or $cluster.MainPort -ne $MainPort ) { continue }

            try {
                Write-Verbose "Аутентификация в кластере '$($cluster.HostName,':',$cluster.MainPort,' - ',$cluster.ClusterName)'"
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
                $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                $connection.Authenticate( $cluster, $User, $PlainPassword )
                $abort = $false
            } catch {
                Write-Warning $_
                continue
            }

            $sessions = $connection.GetSessions( $cluster )
                
            foreach ( $session in $sessions ) {
                    
                if ( $session.InfoBase.Name -ne $InfoBaseName -or $session.SessionID -ne $SessionID ) { continue }

                Write-Verbose "Удаление сеанса '$($session.SessionID,' - ''',$session.UserName,''' с компьютера : ',$session.Host)'"
                try {
                    $connection.TerminateSession( $cluster, $session )
                } catch {
                    Write-Warning $_
                    continue
                }
                
                if ( $CloseIbConnection -and $session.Connection ) {
                    try {
                        # подключаемся к рабочему процессу
                        Write-Verbose "Подключение к рабочему процессу '$($session.Process.HostName):$($session.Process.MainPort)'"
                        $server = $connector.ConnectWorkingProcess( "$($session.Process.HostName):$($session.Process.MainPort)" )
                        # проходим аутентификацию в информационной базе
                        Write-Verbose "Аутентификация пользователя инф. базы '$($IbUser)' в информационной базе '$($InfoBaseName)'"
                        $server.AddAuthentication( $IbUser, $IbPassword )
                        # отключаем соединение
                        $ibDesc = $server.CreateInfoBaseInfo()
                        $ibDesc.Name = $InfoBaseName
                        $ibConnections = $server.GetInfoBaseConnections( $ibDesc )
                        foreach ( $ibConnection in $ibConnections ) {
                            if ( $ibConnection.ConnID -ne $session.connection.ConnID ) { continue } 
                            # отключение соединения
                            Write-Verbose "Отключение соединения № '$($ibConnection.ConnID)' приложения '$($ibConnection.AppID)' c компьютера '$($ibConnection.HostName)'"
                            $server.Disconnect( $ibConnection )
                        }
                    } catch {
                        Write-Warning $_
                        continue
                    }

                }
                
            }

        }

    }
            
    }

End {
    $connector = $null
    }

}

function Get-NetHaspIniStrings
<#
.Synopsis
   Находит значения параметров в файле nethasp.ini

.DESCRIPTION

.NOTES  
    Name: 1CHelper
    Author: yauhen.makei@gmail.com

.LINK  
    https://github.com/emakei/1CHelper.psm1

.EXAMPLE
   Get-NetHaspIniStrings

.OUTPUTS
   Структура параметров
#>
{
    
    $struct = @{}
    
    $pathToStarter = Find-1CEstart
    $pathToFile = $pathToStarter.Replace("common\1cestart.exe", "conf\nethasp.ini")

    if ( $pathToStarter ) {
        
        $content = Get-Content -Encoding UTF8 -LiteralPath $pathToFile
        $strings = $content | ? { $_ -match "^\w" }
        $strings | % { $keyValue = $_.Split('='); $key = $keyValue[0].Replace(" ",""); $value = $keyValue[1].Replace(" ",""); $value = $value.Replace(';',''); $struct[$key] = $value.Split(',') }

    }

    $struct

}

function Find-1CApplicationForExportImport
<#
.Synopsis
   Поиск максимальной версии приложения

.DESCRIPTION
   Поиск максимальной версии приложения (не ниже 8.3)

.NOTES  
    Name: 1CHelper
    Author: yauhen.makei@gmail.com

.LINK  
    https://github.com/emakei/1CHelper.psm1

.EXAMPLE
   Find-1CApplicationForExportImport

.OUTPUTS
   NULL или строку с путем установки приложения
#>
{
    Param(
        # Имя компьютера для поиска версии
        [string]$ComputerName=''
    )

    $installationPath = $null

    $pvs = 0

    $UninstallPathes = @("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall","SOFTWARE\\Wow6432node\\Microsoft\\Windows\\CurrentVersion\\Uninstall")
   
    ForEach($UninstallKey in $UninstallPathes) {
        
         Try {
             $reg=[Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $computerName)
         } Catch {
             $_
             Continue
         }
 
         $regkey = $reg.OpenSubKey($UninstallKey)

         If(-not $regkey) {
             Write-Warning "Не найдены ключи в: HKLM:\\$UninstallKey"
         }

         $subkeys=$regkey.GetSubKeyNames()
        
         foreach($key in $subkeys){
 
             $thisKey = $UninstallKey + "\\" + $key
 
             $thisSubKey = $reg.OpenSubKey($thisKey)

             Try {
                 $displayVersion = $thisSubKey.getValue("DisplayVersion").Split('.')
             } Catch {
                 Continue
             }
            
             if ( $displayVersion.Count -ne 4) { continue }
             if ( -not ($thisSubKey.getValue("Publisher") -in @("1C","1С") `
                     -and $displayVersion[0] -eq 8 `
                     -and $displayVersion[1] -gt 2 ) ) { continue }
             $tmpPath = $thisSubkey.getValue("InstallLocation")
             if (-not $tmpPath.EndsWith('\')) {
                 $tmpPath += '\' + 'bin\1cv8.exe'
             } else {
                 $tmpPath += 'bin\1cv8.exe'
             }
             Try {
                 $tmpPVS = [double]$displayVersion[1] * [Math]::Pow(10, 6) + [double]$displayVersion[2] * [Math]::Pow(10, 5) + [double]$displayVersion[3]
             } Catch {
                 Continue
             }
             if ( $tmpPVS -gt $pvs -and ( Test-Path -LiteralPath $tmpPath) ) {
                 $pvs = $tmpPVS
                 $installationPath = $tmpPath
             }
 
         }

         $reg.Close() 

     }

     $installationPath
}

function Get-NetHaspDirectoryPath
<#
.Synopsis
   Возвращает путь к каталогу с библиотекой hsmon.dll

.DESCRIPTION

.NOTES  
    Name: 1CHelper
    Author: yauhen.makei@gmail.com

.LINK  
    https://github.com/emakei/1CHelper.psm1

.EXAMPLE
   Get-NetHaspDirectoryPath

.OUTPUTS
   Путь к каталогу с библиотекой hsmon.dll
#>
{  
    (Get-Module 1CHelper).Path.TrimEnd('1CHelper.psm1') + "hasp"
}

function Get-NetHaspIniFilePath
<#
.Synopsis
   Возвращает путь к файлу nethasp.ini

.DESCRIPTION

.NOTES  
    Name: 1CHelper
    Author: yauhen.makei@gmail.com

.LINK  
    https://github.com/emakei/1CHelper.psm1

.EXAMPLE
   Get-NetHaspIniFilePath

.OUTPUTS
   Путь к к файлу nethasp.ini
#>
{  
    $pathToStarter = Find-1CEstart
    $pathToStarter.Replace("common\1cestart.exe", "conf\nethasp.ini")
}

function Invoke-SqlQuery
<#
.Synopsis
   Возвращает результат выполнения запроса к серверу SQL

.DESCRIPTION

.NOTES  
    Name: 1CHelper
    Author: yauhen.makei@gmail.com

.LINK  
    https://github.com/emakei/1CHelper.psm1


.EXAMPLE
    Invoke-SqlQuery -Server test.contoso.com -Database test -user admin -password admin -Data Custom -Text 'select @@version'

.EXAMPLE
    Invoke-SqlQuery -Server test.contoso.com -Database test -user admin -password admin -Data DatabaseLocks -Verbose

.EXAMPLE
    Invoke-SqlQuery -Server test.contoso.com -user admin -password admin -Data CurrentExequtingQueries -Verbose

#>
{
Param(
    [string]$Server='local',
    [string]$Database='master',
    [Parameter(Mandatory=$true)]
    [string]$user,
    [Parameter(Mandatory=$true)]
    [Security.SecureString]$password,
    [Parameter(Mandatory=$true)]
    [ValidateSet('DatabaseLocks','CurrentExequtingQueries','Custom')]
    [string]$Data='Custom',
    [string]$Text
    )

    switch ( $Data ) {
        'DatabaseLocks'
        {
            $scriptPath = (Get-NetHaspDirectoryPath).TrimEnd('hasp') + 'sql\batabase locks.sql'
            $sql = Get-Content $scriptPath -ErrorAction Stop
        }
        'CurrentExequtingQueries'
        {
            $scriptPath = (Get-NetHaspDirectoryPath).TrimEnd('hasp') + 'sql\current executing queries.sql'
            $sql = Get-Content $scriptPath -ErrorAction Stop
        }
        default
        {
            $sql = $Text
        }
    }

    Write-Verbose "Подключение к 'Server=$Server;Database=$Database;'"
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection -ArgumentList "Server=$Server;Database=$Database;Uid=$user;Pwd=$PlainPassword"
    try {
        $connection.Open()
    } catch {
        Write-Error $_
    }
    $command = New-Object -TypeName System.Data.SqlClient.SqlCommand $sql, $connection -ErrorAction Stop

    $adapter = New-Object -TypeName System.Data.SqlClient.SqlDataAdapter $command
    $table = New-Object -TypeName System.Data.DataTable

    $rows = $adapter.Fill($table)
    
    Write-Verbose "Получено $rows строк(-а)"

    $connection.Close()
    $connection.Dispose()

    $table

}


<# BEGIN
https://github.com/zbx-sadman
#>

#
#  Select object with Property that equal Value if its given or with Any Property in another case
#
Function PropertyEqualOrAny {
   Param (
      [Parameter(ValueFromPipeline = $True)] 
      [PSObject]$InputObject,
      [PSObject]$Property,
      [PSObject]$Value
   );
   Process {
      # Do something with all objects (non-pipelined input case)  
      ForEach ($Object in $InputObject) { 
         # IsNullorEmpty used because !$Value give a erong result with $Value = 0 (True).
         # But 0 may be right ID  
         If (($Object.$Property -Eq $Value) -Or ([string]::IsNullorEmpty($Value))) { $Object }
      }
   } 
}

#
#  Prepare string to using with Zabbix 
#
#Function PrepareTo-Zabbix {
Function Format-ToZabbix {
   Param (
      [Parameter(ValueFromPipeline = $True)] 
      [PSObject]$InputObject,
      [String]$ErrorCode,
      [Switch]$NoEscape,
      [Switch]$JSONCompatible
   );
   Begin {
      # Add here more symbols to escaping if you need
      $EscapedSymbols = @('\', '"');
      $UnixEpoch = Get-Date -Date "01/01/1970";
   }
   Process {
      # Do something with all objects (non-pipelined input case)  
      ForEach ($Object in $InputObject) { 
         If ($Null -Eq $Object) {
           # Put empty string or $ErrorCode to output  
           If ($ErrorCode) { $ErrorCode } Else { "" }
           Continue;
         }
         # Need add doublequote around string for other objects when JSON compatible output requested?
         $DoQuote = $False;
         Switch (($Object.GetType()).FullName) {
            'System.Boolean'  { $Object = [int]$Object; }
            'System.DateTime' { $Object = (New-TimeSpan -Start $UnixEpoch -End $Object).TotalSeconds; }
            Default           { $DoQuote = $True; }
         }
         # Normalize String object
         $Object = $( If ($JSONCompatible) { $Object.ToString() } else { $Object | Out-String }).Trim();
         
         If (!$NoEscape) { 
            ForEach ($Symbol in $EscapedSymbols) { 
               $Object = $Object.Replace($Symbol, "\$Symbol");
            }
         }

         # Doublequote object if adherence to JSON standart requested
         If ($JSONCompatible -And $DoQuote) { 
            "`"$Object`"";
         } else {
            $Object;
         }
      }
   }
}

#
#  Make & return JSON, due PoSh 2.0 haven't Covert-ToJSON
#
#Function Make-JSON {
Function Get-NetHaspJSON {
   Param (
      [Parameter(ValueFromPipeline = $True)] 
      [PSObject]$InputObject, 
      [array]$ObjectProperties, 
      [Switch]$Pretty
   ); 
   Begin   {
      [String]$Result = "";
      # Pretty json contain spaces, tabs and new-lines
      If ($Pretty) { $CRLF = "`n"; $Tab = "    "; $Space = " "; } Else { $CRLF = $Tab = $Space = ""; }
      # Init JSON-string $InObject
      $Result += "{$CRLF$Space`"data`":[$CRLF";
      # Take each Item from $InObject, get Properties that equal $ObjectProperties items and make JSON from its
      $itFirstObject = $True;
   } 
   Process {
      # Do something with all objects (non-pipelined input case)  
      ForEach ($Object in $InputObject) {
         # Skip object when its $Null
         If ($Null -Eq $Object) { Continue; }

         If (-Not $itFirstObject) { $Result += ",$CRLF"; }
         $itFirstObject=$False;
         $Result += "$Tab$Tab{$Space"; 
         $itFirstProperty = $True;
         # Process properties. No comma printed after last item
         ForEach ($Property in $ObjectProperties) {
            If (-Not $itFirstProperty) { $Result += ",$Space" }
            $itFirstProperty = $False;
            $Result += "`"{#$Property}`":$Space$(Format-ToZabbix <#PrepareTo-Zabbix#> -InputObject $Object.$Property -JSONCompatible)";
         }
         # No comma printed after last string
         $Result += "$Space}";
      }
   }
   End {
      # Finalize and return JSON
      "$Result$CRLF$Tab]$CRLF}";
   }
}

#
#  Return value of object's metric defined by key-chain from $Keys Array
#
Function Get-Metric { 
   Param (
      [Parameter(ValueFromPipeline = $True)] 
      [PSObject]$InputObject, 
      [Array]$Keys
   ); 
   Process {
      # Do something with all objects (non-pipelined input case)  
      ForEach ($Object in $InputObject) { 
        If ($Null -Eq $Object) { Continue; }
        # Expand all metrics related to keys contained in array step by step
        ForEach ($Key in $Keys) {              
           If ($Key) {
              $Object = Select-Object -InputObject $Object -ExpandProperty $Key -ErrorAction SilentlyContinue;
              If ($Error) { Break; }
           }
        }
        $Object;
      }
   }
}

#Function Compile-WrapperDLL() {
Function New-WrapperDLL() {
   $WrapperSourceCode = 
@"
   using System;
   using System.Runtime.InteropServices;
   using System.Text;
   
   namespace HASP { 
      public class Monitor { 
         [DllImport(`"$($HSMON_LIB_FILE)`", CharSet = CharSet.Ansi,EntryPoint=`"mightyfunc`", CallingConvention=CallingConvention.Cdecl)]
         // String type used for request due .NET do auto conversion to Ansi char* with marshaliing procedure;
         // Byte[] type used for response due .NET char* is 2-byte, but mightyfunc() need to 1-byte Ansi char;
         // Int type used for responseBufferSize due .NET GetString() operate with [int] params. So, response lenght must be Int32 sized
         extern static unsafe void mightyfunc(string request, byte[] response, int *responseBufferSize);
     
         public Monitor() {}
      
         public static unsafe string doCmd(string request) {
            int responseBufferSize = 10240, responseLenght = 0;
            byte[] response = new byte[responseBufferSize];
            string returnValue = `"`";
            mightyfunc(request, response, &responseBufferSize);
            while (response[responseLenght++] != '\0') 
            returnValue = System.Text.Encoding.UTF8.GetString(response, 0, responseLenght);
            return returnValue;
         }
      } 
   }
"@

   $CompilerParameters = New-Object -TypeName System.CodeDom.Compiler.CompilerParameters;
   $CompilerParameters.CompilerOptions = "/unsafe /platform:x86";
   $CompilerParameters.OutputAssembly = $WRAPPER_LIB_FILE;
   Add-Type -TypeDefinition $WrapperSourceCode -Language CSharp -CompilerParameters $CompilerParameters;

}

# Is this a Wow64 powershell host
Function Test-Wow64() {
    Return ((Test-Win32) -And (test-path env:\PROCESSOR_ARCHITEW6432))
}

# Is this a 64 bit process
Function Test-Win64() {
    Return ([IntPtr]::Size -Eq 8)
}

# Is this a 32 bit process
Function Test-Win32() {
    Return ([IntPtr]::Size -Eq 4)
}

Function Get-NetHASPData {
   Param (
      [Parameter(Mandatory = $true, ValueFromPipeline = $true)] 
      [String]$Command,
      [Switch]$SkipScanning,
      [Switch]$ReturnPlainText
   );
   # Interoperation to NetHASP stages:
   #    1. Set configuration (point to .ini file)
   #    2. Scan servers while STATUS not OK or Timeout not be reached
   #    3. Do one or several GET* command   

   # Init connect to NetHASP module?   
   $Result = "";
   if (-Not $SkipScanning) {
      # Processing stage 1
      Write-Verbose "$(Get-Date) Stage #1. Initializing NetHASP monitor session"
      $Result = ([HASP.Monitor]::doCmd("SET CONFIG,FILENAME=$HSMON_INI_FILE")).Trim();
      if ('OK' -Ne $Result) { 
         Write-Warning -Message "Error 'SET CONFIG' command: $Result"; 
         Return
      }
   
      # Processing stage 2
      Write-Verbose "$(Get-Date) Stage #2. Scan NetHASP servers"
      $Result = [HASP.Monitor]::doCmd("SCAN SERVERS");
      $ScanSeconds = 0;
      Do {
         # Wait a second before check process state
         Start-Sleep -seconds 1
         $ScanSeconds++; $Result = ([HASP.Monitor]::doCmd("STATUS")).Trim();
         #Write-Verbose "$(Get-Date) Status: $ret"
      } While (('OK' -ne $Result) -And ($ScanSeconds -Lt $HSMON_SCAN_TIMEOUT))

      # Scanning timeout :(
      If ($ScanSeconds -Eq $HSMON_SCAN_TIMEOUT) {
            Write-Warning -Message "'SCAN SERVERS' command error: timeout reached";
        }
    }

   # Processing stage 3
   Write-Verbose "$(Get-Date) Stage #3. Execute '$Command' command";
   $Result = ([HASP.Monitor]::doCmd($Command)).Trim();

   If ('EMPTY' -eq $Result) {
      Write-Warning -Message "No data recieved";
   } else {
      if ($ReturnPlainText) {
        # Return unparsed output 
        $Result;
      } else {
        # Parse output and push PSObjects to output
        # Remove double-quotes and processed lines that taking from splitted by CRLF NetHASP answer. 
        ForEach ($Line in ($Result -Replace "`"" -Split "`r`n" )) {
           If (!$Line) {Continue;}
           # For every non-empty line do additional splitting to Property & Value by ',' and add its to hashtable
           $Properties = @{};
           ForEach ($Item in ($Line -Split ",")) {
              $Property, $Value = $Item.Split('=');
              # "HS" subpart workaround
              if ($Null -Eq $Value) { $Value = "" }
              $Properties.$Property = $Value;
           } 
           # Return new PSObject with hashtable used as properties list
           New-Object PSObject -Property $Properties;
        }
      }
   }
}

function Invoke-NetHasp
<#
.SYNOPSIS  
    Return Sentinel/Aladdin HASP Network Monitor metrics value, make LLD-JSON for Zabbix

.DESCRIPTION
    Return Sentinel/Aladdin HASP Network Monitor metrics value, make LLD-JSON for Zabbix

.NOTES  
    Version: 1.2.1
    Name: Aladdin HASP Network Monitor Miner
    Author: zbx.sadman@gmail.com
    DateCreated: 18MAR2016
    Testing environment: Windows Server 2008R2 SP1, Powershell 2.0, Aladdin HASP Network Monitor DLL 2.5.0.0 (hsmon.dll)

    Due _hsmon.dll_ compiled to 32-bit systems, you need to provide 32-bit environment to run all code, that use that DLL. You must use **32-bit instance of PowerShell** to avoid runtime errors while used on 64-bit systems. Its may be placed here:_%WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe.

.LINK  
    https://github.com/zbx-sadman

.PARAMETER Action
    What need to do with collection or its item:
        Discovery - Make Zabbix's LLD JSON;
        Get       - Get metric from collection's item;
        Count     - Count collection's items.
        DoCommand - Do NetHASP Monitor command that not require connection to server (HELP, VERSION). Command must be specified with -Key parameter

.PARAMETER ObjectType
    Define rule to make collection:
        Server - NetHASP server (detected with "GET SERVERS" command);
        Slot - NetHASP key slot ("GET SLOTS ...");
        Module - NetHASP module ("GET MODULES ...");
        Login - authorized connects to NetHASP server ("GET LOGINS ...").

.PARAMETER Key
    Define "path" to collection item's metric 

.PARAMETER ServerID
    Used to select NetHASP server from list. 
    ServerID can be numeric (real ID) or alphanumeric (server name)
    Server name must be taked from field "NAME" of the "GET SERVERS" command output ('stuffserver.contoso.com' or similar).

.PARAMETER ModuleID
    Used to additional objects selecting by Module Address

.PARAMETER SlotID
    Used to additional objects selecting by Slot

.PARAMETER LoginID
    Used to additional objects selecting by login Index

.PARAMETER ErrorCode
    What must be returned if any process error will be reached

.PARAMETER ConsoleCP
    Codepage of Windows console. Need to properly convert output to UTF-8

.PARAMETER Verbose
    Enable verbose messages

.EXAMPLE 
    Invoke-NetHasp -Action "DoCommand" -Key "VERSION"

    Description
    -----------  
    Get output of NetHASP Monitor VERSION command

.EXAMPLE 
    ... -Action "Discovery" -ObjectType "Server" 

    Description
    -----------  
    Make Zabbix's LLD JSON for NetHASP servers

.EXAMPLE 
    ... -Action "Get" -ObjectType "Slot" -Key "CURR" -ServerId "stuffserver.contoso.com" -SlotId "16" -ErrorCode "-127"

    Description
    -----------  
    Return number of used licenses on Slot #16 of stuffserver.contoso.com server. If processing error reached - return "-127"  

.EXAMPLE 
    ... -Action "Get" -ObjectType "Module" -Verbose

    Description
    -----------  
    Show formatted list of 'Module' object(s) metrics. Verbose messages is enabled. Console width is not changed.
#>
{
    Param (
       [Parameter(Mandatory = $True)] 
       [ValidateSet('DoCommand', 'Discovery', 'Get', 'Count')]
       [String]$Action,
       [Parameter(Mandatory = $False)]
       [ValidateSet('Server', 'Module', 'Slot', 'Login')]
       [Alias('Object')]
       [String]$ObjectType,
       [Parameter(Mandatory = $False)]
       [String]$Key,
       [Parameter(Mandatory = $False)]
       [String]$ServerId,
       [Parameter(Mandatory = $False)]
       [String]$ModuleId,
       [Parameter(Mandatory = $False)]
       [String]$SlotId,
       [Parameter(Mandatory = $False)]
       [String]$LoginId,
       [Parameter(Mandatory = $False)]
       [String]$ErrorCode = '-127',
       [Parameter(Mandatory = $False)]
       [String]$ConsoleCP,
       [Parameter(Mandatory = $False)]
       [String]$HSMON_LIB_PATH,
       [Parameter(Mandatory = $False)]
       [String]$HSMON_INI_FILE,
       [Parameter(Mandatory = $False)]
       [Int]$HSMON_SCAN_TIMEOUT = 30,
       [Parameter(Mandatory = $False)]
       [Switch]$JSON = $false
    );

    # Set default values from '1CHelper' module
    if ( -not $HSMON_LIB_PATH ) {
        $HSMON_LIB_PATH = (Get-NetHaspDirectoryPath).Replace('\','\\')
    }

    if ( -not $HSMON_INI_FILE ) {
        $HSMON_INI_FILE = (Get-NetHaspIniFilePath).Replace('\','\\')
    }

    #Set-StrictMode –Version Latest

    # Set US locale to properly formatting float numbers while converting to string
    #[System.Threading.Thread]::CurrentThread.CurrentCulture = "en-US";

    # Width of console to stop breaking JSON lines
    <#if ( -not $CONSOLE_WIDTH ) {
        Set-Variable -Name "CONSOLE_WIDTH" -Value 255 -Option Constant;
    }#>

    # Full paths to hsmon.dll and nethasp.ini
    if ( -not $HSMON_LIB_FILE ) {
        Set-Variable -Name "HSMON_LIB_FILE" -Value "$HSMON_LIB_PATH\\hsmon.dll" -Option Constant;
    }
    # Set-Variable -Name "HSMON_INI_FILE" -Value "$HSMON_LIB_PATH\\nethasp.ini" -Option Constant;

    # Full path to hsmon.dll wrapper, that compiled by this script
    if ( -not $WRAPPER_LIB_FILE ) {
        Set-Variable -Name "WRAPPER_LIB_FILE" -Value "$HSMON_LIB_PATH\\wraphsmon.dll" -Option Constant;
    }

    # Timeout in seconds for "SCAN SERVERS" connection stage
    Set-Variable -Name "HSMON_SCAN_TIMEOUT" -Value $HSMON_SCAN_TIMEOUT # -Option Constant;

    # Enumerate Objects. [int][NetHASPObjectType]::DumpType equal 0 due [int][NetHASPObjectType]::AnyNonexistItem equal 0 too
    Add-Type -TypeDefinition "public enum NetHASPObjectType { DumpType, Server, Module, Slot, Login }";

    Write-Verbose "$(Get-Date) Checking runtime environment...";

    # Script running into 32-bit environment?
    If ($False -Eq (Test-Wow64)) {
       Write-Warning "You must run this script with 32-bit instance of Powershell, due wrapper interopt with 32-bit Windows Library";
       Write-Warning "Try to use %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe `"&{Invoke-NetHasp [-Options ...]}`" [-OtherOptions ...]";
       Return;
    }

    Write-Verbose "$(Get-Date) Checking wrapper library for HASP Monitor availability...";
    If ($False -eq (Test-Path $WRAPPER_LIB_FILE)) {
       Write-Verbose "$(Get-Date) Wrapper library not found, try compile it";
       Write-Verbose "$(Get-Date) First wrapper library loading can get a few time. Please wait...";
       New-WrapperDLL;
       If ($False -Eq (Test-Path $WRAPPER_LIB_FILE)) {
        Write-Warning "Wrapper library not found after compilation. Something wrong";
        Return
       }
    } else {
      Write-Verbose "$(Get-Date) Loading wrapper library";
      Add-Type -Path $WRAPPER_LIB_FILE;
    }

    # Need to run one HASP command like HELP, VERSION ?
    If ('DoCommand' -Eq $Action) {
       If ($Key) {
           Write-Verbose "$(Get-Date) Just do command '$Key'";
           ([HASP.Monitor]::doCmd($Key)).Trim();
       } Else {
          Write-Warning -Message "No HASPMonitor command given with -Key option";
       }
       Return;
    }

    $Keys = $Key.Split(".");

    # Exit if object is not [NetHASPObjectType]
    #If (0 -Eq [int]($ObjectType -As [NetHASPObjectType])) { Exit-WithMessage -Message "Unknown object type: '$ObjectType'" -ErrorCode $ErrorCode; }

    Write-Verbose "$(Get-Date) Creating collection of specified object: '$ObjectType'";
    # Object must contain Servers data?
    if (($ObjectType -As [NetHASPObjectType]) -Ge [NetHASPObjectType]::Server) {
       Write-Verbose "$(Get-Date) Getting server list";
       $Servers = Get-NetHASPData -Command "GET SERVERS"; 
       if (-Not $Servers) { 
          Write-Warning -Message "No NetHASP servers found";
          Return;
       }

       Write-Verbose "$(Get-Date) Checking server ID";
       if ($ServerId) {
          # Is Server Name into $ServerId
          if (![RegEx]::IsMatch($ServerId,'^\d+$')) {
             # Taking real ID if true
             Write-Verbose "$(Get-Date) ID ($ServerId) was not numeric - probaly its hostname, try to find ID in servers list";
             $ServerId = (PropertyEqualOrAny -InputObject $Servers -Property NAME -Value $ServerId).ID;
             if (!$ServerId) {
                Write-Warning -Message "Server not found";
                Return
             }
             Write-Warning "$(Get-Date) Got real ID ($ServerId)";
          }
       }
       Write-Verbose "$(Get-Date) Filtering... (ID=$ServerId)";
       $Objects = $Servers = PropertyEqualOrAny -InputObject $Servers -Property ID -Value $ServerId
    }

    # Object must be processed with Servers data?
    if (($ObjectType -As [NetHASPObjectType]) -ge [NetHASPObjectType]::Module) {
       Write-Verbose "$(Get-Date) Getting modules list"; 
       $Modules = ForEach ($Server in $Servers) { 
          Get-NetHASPData -Command "GET MODULES,ID=$($Server.ID)" -SkipScanning; 
       }
       $Objects = $Modules = PropertyEqualOrAny -InputObject $Modules -Property MA -Value $ModuleId
    }

    # Object must be processed with Servers+Modules data?
    if (($ObjectType -As [NetHASPObjectType]) -ge [NetHASPObjectType]::Slot) {
       Write-Verbose "$(Get-Date) Getting slots list";
       $Slots = ForEach ($Module in $Modules) { 
          Get-NetHASPData -Command "GET SLOTS,ID=$($Module.ID),MA=$($Module.MA)" -SkipScanning; 
       }
       $Objects = $Slots = PropertyEqualOrAny -InputObject $Slots -Property SLOT -Value $SlotId
    }

    # Object must be processed with Servers+Modules+Slots data?
    If (($ObjectType -As [NetHASPObjectType]) -Ge [NetHASPObjectType]::Login) {
       Write-Verbose "$(Get-Date) Getting logins list";
       # LOGININFO ignore INDEX param and return list of Logins anyway
       $Logins = ForEach ($Slot In $Slots) { 
          Get-NetHASPData -Command "GET LOGINS,ID=$($Slot.ID),MA=$($Slot.MA),SLOT=$($Slot.SLOT)" -SkipScanning;
       }
       $Objects = $Logins = PropertyEqualOrAny -InputObject $Slots -Property INDEX -Value $LoginId
    }


    ForEach ($Object in $Objects) {   
      Add-Member -InputObject $Object -MemberType NoteProperty -Name "ServerName" -Value (PropertyEqualOrAny -InputObject $Servers -Property ID -Value $Object.ID).Name;
      Add-Member -InputObject $Object -MemberType AliasProperty -Name "ServerID" -Value ID
    }

    Write-Verbose "$(Get-Date) Collection created, begin processing its with action: '$Action'";
    switch ($Action) {
       'Discovery' {
          [Array]$ObjectProperties = @();
          Switch ($ObjectType) {
              'Server' {
                 $ObjectProperties = @("SERVERNAME", "SERVERID");
              }
              'Module' {
                 # MA - module address 
                 $ObjectProperties = @("SERVERNAME", "SERVERID", "MA", "MAX");
              }
              'Slot'   {
                 $ObjectProperties = @("SERVERNAME", "SERVERID", "MA", "SLOT", "MAX");
              }
              'Login' {
                 $ObjectProperties = @("SERVERNAME", "SERVERID", "MA", "SLOT", "INDEX", "NAME");
              }
           }
           if ( $JSON ) {
            Write-Verbose "$(Get-Date) Generating LLD JSON";
            $Result =  Get-NetHaspJSON <#Make-JSON#> -InputObject $Objects -ObjectProperties $ObjectProperties -Pretty;
           } else {
            $Result = $Objects
           }
       }
       'Get' {
          If ($Keys) { 
             Write-Verbose "$(Get-Date) Getting metric related to key: '$Key'";
             $Result = Format-ToZabbix -InputObject (Get-Metric -InputObject $Objects -Keys $Keys) -ErrorCode $ErrorCode;
          } Else { 
             Write-Verbose "$(Get-Date) Getting metric list due metric's Key not specified";
             $Result = <#Out-String -InputObject#> Get-Metric -InputObject $Objects -Keys $Keys;
          };
       }
       # Count selected objects
       'Count' { 
          Write-Verbose "$(Get-Date) Counting objects";  
          # if result not null, False or 0 - return .Count
          $Result = $(if ($Objects) { @($Objects).Count } else { 0 } ); 
       }
    }  

    # Convert string to UTF-8 if need (For Zabbix LLD-JSON with Cyrillic chars for example)
    <#If ($consoleCP) { 
       Write-Verbose "$(Get-Date) Converting output data to UTF-8";
       $Result = $Result | ConvertTo-Encoding -From $consoleCP -To UTF-8; 
    }#>

    # Break lines on console output fix - buffer format to 255 chars width lines 
    <#If (!$DefaultConsoleWidth) { 
       Write-Verbose "$(Get-Date) Changing console width to $CONSOLE_WIDTH";
       mode con cols=$CONSOLE_WIDTH; 
    }#>

    Write-Verbose "$(Get-Date) Finishing";
    $Result;
}

function Invoke-UsbHasp
<#
.SYNOPSIS  
    Return USB (HASP) Device metrics value, count selected objects, make LLD-JSON for Zabbix

.DESCRIPTION
    Return USB (HASP) Device metrics value, count selected objects, make LLD-JSON for Zabbix

.NOTES  
    Version: 1.2.1
    Name: USB HASP Keys Miner
    Author: zbx.sadman@gmail.com
    DateCreated: 18MAR2016
    Testing environment: Windows Server 2008R2 SP1, USB/IP service, Powershell 2.0

.LINK  
    https://github.com/zbx-sadman

.PARAMETER Action
    What need to do with collection or its item:
        Discovery - Make Zabbix's LLD JSON;
        Get       - Get metric from collection item;
        Count     - Count collection items.

.PARAMETER ObjectType
    Define rule to make collection:
        USBController - "Physical" devices (USB Key)
        LogicalDevice - "Logical" devices (HASP Key)

.PARAMETER Key
    Define "path" to collection item's metric 

.PARAMETER PnPDeviceID
    Used to select only one item from collection

.PARAMETER ErrorCode
    What must be returned if any process error will be reached

.PARAMETER Verbose
    Enable verbose messages

.EXAMPLE 
    Invoke-UsbHasp -Action "Discovery" -ObjectType "USBController"

    Description
    -----------  
    Make Zabbix's LLD JSON for USB keys

.EXAMPLE 
    ... -Action "Count" -ObjectType "LogicalDevice"

    Description
    -----------  
    Return number of HASP keys

.EXAMPLE 
    ... -Action "Get" -ObjectType "USBController" -PnPDeviceID "USB\VID_0529&PID_0001\1&79F5D87&0&01" -ErrorCode "-127" -DefaultConsoleWidth -Verbose

    Description
    -----------  
    Show formatted list of 'USBController' object metrics selected by PnPId "USB\VID_0529&PID_0001\1&79F5D87&0&01". 
    Return "-127" when processing error caused. Verbose messages is enabled. 

    Note that PNPDeviceID is unique for USB Key, ID - is not.
#>
{
    Param (
       [Parameter(Mandatory = $True)] 
       [ValidateSet('Discovery','Get','Count')]
       [String]$Action,
       [Parameter(Mandatory = $False)]
       [ValidateSet('LogicalDevice','USBController')]
       [Alias('Object')]
       [String]$ObjectType,
       [Parameter(Mandatory = $False)]
       [String]$Key,
       [Parameter(Mandatory = $False)]
       [String]$PnPDeviceID,
       [Parameter(Mandatory = $False)]
       [String]$ErrorCode = '-127',
       [Parameter(Mandatory = $False)]
       [Switch]$JSON = $false
    );

    # split key
    $Keys = $Key.Split(".");

    Write-Verbose "$(Get-Date) Taking Win32_USBControllerDevice collection with WMI"
    $Objects = Get-WmiObject -Class "Win32_USBControllerDevice";

    Write-Verbose "$(Get-Date) Creating collection of specified object: '$ObjectType'";
    Switch ($ObjectType) {
       'LogicalDevice' { 
          $PropertyToSelect = 'Dependent';    
       }
       'USBController' { 
          $PropertyToSelect = 'Antecedent';    
       }
    }

    # Need to take Unique items due Senintel used multiply logical devices linked to physical keys. 
    # As a result - double "physical" device items into 'Antecedent' branch
    #
    # When the -InputObject parameter is used to submit a collection of items, Sort-Object receives one object that represents the collection.
    # Because one object cannot be sorted, Sort-Object returns the entire collection unchanged.
    # To sort objects, pipe them to Sort-Object.
    # (C) PoSh manual
    $Objects = $( ForEach ($Object In $Objects) { 
                     PropertyEqualOrAny -InputObject ([Wmi]$Object.$PropertyToSelect) -Property PnPDeviceID -Value $PnPDeviceID
               }) | Sort-Object -Property PnPDeviceID -Unique;

    Write-Verbose "$(Get-Date) Processing collection with action: '$Action' ";
    Switch ($Action) {
       # Discovery given object, make json for zabbix
       'Discovery' {
          Write-Verbose "$(Get-Date) Generating LLD JSON";
          $ObjectProperties = @("NAME", "PNPDEVICEID");
          if ( $JSON ) {
            $Result = Make-JSON -InputObject $Objects -ObjectProperties $ObjectProperties -Pretty;
          } else {
            $Result = $Objects
          }
       }
       # Get metrics or metric list
       'Get' {
          If ($Keys) { 
             Write-Verbose "$(Get-Date) Getting metric related to key: '$Key'";
             $Result = PrepareTo-Zabbix -InputObject (Get-Metric -InputObject $Objects -Keys $Keys) -ErrorCode $ErrorCode;
          } Else { 
             Write-Verbose "$(Get-Date) Getting metric list due metric's Key not specified";
             $Result = $Objects;
          };
       }
       # Count selected objects
       'Count' { 
          Write-Verbose "$(Get-Date) Counting objects";  
          # if result not null, False or 0 - return .Count
          $Result = $( If ($Objects) { @($Objects).Count } Else { 0 } ); 
       }
    }

    Write-Verbose "$(Get-Date) Finishing";
    $Result;
}

<# END
https://github.com/zbx-sadman
#>

Export-ModuleMember Remove-NotUsedObjects, Find-1CEstart, Find-1C8conn, Get-ClusterData, Get-NetHaspIniStrings, Invoke-NetHasp, Invoke-UsbHasp, Remove-Session, Invoke-SqlQuery, Get-TechJournalData, Get-APDEXinfo, Get-TechJournalLOGtable,Remove-1CTempDirs
