# Dokumentasi Insiden 2 — Rolling Update Tanpa Downtime

## Kronologi Insiden Asli

> **Insiden 2** — Saat deploy fitur baru, aplikasi mati 8 menit. Terjadi pas jam sibuk. Klien tidak senang.

**Akar Masalah**: Proses deploy lama dilakukan dengan cara stop container → pull image baru → run container baru. Selama jeda ini tidak ada container yang melayani request.

---

## Solusi: Kubernetes Rolling Update

Dengan strategi `RollingUpdate` dan `maxUnavailable: 0`, Kubernetes **tidak pernah mematikan Pod lama sebelum Pod baru siap**. Traffic selalu ada yang melayani.

Konfigurasi di `kubernetes/deployment.yaml`:
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # Boleh buat 1 Pod ekstra sementara
    maxUnavailable: 0  # JANGAN matikan Pod lama sebelum yang baru siap
```

Urutan proses:
```
Awal:   [Pod v1] [Pod v1]
Step 1: [Pod v1] [Pod v1] [Pod v2]  ← buat Pod baru dulu
Step 2: [Pod v1] [Pod v2]           ← matikan 1 Pod lama (v2 sudah Ready)
Step 3: [Pod v2] [Pod v2]           ← selesai
```

---

## Langkah Demonstrasi

### Terminal 1 — Loop Request (Windows PowerShell)

Jalankan script ini dan biarkan terus berjalan:

```powershell
$url = (minikube service taskflow-api -n taskflow-prod --url)
while ($true) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2
        Write-Host "$timestamp — HTTP $($resp.StatusCode) — OK" -ForegroundColor Green
    } catch {
        Write-Host "$timestamp — HTTP Error / Down!" -ForegroundColor Red
    }
    Start-Sleep -Seconds 0.5
}
```

### Terminal 2 — Lakukan Update

Edit `kubernetes/deployment.yaml` — ubah `args` atau environment variable untuk membedakan v2, lalu:

```bash
kubectl apply -f kubernetes/deployment.yaml
kubectl rollout status deployment/taskflow-api -n taskflow-prod
```

---

## Hasil yang Diharapkan

Terminal 1 menampilkan **hanya baris hijau** selama proses update berlangsung:

```
08:45:00 — HTTP 200 — OK
08:45:01 — HTTP 200 — OK   ← update dimulai di sini
08:45:01 — HTTP 200 — OK
08:45:02 — HTTP 200 — OK   ← Pod lama diganti Pod baru
08:45:02 — HTTP 200 — OK
08:45:03 — HTTP 200 — OK   ← update selesai
```

> **Tidak ada satu pun baris merah (error).** Pengguna tidak merasakan gangguan.

---

## Perbandingan

| | Cara Lama | Dengan Kubernetes |
|--|-----------|-------------------|
| Proses deploy | Stop → Pull → Run | Rolling (Pod baru dulu, baru Pod lama dihapus) |
| Downtime | 8 menit | **0 detik** |
| Request yang gagal | Semua request selama 8 menit | **0 request gagal** |
| Perlu koordinasi | Harus pilih waktu sepi | Bisa kapan saja |

**Kesimpulan**: Insiden 2 tidak akan terjadi lagi. Deploy bisa dilakukan kapan saja tanpa mematikan layanan.
