; -----------------------------------------------------------------------------
; 組合語言期末專題 - Video2Ascii
;
; Authors:
; 廖健棚 A1085508
; 林嘉軒 A1085512
; 谷傳恩 A1085519
; 藍哲綸 A1085521
; 謝卓均 A1085540
;
; Info:
; 讀取影片 (連續圖片檔案) 並轉換輸出成 ASCII 圖像
; 圖片檔案名稱應該依照規定編號 0000.bmp ~ 9999.bmp
; 將所有檔案儲存在 ./frames 資料夾下
; 重要：圖片寬度應為 4 的倍數！
;
; 讀取背景音樂
; 將背景音樂放置於 ./audios 資料夾下
; 並命名為 bgm.wav
; 重要：音效應為 WAV 格式
;
; 可以選擇是否要開啟圖片比例調整功能
; 設定 enableResize (預設為TRUE)
; -----------------------------------------------------------------------------

INCLUDE Irvine32.inc
INCLUDE Macros.inc
INCLUDELIB Winmm.lib

; PlaySound 函式定義
PlaySound PROTO,
    pszSound: PTR BYTE,
    hmod: DWORD,
    fdwSound: DWORD

.data
; 讀取控制台資訊相關變數
consoleInfo CONSOLE_SCREEN_BUFFER_INFO <>
outputHandle HANDLE 0
consoleRowSize DWORD ?
consoleColumnSize DWORD ?

; 控制台視窗大小參數
; SMALL_RECT <左, 上, 右, 下>
windowRect SMALL_RECT <0, 0, 128, 39>

; 背景音效相關變數
audioPath BYTE "audios/bgm.wav", 0

; 圖片相關變數
imagePath BYTE "frames/0000.bmp", 0
fileHandle HANDLE ?
fileType BYTE 2 DUP(?), 0
fileSize DWORD ?
dataOffset WORD ?
imageWidth DWORD ?
imageHeight DWORD ?
imageSize DWORD ?
buffer DWORD ?
; TODO: 動態配置，定義上限值
byteArray BYTE 20000 DUP(?), 0
totalFrames DWORD 2791

; 字串常數
consoleTitle BYTE "VideoToAscii", 0
asciiArray BYTE ".,:;+*?%$#@", 0

; 圖像比例調整相關
enableResize BYTE 1
grayArray BYTE 20000 DUP(?)
newGrayArray BYTE 20000 DUP(0)
newByteArray BYTE 30000 DUP(0), 0

.code
main PROC
; -----------------------------------------------------------------------------
; 取得控制台顯示視窗長寬 (該部分功能最後沒有用上)
; 呼叫 GetConsoleScreenBufferInfo() 取得 consoleInfo
; consoleRowSize = consoleInfo.srWindow.Bottom - consoleInfo.srWindow.Top
; consoleColumnSize = consoleInfo.srWindow.Right - consoleInfo.srWindow.Left
; 實際大小應該還要再 + 1 (可依狀況調整)

INVOKE GetStdHandle, STD_OUTPUT_HANDLE
; EAX 已存入從上面指令取得之 StdHandle
mov outputHandle, eax
INVOKE GetConsoleScreenBufferInfo, outputHandle, ADDR consoleInfo

movzx eax, consoleInfo.srWindow.Bottom
movzx ebx, consoleInfo.srWindow.Top
sub eax, ebx
inc eax
mov consoleRowSize, eax

movzx eax, consoleInfo.srWindow.Right
movzx ebx, consoleInfo.srWindow.Left
sub eax, ebx
mov consoleColumnSize, eax

; -----------------------------------------------------------------------------
; 設定控制台標題
INVOKE SetConsoleTitle, ADDR consoleTitle

; -----------------------------------------------------------------------------
; 設定控制台視窗大小
INVOKE SetConsoleWindowInfo,
    outputHandle,
    TRUE,
    ADDR windowRect

; -----------------------------------------------------------------------------
; 播放背景音效
; 函式用法 PlaySound(檔案位置, NULL,模式)
; 模式 SND_FILENAME | SND_ASYNC 代碼為 20001H
INVOKE PlaySound, OFFSET audioPath, 0h, 20001h

; -----------------------------------------------------------------------------
; 連續讀取畫面
; 呼叫 displayFrame 程序來讀取一個圖像 (Frame)
; 修改讀取的檔案路徑，來改變下次進入迴圈讀取的圖像
mov ecx, totalFrames
lp_frames:
    ; 變數空間歸零
    push ecx
    mov ecx, 30000
    lp_reset:
        push ecx
        dec ecx
        mov [newGrayArray + ecx], 0
        pop ecx
    loop lp_reset
    pop ecx

    ; 呼叫 displayFrame 顯示圖像
    pushad
    call displayFrame
    popad

    ; 利用迴圈數 (ECX) 轉成圖片編號，再轉成檔案路徑
    ; ESI 初始值為 7，移動到圖片路徑 (imagePath) 之編號位置
    ; totalFrames - ECX = 需要讀取的檔案編號
    mov esi, 7
    mov eax, totalFrames
    sub eax, ecx

    ; 透過 DIV 取商數和餘數，來解析各個位數
    ; 最後轉為字元存到圖片路徑
    push ecx
    mov edx, 0
    mov ecx, 1000
    div ecx
    add eax, 48
    mov [imagePath + esi], al
    inc esi

    mov eax, edx
    mov edx, 0
    mov ecx, 100
    div ecx
    add eax, 48
    mov [imagePath + esi], al
    inc esi

    mov eax, edx
    mov edx, 0
    mov ecx, 10
    div ecx
    add eax, 48
    mov [imagePath + esi], al
    inc esi

    add edx, 48
    mov [imagePath + esi], dl
    pop ecx
loop lp_frames

quit::
; -----------------------------------------------------------------------------
; 停止背景音效
INVOKE PlaySound, 0h, 0h, 0h
exit
main ENDP

displayFrame PROC
; -----------------------------------------------------------------------------
; 讀取 BMP 檔案
; 使用 Irvine32 Library 函式呼叫

mov edx, OFFSET imagePath
; 開啟檔案: (參數) EDX = 圖片位置 / (回傳) EAX = FileHandle
call OpenInputFile
; 若無法成功開啟檔案，擲回 INVALID_HANDLE_VALUE 到 EAX
cmp eax, INVALID_HANDLE_VALUE
; 當條件不相等時跳轉 (jump-if-not-equal)
jne file_ok

; 顯示錯誤警告
file_error:
    mWrite <"ERROR: Failed to open the image!", 10, 0>
    jmp quit

; 成功開啟檔案
file_ok:
    mov fileHandle, eax

; 讀取資料: (參數) EAX = FileHandle
;                ECX = 讀取位元組數量
;                EDX = 緩衝區
;         (回傳) EAX = 讀取位元組數量，錯誤則擲回錯誤代碼

; 讀取檔案格式
mov eax, fileHandle
mov ecx, 2
mov edx, OFFSET fileType
call ReadFromFile

; 讀取檔案大小
mov eax, fileHandle
mov ecx, 4
mov edx, OFFSET fileSize
call ReadFromFile

; 增加 4 Bytes 偏移量
INVOKE SetFilePointer,
    fileHandle,
    4,
    0,
    FILE_CURRENT

; 讀取資料偏移位元組數
mov eax, fileHandle
mov ecx, 1
mov edx, OFFSET dataOffset
call ReadFromFile

; 增加 7 Bytes 偏移量
INVOKE SetFilePointer,
    fileHandle,
    7,
    0,
    FILE_CURRENT

; 讀取圖片寬度
mov eax, fileHandle
mov ecx, 4
mov edx, OFFSET imageWidth
call ReadFromFile

; 讀取圖片高度
mov eax, fileHandle
mov ecx, 4
mov edx, OFFSET imageHeight
call ReadFromFile

; 計算圖片像素數量
; imageSize = imageWidth * imageHeight
mov eax, imageWidth
mov ebx, imageHeight
mul ebx
mov imageSize, eax

; 增加 { dataOffset } Bytes 偏移量
INVOKE SetFilePointer,
    fileHandle,
    dataOffset,
    0,
    FILE_BEGIN

; 讀取色彩資料
; 為了讓資料逆向儲存 (從陣列尾開始存)
; 因此將 Index(ESI) 改為 imageSize + imageHeight (換行) - 1
mov eax, imageSize
add eax, imageHeight
dec eax
mov esi, eax
mov ecx, imageSize
lp_read_bytes:
    ; 字串分行切換
    ; 插入換行位置公式: (imageSize + imageHeight - 1 - ESI) % (imageWidth + 1) == 0
    push ecx
    mov edx, 0
    mov eax, imageSize
    add eax, imageHeight
    dec eax
    sub eax, esi
    mov ecx, imageWidth
    inc ecx
    div ecx
    cmp edx, 0
    jne continue_read
    add_newline:
        mov[byteArray + esi], 10
        dec esi
    continue_read:
    pop ecx

    ; 灰階化: 將三個顏色加總再除以 3
    ; EDI 用來暫時儲存 RGB 3 個值的合
    push ecx
    mov edi, 0
    mov ecx, 3
    lp_read_rgb:
        push ecx
        ; 讀取 RGB 三色值
        mov eax, fileHandle
        mov ecx, 1
        mov edx, OFFSET buffer
        call ReadFromFile
        ; 加總三色值，待之後灰階化
        add edi, buffer
        pop ecx
    loop lp_read_rgb

    ; 進行灰階化並儲存到 byteArray
    mov edx, 0
    mov eax, edi
    ; 這裡因為灰階化而除以 3，又因正規化除以 25
    ; 結果儲存在 EAX
    mov ecx, 75
    div ecx
    pop ecx
    mov [grayArray + ecx], al

    ; 轉換成字元並儲存 (原圖)
    mov dl, [asciiArray + eax]
    mov [byteArray + esi], dl

    dec esi
    dec ecx
    cmp ecx, 0
jne lp_read_bytes

; -----------------------------------------------------------------------------
; 關閉檔案
mov eax, fileHandle
call CloseFile

; 如果 enableResize == true 則跳過
cmp enableResize, 1
je display2xImage

display1xImage:
; -----------------------------------------------------------------------------
; 左右鏡像翻轉
; 對每列做 [ESI] 與 [EDI] 互換
; ESI 起始值為 0
mov esi, 0
mov ecx, imageHeight
lp_mirror:
    push ecx
    ; 每列 EDI 起始值為 ESI + imageWidth - 1
    mov edi, esi
    add edi, imageWidth
    dec edi
    ; 迴圈數設定 imageWidth / 2
    mov edx, 0
    mov eax, imageWidth
    mov ecx, 2
    div ecx
    mov ecx, eax
    push eax
    lp_reverse:
        mov al, [byteArray + esi]
        mov bl, [byteArray + edi]
        mov [byteArray + esi], bl
        mov [byteArray + edi], al
        inc esi
        dec edi
    loop lp_reverse
    pop eax
    add esi, eax
    inc esi
    pop ecx
loop lp_mirror

; -----------------------------------------------------------------------------
; 輸出畫面
mov edx, OFFSET byteArray
call WriteString
jmp finishProc

display2xImage:
; -----------------------------------------------------------------------------
; 圖像比例調整
; 使用線性插值法，將圖像寬度擴增成兩倍
; 將原圖填入 newGrayArray (1~5120)
mov ecx, imagesize
lp_base:
    push ecx    
    mov eax, ecx
    dec eax

    mov ebx, imageWidth
    mov edx, 0
    div ebx
    movzx eax, ax
    push edx
    push eax
    mov edx, 0
    mul ebx
    mov edx, 0
    mov ebx, 2
    mul ebx
    pop ebx
    add eax, ebx
    pop ebx
    add eax, ebx
    add eax, ebx
    mov ebx, 0
    mov bl, [grayArray + ecx]
    mov [newGrayArray + eax], bl
    mov dl, [newGrayArray + 10279]

    mov dl, [asciiArray + ebx]
    mov [newByteArray + eax], dl

    pop ecx
    dec ecx
    cmp ecx, 0
jne lp_base

mov eax, imagesize
mov edx, 0
mov ebx, 2
mul ebx
add eax, imageHeight
dec eax
mov ecx, eax
mov ebx, imagewidth
add ebx, imagewidth
inc ebx

; 進行線性插值
lp_insert: 
    push ecx
    push ebx
    mov eax, ecx
    push eax
    mov edx, 0
    div ebx
    mov ebx, imageWidth
    add ebx, imageWidth
    cmp dx, bx
    pop eax
    jne n1
        mov [newByteArray + ecx], 10
        je con
    n1:
    mov al, [newByteArray + ecx]
    cmp al, 0
    jne con
        mov eax, 0
        inc ecx
        add al, [newGrayArray + ecx]
        dec ecx
        dec ecx
        add al, [newGrayArray + ecx]
        inc ecx
        mov ebx, 2
        mov edx, 0
        div ebx
        mov bl, [asciiArray + eax]
        mov [newByteArray + ecx], bl
    con:
    pop ebx
    pop ecx
loop lp_insert

; -----------------------------------------------------------------------------
; 2X 左右鏡像翻轉
; 對每列做 [ESI] 與 [EDI] 互換
; ESI 起始值為 0
mov esi, 0
mov ecx, imageHeight
lp_2x_mirror:
    push ecx
    ; 每列 EDI 起始值為 ESI + imageWidth - 1
    mov edi, esi
    add edi, imageWidth
    add edi, imageWidth
    dec edi
    ; 迴圈數設定 imageWidth / 2
    mov edx, 0
    mov eax, imageWidth
    add eax, imageWidth
    mov ecx, 2
    div ecx
    mov ecx, eax
    push eax
    lp_2x_reverse:
        mov al, [newByteArray + esi]
        mov bl, [newByteArray + edi]
        mov [newByteArray + esi], bl
        mov [newByteArray + edi], al
        inc esi
        dec edi
    loop lp_2x_reverse
    pop eax
    add esi, eax
    inc esi
    pop ecx
loop lp_2x_mirror

; -----------------------------------------------------------------------------
; 輸出畫面
mov edx, OFFSET newByteArray
call WriteString

finishProc:
ret
displayFrame ENDP

END main