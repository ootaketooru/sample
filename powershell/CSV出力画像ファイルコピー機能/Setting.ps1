### DB接続設定 ###
$L_Oracle_ServiceName      = "service"
$L_Oracle_uid              = "user"
$L_Oracle_pwd              = "password"

### LOG定義 ###
#■ログフォルダ
$LogDir = "D:\Logs\sample"
#■ログレベル
#0：デバッグ < 1：情報 < 2：警告 < 3：エラー < 4：致命的
#設定レベルより下位のレベルのログは表示されません。
$LogLevel = 0
#■ログ保存期間
#新規日付ログ作成時に、指定日時を過ぎたログファイルを削除します
#0以下を指定した場合、過去日付のログ削除を行いません
$LogKeepDays = 90

### ファイル出力定義 ###

# ファイル出力先 #
$OutputPath = "D:\work\Output"
$OutputUsername = ""
$OutputPassword = ""

#タイミングファイル拡張子
$TimingFileExtension = "idx"

#リトライ回数(画像ファイルのみリトライする)
$ImageRetryCount = 3
$ImageRetryWait = 1000 #ミリ秒

#CSV出力対象取得SQL
$getCSVTargetSQL = @"
SELECT
 a2.DOCDATAUID
 ,a2.TITLE
FROM
 DSCHEDULE a1
INNER JOIN
 DREGISTDOCUMENT a2
ON
 a1.ACCESSIONNUMBER = a2.ACCESSIONNUMBER
 AND a1.PATIENTID = a2.PATIENTID
 AND a1.SERIESINSTANCEUID = a2.SERIESINSTANCEUID
WHERE
 a1.ACCESSIONNUMBER = :ACCESSIONNUMBER
"@

#CSVデータ取得SQL
$getCSVDATA_SQL = @"
SELECT
 a0.TITLE
 ,a0.ITEMCAPTION
 ,a0.CSVSEQ
 ,a0.CSVTITLE
 ,a1.ITEMVALUE CSVVALUE
FROM
 MOUTPUTCSV a0
LEFT JOIN
 DREGISTDOCUMENTITEM a1
ON
 a1.DOCDATAUID = :DOCDATAUID
 AND a0.ITEMCAPTION = a1.ITEMCAPTION
WHERE
 a0.TITLE = :TITLE
ORDER BY
 a0.CSVSEQ
"@

#画像ファイル拡張子
$ImageFileExtension = "jpg"

#画像ファイル取得SQL
$getImageListSQL = @"
select
 a1.ACCESSIONNUMBER
 ,a1.SERIESINSTANCEUID
 ,a1.ROOTPATHNAME
 ,a1.USERNAME
 ,a1.PASSWORD
 ,a1.ROOTPATHNAME || a1.IMAGELOCATION || SUBSTR(a2.FILENAME, 1, LENGTH(a2.FILENAME) - INSTR(REVERSE(a2.FILENAME), '.')) || '.' || '$($ImageFileExtension)' FILEPATH
from
 (
	select
	 a1.ACCESSIONNUMBER
	 ,a2.SERIESINSTANCEUID
	 ,a3.ROOTPATHCODE
	 ,a3.ROOTPATHNAME
	 ,a3.ROOTPATHLOCAL
     ,a3.USERNAME
     ,a3.PASSWORD
	 ,a2.IMAGELOCATION
	from
	 DSCHEDULE a1
	inner join
	 DSERIES a2
	on
	 a1.SERIESINSTANCEUID = a2.SERIESINSTANCEUID
	inner join
	 MROOTPATH a3
	on
	 a2.ROOTPATHCODE = a3.ROOTPATHCODE
	where
	 a1.ACCESSIONNUMBER = :ACCESSIONNUMBER
 ) a1
inner join
 DIMAGE a2
on
 a1.SERIESINSTANCEUID = a2.SERIESINSTANCEUID
where
 a2.IMAGEFLAG like 'R:%'
order by
 TO_NUMBER(IMAGENUMBER)
"@