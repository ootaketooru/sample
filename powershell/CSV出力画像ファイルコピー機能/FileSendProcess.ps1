#�����Ȃ�
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

try {
    $StartFlg = $false

  ### �^�C�~���O�t�@�C���m�F
    $WorkBasePath = (Join-Path (Split-Path $PSScriptRoot -Parent) "Work")
    $TimingFileList = @(Get-ChildItem $WorkBasePath -Filter "*.idx")

    #�^�C�~���O�t�@�C���������ꍇ�́A�����I��
    if($TimingFileList.Count -eq 0){
        $m_Logger.DEBUG("�^�C�~���O�t�@�C��0�� �����I��:[$($WorkBasePath)]")
        exit
    }

  ### ���s�J�n���O�o��
    $m_logger.Info("��--- START --- ")
    $StartFlg = $true

  ### �o�̓t�H���_�m�F ###
    $ProcAdd = "�o�̓t�H���_�ڑ�"
    if (CheckOutputFolder) {
        $m_Logger.Info("�o�̓t�H���_�ڑ�OK:[$($OutputPath)] user:[$($OutputUsername)]")
        $ProcessResult = $ProcAdd + "[����]"
    } else {
        $m_Logger.Error("�o�̓t�H���_�ڑ��G���[:[$($OutputPath)] user:[$($OutputUsername)]")
        $ProcessResult = $ProcAdd + "[���s]"
        exit
    }

  ### �A�g��Ƀt�H���_�R�s�[(�^�C�~���O�t�@�C���쐬) ###
    $ProcAdd = "�A�g�t�H���_�R�s�[ "
    $ResultFlg = CopyWorkFolder
    if(-not($ResultFlg)) {
        $ProcessResult = $ProcAdd + "[���s]"
        exit
    }

    $ProcessResult = $ProcAdd + "[����]"
    exit

} catch {

    #�G���[�ڍ׏��ݒ�
    $ERRMSG = $ERROR[0] | Out-string
    #���O�o��
    $m_Logger.Error($ERRMSG)

} finally {

    if($StartFlg){
        #�t�H���_�ؒf
        [void](GetFileCon).NetDisconnect($OutputPath)

        #���s�I�����O�o��
        $m_Logger.Info("��--- END --- " + $ProcessResult)
    }
}