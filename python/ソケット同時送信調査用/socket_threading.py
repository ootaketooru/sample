import socket
import time
import datetime
import threading

event = threading.Event()
# サーバーとの通信に使うポート番号（サーバーと共有）
PORT = 15001
cliesock1 = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
cliesock2 = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

def sleeptime():
    time1 = datetime.datetime.now()
    time2 = time1 + datetime.timedelta(minutes=1)
    time2 = "{0:%Y/%m/%d %H:%M:00.000}".format(time2)
    time2 = datetime.datetime.strptime(time2, '%Y/%m/%d %H:%M:00.000')
    return time2 - time1

def a():
    # 送信データ
    data = bytes('test1-1  01  username  03 userprofile1   userprofile2   userprofile3   requestuser  requesttime                           EOF'.encode("shift-jis"))

    # 送信タイミング調整(次分の直後に実行する)
    td = sleeptime()
    print(td.total_seconds())
    time.sleep(td.total_seconds())

    # サーバーにデータを送信する
    cliesock1.connect((socket.gethostname(), PORT))
    cliesock1.send(data)
    # サーバーからデータを受信する
    data = cliesock1.recv(1024)
    print(data)
    # ソケットを閉じる
    cliesock1.close()

def b():
    # 送信データ
    data = bytes('test1-2  03  username  05 userprofile1   userprofile2   userprofile3   userprofile4   userprofile5   requestuser  requesttime                           EOF'.encode("shift-jis"))

    # 送信タイミング調整(次分の直後に実行する)
    td2 = sleeptime()
    print(td2.total_seconds())
    time.sleep(td2.total_seconds())

    # サーバーにデータを送信する
    cliesock2.connect((socket.gethostname(), PORT))
    cliesock2.send(data)
    # サーバーからデータを受信する
    data = cliesock2.recv(1024)
    print(data)
    # ソケットを閉じる
    cliesock2.close()

#ソケット同時送信実行
th1 = threading.Thread(target=a)
th2 = threading.Thread(target=b)

th1.start()
th2.start()
th1.join()
th2.join()