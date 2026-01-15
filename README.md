# get-stigs
get stig info from cyber.mil

Run the init file first
then run.ps1


# get-stigs


you will need the following :

Minimum required packages:

    
    
    unzip files to:
    vendor\site-packages\
        playwright (Python package)
        https://pypi.org/project/playwright/#files
        playwright-1.57.0-py3-none-win_amd64.whl
         
        pyee (dependency of playwright)
        https://pypi.org/project/pyee/#files
        pyee-13.0.0-py3-none-any.whl

        greenlet (dependency of playwright; includes compiled .pyd on Windows)
        https://pypi.org/project/greenlet/#files
        greenlet-3.3.0-cp314-cp314-win_amd64.whl

    unzip files to:
    vendor\ms-playwright\


    unzip to root:
    Python 3.14 Embedded (Windows x64)
    https://www.python.org/ftp/python/3.14.2/python-3.14.2-embed-amd64.zip





├─ .git
├─ vendor
│  ├─ ms-playwright
│  │  ├─ chromium-1200
│  │  │  └─ chrome-win64
│  │  │     ├─ chrome.exe
│  │  │     └─ (many Chromium files)
│  │  ├─ chromium_headless_shell-1200
│  │  ├─ ffmpeg-1011
│  │  └─ winldd-1007
│  │
│  └─ site-packages
│     ├─ playwright
│     ├─ playwright-1.57.0.dist-info
│     ├─ pyee
│     ├─ pyee-13.0.0.dist-info
│     ├─ greenlet
│     ├─ greenlet-3.3.0.dist-info
│     ├─ greenlet-3.3.0.data
│     └─ greenlet.libs
│
├─ python-3.14.2-embed-amd64
│  ├─ python.exe
│  ├─ python314._pth
│  └─ (standard embedded python files)
│
├─ run.py
├─ run.ps1
├─ README.md

