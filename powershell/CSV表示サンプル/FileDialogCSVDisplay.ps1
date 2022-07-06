#------------------------------------------------
# 処理名：Fn_OpenFile()
# 概　要：ファイルを開くダイアログを表示する　
# 引　数：なし
# 戻り値：ファイル名フルパス
#------------------------------------------------
Function Fn_OpenFile(){
    
    #アセンブリのロード
    Add-Type -AssemblyName System.Windows.Forms

    #ダイアログインスタンス生成
    $dialog = New-Object Windows.Forms.OpenFileDialog
    
    #タイトル、選択可能ファイル拡張子、初期ディレクトリ
    $dialog.Title = "ファイルを選んでくれ！"
    $dialog.Filter = "CSVファイル(*.csv)|*.csv"
    $dialog.InitialDirectory = "C:\hoge\CSV"

    #ダイアログ表示
    $result = $dialog.ShowDialog()

    #「開くボタン」押下ならファイル名フルパスをリターン
    If($result -eq "OK"){
        $file = $dialog.FileName
        $dialog.Dispose()
        Return $file
    }Else{
        $dialog.Dispose()
        Break
    }
}

#ファイル取得
$file = Fn_OpenFile

#CSVファイルを読み込んでグリッド出力する
Import-CSV $file  -Encoding Default | Out-GridView -PassThru -Title "CSVSample"

#Read-Host "×ボタンで終了"