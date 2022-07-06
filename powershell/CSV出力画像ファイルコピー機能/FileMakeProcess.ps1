#����
Param(
    [string] $ACCESSIONNUMBER, #�I�[�_�[�ԍ�
    [string] $PATIENTID,       #����ID
    [string] $STUDYDATE        #������
)

Set-StrictMode -Version 2.0
Set-Location -Path $PSScriptRoot

#�ݒ�t�@�C���Ǎ�
.(".\Setting.ps1")
#���C�����i�Ǎ�
.(".\MainParts.ps1")

#���O������
$m_Logger = GetLogger $LogDir $LogLevel $LogKeepDays
$m_Logger.PreFix = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
#�R���\�[���o�͗L��Ƃ���
$m_Logger.ConsoleOut = $true

### �����`�F�b�N ###
$strParam = "<����> �I�[�_�[�ԍ�:[{0}] ����ID:[{1}] ������[{2}]" -f $ACCESSIONNUMBER, $PATIENTID, $STUDYDATE
if(-not(ParamCheck))
{
    exit
}

### �����J�n ###
try {
    $ProcessResult = "�A�g:������"
    $ResultFlg = $false
    $OutFileProperty = @{
        ACCESSIONNUMBER = $ACCESSIONNUMBER;
        PATIENTID = $PATIENTID;
        STUDYDATE = $STUDYDATE;
        WorkFolder = "";
    }

  ### ���s�J�n���O�o��
    $m_logger.Info("��--- START --- {0}" -f $strParam)

  ### �f�[�^�x�[�X�ڑ��ݒ�(ODBC�ڑ�) ###
    $Oracle = newHiDBAccess

    if(-not($Oracle.Connect($L_Oracle_ServiceName, $L_Oracle_uid, $L_Oracle_pwd)))
    {
        $m_Logger.Error("DB�ڑ�NG:[$($Oracle.Connection.ConnectionString)] $($Oracle.ErrMessage)")
        exit
    }

    $m_Logger.Info("DB�ڑ�OK:[" + $Oracle.Connection.ConnectionString + "]")

  ### �m�背�|�[�g�Ώێ擾 ###
    $ProcAdd = "CSV�쐬�Ώێ擾 "
    $CSVTarget = [PSCustomObject]@{}
    $CSVTargetList = [System.Collections.ArrayList]::new()
    $ResultFlg = SetCSVTargetList
    if(-not($ResultFlg)) {
        $ProcessResult = $ProcAdd + "[���s]"
        exit
    }

    # �쐬�Ώۃf�[�^���݃`�F�b�N
    if($CSVTargetList.Count -eq 0)
    {
        $m_Logger.Info("�A�g�Ώۃf�[�^����")
        exit
    }

  ### ���[�N�t�H���_�쐬 ###
    $ProcAdd = "���[�N�t�H���_�쐬 "
    $ResultFlg = CreateWorkFolder
    if(-not($ResultFlg))
    {
        $ProcessResult = $ProcAdd + "[���s]"
        exit
    }

  ### ���[�N�t�H���_��CSV�t�@�C���쐬 ###
    $ProcAdd = "CSV�쐬(work) "
    $ResultFlg = CreateCSVFile
    if(-not($ResultFlg)) {
        $ProcessResult = $ProcAdd + "[���s]"
        exit
    }

  ### ���[�N�t�H���_�ɉ摜�t�@�C���R�s�[ ###

    # �摜�t�@�C���R�s�[�Ώێ擾
    $ProcAdd = "�摜�t�@�C���R�s�[�Ώێ擾 "
    $ImageList = [System.Collections.ArrayList]::new()
    $ImageTarget = [PSCustomObject]@{}
    $ImageTargetList = [System.Collections.ArrayList]::new()

    $ResultFlg = SetImageList
    if(-not($ResultFlg)) {
        $ProcessResult = $ProcAdd + "[���s]"
        exit
    }

    # �摜�t�@�C�����X�g���݃`�F�b�N
    if($ImageList.Count -eq 0)
    {
        $m_Logger.Info("�A�g�Ώۉ摜�Ȃ�")
        # �I�����Ȃ�
        # exit
    } else {
        # ���[�N�t�H���_�ɉ摜�t�@�C���R�s�[
        $ProcAdd = "�摜�t�@�C���R�s�[(work) "
        $LogOutputCount = 0

        while($true){
            $ResultFlg = CopyImageFile
            if($ResultFlg) {
                break
            }
            if($ImageRetryCount -gt 0){
                $LogOutputCount++
                $m_Logger.WARN($ProcAdd + " ���g���C���܂�($([string]$LogOutputCount)���)")

                $ImageRetryCount--
                Start-Sleep -Milliseconds $ImageRetryWait
            } else {
                break
            }
        }

        if(-not($ResultFlg)) {
            $ProcessResult = $ProcAdd + "[���s]"
            exit
        }
    }

  ### �^�C�~���O�t�@�C���쐬 ###
    $ProcAdd = "�^�C�~���O�t�@�C���쐬"
    $TimingFilePath = (Join-Path (Split-Path -Path $OutFileProperty.WorkFolder) (Split-Path $OutFileProperty.WorkFolder -Leaf)) + "." + $TimingFileExtension

    #�^�C�~���O�t�@�C���쐬
    [void](New-Item -Path $TimingFilePath -Force)
    $ProcessResult = $ProcAdd + "[����]"
    $m_Logger.INFO("�^�C�~���O�t�@�C���쐬 ��[$($TimingFilePath)]")

    exit

} catch {

    #�G���[�ڍ׏��ݒ�
    $ERRMSG = $ERROR[0] | Out-string
    #���O�o��
    $m_Logger.Error($ERRMSG)

    $ProcessResult = $ProcAdd + "[���s]"

    $ResultFlg = $false

} finally {

    #�G���[�������́A���O�t�H���_�Ɉړ�
    if(!$ResultFlg){
        MoveWorkFolder
        if($OutFileProperty.WorkFolder -ne ""){
            $m_Logger.ERROR("�������~�̂��߁ANG�t�H���_�Ɉړ��F��[$($OutFileProperty.WorkFolder)]")
        }
    }

    #DB�ؒf
    if($Oracle -ne $null)
    {
        $Oracle.Disconnect()
    }

    #���s�I�����O�o��
    $m_Logger.Info("��--- END --- " + $ProcessResult)

    #�A�g�p�t�H���_�ւ̑��M(�R�s�[)�������s
    .\FileSendProcess.ps1
}