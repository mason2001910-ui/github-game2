# 月光球場 Moonlight Rally

一款給小學生玩的排球 × 生活理財網頁小遊戲。玩家在兩個回合中練習預算分配、儲蓄、分散投資與風險觀念；答對互動題並完成排球挑戰即可取得關卡鑰匙，最後查看每關得分與理財進步成果。

## 直接遊玩

此 repo 以 GitHub Pages 發佈。若要在本機預覽已匯出的版本，請用支援 WebAssembly 的靜態 HTTP 伺服器提供 repo 根目錄；不要直接以 `file://` 開啟 `index.html`。

## 使用 Godot 重建網頁版

需要 Godot 4.7.x 與 Web export templates。Windows 可執行：

```powershell
./scripts/build-web.ps1
```

也可指定 Godot 執行檔：

```powershell
$env:GODOT_EXE = "C:\Godot.exe\Godot_v4.7.2-stable_win64.exe"
./scripts/build-web.ps1
```

匯出會更新根目錄的 `index.html` 和配套 `.js`、`.wasm`、`.pck` 等靜態檔案。

## 3D 球場來源

- `source_art/dreamcourt.blend`：可在 Blender 編輯的原始場景。
- `assets/dreamcourt.glb`：Godot 與網頁遊戲使用的球場模型。
- `assets/dreamcourt-preview.png`：球場預覽圖。
- `assets/create_dreamcourt.py`：重新產生模型的 Blender Python 腳本。
- `assets/fonts/NotoSansTC-VF.ttf`：Noto Sans TC 繁體中文字型，依 SIL Open Font License 1.1 隨遊戲散佈；授權見 `assets/fonts/OFL.txt`。

## GitHub Pages

推送至 `main` 分支後，`.github/workflows/pages.yml` 會自動將 repo 根目錄部署到 GitHub Pages。第一次部署若尚未啟用 Pages，請在 repo 的 **Settings → Pages → Build and deployment** 將來源設為 **GitHub Actions**。
