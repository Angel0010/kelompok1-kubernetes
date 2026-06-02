## Anggota Kelompok 1 DevOps

| No | Nama | NRP |
|----|------|------|
| 1 | Angella Christie | 5027221047 |
| 2 | Muhammad Rifqi Oktaviansyah | 5027221067 |



## Konteks
TaskFlow Inc. masih menjalankan semua container secara manual di satu server. CTO menceritakan tiga insiden yang terjadi bulan lalu:

Insiden 1 — Container crash jam 02.15 malam. Tidak ada yang tahu sampai klien komplain jam 08.30 pagi. Downtime 6 jam lebih.

Insiden 2 — Saat deploy fitur baru, aplikasi mati 8 menit. Terjadi pas jam sibuk. Klien tidak senang.

Insiden 3 — Versi baru punya bug kritis. Rollback manual memakan 25 menit: SSH ke server, stop container, pull image lama, jalankan ulang.

Tugas kelompok kalian: pindahkan TaskFlow ke Kubernetes dan buktikan bahwa ketiga insiden itu tidak akan terjadi lagi.

## Tugas 1 — Siapkan Namespace

Buat dua namespace untuk memisahkan environment:

```bash
kubectl create namespace taskflow-dev
kubectl create namespace taskflow-prod
```

Simpan juga sebagai file YAML agar bisa dibuat ulang dari Git:

```bash
apiVersion: v1
kind: Namespace
metadata:
  name: taskflow-dev
```

## Tugas 2 — Deploy ke Production

Buat `deployment.yaml` dengan ketentuan:

- `replicas: 2` di namespace `prod`
- Rolling update strategy dengan `maxUnavailable: 0`
- Gunakan image dari hasil CI/CD pipeline modul 9, atau gunakan hashicorp/http-echo sebagai placeholder
- Buat `service.yaml` dengan tipe NodePort.

Deploy ke namespace prod:
```bash
kubectl apply -f deployment.yaml -n taskflow-prod
kubectl apply -f service.yaml -n taskflow-prod

# Verifikasi semua berjalan
kubectl get all -n taskflow-prod
```

## Tugas 3 — Jawaban untuk Insiden 1 (Self-Healing)
Demonstrasikan self-healing. Lakukan dan dokumentasikan langkah berikut:

1. Buka dua terminal
2. Terminal 1: `kubectl get pods -n taskflow-prod -w`
3. Terminal 2: hapus salah satu Pod
4. Ukur waktu dari Pod dihapus hingga Pod baru `Running`

Simpan screenshot dan catat waktunya. Insiden 1 tidak akan terjadi lagi karena Kubernetes langsung membuat Pod baru tanpa menunggu ada orang yang datang ke kantor.

## Screenshoot hasil (nanti benerin lagi yaa, biar dokumentasinya jelas)
# Hasil tugas 1

Membuat namespace development:

```bash
kubectl apply -f namespace-dev.yaml
```

Membuat namespace production:

```bash
kubectl apply -f namespace-prod.yaml
```

Melihat daftar namespace:

```bash
kubectl get namespace
```

<img width="1470" height="406" alt="image" src="https://github.com/user-attachments/assets/b041ecda-750b-493e-943e-bcd32203fadd" />

Namespace `taskflow-dev` dan `taskflow-prod` berhasil dibuat dan aktif di dalam cluster Kubernetes.

# Hasil Tugas 2

Deploy deployment.yaml:

```bash
kubectl apply -f deployment.yaml -n taskflow-prod
```

Deploy service.yaml:

```bash
kubectl apply -f service.yaml -n taskflow-prod
```

Verifikasi resource Kubernetes:

```bash
kubectl get all -n taskflow-prod
```

<img width="1693" height="585" alt="image" src="https://github.com/user-attachments/assets/5f4e4dc4-8e7d-487c-b503-45de12648dae" />

Mengakses aplikasi:

```bash
minikube service taskflow-api -n taskflow-prod --url
```

<img width="1832" height="111" alt="image" src="https://github.com/user-attachments/assets/efea7919-03a7-4cf0-952d-25434335e7a5" />
Output aplikasi:

`
Halo dari TaskFlow Production!
`
<img width="2178" height="993" alt="Screenshot 2026-05-25 185811" src="https://github.com/user-attachments/assets/d3b2582a-901e-45ad-9bb4-e6e7af310072" />

# Hasil Tugas 3

Memantau Pod secara realtime:
```bash
kubectl get pods -n taskflow-prod -w
```

Menghapus salah satu Pod:

Ganti `<nama-pod>` dengan nama Pod yang muncul pada hasil:

```bash
kubectl delete pod <nama-pod> -n taskflow-prod
```
<img width="2732" height="885" alt="image" src="https://github.com/user-attachments/assets/038d4881-b882-437c-a916-69964c597727" />

Pod dihapus dan Kubernetes berhasil membuat Pod baru dengan status Running dalam waktu sekitar 7 detik.

# Hasil Tugas 4 

Menjalankan script loop request di Terminal 1 yang mengarah ke URL `http://127.0.0.1:56102`:
```
while ($true) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    try {
        # Menggunakan URL yang kamu dapatkan dari minikube tadi
        $resp = Invoke-WebRequest -Uri "http://127.0.0.1:56102" -UseBasicParsing -TimeoutSec 2
        Write-Host "$timestamp — HTTP $($resp.StatusCode) — $($resp.Content.Trim())" -ForegroundColor Green
    } catch {
        Write-Host "$timestamp — HTTP Error atau Down!" -ForegroundColor Red
    }
    Start-Sleep -Seconds 0.5
}
```

Mengubah argumen teks `deployment.yaml` menjadi versi 2:
```
# kubernetes/deployment.yaml (Edit di bagian args)
          args:
            - "-text=Halo dari TaskFlow Production v2! Fitur Baru Berhasil Deploy!"
            - "-listen=:8080"
```

Melakukan `kubectl apply -f kubernetes/deployment.yaml -n taskflow-prod` di Terminal 2

<img width="1919" height="1052" alt="image" src="https://github.com/user-attachments/assets/66fa4da5-4b07-4aa1-86b0-58a17d5d9d83" />

Berhasil mengupdate versi tanpa adanya downtime (dapat dilihat pada http status code nya).

# Hasil Tugas 5 
Memeriksa riwayat revisi deployment:
```
kubectl rollout history deployment/taskflow-api -n taskflow-prod
```

Melakukan rollback otomatis:
```
kubectl rollout undo deployment/taskflow-api -n taskflow-prod
```
| Parameter | Manajemen Tradisional (Cara Lama) | Dengan Manajemen Kubernetes |
| :--- | :--- | :--- |
| **Langkah Kerja** | Harus SSH ke server -> stop container -> manual pull image lama -> run ulang dengan parameter konfigurasi manual. | Cukup menjalankan satu baris perintah pemulihan (`kubectl rollout undo`). |
| **Waktu Pemulihan** | Memakan waktu ± 25 Menit. | Super instan, selesai dalam waktu < 1 Detik. |
| **Tingkat Risiko** | **Tinggi**, karena rentan terjadi kesalahan pengetikan manual manusia (*human error*) saat konfigurasi ulang di server. | **Rendah**, karena otomatis dikelola oleh state internal cluster Kubernetes yang sudah terekam dengan aman. |

# Hasil Tugas 6
Mendeploy aplikasi ke namespace `taskflow-dev`:
```
kubectl apply -f kubernetes/deployment.yaml -n taskflow-dev
```

Menghapus seluruh pod yang ada di namespace `dev`:
```
kubectl delete pods --all -n taskflow-dev
```

Memeriksa status pod di prod:
```
kubectl get pods -n taskflow-prod
```
Akses URL aplikasi prod:
```
(Invoke-WebRequest -Uri "http://127.0.0.1:40908" -UseBasicParsing).Content.Trim()
```
Output aplikasi 
`
Halo dari TaskFlow Production!
`

<img width="1917" height="1071" alt="image" src="https://github.com/user-attachments/assets/1f81282f-f766-4505-b33d-b74587ac64da" />

Meskipun seluruh Pod di namespace `taskflow-dev` telah dihapus, seluruh Pod di namespace `taskflow-prod` terpantau tetap berjalan (Running) dengan aman, dan aplikasi tetap dapat diakses oleh pengguna tanpa gangguan.
