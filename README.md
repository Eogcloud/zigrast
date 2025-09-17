# 🚀 ZigRast – Software Renderer

ZigRast is a **software rendering engine** built for learning, experimentation, and fun.  
It focuses on understanding the fundamentals of rendering pipelines by implementing them from scratch.  

---

## ✨ Features
- 🖼️ **Custom rendering pipeline** (no GPU acceleration)
- 🎨 Configurable window + rendering settings via `launchSettings.json`
- ⚡ Written with performance and simplicity in mind
- 📚 Educational resource for graphics programming

---

## 📂 Project Structure
zigrast/  
├── src/                # Core source files  
├── include/            # Headers / public interfaces  
├── assets/             # Textures, models, etc.  
└── launchSettings.json # Config file for window + renderer  

---

## 🔧 Getting Started

### 1. Clone the repository
git clone https://github.com/Eogcloud/zigrast.git  
cd zigrast  

### 2. Build
zig build  

### 3. Run
./zig-out/bin/zigrast  

---

## 🛠️ Configuration
You can configure window size, vsync, and rendering options in:

```json
{
  "window": {
    "width": 1920,
    "height": 1080,
    "title": "ZigRast - Software Renderer",
    "resizable": true,
    "vsync": true
  },
  "rendering": {
    "clear_color": [0, 17, 34]
  }
}
````
