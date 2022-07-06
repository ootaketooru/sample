#共通DLL利用
[void][Reflection.Assembly]::LoadFile((Convert-Path ".\Dlls\HiCommonLibrary.dll"))
#ログ処理DLL利用
[void][Reflection.Assembly]::LoadFile((Convert-Path ".\Dlls\HiLogManager2.dll"))
#共有フォルダ接続に利用
[void][Reflection.Assembly]::LoadFile((Convert-Path ".\Dlls\HiFileAccess.dll"))
#DBアクセス利用
[void][Reflection.Assembly]::LoadFile((Convert-Path ".\Dlls\HiDBAccess.dll"))

### ログ操作インスタンスを返す ###
function GetLogger($LogDir, $LogLevel, $LogKeepDays)
{
    if ($LogDir -ne "" -and $LogDir -ne $null)
    {
        return [Fms.Himedion.HiLogManager2.Logger]::new($LogDir, $LogLevel, $LogKeepDays, 1, 1)
    }
    else
    {
        return [Fms.Himedion.HiLogManager2.Logger]::new((Join-Path (Split-Path $PSScriptRoot -Parent) "AppLog"), 0, 1, 1, 1)
    }
}

### 実行引数をチェックする ###
function ParamCheck()
{
    #全ての引数が指定されているかチェック
    if([string]::IsNullOrEmpty($ACCESSIONNUMBER) `
        -or [string]::IsNullOrEmpty($PATIENTID) `
        -or [string]::IsNullOrEmpty($STUDYDATE) `
        )
    {
        $m_Logger.ERROR("--- 実行不能  --- 引数が不足しています。{0}" -f $strParam)
        return $false
    }

    return $true
}


### ファイル操作インスタンス作成 ###
function GetFileCon()
{
    return [Fms.Himedion.HiFileAccess.HiFileAccessFunction]::new()
}

### 出力フォルダチェック ###
function CheckOutputFolder()
{
    # 出力フォルダが存在するかをチェック
    if(Test-Path $OutputPath) {
        return $true
    }

  ### 存在しない場合の処理 ###

    #出力先がネットワークフォルダの場合、接続し出来ない場合は終了
    if($OutputPath.Substring(0,2) -eq "\\") {
        #共有フォルダ接続
        $filecon = GetFileCon
        if(!$filecon.NetConnect($OutputPath,$OutputUsername,$OutputPassword))
        {
            $m_Logger.Error($filecon.MessageObject.Description)
            if (-not([string]::IsNullOrEmpty($filecon.MessageObject.Exception)))
            {
                $m_Logger.Error($filecon.MessageObject.Exception)
            }
        }
    #出力先がローカルフォルダの場合、フォルダ作成
    } else {
        [void](New-Item -ItemType Directory -Path $OutputPath -Force)
        $m_logger.Warn("フォルダが存在しないため作成 ※共有設定はしていません！。[{0}]" -f $OutputPath)
    }

    # 最終チェック
    return (Test-Path $OutputPath)
}

### DB接続コネクション作成 ###
function newHiDBAccess()
{
    return [HiDBAccess.OracleControl]::new()
}

function CreateWorkFolder()
{
    try
    {
        $WorkBasePath = (Join-Path (Split-Path $PSScriptRoot -Parent) "Work")

        #ベースフォルダが無ければ作成する
        [void](New-Item -ItemType Directory -Path $WorkBasePath -Force)

        #作業用フォルダ（ACCESSIONNUMBER + 日付時刻フォルダ）を作成する
        $FolderName = $OutFileProperty.ACCESSIONNUMBER + "_" + (Get-Date -Format "yyyyMMddHHmmssfff")
        $OutFileProperty.WorkFolder = Join-Path $WorkBasePath $FolderName
        [void](New-Item -ItemType Directory -Path $OutFileProperty.WorkFolder -Force)

        return $true

    } catch {
        #エラー詳細情報設定
        $ERRMSG = $ERROR[0] | Out-string
        #ログ出力
        $m_Logger.Error($ERRMSG)

        return $false

    } finally {
        #なし
    }
}

#column名を取得するサンプル
#$columnNames=$odbcReader.GetSchemaTable() | Select-Object -ExpandProperty ColumnName
#foreach($h in $columnNames){
#    $h
#}

function SetCSVTargetList()
{
    try
    {
        $Sql = $getCSVTargetSQL
        # バインド変数作成
        $Dictionaly = [System.Collections.Generic.Dictionary[string, string]]::new()
        [void]$Dictionaly.Add("ACCESSIONNUMBER", $OutFileProperty.ACCESSIONNUMBER)
        $Param = "ACCESSIONNUMBER:[$($Dictionaly.ACCESSIONNUMBER)]"

        # データ取得
        [void]$Oracle.ReConnect()
        $DataTable = $Oracle.GetDataTable($Sql, $Dictionaly)

        if($Oracle.ErrCode -ne 0)
        {
            $m_Logger.Error($Oracle.ErrMessage + `
                            "`r`n[SQL]" + $Sql + `
                            "`r`n[Param] $($Param)"
                            )
            return $false
        }

        $columnNames = $DataTable.Columns
        Foreach($Row in $DataTable.Rows)
        {
            #CSVTargetにデータを格納
            $CSVTarget = [PSCustomObject]@{}
            foreach($colname in $columnNames){
                $CSVTarget | Add-Member -MemberType NoteProperty -Name $colname -Value ($Row.Item($colname) + "")
            }

            [void]$CSVTargetList.Add($CSVTarget)
        }

        return $true
    } catch {

        #エラー詳細情報設定
        $ERRMSG = $ERROR[0] | Out-string
        #ログ出力
        $m_Logger.ERROR($ERRMSG)

        return $false
    } finally {
        #$odbcReader.Dispose()
        #$odbcCmd.Dispose()
    }
}

function CreateCSVFile()
{
    try
    {
        # データ取得SQL文
        $Sql = $getCSVDATA_SQL

        #CSVターゲットの1データのみ処理する
        $CSVTarget = $CSVTargetList[0]

        #ファイル名作成
        $CSVFileName = (Split-Path -Leaf $OutFileProperty.WorkFolder) + ".csv"

        ### データ取得 ###
        $DOCDATAUID = $CSVTarget.DOCDATAUID
        $TITLE = $CSVTarget.TITLE

        # バインド変数作成
        $Dictionaly = [System.Collections.Generic.Dictionary[string, string]]::new()
        [void]$Dictionaly.Add("DOCDATAUID", $DOCDATAUID)
        [void]$Dictionaly.Add("TITLE", $TITLE)
        $Param = "DOCDATAUID:[$($DOCDATAUID)] / TITLE:[$($TITLE)]"

        [void]$Oracle.ReConnect()
        $DataTable = $Oracle.GetDataTable($Sql, $Dictionaly)

        if($Oracle.ErrCode -ne 0)
        {
            $m_Logger.Error($Oracle.ErrMessage + `
                            "`r`n[SQL]" + $Sql + `
                            "`r`n[Param] $($Param)"
                            )
            return $false
        }

        if($DataTable.Rows.Count -eq 0)
        {
            $m_Logger.Error("出力用データが取得できません。" + `
                            "`r`n[Param] $($Param)"
                            )
            return $false
        }

        ### CSV用オブジェクト作成 ###
        $CSVObject = [PSCustomObject]@{}

        # 共通情報設定
        $ACCESSIONNUMBER = $OutFileProperty.ACCESSIONNUMBER
        $PATIENTID = $OutFileProperty.PATIENTID
        $STUDYDATE = $OutFileProperty.STUDYDATE

        $CSVObject | Add-Member -MemberType NoteProperty -Name "検査日" -Value $STUDYDATE
        $CSVObject | Add-Member -MemberType NoteProperty -Name "オーダー番号" -Value $ACCESSIONNUMBER
        $CSVObject | Add-Member -MemberType NoteProperty -Name "個人ID" -Value $PATIENTID
        $CSVObject | Add-Member -MemberType NoteProperty -Name "種別" -Value $TITLE
                
        # レポート値情報設定
        Foreach($Row in $DataTable.Rows)
        {
            $key = $Row.CSVTITLE
            $value = $Row.CSVVALUE

            #同一キー名がある場合は、改行し文字結合
            if($CSVObject.psobject.properties.match($key).count){
                if (-not([string]::IsNullOrEmpty($CSVObject.$key)) -and -not([string]::IsNullOrEmpty($value))) {
                    $CSVObject.$key = $CSVObject.$key + "`r`n" + $value
                } else {
                    $CSVObject.$key = $value
                }
            } else {
                $CSVObject | Add-Member -MemberType NoteProperty -Name $key -Value $value
            }
        }

        ### CSV出力 ###
        #CSV用オブジェクトの項目が取得出来た場合にCSV出力する
        if(@($CSVObject.PSobject.Properties).Count -gt 0)
        {
            # CSV出力先設定
            $CSVWorkPath = (Join-Path $OutFileProperty.WorkFolder $CSVFileName)

            # CSV出力処理
            # カンマ区切り、文字コード:ShiftJIS
            $CSVObject | Export-Csv -delimiter "," -Encoding Default -NoTypeInformation -LiteralPath $CSVWorkPath

            $m_Logger.Debug("csvファイル作成：[" + $CSVWorkPath + "]")
        }

        $m_Logger.Info("CSV作成完了")

        return $true

    } catch {

        #エラー詳細情報設定
        $ERRMSG = $ERROR[0] | Out-string
        #ログ出力
        $m_Logger.Error("ACCESSIONNUMBER:[$($ACCESSIONNUMBER)] `r`n$ERRMSG")

        return $false

    } finally {
        #特になし
    }
}

function SetImageList()
{
    try
    {
        $Sql = $getImageListSQL
        # バインド変数作成
        $Dictionaly = [System.Collections.Generic.Dictionary[string, string]]::new()
        [void]$Dictionaly.Add("ACCESSIONNUMBER", $OutFileProperty.ACCESSIONNUMBER)
        $Param = "ACCESSIONNUMBER:[$($Dictionaly.ACCESSIONNUMBER)]"

        # データ取得
        [void]$Oracle.ReConnect()
        $DataTable = $Oracle.GetDataTable($Sql, $Dictionaly)

        if($Oracle.ErrCode -ne 0)
        {
            $m_Logger.Error($Oracle.ErrMessage + `
                            "`r`n[SQL]" + $Sql + `
                            "`r`n[Param] $($Param)"
                            )
            return $false
        }

        Foreach($Row in $DataTable.Rows)
        {
            $FILEPATH = $Row.Item("FILEPATH")
            [void]$ImageList.Add($FILEPATH)
        }
        $columnNames = $DataTable.Columns
        Foreach($Row in $DataTable.Rows)
        {
            #ImageTargetにデータを格納
            $ImageTarget = [PSCustomObject]@{}
            foreach($colname in $columnNames){
                $ImageTarget | Add-Member -MemberType NoteProperty -Name $colname -Value ($Row.Item($colname) + "")
            }

            [void]$ImageTargetList.Add($ImageTarget)
        }

        return $true
    } catch {

        #エラー詳細情報設定
        $ERRMSG = $ERROR[0] | Out-string
        #ログ出力
        $m_Logger.ERROR($ERRMSG)

        return $false
    } finally {
        #$odbcReader.Dispose()
        #$odbcCmd.Dispose()
    }
}

function CopyImageFile()
{
    $CopyCount = 0
    try
    {
        $ROOTPATHNAME = ""

        ### ルートフォルダ接続 ###
        if($ImageTargetList.Count -gt 0){

            #画像リストの1番目のデータよりルートフォルダ接続情報取得
            $ImageTarget = $ImageTargetList[0]

            $ROOTPATHNAME = $ImageTarget.ROOTPATHNAME
            $USERNAME = $ImageTarget.USERNAME
            $PASSWORD = $ImageTarget.PASSWORD

            # ROOTPATHの接続確認
            $CONNECTLOG = "画像ファイル ルートフォルダ接続：[$($ROOTPATHNAME)] $($USERNAME) / *****"

            # ネットワークフォルダで接続出来ない場合
            if(!(Test-Path $ROOTPATHNAME) -and $ROOTPATHNAME.Substring(0,2) -eq "\\") {
                $filecon = GetFileCon
                # ユーザーとパスワードで接続処理実行
                if(!$filecon.NetConnect($ROOTPATHNAME,$USERNAME,$PASSWORD))
                {
                    $m_Logger.WARN($filecon.MessageObject.Description)
                    if (-not([string]::IsNullOrEmpty($filecon.MessageObject.Exception)))
                    {
                        $m_Logger.WARN($filecon.MessageObject.Exception)
                    }
                }
            }
            
            if(!(Test-Path $ROOTPATHNAME)){
                #接続出来ない場合は、処理終了
                $m_Logger.WARN($CONNECTLOG)

                return $false
            } else {
                $m_Logger.DEBUG($CONNECTLOG)
            }

        }

        ### 画像ファイルコピー ###
        Foreach($ImageTarget in $ImageTargetList){

            # 画像ファイルの取得
            $FilePath = $ImageTarget.FILEPATH

            if(Test-Path $FilePath){
                $File = @(Get-ChildItem -Path $FilePath)
                $FileName = (Split-Path $OutFileProperty.WorkFolder -Leaf) + "_" +  ([string]($CopyCount + 1)) + ([System.IO.Path]::GetExtension($FilePath))
                $WorkFilePath = Join-Path $OutFileProperty.WorkFolder "$($FileName)"

                try
                {
                    #ワークフォルダにファイルコピー
                    $Message = "画像ファイルコピー:[$($File.FullName)]⇒[$($WorkFilePath)]"
                    [void](Copy-Item -LiteralPath $File.FullName -Destination $WorkFilePath -Force)

                    $m_Logger.DEBUG($Message)
                    $CopyCount += 1

                } catch {
                    #エラー詳細情報設定
                    $ERRMSG = $ERROR[0] | Out-string
                    #ログ出力
                    $m_Logger.ERROR("$($Message) `r`n$ERRMSG")

                    continue
                }
            } else {
                #ログ出力
                $m_Logger.WARN("画像ファイルが存在しません。:[$($FilePath)]")
            }
        }

        if ($ImageList.Count -gt 0)
        {
            $ResultCount = "[$($CopyCount.ToString()) / $($ImageList.Count.ToString())]"

            if ($CopyCount -eq $ImageList.Count){
                $m_Logger.Info("画像ファイルコピー完了 $($ResultCount)")
            } else {
                $m_Logger.WARN("画像ファイルコピー完了(未あり) $($ResultCount)")

                return $false
            }
        }

        return $true

    } catch {

        #エラー詳細情報設定
        $ERRMSG = $ERROR[0] | Out-string
        #ログ出力
        $m_Logger.ERROR($ERRMSG)

        return $false
    } finally {
        #ルートフォルダ切断
        [void](GetFileCon).NetDisconnect($ROOTPATHNAME)
    }
}

function CopyWorkFolder()
{

    $IDXCount = 0
    $OKCount = 0

    try
    {
        # タイミングファイル検知
        Foreach($TimingFile in $TimingFileList){

            $IDXCount++
            $ResultFlg = $true

            # 同名フォルダチェック
            $ResultPath = Join-Path (Split-Path -Path $TimingFile.FullName) ([System.IO.Path]::GetFileNameWithoutExtension($TimingFile.FullName))

            if(Test-Path $ResultPath){
                $target_path = Join-Path $OutputPath (Split-Path $ResultPath -Leaf)
                # 出力先にフォルダが存在した場合、中身ごと削除
                if(Test-Path $target_path){
                    Remove-Item $target_path -Recurse
                }

                # 結果フォルダを中身ごとコピー
                Copy-Item $ResultPath $target_path -Force -Recurse
                $m_Logger.DEBUG("($([string]$IDXCount))連携フォルダ出力 ⇒[$($target_path)]")

                # タイミングファイル作成
                $TimingFilePath = Join-Path (Split-Path -Path $target_path) $TimingFile.Name
                [void](New-Item -Path $TimingFilePath -Force)
                $m_Logger.DEBUG("($([string]$IDXCount))タイミングファイル作成 ⇒[$($TimingFilePath)]")

                #正常コピー件数+1
                $OKCount++

                # 結果フォルダをログフォルダに移動
                $m_Logger.CopyToLogResultDir2($ResultPath, $true, $true)

            } else {
                $m_Logger.WARN("($([string]$IDXCount))連携不能 タイミングファイルのみ[$($TimingFile.FullName)]")
                $ResultFlg = $false
            }

            # タイミングファイルをログフォルダに移動
            $m_Logger.CopyToLogResult($TimingFile, $ResultFlg, $true)

        }

        if($TimingFileList.Count -gt 0){
            $m_Logger.INFO("結果連携完了[$([string]$OKCount) / $([string]$TimingFileList.Count)]")
        }
        return $true

    } catch {

        #エラー詳細情報設定
        $ERRMSG = $ERROR[0] | Out-string
        #ログ出力
        $m_Logger.ERROR($ERRMSG)

        return $false
    } finally {
        #なし
    }
}

### ログ処理 ###

#作成したファイルを移動
function MoveWorkFolder()
{
    try
    {
        $m_Logger.CopyToLogResultDir2($OutFileProperty.WorkFolder, $ResultFlg, $true)
        return $true
    } catch {

        #エラー詳細情報設定
        $ERRMSG = $ERROR[0] | Out-string
        #ログ出力
        $m_Logger.ERROR($ERRMSG)

        return $false
    } finally {
        #なし
    }
}

### 導入時テスト用処理 ###
function TEST-OUTPUTFOLDER()
{
    try
    {
      ### 出力フォルダ確認 ###
        $TEST_filecon = GetFileCon
            
        Write-Host "##### 出力先フォルダテスト #####"
        #出力先がネットワークフォルダの場合、接続し出来ない場合は終了
        if($OutputPath.Substring(0,2) -eq "\\") {
            #共有フォルダ接続
            if(!$TEST_filecon.NetConnect($OutputPath,$OutputUsername,$OutputPassword))
            {
                Write-Host $TEST_filecon.MessageObject.Description
                if (-not([string]::IsNullOrEmpty($TEST_filecon.MessageObject.Exception)))
                {
                    Write-Host $TEST_filecon.MessageObject.Exception
                }
            }
        }
        if(Test-Path($OutputPath))
        {
            Write-Host "出力先フォルダOK:[$($OutputPath)]"
        } else {
            Write-Host "出力先フォルダNG:[$($OutputPath)]"
        }

    } catch {
        #エラー詳細情報設定
        Write-Host $ERROR[0]
    } finally {
        [void]$TEST_filecon.NetDisconnect($OutputPath)
    }
}

function TEST-DBCONNECT()
{
    try
    {
      ### データベース接続設定(ODBC接続) ###
        $TEST_Oracle = newHiDBAccess

        Write-Host "##### DB接続テスト #####"

        if($TEST_Oracle.Connect($L_Oracle_ServiceName, $L_Oracle_uid, $L_Oracle_pwd))
        {
            Write-Host "DB接続OK:[$($TEST_Oracle.Connection.ConnectionString)]"
        } else {
            Write-Host "DB接続NG:[$($TEST_Oracle.Connection.ConnectionString)] $($TEST_Oracle.ErrMessage)"
        }

    } catch {
        #エラー詳細情報設定
        Write-Host $ERROR[0]
    } finally {
        [void]$TEST_Oracle.DisConnect
    }
}
