Set-StrictMode -Version 2.0
Set-Location -Path $PSScriptRoot

#�ݒ�t�@�C���Ǎ�
.(".\Setting.ps1")
#���C�����i�Ǎ�
.(".\MainParts.ps1")

TEST-OUTPUTFOLDER
TEST-DBCONNECT

#�A�Z���u���ꗗ�\��
[System.AppDomain]::CurrentDomain.GetAssemblies()
