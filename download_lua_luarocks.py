"""
Download and extracts Lua source code and LuaRocks package manager for windows.

"""

import urllib.request
import shutil
from pathlib import Path

LUA_URL = "https://www.lua.org/ftp/lua-5.4.8.tar.gz"
LUAROCKS_URL = "https://luarocks.github.io/luarocks/releases/luarocks-3.12.2-windows-64.zip"


def download_file(url, dest):
    """Download a file from a URL to a specified destination."""
    print(f"Downloading {url} to {dest}...")
    urllib.request.urlretrieve(url, dest)
    print(f"Downloaded {dest}")

def download():
    # Create directories if they do not exist
    downloads_dir = Path("downloads")
    downloads_dir.mkdir(exist_ok=True)

    # Define file paths
    lua_file = downloads_dir / "lua-5.4.8.tar.gz"
    luarocks_file = downloads_dir / "luarocks-3.12.2-windows-64.zip"

    # Download Lua and LuaRocks
    download_file(LUA_URL, str(lua_file))
    download_file(LUAROCKS_URL, str(luarocks_file))
    return str(lua_file), str(luarocks_file)

## Extract files and move extracted folders to parent directory
def extract_file(file_path):
    """Extract a file and move the extracted contents to the parent directory."""
    file_path = Path(file_path)

    if file_path.suffix == ".gz" and file_path.stem.endswith(".tar"):
        import tarfile
        with tarfile.open(file_path, "r:gz") as tar:
            # Extract to downloads directory first
            tar.extractall(path=file_path.parent)
            print(f"Extracted {file_path} to {file_path.parent}")

            # Move extracted folders to parent directory
            for member in tar.getnames():
                if '/' not in member:  # Top-level directory
                    source = file_path.parent / member
                    dest = Path(member)
                    if source.exists() and source.is_dir():
                        if dest.exists():
                            shutil.rmtree(dest)
                        shutil.move(str(source), str(dest))
                        print(f"Moved {source} to {dest}")

    elif file_path.suffix == ".zip":
        import zipfile
        with zipfile.ZipFile(file_path, 'r') as zip_ref:
            # Extract to downloads directory first
            zip_ref.extractall(path=file_path.parent)
            print(f"Extracted {file_path} to {file_path.parent}")

            # Move extracted folders to parent directory
            extracted_items = set()
            for name in zip_ref.namelist():
                if '/' in name:
                    top_dir = name.split('/')[0]
                    extracted_items.add(top_dir)
                else:
                    extracted_items.add(name)

            for item in extracted_items:
                source = file_path.parent / item
                dest = Path(item)
                if source.exists():
                    if dest.exists():
                        if dest.is_dir():
                            shutil.rmtree(dest)
                        else:
                            dest.unlink()
                    shutil.move(str(source), str(dest))
                    print(f"Moved {source} to {dest}")
    else:
        print(f"Unsupported file format: {file_path}")


if __name__ == "__main__":
    dlds = download()
    for file in dlds:
        extract_file(file)