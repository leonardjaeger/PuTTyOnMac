# Gemeinsame Umgebung der M0-Skripte (wird mit "." eingebunden).
# cmake/gpg können über Homebrew oder die CMake-App kommen; wir nutzen sie nur zum Bauen, nichts davon landet in der App.
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:/Applications/CMake.app/Contents/bin"
PUTTY_TARBALL="Quellen/putty-0.85.tar.gz"
PUTTY_SHA256="13fd4db2936d03b73812a7bcc2a658e4dd29cc776a56c3670a7fc6f1a0ee8af8"
PUTTY_SRC="build/putty-src"
PUTTY_BUILD="build/putty-bau"
