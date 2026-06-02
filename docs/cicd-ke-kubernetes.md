# Tugas 7 — Integrasi CI/CD Pipeline ke Kubernetes
**Kelompok 1 - DevOps**

Modul ini mendokumentasikan integrasi pipeline CI/CD (Continuous Integration & Continuous Deployment) menggunakan GitHub Actions dengan cluster Kubernetes (Minikube). Pipeline ini mengotomatiskan proses pengujian kode, pembangunan container image, pengunggahan ke GitHub Container Registry (GHCR), hingga rolling update aplikasi di klaster production secara otomatis tanpa downtime (*zero-downtime rolling update*).

---

## 1. Diagram Alur Deploy (Workflow CI/CD)

Berikut adalah visualisasi alur kerja otomatis dari saat developer melakukan push kode hingga aplikasi terbarui secara otomatis di klaster Kubernetes:

```mermaid
graph TD
    A[Developer Push Kode ke Main] -->|Trigger| B[GitHub Actions Runner]
    
    subgraph CI Job (build)
        B --> C[Checkout Code]
        C --> D[Setup Go & Run dependencies]
        D --> E[Lari Linting: go vet]
        E --> F[Unit Test & Integration Test dengan Postgres]
        F --> G[Pemeriksaan Coverage Gate >= 75%]
        G --> H[Build Docker Image Multi-Stage]
        H --> I[Push Docker Image ke GHCR dengan Tag Commit SHA]
    end
    
    I -->|needs: build| J[CD Job (deploy)]
    
    subgraph CD Job (deploy)
        J --> K[Setup Kubectl]
        K --> L[Decode KUBECONFIG_BASE64 ke ~/.kube/config]
        L --> M[Jalankan: kubectl set image deployment/taskflow-api]
        M --> N[Verifikasi: kubectl rollout status]
    end
    
    N --> O[Aplikasi Terupdate di Cluster Kubernetes! (Zero-Downtime)]
    
    style CI Job fill:#e1f5fe,stroke:#039be5,stroke-width:2px;
    style CD Job fill:#e8f5e9,stroke:#43a047,stroke-width:2px;
    style A fill:#fff9c4,stroke:#fbc02d,stroke-width:2px;
    style O fill:#ffe0b2,stroke:#f57c00,stroke-width:2px;
```

---

## 2. Panduan Setup Kubeconfig sebagai GitHub Secret

Untuk mengizinkan GitHub Actions berkomunikasi dengan klaster Kubernetes lokal (Minikube) Anda, silakan ikuti langkah-langkah berikut:

1. **Export file kubeconfig ke format base64**:
   Jalankan perintah ini di terminal lokal Anda (PowerShell/Bash) untuk mendapatkan nilai base64 dari file config Kubernetes Anda:
   ```bash
   # Windows PowerShell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\.kube\config"))
   
   # Linux / macOS Bash
   cat ~/.kube/config | base64 | tr -d '\n'
   ```
   > [!IMPORTANT]
   > Nilai base64 yang dihasilkan di atas sangat sensitif. Pastikan tidak membagikannya ke publik.

2. **Simpan sebagai GitHub Secret**:
   - Buka repositori kelompok Anda di GitHub.
   - Pergi ke menu **Settings** → **Secrets and variables** → **Actions**.
   - Klik tombol **New repository secret**.
   - Beri nama secret: `KUBECONFIG_BASE64`.
   - Paste nilai base64 yang Anda dapatkan di langkah 1 ke dalam kolom **Value**.
   - Klik **Add secret**.

3. **Pengaturan Akses Pull Image (GHCR)**:
   - **Opsi A (Rekomendasi untuk Lab)**: Buka profil GitHub Anda, masuk ke **Packages**, pilih image repository `kelompok1-kubernetes`, buka **Package Settings**, lalu ubah visibilitasnya menjadi **Public**. Hal ini memudahkan klaster Kubernetes untuk langsung melakukan pull image tanpa kredensial tambahan.
   - **Opsi B (Rekomendasi untuk Production)**: Membuat Personal Access Token (PAT) dengan scope `read:packages`, lalu buat Kubernetes Secret di namespace `taskflow-prod` dengan perintah:
     ```bash
     kubectl create secret docker-registry ghcr-secret \
       --docker-server=ghcr.io \
       --docker-username=<github-username> \
       --docker-password=<personal-access-token> \
       -n taskflow-prod
     ```
     Kemudian tambahkan `imagePullSecrets` pada `kubernetes/deployment.yaml` di bawah bagian `spec.template.spec`:
     ```yaml
     imagePullSecrets:
       - name: ghcr-secret
     ```

---

## 3. Hasil Pengujian Pipeline (Screenshot)

> [!TIP]
> *Silakan masukkan tangkapan layar (screenshot) hasil eksekusi pipeline Anda pada bagian di bawah ini setelah pipeline berhasil dijalankan di GitHub Actions Anda.*

### A. Screenshot Pipeline GitHub Actions yang Berhasil

Berikut adalah tangkapan layar status pipeline GitHub Actions yang sukses menjalankan seluruh rangkaian `build` (CI) dan `deploy` (CD):

`<!-- MASUKKAN SCREENSHOT PIPELINE DI SINI, CONTOH: ![GitHub Actions Success](./images/github-actions-success.png) -->`

### B. Screenshot Hasil `kubectl get pods` dengan Image Baru

Berikut adalah hasil perintah `kubectl get pods -n taskflow-prod -o wide` yang memperlihatkan bahwa Pod lama telah sepenuhnya digantikan oleh Pod baru yang berjalan di atas image aplikasi Go dengan tag commit SHA yang baru:

`<!-- MASUKKAN SCREENSHOT KUBECTL GET PODS DI SINI, CONTOH: ![Kubectl Pods Success](./images/kubectl-get-pods.png) -->`

---

## 4. Jawaban Pertanyaan Evaluasi

### Pertanyaan 1: Apa dampaknya jika job `build` gagal dalam sebuah pipeline?
**Jawaban:**
Jika job `build` gagal (misalnya karena kesalahan kompilasi kode, kegagalan unit test/integration test, atau coverage yang kurang dari 75%):
1. **Pipeline Terhenti Seketika**: Pipeline akan langsung menandai build tersebut sebagai *Failed* (merah).
2. **CD/Deploy Tidak Dieksekusi**: Karena ada dependensi `needs: build`, job `deploy` tidak akan pernah dijalankan jika job `build` tidak sukses.
3. **Mencegah Kerusakan di Production**: Ini bertindak sebagai **Quality Gate (Gerbang Kualitas)** yang krusial. Sistem memastikan kode yang rusak, mengandung bug kritis, atau belum lulus uji keamanan (SAST/SCA) **tidak akan pernah dideploy ke server production**, sehingga menjaga ketersediaan (*availability*) aplikasi bagi pengguna.

---

### Pertanyaan 2: Mengapa kita perlu menggunakan properti `needs: build` pada job `deploy`?
**Jawaban:**
Properti `needs: build` mendefinisikan hubungan ketergantungan (dependensi) antar job dalam Directed Acyclic Graph (DAG) GitHub Actions. Alasan pentingnya adalah:
1. **Urutan Logis (Sequential Execution)**: Proses deployment memerlukan artefak yang valid (Docker image yang sudah ter-push ke GHCR). Job `deploy` tidak boleh berjalan sebelum Docker image tersebut sukses dibuat dan diunggah oleh job `build`.
2. **Kemanan Lingkungan Terdepan**: Tanpa `needs: build`, job `build` dan `deploy` akan berjalan secara paralel. Hal ini dapat mengakibatkan server production ter-deploy menggunakan kode lama atau bahkan error karena mencoba menarik image yang belum selesai dibuat. Properti ini menjamin bahwa hanya kode yang **100% tervalidasi dan aman** yang masuk ke klaster Kubernetes.

---

### Pertanyaan 3: Apa perbedaan utama antara pendekatan deploy otomatis ini dengan pendekatan deploy manual (misalnya menjalankan perintah `kubectl` dari laptop)?
**Jawaban:**

Berikut adalah tabel komparasi komprehensif antara pendekatan deploy manual dan deploy otomatis melalui CI/CD:

| Parameter Evaluasi | Pendekatan Deploy Manual (Laptop Developer) | Pendekatan Deploy Otomatis (CI/CD Pipeline) |
| :--- | :--- | :--- |
| **Kecepatan & Efisiensi** | Lambat dan tidak konsisten. Developer harus manual login, melakukan push, lalu menjalankan perintah shell. | Sangat cepat dan instan. Cukup dengan melakukan `git push`, sistem otomatis menangani semuanya. |
| **Resiko Human Error** | **Tinggi**. Rentan terhadap salah ketik perintah (*typo*), salah environment namespace, atau lupa menjalankan test sebelum deploy. | **Sangat Rendah**. Seluruh langkah didefinisikan secara deklaratif di file YAML sehingga eksekusinya selalu konsisten. |
| **Keamanan & Kredensial** | **Berisiko**. Kredensial cluster (`kubeconfig`) harus disimpan di banyak laptop developer lokal, memperluas *attack surface*. | **Sangat Aman**. Kredensial disimpan terpusat dan terenkripsi sebagai GitHub Secrets. Developer tidak memiliki akses langsung ke kredensial prod. |
| **Standardisasi & Audit Trail** | Sulit dilacak. Tidak ada riwayat lengkap siapa yang melakukan perubahan dan apakah kode tersebut sudah lulus uji coba atau belum. | Sangat jelas. Setiap deployment terikat langsung dengan *commit SHA* dan *author* di Git. Semua log pipeline tercatat di GitHub Actions. |
| **Kolaborasi Tim** | Sulit. Anggota tim lain tidak tahu status rilis terakhir kecuali dikabari secara manual oleh developer yang bersangkutan. | Sangat mudah. Seluruh tim dapat memantau status rilis secara transparan melalui dashboard GitHub. |

---

## 5. Kesimpulan
Integrasi CI/CD dengan GitHub Actions ke Kubernetes memberikan jaminan *reliability* yang sangat tinggi bagi TaskFlow Inc. Dengan otomatisasi ini, developer cukup fokus menulis kode, sementara sistem secara mandiri memastikan kualitas, keamanan, keandalan build, dan melakukan pembaruan di server produksi secara mulus tanpa downtime.
