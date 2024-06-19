Ubuntu 24.04 VM Reset Command:
# 使用curl下載腳本並運行
curl -fsSL https://raw.githubusercontent.com/leonoxo/reset_vm/main/reset_vm_ubuntu.sh | bash

curl -fsSL 這四個參數字母代表以下意思：

	•	-f: Fail silently. 當 HTTP 狀態碼大於或等於 400 時，curl 會退出並不會輸出錯誤信息到標準輸出。這樣可以避免下載失敗時顯示錯誤頁面的 HTML 內容。
	•	-s: Silent mode. 使 curl 在執行過程中不顯示進度條或錯誤信息。這樣可以使輸出更加簡潔。
	•	-S: Show error. 配合 -s 使用，使 curl 在 silent 模式下如果出錯仍然顯示錯誤信息。
	•	-L: Location. 如果下載的 URL 有重定向 (3XX 狀態碼)，curl 會跟隨重定向 URL。

組合起來，curl -fsSL 的作用是：

	•	安靜地下載文件，不顯示進度條。
	•	在遇到 HTTP 錯誤時，退出並顯示錯誤信息。
	•	跟隨任何重定向。

這些選項結合使用時，可以更可靠地從 URL 下載文件，並在出現問題時給出適當的錯誤信息。

完整的命令用於直接下載並執行腳本：
