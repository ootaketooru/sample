### DB�ڑ��ݒ� ###
$L_Oracle_ServiceName      = "service"
$L_Oracle_uid              = "user"
$L_Oracle_pwd              = "password"

### LOG��` ###
#�����O�t�H���_
$LogDir = "D:\Logs\sample"
#�����O���x��
#0�F�f�o�b�O < 1�F��� < 2�F�x�� < 3�F�G���[ < 4�F�v���I
#�ݒ背�x����艺�ʂ̃��x���̃��O�͕\������܂���B
$LogLevel = 0
#�����O�ۑ�����
#�V�K���t���O�쐬���ɁA�w��������߂������O�t�@�C�����폜���܂�
#0�ȉ����w�肵���ꍇ�A�ߋ����t�̃��O�폜���s���܂���
$LogKeepDays = 90

### �t�@�C���o�͒�` ###

# �t�@�C���o�͐� #
$OutputPath = "D:\work\Output"
$OutputUsername = ""
$OutputPassword = ""

#�^�C�~���O�t�@�C���g���q
$TimingFileExtension = "idx"

#���g���C��(�摜�t�@�C���̂݃��g���C����)
$ImageRetryCount = 3
$ImageRetryWait = 1000 #�~���b

#CSV�o�͑Ώێ擾SQL
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

#CSV�f�[�^�擾SQL
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

#�摜�t�@�C���g���q
$ImageFileExtension = "jpg"

#�摜�t�@�C���擾SQL
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