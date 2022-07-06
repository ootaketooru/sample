# Porwershell 開発留意事項

- [void] を多用している理由
    - powershellの戻り値は、returnで返した値だけにならない。
    - 戻り値のある関数を変数に代入しない場合、上位の呼び出し元にも戻り値として返してしまう。
    - 他の対応方法 {処理 | Out-Null} / {$null = 処理} / {処理 > $null}

    void無しの場合(意図しない戻り値が含まれる)

    ```powershell
        function sample
        {
            return 'output-sample'
        }

        function returnTEST
        {

            # void無し実行
            sample

            $a = 1 + 2

            return $a
        }

        #処理実行
        $result = returnTEST
        Write-Host $result

        #戻り値の結果
        output-sample 3
    ```

    voidありの場合(呼び出し元に返さない)
    ```powershell
        function sample
        {
            return 'output-sample'
        }

        function returnTEST
        {

            # voidあり実行
            [void]sample

            $a = 1 + 2

            return $a
        }

        #処理実行
        $result = returnTEST
        Write-Host $result

        #戻り値の結果
        3
    ```
