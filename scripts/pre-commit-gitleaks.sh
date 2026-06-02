#!/bin/sh
# ── Pre-commit Hook: Gitleaks Secret Scanning ──
# 
# Instalasi:
#   cp scripts/pre-commit-gitleaks.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit
#
# Atau gunakan symlink:
#   ln -sf ../../scripts/pre-commit-gitleaks.sh .git/hooks/pre-commit
#
# Prerequisite: Install gitleaks
#   brew install gitleaks        (macOS)
#   choco install gitleaks       (Windows)
#   apt install gitleaks         (Linux/Debian)
#   go install github.com/gitleaks/gitleaks/v8@latest  (Go)

echo "Running Gitleaks pre-commit scan..."

# Scan hanya file yang di-stage (bukan seluruh repo)
gitleaks protect --staged --redact --exit-code 1

if [ $? -ne 0 ]; then
  echo ""
  echo "❌ COMMIT BLOCKED: Secrets terdeteksi di staged files!"
  echo ""
  echo "Langkah perbaikan:"
  echo "  1. Hapus secrets dari kode"
  echo "  2. Gunakan environment variables (.env) sebagai gantinya"
  echo "  3. Pastikan .env sudah ada di .gitignore"
  echo ""
  echo "Untuk bypass (TIDAK DISARANKAN):"
  echo "  git commit --no-verify"
  echo ""
  exit 1
fi

echo "No secrets detected. Commit allowed."
