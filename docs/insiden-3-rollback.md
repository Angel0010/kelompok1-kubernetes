# Dokumentasi Insiden 3 — Rollback Cepat

## Kronologi Insiden Asli

> **Insiden 3** — Versi baru punya bug kritis. Rollback manual memakan 25 menit: SSH ke server, stop container, pull image lama, jalankan ulang.

**Akar Masalah**: Tidak ada sistem versioning yang siap pakai. Rollback manual = banyak langkah = banyak peluang human error = lama.

---

## Solusi: Kubernetes Rollout History & Undo

Kubernetes menyimpan **riwayat setiap Deployment**. Rollback ke versi sebelumnya cukup dengan **satu perintah**.

---

## Langkah Demonstrasi

### Langkah 1 — Lihat Riwayat Deployment

```bash
kubectl rollout history deployment/taskflow-api -n taskflow-prod
```

Output contoh:
```
REVISION  CHANGE-CAUSE
1         <none>    ← versi awal (v1)
2         <none>    ← versi setelah rolling update (v2)
```

### Langkah 2 — Catat Waktu Mulai Rollback

```bash
echo "Rollback dimulai: $(date +%H:%M:%S)"
```

### Langkah 3 — Eksekusi Rollback (1 Perintah!)

```bash
kubectl rollout undo deployment/taskflow-api -n taskflow-prod
```

### Langkah 4 — Pantau Hingga Selesai

```bash
kubectl rollout status deployment/taskflow-api -n taskflow-prod
echo "Rollback selesai: $(date +%H:%M:%S)"
```

### Langkah 5 — Verifikasi

```bash
# Cek revisi sekarang kembali ke 1
kubectl rollout history deployment/taskflow-api -n taskflow-prod

# Test endpoint masih berfungsi
curl http://$(minikube ip):30080/health
```

---

## Hasil Pengukuran

| Metrik | Nilai |
|--------|-------|
| Waktu total rollback | **< 60 detik** |
| Jumlah perintah yang dieksekusi | **1** (`kubectl rollout undo`) |
| Downtime selama rollback | **0 detik** (rolling process) |

---

## Perbandingan

| Parameter | Manajemen Tradisional (Cara Lama) | Dengan Kubernetes |
|:---|:---|:---|
| **Langkah Kerja** | SSH → stop container → manual pull image lama → run ulang dengan parameter konfigurasi manual | Cukup satu baris perintah (`kubectl rollout undo`) |
| **Waktu Pemulihan** | ± 25 Menit | **< 60 detik** |
| **Tingkat Risiko** | **Tinggi** — rentan human error saat konfigurasi ulang manual | **Rendah** — otomatis dikelola oleh state internal cluster |
| **Ketersediaan Service** | Down selama proses rollback | **Tetap up** (rolling rollback) |
| **Audit Trail** | Tidak ada | `kubectl rollout history` mencatat semua revisi |

**Kesimpulan**: Insiden 3 tidak akan terjadi lagi. Rollback dapat dilakukan dalam hitungan detik tanpa engineer harus SSH ke server di tengah malam.
