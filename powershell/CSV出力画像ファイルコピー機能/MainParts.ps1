#����DLL���p
[void][Reflection.Assembly]::LoadFile((Convert-Path ".\Dlls\HiCommonLibrary.dll"))
#���O����DLL���p
[void][Reflection.Assembly]::LoadFile((Convert-Path ".\Dlls\HiLogManager2.dll"))
#���L�t�H���_�ڑ��ɗ��p
[void][Reflection.Assembly]::LoadFile((Convert-Path ".\Dlls\HiFileAccess.dll"))
#DB�A�N�Z�X���p
[void][Reflection.Assembly]::LoadFile((Convert-Path ".\Dlls\HiDBAccess.dll"))

### ���O����C���X�^���X��Ԃ� ###
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

### ���s�������`�F�b�N���� ###
function ParamCheck()
{
    #�S�Ă̈������w�肳��Ă��邩�`�F�b�N
    if([string]::IsNullOrEmpty($ACCESSIONNUMBER) `
        -or [string]::IsNullOrEmpty($PATIENTID) `
        -or [string]::IsNullOrEmpty($STUDYDATE) `
        )
    {
        $m_Logger.ERROR("--- ���s�s�\  --- �������s�����Ă��܂��B{0}" -f $strParam)
        return $false
    }

    return $true
}


### �t�@�C������C���X�^���X�쐬 ###
function GetFileCon()
{
    return [Fms.Himedion.HiFileAccess.HiFileAccessFunction]::new()
}

### �o�̓t�H���_�`�F�b�N ###
function CheckOutputFolder()
{
    # �o�̓t�H���_�����݂��邩���`�F�b�N
    if(Test-Path $OutputPath) {
        return $true
    }

  ### ���݂��Ȃ��ꍇ�̏��� ###

    #�o�͐悪�l�b�g���[�N�t�H���_�̏ꍇ�A�ڑ����o���Ȃ��ꍇ�͏I��
    if($OutputPath.Substring(0,2) -eq "\\") {
        #���L�t�H���_�ڑ�
        $filecon = GetFileCon
        if(!$filecon.NetConnect($OutputPath,$OutputUsername,$OutputPassword))
        {
            $m_Logger.Error($filecon.MessageObject.Description)
            if (-not([string]::IsNullOrEmpty($filecon.MessageObject.Exception)))
            {
                $m_Logger.Error($filecon.MessageObject.Exception)
            }
        }
    #�o�͐悪���[�J���t�H���_�̏ꍇ�A�t�H���_�쐬
    } else {
        [void](New-Item -ItemType Directory -Path $OutputPath -Force)
        $m_logger.Warn("�t�H���_�����݂��Ȃ����ߍ쐬 �����L�ݒ�͂��Ă��܂���I�B[{0}]" -f $OutputPath)
    }

    # �ŏI�`�F�b�N
    return (Test-Path $OutputPath)
}

### DB�ڑ��R�l�N�V�����쐬 ###
function newHiDBAccess()
{
    return [HiDBAccess.OracleControl]::new()
}

function CreateWorkFolder()
{
    try
    {
        $WorkBasePath = (Join-Path (Split-Path $PSScriptRoot -Parent) "Work")

        #�x�[�X�t�H���_��������΍쐬����
        [void](New-Item -ItemType Directory -Path $WorkBasePath -Force)

        #��Ɨp�t�H���_�iACCESSIONNUMBER + ���t�����t�H���_�j���쐬����
        $FolderName = $OutFileProperty.ACCESSIONNUMBER + "_" + (Get-Date -Format "yyyyMMddHHmmssfff")
        $OutFileProperty.WorkFolder = Join-Path $WorkBasePath $FolderName
        [void](New-Item -ItemType Directory -Path $OutFileProperty.WorkFolder -Force)

        return $true

    } catch {
        #�G���[�ڍ׏��ݒ�
        $ERRMSG = $ERROR[0] | Out-string
        #���O�o��
        $m_Logger.Error($ERRMSG)

        return $false

    } finally {
        #�Ȃ�
    }
}

#column�����擾����T���v��
#$columnNames=$odbcReader.GetSchemaTable() | Select-Object -ExpandProperty ColumnName
#foreach($h in $columnNames){
#    $h
#}

function SetCSVTargetList()
{
    try
    {
        $Sql = $getCSVTargetSQL
        # �o�C���h�ϐ��쐬
        $Dictionaly = [System.Collections.Generic.Dictionary[string, string]]::new()
        [void]$Dictionaly.Add("ACCESSIONNUMBER", $OutFileProperty.ACCESSIONNUMBER)
        $Param = "ACCESSIONNUMBER:[$($Dictionaly.ACCESSIONNUMBER)]"

        # �f�[�^�擾
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
            #CSVTarget�Ƀf�[�^���i�[
            $CSVTarget = [PSCustomObject]@{}
            foreach($colname in $columnNames){
                $CSVTarget | Add-Member -MemberType NoteProperty -Name $colname -Value ($Row.Item($colname) + "")
            }

            [void]$CSVTargetList.Add($CSVTarget)
        }

        return $true
    } catch {

        #�G���[�ڍ׏��ݒ�
        $ERRMSG = $ERROR[0] | Out-string
        #���O�o��
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
        # �f�[�^�擾SQL��
        $Sql = $getCSVDATA_SQL

        #CSV�^�[�Q�b�g��1�f�[�^�̂ݏ�������
        $CSVTarget = $CSVTargetList[0]

        #�t�@�C�����쐬
        $CSVFileName = (Split-Path -Leaf $OutFileProperty.WorkFolder) + ".csv"

        ### �f�[�^�擾 ###
        $DOCDATAUID = $CSVTarget.DOCDATAUID
        $TITLE = $CSVTarget.TITLE

        # �o�C���h�ϐ��쐬
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
            $m_Logger.Error("�o�͗p�f�[�^���擾�ł��܂���B" + `
                            "`r`n[Param] $($Param)"
                            )
            return $false
        }

        ### CSV�p�I�u�W�F�N�g�쐬 ###
        $CSVObject = [PSCustomObject]@{}

        # ���ʏ��ݒ�
        $ACCESSIONNUMBER = $OutFileProperty.ACCESSIONNUMBER
        $PATIENTID = $OutFileProperty.PATIENTID
        $STUDYDATE = $OutFileProperty.STUDYDATE

        $CSVObject | Add-Member -MemberType NoteProperty -Name "������" -Value $STUDYDATE
        $CSVObject | Add-Member -MemberType NoteProperty -Name "�I�[�_�[�ԍ�" -Value $ACCESSIONNUMBER
        $CSVObject | Add-Member -MemberType NoteProperty -Name "�lID" -Value $PATIENTID
        $CSVObject | Add-Member -MemberType NoteProperty -Name "���" -Value $TITLE
                
        # ���|�[�g�l���ݒ�
        Foreach($Row in $DataTable.Rows)
        {
            $key = $Row.CSVTITLE
            $value = $Row.CSVVALUE

            #����L�[��������ꍇ�́A���s����������
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

        ### CSV�o�� ###
        #CSV�p�I�u�W�F�N�g�̍��ڂ��擾�o�����ꍇ��CSV�o�͂���
        if(@($CSVObject.PSobject.Properties).Count -gt 0)
        {
            # CSV�o�͐�ݒ�
            $CSVWorkPath = (Join-Path $OutFileProperty.WorkFolder $CSVFileName)

            # CSV�o�͏���
            # �J���}��؂�A�����R�[�h:ShiftJIS
            $CSVObject | Export-Csv -delimiter "," -Encoding Default -NoTypeInformation -LiteralPath $CSVWorkPath

            $m_Logger.Debug("csv�t�@�C���쐬�F[" + $CSVWorkPath + "]")
        }

        $m_Logger.Info("CSV�쐬����")

        return $true

    } catch {

        #�G���[�ڍ׏��ݒ�
        $ERRMSG = $ERROR[0] | Out-string
        #���O�o��
        $m_Logger.Error("ACCESSIONNUMBER:[$($ACCESSIONNUMBER)] `r`n$ERRMSG")

        return $false

    } finally {
        #���ɂȂ�
    }
}

function SetImageList()
{
    try
    {
        $Sql = $getImageListSQL
        # �o�C���h�ϐ��쐬
        $Dictionaly = [System.Collections.Generic.Dictionary[string, string]]::new()
        [void]$Dictionaly.Add("ACCESSIONNUMBER", $OutFileProperty.ACCESSIONNUMBER)
        $Param = "ACCESSIONNUMBER:[$($Dictionaly.ACCESSIONNUMBER)]"

        # �f�[�^�擾
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
            #ImageTarget�Ƀf�[�^���i�[
            $ImageTarget = [PSCustomObject]@{}
            foreach($colname in $columnNames){
                $ImageTarget | Add-Member -MemberType NoteProperty -Name $colname -Value ($Row.Item($colname) + "")
            }

            [void]$ImageTargetList.Add($ImageTarget)
        }

        return $true
    } catch {

        #�G���[�ڍ׏��ݒ�
        $ERRMSG = $ERROR[0] | Out-string
        #���O�o��
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

        ### ���[�g�t�H���_�ڑ� ###
        if($ImageTargetList.Count -gt 0){

            #�摜���X�g��1�Ԗڂ̃f�[�^��胋�[�g�t�H���_�ڑ����擾
            $ImageTarget = $ImageTargetList[0]

            $ROOTPATHNAME = $ImageTarget.ROOTPATHNAME
            $USERNAME = $ImageTarget.USERNAME
            $PASSWORD = $ImageTarget.PASSWORD

            # ROOTPATH�̐ڑ��m�F
            $CONNECTLOG = "�摜�t�@�C�� ���[�g�t�H���_�ڑ��F[$($ROOTPATHNAME)] $($USERNAME) / *****"

            # �l�b�g���[�N�t�H���_�Őڑ��o���Ȃ��ꍇ
            if(!(Test-Path $ROOTPATHNAME) -and $ROOTPATHNAME.Substring(0,2) -eq "\\") {
                $filecon = GetFileCon
                # ���[�U�[�ƃp�X���[�h�Őڑ��������s
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
                #�ڑ��o���Ȃ��ꍇ�́A�����I��
                $m_Logger.WARN($CONNECTLOG)

                return $false
            } else {
                $m_Logger.DEBUG($CONNECTLOG)
            }

        }

        ### �摜�t�@�C���R�s�[ ###
        Foreach($ImageTarget in $ImageTargetList){

            # �摜�t�@�C���̎擾
            $FilePath = $ImageTarget.FILEPATH

            if(Test-Path $FilePath){
                $File = @(Get-ChildItem -Path $FilePath)
                $FileName = (Split-Path $OutFileProperty.WorkFolder -Leaf) + "_" +  ([string]($CopyCount + 1)) + ([System.IO.Path]::GetExtension($FilePath))
                $WorkFilePath = Join-Path $OutFileProperty.WorkFolder "$($FileName)"

                try
                {
                    #���[�N�t�H���_�Ƀt�@�C���R�s�[
                    $Message = "�摜�t�@�C���R�s�[:[$($File.FullName)]��[$($WorkFilePath)]"
                    [void](Copy-Item -LiteralPath $File.FullName -Destination $WorkFilePath -Force)

                    $m_Logger.DEBUG($Message)
                    $CopyCount += 1

                } catch {
                    #�G���[�ڍ׏��ݒ�
                    $ERRMSG = $ERROR[0] | Out-string
                    #���O�o��
                    $m_Logger.ERROR("$($Message) `r`n$ERRMSG")

                    continue
                }
            } else {
                #���O�o��
                $m_Logger.WARN("�摜�t�@�C�������݂��܂���B:[$($FilePath)]")
            }
        }

        if ($ImageList.Count -gt 0)
        {
            $ResultCount = "[$($CopyCount.ToString()) / $($ImageList.Count.ToString())]"

            if ($CopyCount -eq $ImageList.Count){
                $m_Logger.Info("�摜�t�@�C���R�s�[���� $($ResultCount)")
            } else {
                $m_Logger.WARN("�摜�t�@�C���R�s�[����(������) $($ResultCount)")

                return $false
            }
        }

        return $true

    } catch {

        #�G���[�ڍ׏��ݒ�
        $ERRMSG = $ERROR[0] | Out-string
        #���O�o��
        $m_Logger.ERROR($ERRMSG)

        return $false
    } finally {
        #���[�g�t�H���_�ؒf
        [void](GetFileCon).NetDisconnect($ROOTPATHNAME)
    }
}

function CopyWorkFolder()
{

    $IDXCount = 0
    $OKCount = 0

    try
    {
        # �^�C�~���O�t�@�C�����m
        Foreach($TimingFile in $TimingFileList){

            $IDXCount++
            $ResultFlg = $true

            # �����t�H���_�`�F�b�N
            $ResultPath = Join-Path (Split-Path -Path $TimingFile.FullName) ([System.IO.Path]::GetFileNameWithoutExtension($TimingFile.FullName))

            if(Test-Path $ResultPath){
                $target_path = Join-Path $OutputPath (Split-Path $ResultPath -Leaf)
                # �o�͐�Ƀt�H���_�����݂����ꍇ�A���g���ƍ폜
                if(Test-Path $target_path){
                    Remove-Item $target_path -Recurse
                }

                # ���ʃt�H���_�𒆐g���ƃR�s�[
                Copy-Item $ResultPath $target_path -Force -Recurse
                $m_Logger.DEBUG("($([string]$IDXCount))�A�g�t�H���_�o�� ��[$($target_path)]")

                # �^�C�~���O�t�@�C���쐬
                $TimingFilePath = Join-Path (Split-Path -Path $target_path) $TimingFile.Name
                [void](New-Item -Path $TimingFilePath -Force)
                $m_Logger.DEBUG("($([string]$IDXCount))�^�C�~���O�t�@�C���쐬 ��[$($TimingFilePath)]")

                #����R�s�[����+1
                $OKCount++

                # ���ʃt�H���_�����O�t�H���_�Ɉړ�
                $m_Logger.CopyToLogResultDir2($ResultPath, $true, $true)

            } else {
                $m_Logger.WARN("($([string]$IDXCount))�A�g�s�\ �^�C�~���O�t�@�C���̂�[$($TimingFile.FullName)]")
                $ResultFlg = $false
            }

            # �^�C�~���O�t�@�C�������O�t�H���_�Ɉړ�
            $m_Logger.CopyToLogResult($TimingFile, $ResultFlg, $true)

        }

        if($TimingFileList.Count -gt 0){
            $m_Logger.INFO("���ʘA�g����[$([string]$OKCount) / $([string]$TimingFileList.Count)]")
        }
        return $true

    } catch {

        #�G���[�ڍ׏��ݒ�
        $ERRMSG = $ERROR[0] | Out-string
        #���O�o��
        $m_Logger.ERROR($ERRMSG)

        return $false
    } finally {
        #�Ȃ�
    }
}

### ���O���� ###

#�쐬�����t�@�C�����ړ�
function MoveWorkFolder()
{
    try
    {
        $m_Logger.CopyToLogResultDir2($OutFileProperty.WorkFolder, $ResultFlg, $true)
        return $true
    } catch {

        #�G���[�ڍ׏��ݒ�
        $ERRMSG = $ERROR[0] | Out-string
        #���O�o��
        $m_Logger.ERROR($ERRMSG)

        return $false
    } finally {
        #�Ȃ�
    }
}

### �������e�X�g�p���� ###
function TEST-OUTPUTFOLDER()
{
    try
    {
      ### �o�̓t�H���_�m�F ###
        $TEST_filecon = GetFileCon
            
        Write-Host "##### �o�͐�t�H���_�e�X�g #####"
        #�o�͐悪�l�b�g���[�N�t�H���_�̏ꍇ�A�ڑ����o���Ȃ��ꍇ�͏I��
        if($OutputPath.Substring(0,2) -eq "\\") {
            #���L�t�H���_�ڑ�
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
            Write-Host "�o�͐�t�H���_OK:[$($OutputPath)]"
        } else {
            Write-Host "�o�͐�t�H���_NG:[$($OutputPath)]"
        }

    } catch {
        #�G���[�ڍ׏��ݒ�
        Write-Host $ERROR[0]
    } finally {
        [void]$TEST_filecon.NetDisconnect($OutputPath)
    }
}

function TEST-DBCONNECT()
{
    try
    {
      ### �f�[�^�x�[�X�ڑ��ݒ�(ODBC�ڑ�) ###
        $TEST_Oracle = newHiDBAccess

        Write-Host "##### DB�ڑ��e�X�g #####"

        if($TEST_Oracle.Connect($L_Oracle_ServiceName, $L_Oracle_uid, $L_Oracle_pwd))
        {
            Write-Host "DB�ڑ�OK:[$($TEST_Oracle.Connection.ConnectionString)]"
        } else {
            Write-Host "DB�ڑ�NG:[$($TEST_Oracle.Connection.ConnectionString)] $($TEST_Oracle.ErrMessage)"
        }

    } catch {
        #�G���[�ڍ׏��ݒ�
        Write-Host $ERROR[0]
    } finally {
        [void]$TEST_Oracle.DisConnect
    }
}
