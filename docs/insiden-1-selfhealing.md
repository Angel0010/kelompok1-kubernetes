# Dokumentasi Insiden 1 — Self-Healing

## Kronologi Insiden Asli

> **Insiden 1** — Container crash jam 02.15 malam. Tidak ada yang tahu sampai klien komplain jam 08.30 pagi. Downtime 6 jam lebih.

**Akar Masalah**: Tidak ada mekanisme otomatis yang memonitor dan me-restart container yang crash. Sistem bergantung sepenuhnya pada intervensi manual.

---

## Solusi: Kubernetes Self-Healing via Deployment

Kubernetes **Deployment** secara terus-menerus memantau jumlah Pod yang berjalan. Jika sebuah Pod mati (crash, OOMKilled, dsb.), Deployment controller langsung membuat Pod pengganti **tanpa campur tangan manusia**.

---

## Langkah Demonstrasi

### Persiapan
```bash
# Pastikan 2 Pod berjalan di prod
kubectl get pods -n taskflow-prod
```

### Langkah 1 — Buka dua terminal

**Terminal 1** — Pantau Pod secara real-time:
```bash
kubectl get pods -n taskflow-prod -w
```

**Terminal 2** — Catat nama Pod dan hapus salah satunya:
```bash
# Ambil nama Pod pertama
POD_NAME=$(kubectl get pods -n taskflow-prod -o jsonpath='{.items[0].metadata.name}')
echo "Menghapus Pod: $POD_NAME"

# Catat waktu sebelum hapus
date +%H:%M:%S

# Hapus Pod (simulasi crash)
kubectl delete pod $POD_NAME -n taskflow-prod

# Catat waktu Pod baru Running
date +%H:%M:%S
```

### Langkah 2 — Amati di Terminal 1

Output yang muncul:
```
NAME                            READY   STATUS    RESTARTS   AGE
taskflow-api-xxx-aaa            1/1     Running   0          5m
taskflow-api-xxx-bbb            1/1     Running   0          5m
taskflow-api-xxx-aaa            1/1     Terminating   0       5m   ← Pod dihapus
taskflow-api-xxx-ccc            0/1     Pending       0       0s   ← Pod baru dibuat
taskflow-api-xxx-ccc            0/1     ContainerCreating   0  0s
taskflow-api-xxx-ccc            1/1     Running       0       7s   ← Pod baru Running!
```

---

## Hasil Pengukuran

| Metrik | Nilai |
|--------|-------|
| Waktu deteksi crash | < 1 detik |
| Waktu Pod baru `Running` | **~7 detik** |
| Total downtime untuk pengguna | ~0 detik (Pod lain tetap melayani) |

> Karena `replicas: 2`, saat Pod pertama dihapus, Pod kedua tetap melayani traffic. Pengguna **tidak merasakan gangguan sama sekali**.

---

## Perbandingan

| | Cara Lama (Manual) | Dengan Kubernetes |
|--|----|----|
| Deteksi crash | Menunggu laporan klien (~6 jam) | Otomatis < 1 detik |
| Restart container | Manual oleh engineer | Otomatis oleh Kubernetes |
| Downtime | 6+ jam | 0 detik (multi-replica) |
| Intervensi manusia | Wajib | Tidak diperlukan |

**Kesimpulan**: Insiden 1 tidak akan terjadi lagi. Kubernetes langsung membuat Pod baru tanpa menunggu ada orang yang datang ke kantor.
