#------------------------------------------------
# �������FFn_OpenFile()
# �T�@�v�F�t�@�C�����J���_�C�A���O��\������@
# ���@���F�Ȃ�
# �߂�l�F�t�@�C�����t���p�X
#------------------------------------------------
Function Fn_OpenFile(){
    
    #�A�Z���u���̃��[�h
    Add-Type -AssemblyName System.Windows.Forms

    #�_�C�A���O�C���X�^���X����
    $dialog = New-Object Windows.Forms.OpenFileDialog
    
    #�^�C�g���A�I���\�t�@�C���g���q�A�����f�B���N�g��
    $dialog.Title = "�t�@�C����I��ł���I"
    $dialog.Filter = "CSV�t�@�C��(*.csv)|*.csv"
    $dialog.InitialDirectory = "C:\hoge\CSV"

    #�_�C�A���O�\��
    $result = $dialog.ShowDialog()

    #�u�J���{�^���v�����Ȃ�t�@�C�����t���p�X�����^�[��
    If($result -eq "OK"){
        $file = $dialog.FileName
        $dialog.Dispose()
        Return $file
    }Else{
        $dialog.Dispose()
        Break
    }
}

#�t�@�C���擾
$file = Fn_OpenFile

#CSV�t�@�C����ǂݍ���ŃO���b�h�o�͂���
Import-CSV $file  -Encoding Default | Out-GridView -PassThru -Title "CSVSample"

#Read-Host "�~�{�^���ŏI��"