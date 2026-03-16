//
//  WebServerManager+HTML.swift
//  PicMate
//
//  Created by Claude on 2026/03/16.
//

import Foundation

extension WebServerManager {

    static let mainPageHTML: String = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>PicMate</title>
        <style>
            :root {
                --bg: #f2f2f7;
                --card-bg: #ffffff;
                --text: #1c1c1e;
                --text-secondary: #8e8e93;
                --accent: #007aff;
                --border: #d1d1d6;
                --hover: #e5e5ea;
                --shadow: rgba(0,0,0,0.08);
                --modal-bg: rgba(0,0,0,0.6);
            }
            @media (prefers-color-scheme: dark) {
                :root {
                    --bg: #000000;
                    --card-bg: #1c1c1e;
                    --text: #f5f5f7;
                    --text-secondary: #98989d;
                    --accent: #0a84ff;
                    --border: #38383a;
                    --hover: #2c2c2e;
                    --shadow: rgba(0,0,0,0.3);
                    --modal-bg: rgba(0,0,0,0.8);
                }
            }
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
                background: var(--bg);
                color: var(--text);
                min-height: 100vh;
            }
            .header {
                position: sticky;
                top: 0;
                z-index: 100;
                background: var(--bg);
                border-bottom: 1px solid var(--border);
                padding: 16px 24px;
                display: flex;
                align-items: center;
                justify-content: space-between;
                backdrop-filter: blur(20px);
                -webkit-backdrop-filter: blur(20px);
            }
            .header h1 {
                font-size: 24px;
                font-weight: 700;
            }
            .header-actions { display: flex; gap: 8px; }
            .btn {
                display: inline-flex;
                align-items: center;
                gap: 6px;
                padding: 8px 16px;
                border: none;
                border-radius: 8px;
                font-size: 14px;
                font-weight: 600;
                cursor: pointer;
                transition: opacity 0.15s;
            }
            .btn:hover { opacity: 0.8; }
            .btn-primary {
                background: var(--accent);
                color: white;
            }
            .breadcrumb {
                padding: 12px 24px;
                display: flex;
                align-items: center;
                gap: 4px;
                flex-wrap: wrap;
                font-size: 14px;
                color: var(--text-secondary);
            }
            .breadcrumb a {
                color: var(--accent);
                text-decoration: none;
                cursor: pointer;
            }
            .breadcrumb a:hover { text-decoration: underline; }
            .breadcrumb .separator { margin: 0 4px; }
            .content { padding: 0 24px 24px; }
            .section-title {
                font-size: 18px;
                font-weight: 600;
                margin: 20px 0 12px;
            }
            .album-grid {
                display: grid;
                grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
                gap: 16px;
            }
            .album-card {
                background: var(--card-bg);
                border-radius: 12px;
                overflow: hidden;
                cursor: pointer;
                transition: transform 0.15s, box-shadow 0.15s;
                box-shadow: 0 1px 3px var(--shadow);
            }
            .album-card:hover {
                transform: translateY(-2px);
                box-shadow: 0 4px 12px var(--shadow);
            }
            .album-cover {
                width: 100%;
                aspect-ratio: 1;
                background: var(--hover);
                display: flex;
                align-items: center;
                justify-content: center;
                overflow: hidden;
            }
            .album-cover img {
                width: 100%;
                height: 100%;
                object-fit: cover;
            }
            .album-cover .placeholder {
                font-size: 48px;
                opacity: 0.3;
            }
            .album-info {
                padding: 10px 12px;
            }
            .album-name {
                font-size: 14px;
                font-weight: 600;
                white-space: nowrap;
                overflow: hidden;
                text-overflow: ellipsis;
            }
            .album-meta {
                font-size: 12px;
                color: var(--text-secondary);
                margin-top: 2px;
            }
            .pic-grid {
                display: grid;
                grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
                gap: 8px;
            }
            .pic-thumb {
                width: 100%;
                aspect-ratio: 1;
                object-fit: cover;
                border-radius: 8px;
                cursor: pointer;
                transition: transform 0.15s, opacity 0.15s;
                background: var(--hover);
            }
            .pic-thumb:hover {
                transform: scale(1.03);
                opacity: 0.9;
            }
            .modal-overlay {
                position: fixed;
                inset: 0;
                background: var(--modal-bg);
                z-index: 200;
                display: flex;
                align-items: center;
                justify-content: center;
                opacity: 0;
                pointer-events: none;
                transition: opacity 0.2s;
            }
            .modal-overlay.active {
                opacity: 1;
                pointer-events: auto;
            }
            .viewer-content {
                position: relative;
                max-width: 90vw;
                max-height: 90vh;
                display: flex;
                flex-direction: column;
                align-items: center;
            }
            .viewer-content img {
                max-width: 90vw;
                max-height: 80vh;
                object-fit: contain;
                border-radius: 8px;
            }
            .viewer-controls {
                display: flex;
                gap: 12px;
                margin-top: 16px;
            }
            .viewer-controls .btn {
                background: rgba(255,255,255,0.2);
                color: white;
                backdrop-filter: blur(10px);
            }
            .viewer-name {
                color: white;
                font-size: 14px;
                margin-top: 8px;
                opacity: 0.8;
            }
            .upload-modal {
                background: var(--card-bg);
                border-radius: 16px;
                padding: 24px;
                max-width: 480px;
                width: 90vw;
            }
            .upload-modal h2 {
                font-size: 20px;
                margin-bottom: 16px;
            }
            .upload-drop-zone {
                border: 2px dashed var(--border);
                border-radius: 12px;
                padding: 40px 20px;
                text-align: center;
                color: var(--text-secondary);
                margin-bottom: 16px;
                transition: border-color 0.15s, background 0.15s;
            }
            .upload-drop-zone.dragover {
                border-color: var(--accent);
                background: rgba(0, 122, 255, 0.05);
            }
            .upload-drop-zone input[type="file"] {
                display: none;
            }
            .upload-drop-zone label {
                color: var(--accent);
                cursor: pointer;
                font-weight: 600;
            }
            .upload-actions {
                display: flex;
                gap: 8px;
                justify-content: flex-end;
            }
            .btn-secondary {
                background: var(--hover);
                color: var(--text);
            }
            .upload-progress {
                margin: 12px 0;
                font-size: 14px;
                color: var(--text-secondary);
            }
            .progress-bar {
                width: 100%;
                height: 4px;
                background: var(--hover);
                border-radius: 2px;
                overflow: hidden;
                margin-top: 8px;
            }
            .progress-bar-fill {
                height: 100%;
                background: var(--accent);
                transition: width 0.3s;
                width: 0%;
            }
            .empty-state {
                text-align: center;
                padding: 60px 20px;
                color: var(--text-secondary);
            }
            .empty-state .icon { font-size: 48px; margin-bottom: 12px; opacity: 0.5; }
            .empty-state p { font-size: 16px; }
            .loading {
                text-align: center;
                padding: 60px;
                color: var(--text-secondary);
            }
            @media (max-width: 600px) {
                .header { padding: 12px 16px; }
                .header h1 { font-size: 20px; }
                .breadcrumb { padding: 8px 16px; }
                .content { padding: 0 16px 16px; }
                .album-grid { grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 12px; }
                .pic-grid { grid-template-columns: repeat(auto-fill, minmax(100px, 1fr)); gap: 6px; }
            }
        </style>
    </head>
    <body>
        <div class="header">
            <h1 id="pageTitle">PicMate</h1>
            <div class="header-actions">
                <button class="btn btn-primary" id="uploadBtn" onclick="openUpload()">
                    &#x2B; Upload
                </button>
            </div>
        </div>
        <div class="breadcrumb" id="breadcrumb"></div>
        <div class="content" id="content">
            <div class="loading">Loading...</div>
        </div>

        <!-- Image Viewer Modal -->
        <div class="modal-overlay" id="viewerModal" onclick="closeViewer(event)">
            <div class="viewer-content">
                <img id="viewerImage" src="" alt="">
                <div class="viewer-name" id="viewerName"></div>
                <div class="viewer-controls">
                    <a class="btn" id="downloadLink" download>&#x21E3; Download</a>
                    <button class="btn" onclick="closeViewer()">&#x2715; Close</button>
                </div>
            </div>
        </div>

        <!-- Upload Modal -->
        <div class="modal-overlay" id="uploadModal">
            <div class="upload-modal">
                <h2>Upload Images</h2>
                <div class="upload-drop-zone" id="dropZone">
                    <p>Drag and drop images here, or</p>
                    <p><label for="fileInput">browse files</label></p>
                    <input type="file" id="fileInput" multiple accept="image/*">
                </div>
                <div id="fileList"></div>
                <div class="upload-progress" id="uploadProgress" style="display:none">
                    <span id="uploadStatusText">Uploading...</span>
                    <div class="progress-bar">
                        <div class="progress-bar-fill" id="progressBarFill"></div>
                    </div>
                </div>
                <div class="upload-actions">
                    <button class="btn btn-secondary" onclick="closeUpload()">Cancel</button>
                    <button class="btn btn-primary" id="uploadSubmitBtn" onclick="submitUpload()">Upload</button>
                </div>
            </div>
        </div>

        <script>
            // State
            let currentPath = [];
            let currentAlbumId = null;
            let selectedFiles = [];

            // Navigation
            async function loadRoot() {
                currentPath = [];
                currentAlbumId = null;
                try {
                    const resp = await fetch('/api/albums');
                    const data = await resp.json();
                    renderContent(data);
                    renderBreadcrumb();
                } catch (err) {
                    document.getElementById('content').innerHTML =
                        '<div class="empty-state"><p>Failed to load. Please try again.</p></div>';
                }
            }

            async function loadAlbum(id, name) {
                try {
                    const resp = await fetch('/api/albums/' + encodeURIComponent(id));
                    const data = await resp.json();
                    currentPath.push({ id: id, name: name });
                    currentAlbumId = id;
                    renderContent(data);
                    renderBreadcrumb();
                } catch (err) {
                    document.getElementById('content').innerHTML =
                        '<div class="empty-state"><p>Failed to load album.</p></div>';
                }
            }

            function navigateTo(index) {
                if (index < 0) {
                    loadRoot();
                } else {
                    currentPath = currentPath.slice(0, index);
                    const target = currentPath[currentPath.length - 1];
                    if (target) {
                        currentAlbumId = target.id;
                        // Re-fetch instead of caching
                        currentPath.pop();
                        loadAlbum(target.id, target.name);
                    } else {
                        loadRoot();
                    }
                }
            }

            // Rendering
            function renderBreadcrumb() {
                const el = document.getElementById('breadcrumb');
                let html = '<a onclick="navigateTo(-1)">Collection</a>';
                currentPath.forEach((item, i) => {
                    html += '<span class="separator">/</span>';
                    if (i === currentPath.length - 1) {
                        html += '<span>' + escapeHtml(item.name) + '</span>';
                    } else {
                        html += '<a onclick="navigateTo(' + i + ')">' + escapeHtml(item.name) + '</a>';
                    }
                });
                el.innerHTML = html;
            }

            function renderContent(data) {
                const el = document.getElementById('content');
                let html = '';

                const hasAlbums = data.albums && data.albums.length > 0;
                const hasPics = data.pics && data.pics.length > 0;

                if (!hasAlbums && !hasPics) {
                    html = '<div class="empty-state"><div class="icon">&#x1F5BC;</div><p>No albums or pics here yet.</p></div>';
                    el.innerHTML = html;
                    return;
                }

                if (hasAlbums) {
                    html += '<div class="section-title">Albums</div>';
                    html += '<div class="album-grid">';
                    data.albums.forEach(album => {
                        const coverUrl = album.hasCover
                            ? '/api/albums/' + encodeURIComponent(album.id) + '/cover'
                            : '';
                        const coverHtml = coverUrl
                            ? '<img src="' + coverUrl + '" alt="" loading="lazy">'
                            : '<div class="placeholder">&#x1F4C1;</div>';
                        let metaParts = [];
                        if (album.albumCount > 0) metaParts.push(album.albumCount + ' album' + (album.albumCount !== 1 ? 's' : ''));
                        if (album.picCount > 0) metaParts.push(album.picCount + ' pic' + (album.picCount !== 1 ? 's' : ''));
                        const meta = metaParts.join(', ') || 'Empty';
                        html += '<div class="album-card" onclick="loadAlbum(\\'';
                        html += escapeJs(album.id);
                        html += '\\', \\'';
                        html += escapeJs(album.name);
                        html += '\\')">';
                        html += '<div class="album-cover">' + coverHtml + '</div>';
                        html += '<div class="album-info">';
                        html += '<div class="album-name">' + escapeHtml(album.name) + '</div>';
                        html += '<div class="album-meta">' + escapeHtml(meta) + '</div>';
                        html += '</div></div>';
                    });
                    html += '</div>';
                }

                if (hasPics) {
                    html += '<div class="section-title">Pics</div>';
                    html += '<div class="pic-grid">';
                    data.pics.forEach(pic => {
                        const thumbUrl = '/api/pics/' + encodeURIComponent(pic.id) + '/thumbnail';
                        html += '<img class="pic-thumb" src="' + thumbUrl + '" ';
                        html += 'alt="' + escapeHtml(pic.name) + '" ';
                        html += 'loading="lazy" ';
                        html += 'onclick="openViewer(\\'';
                        html += escapeJs(pic.id);
                        html += '\\', \\'';
                        html += escapeJs(pic.name);
                        html += '\\')">';
                    });
                    html += '</div>';
                }

                el.innerHTML = html;
            }

            // Image Viewer
            function openViewer(picId, picName) {
                const modal = document.getElementById('viewerModal');
                const img = document.getElementById('viewerImage');
                const name = document.getElementById('viewerName');
                const dl = document.getElementById('downloadLink');
                const fullUrl = '/api/pics/' + encodeURIComponent(picId) + '/image';
                img.src = fullUrl;
                name.textContent = picName;
                dl.href = fullUrl;
                dl.download = picName;
                modal.classList.add('active');
                document.body.style.overflow = 'hidden';
            }

            function closeViewer(event) {
                if (event && event.target !== event.currentTarget) return;
                const modal = document.getElementById('viewerModal');
                modal.classList.remove('active');
                document.getElementById('viewerImage').src = '';
                document.body.style.overflow = '';
            }

            // Upload
            function openUpload() {
                document.getElementById('uploadModal').classList.add('active');
                document.getElementById('fileInput').value = '';
                document.getElementById('fileList').innerHTML = '';
                document.getElementById('uploadProgress').style.display = 'none';
                document.getElementById('uploadSubmitBtn').disabled = false;
                selectedFiles = [];
                document.body.style.overflow = 'hidden';
            }

            function closeUpload() {
                document.getElementById('uploadModal').classList.remove('active');
                document.body.style.overflow = '';
                selectedFiles = [];
            }

            // Drop zone
            const dropZone = document.getElementById('dropZone');
            dropZone.addEventListener('dragover', (e) => {
                e.preventDefault();
                dropZone.classList.add('dragover');
            });
            dropZone.addEventListener('dragleave', () => {
                dropZone.classList.remove('dragover');
            });
            dropZone.addEventListener('drop', (e) => {
                e.preventDefault();
                dropZone.classList.remove('dragover');
                if (e.dataTransfer.files.length > 0) {
                    selectedFiles = Array.from(e.dataTransfer.files);
                    updateFileList();
                }
            });
            document.getElementById('fileInput').addEventListener('change', (e) => {
                selectedFiles = Array.from(e.target.files);
                updateFileList();
            });

            function updateFileList() {
                const el = document.getElementById('fileList');
                if (selectedFiles.length === 0) {
                    el.innerHTML = '';
                    return;
                }
                el.innerHTML = '<p style="font-size:14px;color:var(--text-secondary);margin:8px 0">'
                    + selectedFiles.length + ' file' + (selectedFiles.length !== 1 ? 's' : '') + ' selected</p>';
            }

            async function submitUpload() {
                if (selectedFiles.length === 0) return;

                const btn = document.getElementById('uploadSubmitBtn');
                const progress = document.getElementById('uploadProgress');
                const statusText = document.getElementById('uploadStatusText');
                const progressFill = document.getElementById('progressBarFill');

                btn.disabled = true;
                progress.style.display = 'block';
                statusText.textContent = 'Uploading...';
                progressFill.style.width = '0%';

                const formData = new FormData();
                for (const file of selectedFiles) {
                    formData.append('file', file);
                }

                const url = currentAlbumId
                    ? '/api/albums/' + encodeURIComponent(currentAlbumId) + '/upload'
                    : '/api/upload';

                try {
                    const resp = await fetch(url, { method: 'POST', body: formData });
                    const result = await resp.json();
                    progressFill.style.width = '100%';
                    statusText.textContent = result.uploaded + ' image' + (result.uploaded !== 1 ? 's' : '') + ' uploaded!';
                    setTimeout(() => {
                        closeUpload();
                        if (currentAlbumId) {
                            const name = currentPath.length > 0 ? currentPath[currentPath.length - 1].name : 'Album';
                            currentPath.pop();
                            loadAlbum(currentAlbumId, name);
                        } else {
                            loadRoot();
                        }
                    }, 1000);
                } catch (err) {
                    statusText.textContent = 'Upload failed. Please try again.';
                    btn.disabled = false;
                }
            }

            // Utilities
            function escapeHtml(str) {
                const div = document.createElement('div');
                div.textContent = str;
                return div.innerHTML;
            }
            function escapeJs(str) {
                return str.replace(/\\\\/g, '\\\\\\\\').replace(/'/g, "\\\\'");
            }

            // Keyboard
            document.addEventListener('keydown', (e) => {
                if (e.key === 'Escape') {
                    closeViewer();
                    closeUpload();
                }
            });

            // Init
            loadRoot();
        </script>
    </body>
    </html>
    """
}
