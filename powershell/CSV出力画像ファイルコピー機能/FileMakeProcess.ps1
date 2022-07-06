#引数
Param(
    [string] $ACCESSIONNUMBER, #オーダー番号
    [string] $PATIENTID,       #患者ID
    [string] $STUDYDATE        #検査日
)

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

### 引数チェック ###
$strParam = "<引数> オーダー番号:[{0}] 患者ID:[{1}] 検査日[{2}]" -f $ACCESSIONNUMBER, $PATIENTID, $STUDYDATE
if(-not(ParamCheck))
{
    exit
}

### 処理開始 ###
try {
    $ProcessResult = "連携:未処理"
    $ResultFlg = $false
    $OutFileProperty = @{
        ACCESSIONNUMBER = $ACCESSIONNUMBER;
        PATIENTID = $PATIENTID;
        STUDYDATE = $STUDYDATE;
        WorkFolder = "";
    }

  ### 実行開始ログ出力
    $m_logger.Info("▼--- START --- {0}" -f $strParam)

  ### データベース接続設定(ODBC接続) ###
    $Oracle = newHiDBAccess

    if(-not($Oracle.Connect($L_Oracle_ServiceName, $L_Oracle_uid, $L_Oracle_pwd)))
    {
        $m_Logger.Error("DB接続NG:[$($Oracle.Connection.ConnectionString)] $($Oracle.ErrMessage)")
        exit
    }

    $m_Logger.Info("DB接続OK:[" + $Oracle.Connection.ConnectionString + "]")

  ### 確定レポート対象取得 ###
    $ProcAdd = "CSV作成対象取得 "
    $CSVTarget = [PSCustomObject]@{}
    $CSVTargetList = [System.Collections.ArrayList]::new()
    $ResultFlg = SetCSVTargetList
    if(-not($ResultFlg)) {
        $ProcessResult = $ProcAdd + "[失敗]"
        exit
    }

    # 作成対象データ存在チェック
    if($CSVTargetList.Count -eq 0)
    {
        $m_Logger.Info("連携対象データ無し")
        exit
    }

  ### ワークフォルダ作成 ###
    $ProcAdd = "ワークフォルダ作成 "
    $ResultFlg = CreateWorkFolder
    if(-not($ResultFlg))
    {
        $ProcessResult = $ProcAdd + "[失敗]"
        exit
    }

  ### ワークフォルダにCSVファイル作成 ###
    $ProcAdd = "CSV作成(work) "
    $ResultFlg = CreateCSVFile
    if(-not($ResultFlg)) {
        $ProcessResult = $ProcAdd + "[失敗]"
        exit
    }

  ### ワークフォルダに画像ファイルコピー ###

    # 画像ファイルコピー対象取得
    $ProcAdd = "画像ファイルコピー対象取得 "
    $ImageList = [System.Collections.ArrayList]::new()
    $ImageTarget = [PSCustomObject]@{}
    $ImageTargetList = [System.Collections.ArrayList]::new()

    $ResultFlg = SetImageList
    if(-not($ResultFlg)) {
        $ProcessResult = $ProcAdd + "[失敗]"
        exit
    }

    # 画像ファイルリスト存在チェック
    if($ImageList.Count -eq 0)
    {
        $m_Logger.Info("連携対象画像なし")
        # 終了しない
        # exit
    } else {
        # ワークフォルダに画像ファイルコピー
        $ProcAdd = "画像ファイルコピー(work) "
        $LogOutputCount = 0

        while($true){
            $ResultFlg = CopyImageFile
            if($ResultFlg) {
                break
            }
            if($ImageRetryCount -gt 0){
                $LogOutputCount++
                $m_Logger.WARN($ProcAdd + " リトライします($([string]$LogOutputCount)回目)")

                $ImageRetryCount--
                Start-Sleep -Milliseconds $ImageRetryWait
            } else {
                break
            }
        }

        if(-not($ResultFlg)) {
            $ProcessResult = $ProcAdd + "[失敗]"
            exit
        }
    }

  ### タイミングファイル作成 ###
    $ProcAdd = "タイミングファイル作成"
    $TimingFilePath = (Join-Path (Split-Path -Path $OutFileProperty.WorkFolder) (Split-Path $OutFileProperty.WorkFolder -Leaf)) + "." + $TimingFileExtension

    #タイミングファイル作成
    [void](New-Item -Path $TimingFilePath -Force)
    $ProcessResult = $ProcAdd + "[完了]"
    $m_Logger.INFO("タイミングファイル作成 ⇒[$($TimingFilePath)]")

    exit

} catch {

    #エラー詳細情報設定
    $ERRMSG = $ERROR[0] | Out-string
    #ログ出力
    $m_Logger.Error($ERRMSG)

    $ProcessResult = $ProcAdd + "[失敗]"

    $ResultFlg = $false

} finally {

    #エラー発生時は、ログフォルダに移動
    if(!$ResultFlg){
        MoveWorkFolder
        if($OutFileProperty.WorkFolder -ne ""){
            $m_Logger.ERROR("処理中止のため、NGフォルダに移動：⇒[$($OutFileProperty.WorkFolder)]")
        }
    }

    #DB切断
    if($Oracle -ne $null)
    {
        $Oracle.Disconnect()
    }

    #実行終了ログ出力
    $m_Logger.Info("▲--- END --- " + $ProcessResult)

    #連携用フォルダへの送信(コピー)処理実行
    .\FileSendProcess.ps1
}