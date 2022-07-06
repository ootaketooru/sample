#引数なし
Set-StrictMode -Version 2.0
Set-Location -Path $PSScriptRoot

#設定ファイル読込
.(".\Setting.ps1")
#メイン部品読込
.(".\MainParts.ps1")

#ログ初期化
$m_Logger = GetLogger $LogDir $LogLevel $LogKeepDays
$m_Logger.PreFix = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
#コンソール出力有りとする
$m_Logger.ConsoleOut = $true

try {
    $StartFlg = $false

  ### タイミングファイル確認
    $WorkBasePath = (Join-Path (Split-Path $PSScriptRoot -Parent) "Work")
    $TimingFileList = @(Get-ChildItem $WorkBasePath -Filter "*.idx")

    #タイミングファイルが無い場合は、処理終了
    if($TimingFileList.Count -eq 0){
        $m_Logger.DEBUG("タイミングファイル0件 処理終了:[$($WorkBasePath)]")
        exit
    }

  ### 実行開始ログ出力
    $m_logger.Info("▼--- START --- ")
    $StartFlg = $true

  ### 出力フォルダ確認 ###
    $ProcAdd = "出力フォルダ接続"
    if (CheckOutputFolder) {
        $m_Logger.Info("出力フォルダ接続OK:[$($OutputPath)] user:[$($OutputUsername)]")
        $ProcessResult = $ProcAdd + "[完了]"
    } else {
        $m_Logger.Error("出力フォルダ接続エラー:[$($OutputPath)] user:[$($OutputUsername)]")
        $ProcessResult = $ProcAdd + "[失敗]"
        exit
    }

  ### 連携先にフォルダコピー(タイミングファイル作成) ###
    $ProcAdd = "連携フォルダコピー "
    $ResultFlg = CopyWorkFolder
    if(-not($ResultFlg)) {
        $ProcessResult = $ProcAdd + "[失敗]"
        exit
    }

    $ProcessResult = $ProcAdd + "[完了]"
    exit

} catch {

    #エラー詳細情報設定
    $ERRMSG = $ERROR[0] | Out-string
    #ログ出力
    $m_Logger.Error($ERRMSG)

} finally {

    if($StartFlg){
        #フォルダ切断
        [void](GetFileCon).NetDisconnect($OutputPath)

        #実行終了ログ出力
        $m_Logger.Info("▲--- END --- " + $ProcessResult)
    }
}