Set-StrictMode -Version 2.0
Set-Location -Path $PSScriptRoot

#設定ファイル読込
.(".\Setting.ps1")
#メイン部品読込
.(".\MainParts.ps1")

TEST-OUTPUTFOLDER
TEST-DBCONNECT

#アセンブリ一覧表示
[System.AppDomain]::CurrentDomain.GetAssemblies()
